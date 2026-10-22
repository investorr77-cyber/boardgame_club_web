import 'package:flutter/foundation.dart';

/// Сигнал «данные изменились». Списки, карточки и справочники подписаны
/// на него и перечитывают данные после сохранения формы или удаления —
/// иначе после возврата с формы на экране остался бы старый список.
class DataChanges extends ChangeNotifier {
  Object? _source;

  /// Кто сообщил об изменении: сам источник повторно не перезагружается.
  Object? get source => _source;

  void bump([Object? source]) {
    _source = source;
    notifyListeners();
  }
}
