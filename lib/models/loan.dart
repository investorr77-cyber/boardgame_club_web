import 'json_read.dart';

/// Выдача коробки игры участнику клуба.
class Loan {
  const Loan({
    required this.id,
    required this.gameId,
    required this.gameTitle,
    required this.userId,
    required this.userName,
    required this.issuedAt,
    required this.dueDate,
    this.returnedAt,
    this.extensions = 0,
    this.overdue = false,
  });

  factory Loan.fromJson(Map<String, dynamic> json) => Loan(
        id: readInt(json['id']),
        gameId: readInt(json['gameId']),
        gameTitle: readString(json['gameTitle']),
        userId: readInt(json['userId']),
        userName: readString(json['userName']),
        issuedAt: readDate(json['issuedAt']) ?? DateTime(2000),
        dueDate: readDate(json['dueDate']) ?? DateTime(2000),
        returnedAt: readDate(json['returnedAt']),
        extensions: readInt(json['extensions']),
        overdue: json['overdue'] == true,
      );

  final int id;
  final int gameId;
  final String gameTitle;
  final int userId;
  final String userName;
  final DateTime issuedAt;
  final DateTime dueDate;
  final DateTime? returnedAt;
  final int extensions;
  final bool overdue;

  bool get isActive => returnedAt == null;
}
