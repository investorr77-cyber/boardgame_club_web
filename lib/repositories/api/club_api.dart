import 'package:dio/dio.dart';

import '../../core/api_exceptions.dart';
import '../../models/app_user.dart';
import '../../models/loan.dart';

List<Map<String, dynamic>> _items(Object? data) {
  if (data is! Map || data['items'] is! List) {
    throw const ServerException('Сервер вернул данные в неверном формате.');
  }
  return [
    for (final item in data['items'] as List)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

/// Выдачи коробок: свои — участнику, все — сотруднику.
class LoanApi {
  LoanApi(this._dio);

  final Dio _dio;

  Future<List<Loan>> mine() => guard(() async =>
      _items((await _dio.get<Object?>('/loans', queryParameters: {'mine': true})).data)
          .map(Loan.fromJson)
          .toList());

  Future<List<Loan>> all({bool activeOnly = false}) => guard(() async => _items((await _dio
              .get<Object?>('/loans', queryParameters: {if (activeOnly) 'active': true}))
          .data)
      .map(Loan.fromJson)
      .toList());

  Future<Loan> issue({required int gameId, required int userId}) => guard(() async =>
      Loan.fromJson(Map<String, dynamic>.from((await _dio
              .post<Object?>('/loans', data: {'gameId': gameId, 'userId': userId}))
          .data as Map)));

  Future<void> close(int id) => guard(() => _dio.post<Object?>('/loans/$id/close'));

  Future<void> extend(int id) => guard(() => _dio.post<Object?>('/loans/$id/extend'));

  /// Участники с ролью member — для оформления выдачи.
  Future<List<AppUser>> readers() => guard(() async =>
      _items((await _dio.get<Object?>('/readers')).data).map(AppUser.fromJson).toList());
}

/// Администрирование: пользователи, роли, статистика.
class AdminApi {
  AdminApi(this._dio);

  final Dio _dio;

  Future<List<AppUser>> users() => guard(() async =>
      _items((await _dio.get<Object?>('/admin/users')).data).map(AppUser.fromJson).toList());

  Future<AppUser> setRole(int userId, Role role) => guard(() async => AppUser.fromJson(
      Map<String, dynamic>.from((await _dio
              .put<Object?>('/admin/users/$userId', data: {'role': role.name}))
          .data as Map)));

  Future<Map<String, Object?>> stats() => guard(() async {
        final data = (await _dio.get<Object?>('/admin/stats')).data;
        if (data is! Map) throw const ServerException('Сервер вернул данные в неверном формате.');
        return Map<String, Object?>.from(data);
      });

  Future<void> resetData() => guard(() => _dio.post<Object?>('/__reset'));
}
