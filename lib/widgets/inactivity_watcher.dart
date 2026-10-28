import 'dart:async'; // Timer

import 'package:flutter/services.dart'; // HardwareKeyboard, KeyEvent
import 'package:flutter/widgets.dart';

/// Выход по бездействию. Таймер сбрасывается при любом действии пользователя:
/// касании, движении мыши, прокрутке, нажатии клавиши.
/// За [warningBefore] до конца вызывается [onWarning].
class InactivityWatcher extends StatefulWidget {
  const InactivityWatcher({
    super.key,
    required this.enabled,
    required this.timeout,
    required this.onTimeout,
    required this.child,
    this.warningBefore = const Duration(seconds: 30),
    this.onWarning,
    this.onActivity,
  });

  /// Следить только пока пользователь вошёл.
  final bool enabled;
  final Duration timeout;
  final Duration warningBefore;
  final VoidCallback onTimeout;
  final VoidCallback? onWarning;

  /// Действие пользователя: время последнего действия сохраняется,
  /// чтобы бездействие учитывалось и через перезагрузку страницы.
  final VoidCallback? onActivity;
  final Widget child;

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  Timer? _warningTimer;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Клавиатуру слушаем глобально. Виджет KeyboardListener здесь не подошёл бы:
    // он сообщает о нажатиях, только когда его FocusNode в фокусе, а у обёртки
    // над всем приложением фокуса нет — набор текста в форме не сбрасывал бы
    // таймер, и пользователя выбросило бы прямо посреди заполнения.
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  @override
  void didUpdateWidget(InactivityWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _restart();
  }

  // false означает «событие не обработано, передайте его дальше».
  bool _onKey(KeyEvent event) {
    _restart();
    return false;
  }

  void _restart() {
    _warningTimer?.cancel();
    _timer?.cancel();
    if (!widget.enabled) return;
    widget.onActivity?.call();
    final warnAt = widget.timeout - widget.warningBefore;
    if (widget.onWarning != null && warnAt > Duration.zero) {
      _warningTimer = Timer(warnAt, widget.onWarning!);
    }
    _timer = Timer(widget.timeout, widget.onTimeout);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _warningTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Перехват без поглощения: событие идёт дальше к виджетам.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerMove: (_) => _restart(),
      onPointerHover: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
