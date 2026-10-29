import 'api_exceptions.dart';

/// Ошибка PostgREST (Supabase) → исключение предметной области.
///
/// В теле ответа PostgREST — код PostgreSQL: `{code: '23505', message, details}`.
/// Сообщения базы английские, пользователю показывается русский текст.
ApiException mapSupabaseError(int status, dynamic body) {
  final map = body is Map ? body : const {};
  final code = '${map['code'] ?? ''}';
  final message = map['message'] is String ? map['message'] as String : null;
  final details = '${map['details'] ?? ''}';

  return switch (code) {
    // Нарушена уникальность: штрихкод, почта, номер карты, название.
    '23505' => ConflictException(_uniqueMessage('$details $message')),
    // Нарушена внешняя ключевая связь: на запись ссылаются другие.
    '23503' => const ConflictException(
        'Есть связанные записи: сначала удалите или измените их.'),
    '23514' ||
    '23502' ||
    '22P02' ||
    '22003' =>
      ValidationException('Данные не прошли проверку на сервере.', const {}),
    // Политика RLS или проверка роли в функции.
    '42501' => ForbiddenException(
        message == null || message.contains('row-level security')
            ? 'Недостаточно прав для этого действия.'
            : message),
    'PGRST301' ||
    'PGRST302' ||
    'PGRST303' =>
      const UnauthorizedException('Сессия истекла. Войдите снова.'),
    'PGRST116' => const NotFoundException(),
    // raise exception ... using errcode = 'PT409' — PostgREST отвечает 409.
    _ when status == 409 =>
      ConflictException(message ?? 'Операция невозможна.'),
    _ when status == 403 =>
      const ForbiddenException('Недостаточно прав для этого действия.'),
    _ => mapHttpError(status, body),
  };
}

String _uniqueMessage(String text) {
  if (text.contains('barcode')) return 'Игра с таким штрихкодом уже есть.';
  if (text.contains('email')) return 'Участник с такой почтой уже есть.';
  if (text.contains('number')) return 'Клубная карта с таким номером уже есть.';
  if (text.contains('username')) return 'Такой логин уже занят.';
  if (text.contains('name')) return 'Запись с таким названием уже есть.';
  return 'Такая запись уже есть.';
}
