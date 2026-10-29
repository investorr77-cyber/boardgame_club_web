import 'package:dio/dio.dart';

import '../../core/api_exceptions.dart';
import '../../models/app_user.dart';
import '../../models/loan.dart';
import '../api/club_api.dart';

List<Map<String, dynamic>> _rows(Object? data) => [
      if (data is List)
        for (final item in data)
          if (item is Map) Map<String, dynamic>.from(item),
    ];

const _profile = 'id,username,name,role';

/// Выдачи в Supabase. Таблица loans открыта только для чтения (RLS: участник
/// видит свои строки, сотрудник и администратор — все); выдача, возврат
/// и продление — функции базы с проверкой роли.
class SupabaseLoanApi implements LoanApi {
  SupabaseLoanApi(this._dio);

  final Dio _dio;

  // game и user — один ко многим: у выдачи одна игра и один пользователь.
  static const _select = 'id,gameId:game_id,userId:user_id,issuedAt:issued_at,'
      'dueDate:due_date,returnedAt:returned_at,extensions,'
      'game:games(title),user:profiles(name)';

  static Loan _loan(Map<String, dynamic> row) {
    final due = DateTime.tryParse('${row['dueDate']}');
    return Loan.fromJson({
      ...row,
      'gameTitle': (row['game'] as Map?)?['title'],
      'userName': (row['user'] as Map?)?['name'],
      'overdue': row['returnedAt'] == null &&
          due != null &&
          due.isBefore(DateTime.now()),
    });
  }

  Future<List<Loan>> _list(Map<String, dynamic> where) => guard(() async {
        final response = await _dio.get<Object?>('/loans', queryParameters: {
          'select': _select,
          ...where,
          'order': 'issued_at.desc',
        });
        return _rows(response.data).map(_loan).toList();
      });

  /// Фильтр по пользователю не нужен: чужие выдачи участнику не отдаст RLS.
  @override
  Future<List<Loan>> mine() => _list(const {});

  @override
  Future<List<Loan>> all({bool activeOnly = false}) =>
      _list({if (activeOnly) 'returned_at': 'is.null'});

  @override
  Future<Loan> issue({required int gameId, required int userId}) =>
      guard(() async {
        final id = (await _dio.post<Object?>('/rpc/issue_loan',
                data: {'p_game': gameId, 'p_user': userId}))
            .data;
        final list = await _list({'id': 'eq.$id'});
        if (list.isEmpty) throw const NotFoundException();
        return list.first;
      });

  @override
  Future<void> close(int id) =>
      guard(() => _dio.post<Object?>('/rpc/close_loan', data: {'p_id': id}));

  @override
  Future<void> extend(int id) =>
      guard(() => _dio.post<Object?>('/rpc/extend_loan', data: {'p_id': id}));

  @override
  Future<List<AppUser>> readers() => guard(() async {
        final response = await _dio.get<Object?>('/profiles', queryParameters: {
          'select': _profile,
          'role': 'eq.member',
          'order': 'name.asc',
        });
        return _rows(response.data).map(AppUser.fromJson).toList();
      });
}

/// Администрирование: пользователи и роли (profiles), статистика.
class SupabaseAdminApi implements AdminApi {
  SupabaseAdminApi(this._dio);

  final Dio _dio;

  @override
  Future<List<AppUser>> users() => guard(() async {
        final response = await _dio.get<Object?>('/profiles',
            queryParameters: {'select': _profile, 'order': 'id.asc'});
        return _rows(response.data).map(AppUser.fromJson).toList();
      });

  /// Политика profiles_update пропускает только администратора.
  @override
  Future<AppUser> setRole(int userId, Role role) => guard(() async {
        final response = await _dio.patch<Object?>('/profiles',
            queryParameters: {'select': _profile, 'id': 'eq.$userId'},
            data: {'role': role.name},
            options: Options(headers: {'Prefer': 'return=representation'}));
        final list = _rows(response.data);
        if (list.isEmpty) throw const ForbiddenException();
        return AppUser.fromJson(list.first);
      });

  @override
  Future<Map<String, Object?>> stats() => guard(() async {
        final data = (await _dio.post<Object?>('/rpc/club_stats')).data;
        if (data is! Map) {
          throw const ServerException(
              'Сервер вернул данные в неверном формате.');
        }
        return Map<String, Object?>.from(data);
      });

  /// Начальный набор данных возвращает функция базы reset_demo.
  @override
  Future<void> resetData() =>
      guard(() => _dio.post<Object?>('/rpc/reset_demo'));
}
