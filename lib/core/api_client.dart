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
///
/// Для Supabase: [headers] — ключ проекта `apikey`, [errorMapper] разбирает
/// коды ошибок PostgreSQL, [simulateOnClient] — сбой имитируется без запроса
/// (PostgREST принял бы `__fail` за фильтр по несуществующему столбцу).
Dio buildDio({
  String baseUrl = apiBaseUrl,
  Map<String, String> headers = const {},
  ApiException Function(int status, dynamic body) errorMapper = mapHttpError,
  bool simulateOnClient = false,
  String? Function()? tokenProvider,
  Future<bool> Function()? refreshSession,
  void Function()? onSessionExpired,
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
      headers: {'Content-Type': 'application/json', ...headers},
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
        final fail = simulateFailure?.call() ?? false;
        if (fail && simulateOnClient) {
          return handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            error: const ServerException(
                'Сымитированная ошибка сервера (код 500).'),
          ));
        }
        options.queryParameters = {
          ...options.queryParameters,
          ...params,
          if (fail) '__fail': 500,
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
        // acceptStatus — код, который вызывающий код разбирает сам
        // (416 у PostgREST: страница за пределами выборки).
        if (status >= 400 &&
            response.requestOptions.extra['acceptStatus'] != status) {
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
              error: errorMapper(status, response.data),
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

        // 401: токен истёк прямо во время работы. Молча обновляем его
        // и повторяем запрос; не получилось — выводим из системы.
        // Условие !path.contains('/auth/') обязательно: без него неудачный
        // вход с кодом 401 запускал бы обновление токена, то вернуло бы 401 —
        // и получился бы бесконечный цикл. Флаг refreshed не даёт повторять
        // один и тот же запрос больше одного раза.
        if (error.response?.statusCode == 401 &&
            refreshSession != null &&
            !options.path.contains('/auth/') &&
            options.extra['refreshed'] != true) {
          if (await refreshSession()) {
            options.extra['refreshed'] = true;
            if (kDebugMode) {
              debugPrint('[API] токен обновлён, повтор ${options.uri}');
            }
            try {
              return handler.resolve(await dio.fetch(options));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          onSessionExpired?.call();
          return handler.next(error);
        }

        final attempt = (options.extra['attempt'] as int?) ?? 1;
        // Повтор — только для чтения: повторять создание записи нельзя.
        if (options.method == 'GET' &&
            _isNetworkFailure(error) &&
            attempt < maxAttempts) {
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
          debugPrint(
              '[API] сбой ${options.method} ${options.uri}: ${error.type}');
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
