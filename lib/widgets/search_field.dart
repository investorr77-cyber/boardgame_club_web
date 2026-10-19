import 'dart:async';

import 'package:flutter/material.dart';

/// Поле поиска с задержкой: [onChanged] вызывается через [debounce]
/// после окончания ввода, а не на каждое нажатие.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Поиск',
    this.debounce = const Duration(milliseconds: 400),
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  Timer? _timer;

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Переход по адресу («назад», ссылка) — синхронизируем текст поля.
    if (widget.value != oldWidget.value &&
        widget.value != _controller.text.trim()) {
      _timer?.cancel();
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(text.trim()));
    setState(() {}); // показать или скрыть кнопку очистки
  }

  void _submitNow(String text) {
    _timer?.cancel();
    widget.onChanged(text.trim());
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    _submitNow('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      onSubmitted: _submitNow,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Очистить',
                icon: const Icon(Icons.clear),
                onPressed: _clear,
              ),
      ),
    );
  }
}
