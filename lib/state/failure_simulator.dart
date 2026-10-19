import 'package:flutter/foundation.dart';

/// Переключатель «Сымитировать ошибку» в AppBar. Репозитории получают
/// функцию `() => simulator.enabled` и при включённом флаге бросают исключение.
class FailureSimulator extends ChangeNotifier {
  bool _enabled = false;

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }
}
