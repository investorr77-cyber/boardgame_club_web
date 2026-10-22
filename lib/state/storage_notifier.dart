import 'package:flutter/foundation.dart';

import 'data_changes.dart';

/// Сообщения о хранилище (сброшены данные старого формата и т. п.)
/// и возврат к начальному набору данных.
class StorageNotifier extends ChangeNotifier {
  StorageNotifier({
    required List<String> notices,
    required List<Future<void> Function()> resetters,
    DataChanges? changes,
  })  : _notices = List.of(notices),
        _resetters = resetters,
        _changes = changes;

  final List<String> _notices;
  final List<Future<void> Function()> _resetters;
  final DataChanges? _changes;

  List<String> get notices => List.unmodifiable(_notices);

  void dismissNotices() {
    _notices.clear();
    notifyListeners();
  }

  Future<void> resetAll() async {
    for (final reset in _resetters) {
      await reset();
    }
    _notices.clear();
    _changes?.bump(this);
    notifyListeners();
  }
}
