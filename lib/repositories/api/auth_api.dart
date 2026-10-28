import 'package:dio/dio.dart';

import '../../core/api_exceptions.dart';
import '../../core/config.dart';
import '../../models/app_user.dart';

/// Ответ на вход, регистрацию и обновление токена.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Object? data) {
    if (data is! Map) throw const ServerException('Сервер вернул данные в неверном формате.');
    return AuthResult(
      accessToken: '${data['accessToken']}',
      refreshToken: '${data['refreshToken']}',
      user: AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
    );
  }

  final String accessToken;
  final String refreshToken;
  final AppUser user;
}

/// Эндпоинты /auth/*. Свой Dio без интерсептора обновления токена:
/// иначе неудачное обновление (401) снова запускало бы обновление — бесконечный цикл.
class AuthApi {
  AuthApi({Dio? dio, String baseUrl = apiBaseUrl})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Content-Type': 'application/json'},
            ));

  final Dio _dio;

  /// Пароль уходит как есть: хеширует его сервер. Хеш на клиенте
  /// стал бы просто новым паролем.
  Future<AuthResult> login(String username, String password) => guard(() async =>
      AuthResult.fromJson((await _dio.post<Object?>('/auth/login',
              data: {'username': username, 'password': password}))
          .data));

  Future<AuthResult> register({
    required String username,
    required String name,
    required String password,
  }) =>
      guard(() async => AuthResult.fromJson((await _dio.post<Object?>(
              '/auth/register',
              data: {'username': username, 'name': name, 'password': password}))
          .data));

  Future<AuthResult> refresh(String refreshToken) => guard(() async =>
      AuthResult.fromJson((await _dio.post<Object?>('/auth/refresh',
              data: {'refreshToken': refreshToken}))
          .data));

  Future<AppUser> me(String accessToken) => guard(() async {
        final response = await _dio.get<Object?>('/auth/me',
            options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
        final data = response.data;
        if (data is! Map) throw const ServerException('Сервер вернул данные в неверном формате.');
        return AppUser.fromJson(Map<String, dynamic>.from(data));
      });
}
