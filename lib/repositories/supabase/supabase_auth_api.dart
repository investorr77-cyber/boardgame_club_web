import 'package:dio/dio.dart';

import '../../core/api_exceptions.dart';
import '../../core/config.dart';
import '../../models/app_user.dart';
import '../api/auth_api.dart';

/// Вход и регистрация через Supabase Auth (GoTrue, /auth/v1).
///
/// Supabase хранит пароль (bcrypt) и выдаёт подписанный JWT на час
/// и refresh-токен. Роль берётся не из токена, а из таблицы profiles:
/// её читают политики RLS через функцию my_role().
class SupabaseAuthApi implements AuthApi {
  SupabaseAuthApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: supabaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Content-Type': 'application/json',
                'apikey': supabaseKey
              },
            ));

  final Dio _dio;

  /// Логин без «@» → служебный адрес (Supabase Auth входит по почте).
  static String emailFor(String login) {
    final value = login.trim().toLowerCase();
    return value.contains('@') ? value : '$value@$loginEmailDomain';
  }

  @override
  Future<AuthResult> login(String username, String password) =>
      _session(() => _dio.post<Object?>('/auth/v1/token',
          queryParameters: {'grant_type': 'password'},
          data: {'email': emailFor(username), 'password': password}));

  @override
  Future<AuthResult> register({
    required String username,
    required String name,
    required String password,
  }) =>
      _session(() => _dio.post<Object?>('/auth/v1/signup', data: {
            'email': emailFor(username),
            'password': password,
            // Попадает в raw_user_meta_data: из него триггер создаёт профиль.
            'data': {'username': username, 'name': name},
          }));

  @override
  Future<AuthResult> refresh(String refreshToken) =>
      _session(() => _dio.post<Object?>('/auth/v1/token',
          queryParameters: {'grant_type': 'refresh_token'},
          data: {'refresh_token': refreshToken}));

  /// Профиль и роль текущего пользователя — функция базы me().
  @override
  Future<AppUser> me(String accessToken) async {
    try {
      final response = await _dio.post<Object?>('/rest/v1/rpc/me',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      final data = response.data;
      if (data is! Map) {
        throw const UnauthorizedException('Профиль пользователя не найден.');
      }
      return AppUser.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<AuthResult> _session(
      Future<Response<Object?>> Function() request) async {
    try {
      final data = (await request()).data;
      if (data is! Map || data['access_token'] is! String) {
        // Ответ без сессии: в проекте включено подтверждение почты.
        throw const ConflictException(
            'Регистрация принята, но вход невозможен: в Supabase включено '
            'подтверждение почты (Authentication → Sign In / Providers).');
      }
      final access = data['access_token'] as String;
      return AuthResult(
        accessToken: access,
        refreshToken: '${data['refresh_token']}',
        user: await me(access),
      );
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// Ошибки GoTrue: `{error_code: 'invalid_credentials', msg: ...}`.
  static ApiException _map(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) return mapDioError(e);
    final body = e.response?.data;
    final code = body is Map
        ? '${body['error_code'] ?? body['error'] ?? body['code'] ?? ''}'
        : '';
    return switch (code) {
      'invalid_credentials' ||
      'invalid_grant' when status == 400 =>
        const UnauthorizedException('Неверный логин или пароль.'),
      'refresh_token_not_found' ||
      'refresh_token_already_used' ||
      'session_not_found' =>
        const UnauthorizedException('Сессия истекла. Войдите снова.'),
      'user_already_exists' || 'email_exists' => const ValidationException(
          'Логин уже занят', {'username': 'Такой логин уже занят'}),
      'weak_password' => const ValidationException(
          'Слабый пароль', {'password': 'Пароль слишком простой'}),
      'email_address_invalid' => const ValidationException(
          'Недопустимый логин', {'username': 'Недопустимый логин'}),
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' =>
        const ConflictException('Слишком много попыток. Подождите минуту.'),
      _ when status == 401 || status == 403 =>
        const UnauthorizedException('Сессия истекла. Войдите снова.'),
      _ => mapHttpError(status, body),
    };
  }
}
