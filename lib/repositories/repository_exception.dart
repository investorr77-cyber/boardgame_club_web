/// Ошибка источника данных. Текст показывается пользователю в состоянии «ошибка».
class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
