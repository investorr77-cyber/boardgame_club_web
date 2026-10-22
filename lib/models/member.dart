import 'json_read.dart';

/// Клубная карта участника (аналог LibraryCard). Связь один к одному с Member:
/// карта не существует отдельно и хранится внутри записи участника.
class MemberCard {
  const MemberCard({
    required this.number,
    required this.issuedYear,
    required this.maxGames,
  });

  factory MemberCard.fromJson(Map<String, dynamic> json) => MemberCard(
        number: readString(json['number']),
        issuedYear: readInt(json['issuedYear']),
        maxGames: readInt(json['maxGames'], 1),
      );

  /// Номер карты вида BG-000123, уникален.
  final String number;
  final int issuedYear;

  /// Сколько игр участник может взять одновременно.
  final int maxGames;

  Map<String, dynamic> toJson() => {
        'number': number,
        'issuedYear': issuedYear,
        'maxGames': maxGames,
      };
}

/// Участник клуба (аналог Reader).
class Member {
  const Member({
    required this.id,
    required this.lastName,
    required this.firstName,
    required this.email,
    required this.phone,
    required this.city,
    required this.card,
    this.deletedAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: readInt(json['id']),
        lastName: readString(json['lastName']),
        firstName: readString(json['firstName']),
        email: readString(json['email']),
        phone: readString(json['phone']),
        city: readString(json['city']),
        card: MemberCard.fromJson(readMap(json['card'])),
        deletedAt: readDate(json['deletedAt']),
      );

  final int id;
  final String lastName;
  final String firstName;

  /// Почта, уникальна среди участников.
  final String email;
  final String phone;
  final String city;
  final MemberCard card;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() => {
        'id': id,
        'lastName': lastName,
        'firstName': firstName,
        'email': email,
        'phone': phone,
        'city': city,
        'card': card.toJson(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  Member copyWith({
    int? id,
    String? lastName,
    String? firstName,
    String? email,
    String? phone,
    String? city,
    MemberCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Member(
      id: id ?? this.id,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      card: card ?? this.card,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
