import 'json_read.dart';

/// Роли клуба. Наборы функций у них разные — см. permissions.dart.
enum Role {
  member('участник клуба'),
  staff('сотрудник клуба'),
  admin('администратор');

  const Role(this.title);

  final String title;

  /// Неизвестная роль из ответа — самая слабая, а не исключение.
  static Role parse(Object? value) =>
      Role.values.firstWhere((r) => r.name == value, orElse: () => Role.member);
}

/// Пользователь, вошедший в систему.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: readInt(json['id']),
        username: readString(json['username']),
        name: readString(json['name']),
        role: Role.parse(json['role']),
      );

  final int id;
  final String username;
  final String name;
  final Role role;

  Map<String, dynamic> toJson() =>
      {'id': id, 'username': username, 'name': name, 'role': role.name};

  AppUser copyWith({Role? role}) =>
      AppUser(id: id, username: username, name: name, role: role ?? this.role);
}
