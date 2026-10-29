import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/permissions.dart';
import '../repositories/api/auth_api.dart';

/// Сессия пользователя: токены, профиль, роль, ограничения времени.
///
/// В localStorage лежат токены и профиль (для отрисовки интерфейса).
/// Роль из профиля — только удобство: её можно поправить в DevTools,
/// но сервер берёт роль из подписанного токена и всё равно ответит 403.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(
    this._prefs,
    this._api, {
    this.inactivityTimeout = const Duration(minutes: 3),
    this.maxSession = const Duration(hours: 1),
  });

  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser = 'auth_user';
  static const _kStarted = 'auth_session_started';
  static const _kActivity = 'auth_last_activity';

  final SharedPreferences _prefs;
  final AuthApi _api;

  /// Выход по бездействию.
  final Duration inactivityTimeout;

  /// Ограничение общей длительности сессии — независимо от активности.
  final Duration maxSession;

  AppUser? _user;
  String? _accessToken;
  String? _logoutReason;
  Future<bool>? _refreshing;
  Timer? _sessionTimer;
  DateTime _lastActivitySaved = DateTime.fromMillisecondsSinceEpoch(0);

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null;
  Role? get role => _user?.role;

  /// Почему сессия завершилась — показывается на экране входа.
  String? get logoutReason => _logoutReason;

  bool can(Operation operation) =>
      permissions[operation]?.contains(role) ?? false;

  /// Восстановление сессии при запуске приложения.
  /// Вызывается один раз до построения дерева виджетов.
  Future<void> restore() async {
    final access = _prefs.getString(_kAccess);
    final refresh = _prefs.getString(_kRefresh);
    if (access == null) return;

    // Неактивность отслеживается и через перезагрузку: время последнего
    // действия хранится в localStorage.
    final lastActivity = DateTime.tryParse(_prefs.getString(_kActivity) ?? '');
    if (lastActivity != null &&
        DateTime.now().difference(lastActivity) > inactivityTimeout) {
      await logout(reason: 'Сеанс завершён из-за бездействия.');
      return;
    }
    final started = DateTime.tryParse(_prefs.getString(_kStarted) ?? '');
    if (started != null && DateTime.now().difference(started) > maxSession) {
      await logout(reason: 'Время сеанса истекло. Войдите снова.');
      return;
    }

    _accessToken = access;
    _user = _cachedUser();
    try {
      final me = await _api.me(access); // токен ещё жив
      // Профиль для интерфейса берётся из сохранённых данных, если они есть:
      // это видно в пункте 17 — правка роли в DevTools меняет кнопки,
      // но не права на сервере.
      _user ??= me;
    } on UnauthorizedException {
      if (refresh != null) {
        try {
          await _refreshWith(refresh); // токен истёк, обновляем
        } catch (_) {
          await logout(reason: 'Сессия истекла. Войдите снова.');
        }
      } else {
        await logout();
      }
    } catch (_) {
      // Сервер недоступен: сессию не сбрасываем, покажем ошибку позже.
    }
    _startSessionTimer(started ?? DateTime.now());
    notifyListeners();
  }

  AppUser? _cachedUser() {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String username, String password) async {
    await _apply(await _api.login(username.trim(), password), newSession: true);
  }

  Future<void> register({
    required String username,
    required String name,
    required String password,
  }) async {
    await _apply(
      await _api.register(
          username: username.trim(), name: name.trim(), password: password),
      newSession: true,
    );
  }

  Future<void> _apply(AuthResult result, {required bool newSession}) async {
    _accessToken = result.accessToken;
    _user = result.user;
    _logoutReason = null;
    await _prefs.setString(_kAccess, result.accessToken);
    await _prefs.setString(_kRefresh, result.refreshToken);
    await _prefs.setString(_kUser, jsonEncode(result.user.toJson()));
    if (newSession) {
      final now = DateTime.now();
      await _prefs.setString(_kStarted, now.toIso8601String());
      await _prefs.setString(_kActivity, now.toIso8601String());
      _startSessionTimer(now);
    }
    notifyListeners();
  }

  Future<void> _refreshWith(String refresh) async {
    final result = await _api.refresh(refresh);
    _accessToken = result.accessToken;
    await _prefs.setString(_kAccess, result.accessToken);
    await _prefs.setString(_kRefresh, result.refreshToken);
    _user ??= result.user;
  }

  /// Обновление токена для интерсептора. Несколько запросов, получивших 401
  /// одновременно, ждут одного обновления. false — обновить не удалось.
  Future<bool> refreshTokens() {
    return _refreshing ??= () async {
      try {
        final refresh = _prefs.getString(_kRefresh);
        if (refresh == null) return false;
        await _refreshWith(refresh);
        return true;
      } catch (_) {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  /// Любое действие пользователя. Время пишется в localStorage не чаще раза в 10 с.
  void touch() {
    final now = DateTime.now();
    if (now.difference(_lastActivitySaved) < const Duration(seconds: 10)) {
      return;
    }
    _lastActivitySaved = now;
    _prefs.setString(_kActivity, now.toIso8601String());
  }

  void _startSessionTimer(DateTime started) {
    _sessionTimer?.cancel();
    final left = maxSession - DateTime.now().difference(started);
    _sessionTimer = Timer(left.isNegative ? Duration.zero : left, () {
      logout(
          reason:
              'Время сеанса истекло (${maxSession.inMinutes} мин). Войдите снова.');
    });
  }

  Future<void> logout({String? reason}) async {
    _sessionTimer?.cancel();
    _user = null;
    _accessToken = null;
    _logoutReason = reason;
    for (final key in [_kAccess, _kRefresh, _kUser, _kStarted, _kActivity]) {
      await _prefs.remove(key);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
