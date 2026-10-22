import 'json_read.dart';

/// Издатель. Связь один ко многим с BoardGame (у игры ровно один издатель).
class Publisher {
  const Publisher({
    required this.id,
    required this.name,
    required this.country,
    required this.foundedYear,
    this.email = '',
    this.deletedAt,
  });

  factory Publisher.fromJson(Map<String, dynamic> json) => Publisher(
        id: readInt(json['id']),
        name: readString(json['name']),
        country: readString(json['country']),
        foundedYear: readInt(json['foundedYear']),
        email: readString(json['email']),
        deletedAt: readDate(json['deletedAt']),
      );

  final int id;
  final String name;
  final String country;
  final int foundedYear;

  /// Контактная почта, необязательна.
  final String email;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'country': country,
        'foundedYear': foundedYear,
        'email': email,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  Publisher copyWith({
    int? id,
    String? name,
    String? country,
    int? foundedYear,
    String? email,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Publisher(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      foundedYear: foundedYear ?? this.foundedYear,
      email: email ?? this.email,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
