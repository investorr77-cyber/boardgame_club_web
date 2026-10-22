import 'json_read.dart';

/// Настольная игра клуба (аналог Book из методички).
/// Связи: многие к одному с Publisher, многие ко многим с Designer и Genre.
class BoardGame {
  const BoardGame({
    required this.id,
    required this.title,
    required this.barcode,
    required this.year,
    required this.playTimeMin,
    required this.minPlayers,
    required this.maxPlayers,
    required this.publisherId,
    required this.designerIds,
    required this.genreIds,
    required this.copiesTotal,
    required this.copiesAvailable,
    this.deletedAt,
  });

  factory BoardGame.fromJson(Map<String, dynamic> json) => BoardGame(
        id: readInt(json['id']),
        title: readString(json['title']),
        barcode: readString(json['barcode']),
        year: readInt(json['year']),
        playTimeMin: readInt(json['playTimeMin']),
        minPlayers: readInt(json['minPlayers'], 1),
        maxPlayers: readInt(json['maxPlayers'], 1),
        publisherId: readInt(json['publisherId']),
        designerIds: readIntList(json['designerIds']),
        genreIds: readIntList(json['genreIds']),
        copiesTotal: readInt(json['copiesTotal']),
        copiesAvailable: readInt(json['copiesAvailable']),
        deletedAt: readDate(json['deletedAt']),
      );

  final int id;
  final String title;

  /// Штрихкод EAN-13 (аналог ISBN): строка из 13 цифр, уникален в каталоге.
  final String barcode;

  /// Год издания.
  final int year;

  /// Длительность партии в минутах (аналог pages).
  final int playTimeMin;
  final int minPlayers;
  final int maxPlayers;
  final int publisherId;
  final List<int> designerIds;
  final List<int> genreIds;

  /// Коробок в клубе.
  final int copiesTotal;

  /// Свободных коробок.
  final int copiesAvailable;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'barcode': barcode,
        'year': year,
        'playTimeMin': playTimeMin,
        'minPlayers': minPlayers,
        'maxPlayers': maxPlayers,
        'publisherId': publisherId,
        'designerIds': designerIds,
        'genreIds': genreIds,
        'copiesTotal': copiesTotal,
        'copiesAvailable': copiesAvailable,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  /// [clearDeletedAt] отличает «не менять поле» (deletedAt не передан)
  /// от «сбросить в null» (восстановление записи).
  BoardGame copyWith({
    int? id,
    String? title,
    String? barcode,
    int? year,
    int? playTimeMin,
    int? minPlayers,
    int? maxPlayers,
    int? publisherId,
    List<int>? designerIds,
    List<int>? genreIds,
    int? copiesTotal,
    int? copiesAvailable,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return BoardGame(
      id: id ?? this.id,
      title: title ?? this.title,
      barcode: barcode ?? this.barcode,
      year: year ?? this.year,
      playTimeMin: playTimeMin ?? this.playTimeMin,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      publisherId: publisherId ?? this.publisherId,
      designerIds: designerIds ?? this.designerIds,
      genreIds: genreIds ?? this.genreIds,
      copiesTotal: copiesTotal ?? this.copiesTotal,
      copiesAvailable: copiesAvailable ?? this.copiesAvailable,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
