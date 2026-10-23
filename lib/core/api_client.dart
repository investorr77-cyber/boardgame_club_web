import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // kDebugMode, debugPrint

import 'api_exceptions.dart';
import 'config.dart';

/// Настроенный клиент Dio.
///
/// [tokenProvider] — токен для заголовка Authorization (появится вместе со входом).
/// [simulateFailure] — переключатель «Сымитировать ошибку»: добавляет к запросам
/// `__fail=500`. Параметры `__fail` и `__delay` из адреса страницы
/// (`/games?__delay=1500`) тоже передаются серверу.
Dio buildDio({
  String baseUrl = apiBaseUrl,
  String? Function()? tokenProvider,
  bool Function()? simulateFailure,
  Map<String, String>? debugParams,
  int maxAttempts = 3,
  Duration retryDelay = const Duration(milliseconds: 400),
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      // Не бросать исключение на кодах 4xx — разберём их сами.
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  final params = debugParams ?? _pageDebugParams();

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.queryParameters = {
          ...options.queryParameters,
          ...params,
          if (simulateFailure?.call() ?? false) '__fail': 500,
        };
        if (kDebugMode) debugPrint('[API] → ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (kDebugMode) {
          debugPrint('[API] ← $status ${response.requestOptions.method} '
              '${response.requestOptions.uri}');
        }
        // Коды 4xx попадают сюда, а не в onError, из-за validateStatus.
        if (status >= 400) {
          // Просто написать `throw mapHttpError(...)` нельзя: dio перехватит
          // любое исключение из интерсептора и завернёт его в DioException
          // с типом unknown, а наш ValidationException окажется спрятан
          // внутри поля error. Поэтому отправляем ответ по ветке ошибок сами,
          // приложив уже разобранное исключение.
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        // Сюда приходят сетевые сбои, таймауты, коды 5xx
        // и всё, что отклонил обработчик выше.
        final options = error.requestOptions;
        final attempt = (options.extra['attempt'] as int?) ?? 1;
        // Повтор — только для чтения: повторять создание записи нельзя.
        if (options.method == 'GET' && _isNetworkFailure(error) && attempt < maxAttempts) {
          final wait = retryDelay * (1 << (attempt - 1)); // нарастающая пауза
          if (kDebugMode) {
            debugPrint('[API] повтор $attempt/${maxAttempts - 1} через '
                '${wait.inMilliseconds} мс: ${options.uri}');
          }
          await Future<void>.delayed(wait);
          options.extra['attempt'] = attempt + 1;
          try {
            return handler.resolve(await dio.fetch(options));
          } on DioException catch (e) {
            return handler.next(e);
          }
        }
        if (kDebugMode) {
          debugPrint('[API] сбой ${options.method} ${options.uri}: ${error.type}');
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}

bool _isNetworkFailure(DioException e) =>
    e.error is! ApiException &&
    switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        true,
      _ => false,
    };

/// `__fail` и `__delay` из адреса страницы — для проверки состояний ошибки и загрузки.
Map<String, String> _pageDebugParams() {
  if (!kIsWeb) return const {};
  final query = Uri.base.queryParameters;
  return {
    for (final key in const ['__fail', '__delay'])
      if (query[key] case final String value) key: value,
  };
}
