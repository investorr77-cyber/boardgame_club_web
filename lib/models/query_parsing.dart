// Общий разбор параметров адресной строки для GameQuery и DesignerQuery.
// Некорректные значения не бросают исключений: возвращается null,
// и Query подставляет значение по умолчанию.

const allowedPageSizes = [10, 25, 50];
const defaultPageSize = 10;

int? parsePositiveInt(String? value) {
  final n = int.tryParse(value?.trim() ?? '');
  return (n != null && n > 0) ? n : null;
}

int? parseYear(String? value) {
  final n = int.tryParse(value?.trim() ?? '');
  return (n != null && n >= 1900 && n <= 2100) ? n : null;
}

int parsePageSize(String? value) {
  final n = int.tryParse(value?.trim() ?? '');
  return (n != null && allowedPageSizes.contains(n)) ? n : defaultPageSize;
}

/// `sort=year,desc` → ('year', false). Неизвестное поле или направление → null.
(String, bool)? parseSort(String? value, List<String> allowedFields) {
  if (value == null) return null;
  final parts = value.split(',');
  if (parts.length > 2) return null;
  final field = parts[0].trim();
  if (!allowedFields.contains(field)) return null;
  if (parts.length == 1) return (field, true);
  switch (parts[1].trim().toLowerCase()) {
    case 'asc':
      return (field, true);
    case 'desc':
      return (field, false);
    default:
      return null;
  }
}

String formatSort(String field, bool ascending) =>
    '$field,${ascending ? 'asc' : 'desc'}';

bool parseFlag(String? value) => value == '1' || value == 'true';

String? parseText(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}
