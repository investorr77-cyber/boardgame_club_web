// Безопасный разбор данных из внешнего источника (хранилище, позже — сервер).
// Поля может не быть, оно может оказаться null или прийти другого типа:
// вместо `json['field'] as int` всегда берётся значение по умолчанию.

int readInt(Object? value, [int fallback = 0]) => readIntOrNull(value) ?? fallback;

int? readIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String readString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

List<int> readIntList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (readIntOrNull(item) case final int id) id,
  ];
}

/// Список развёрнутых объектов `[{id: 1, ...}, ...]` → список id.
List<int> readIdsOfObjects(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        if (readIntOrNull(item['id']) case final int id) id,
  ];
}

DateTime? readDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

Map<String, dynamic> readMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};
