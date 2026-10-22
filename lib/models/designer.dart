import 'json_read.dart';

/// Автор настольных игр (аналог Author). Связь многие ко многим с BoardGame.
class Designer {
  const Designer({
    required this.id,
    required this.lastName,
    required this.firstName,
    required this.country,
    required this.birthYear,
    this.deletedAt,
  });

  factory Designer.fromJson(Map<String, dynamic> json) => Designer(
        id: readInt(json['id']),
        lastName: readString(json['lastName']),
        firstName: readString(json['firstName']),
        country: readString(json['country']),
        birthYear: readInt(json['birthYear']),
        deletedAt: readDate(json['deletedAt']),
      );

  final int id;
  final String lastName;
  final String firstName;
  final String country;
  final int birthYear;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() => {
        'id': id,
        'lastName': lastName,
        'firstName': firstName,
        'country': country,
        'birthYear': birthYear,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  /// [clearDeletedAt] отличает «не менять поле» от «сбросить в null».
  Designer copyWith({
    int? id,
    String? lastName,
    String? firstName,
    String? country,
    int? birthYear,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Designer(
      id: id ?? this.id,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      country: country ?? this.country,
      birthYear: birthYear ?? this.birthYear,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
