import 'app_user.dart';

/// Операции приложения. Таблица прав ниже повторяет таблицу сервера
/// (server/auth.js). На клиенте это удобство интерфейса — скрыть то,
/// что всё равно не разрешат; настоящая проверка выполняется на сервере.
enum Operation {
  viewCatalog,
  viewOwnLoans,
  extendLoan,
  editCatalog,
  softDelete,
  viewMembers,
  manageMembers,
  issueLoans,
  hardDelete,
  restore,
  manageUsers,
  viewStats,
}

/// Три роли с различающимся набором функций (а не с разным объёмом одного и того же):
/// участник — свои выдачи, сотрудник — каталог и выдачи, администратор —
/// пользователи, физическое удаление, восстановление и статистика.
const Map<Operation, Set<Role>> permissions = {
  Operation.viewCatalog: {Role.member, Role.staff, Role.admin},
  Operation.viewOwnLoans: {Role.member},
  Operation.extendLoan: {Role.member},
  Operation.editCatalog: {Role.staff},
  Operation.softDelete: {Role.staff},
  Operation.viewMembers: {Role.staff, Role.admin},
  Operation.manageMembers: {Role.staff},
  Operation.issueLoans: {Role.staff},
  Operation.hardDelete: {Role.admin},
  Operation.restore: {Role.admin},
  Operation.manageUsers: {Role.admin},
  Operation.viewStats: {Role.admin},
};

bool can(Role? role, Operation operation) =>
    role != null && (permissions[operation]?.contains(role) ?? false);

/// Какое право нужно, чтобы открыть адрес. Null — адрес публичный
/// (вход, регистрация).
Operation? operationForPath(String path) {
  if (path == '/login' || path == '/register') return null;
  final segments = Uri.parse(path).pathSegments;
  if (segments.isEmpty) return Operation.viewCatalog;
  final last = segments.last;
  if (segments.first == 'admin') {
    return segments.length > 1 && segments[1] == 'stats'
        ? Operation.viewStats
        : Operation.manageUsers;
  }
  if (segments.first == 'my-loans') return Operation.viewOwnLoans;
  if (segments.first == 'loans') return Operation.issueLoans;
  final isForm = last == 'new' || last == 'edit';
  if (segments.first == 'members') {
    return isForm ? Operation.manageMembers : Operation.viewMembers;
  }
  return isForm ? Operation.editCatalog : Operation.viewCatalog;
}

/// Решение маршрутизатора: null — переход разрешён, иначе адрес перенаправления.
String? authRedirect({required Role? role, required Uri uri}) {
  final path = uri.path;
  final isPublic = path == '/login' || path == '/register';
  // Не вошёл и идёт на закрытый экран — на вход, запомнив, куда он хотел попасть.
  if (role == null) {
    return isPublic ? null : '/login?from=${Uri.encodeComponent(uri.toString())}';
  }
  // Уже вошёл и идёт на экран входа — на главную.
  if (isPublic) return '/';
  if (path == '/forbidden') return null;
  final operation = operationForPath(path);
  if (operation != null && !can(role, operation)) {
    return '/forbidden?from=${Uri.encodeComponent(path)}';
  }
  return null;
}
