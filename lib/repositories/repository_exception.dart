/// Ошибка источника данных. Текст показывается пользователю в состоянии «ошибка».
class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Отказ в операции по бизнес-правилу: например, удалить издателя нельзя,
/// пока на него ссылаются игры. Это не сбой — экран показывает сообщение
/// и оставляет список как есть.
class OperationRefused implements Exception {
  const OperationRefused(this.message);

  final String message;

  @override
  String toString() => message;
}
