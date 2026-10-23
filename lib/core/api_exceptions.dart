import 'package:dio/dio.dart';

// Исключения предметной области. Виджеты не знают о Dio: между сетевым слоем
// и остальным приложением стоит этот набор собственных исключений.

sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Нет соединения, таймаут, сервер недоступен, заблокировано CORS.
class NetworkException extends ApiException {
  const NetworkException([super.message = 'Сервер недоступен. Проверьте соединение.']);
}

/// 401 — не аутентифицирован либо срок действия токена истёк.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

/// 403 — роль не позволяет выполнить операцию.
class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Недостаточно прав для этого действия.']);
}

/// 404.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

/// 409 — нарушено ограничение целостности.
class ConflictException extends ApiException {
  const ConflictException(super.message);
}

/// 422 — ошибки валидации по полям. Ключи совпадают с именами полей модели.
class ValidationException extends ApiException {
  const ValidationException(super.message, this.errors);

  final Map<String, String> errors;
}

/// 5xx.
class ServerException extends ApiException {
  const ServerException([super.message = 'Ошибка на сервере. Попробуйте позже.']);
}

/// Код ответа и тело → исключение предметной области.
ApiException mapHttpError(int status, dynamic body) {
  final message =
      (body is Map && body['message'] is String) ? body['message'] as String : null;

  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(message ?? 'Недостаточно прав для этого действия.'),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
        message ?? 'Ошибка валидации',
        (body is Map && body['errors'] is Map)
            ? (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v'))
            : const {},
      ),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

/// DioException → исключение предметной области.
ApiException mapDioError(DioException e) {
  // Если исключение уже разобрал интерсептор, повторно его не разбираем.
  // Без этой проверки ошибка 422 пришла бы в приложение как ServerException,
  // и обработчик `on ValidationException` никогда не сработал бы.
  final existing = e.error;
  if (existing is ApiException) return existing;

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      const NetworkException('Сервер не ответил вовремя.'),
    DioExceptionType.connectionError => const NetworkException(
        'Не удалось соединиться с сервером. '
        'Если сервер запущен, откройте консоль браузера и проверьте наличие ошибки CORS.',
      ),
    DioExceptionType.cancel => const NetworkException('Запрос отменён.'),
    DioExceptionType.badResponse when e.response != null =>
      mapHttpError(e.response!.statusCode ?? 500, e.response!.data),
    _ => const ServerException(),
  };
}

/// Каждое обращение к сети оборачивается в guard: наружу не выходит
/// ни один DioException — только исключения предметной области.
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
