import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Выпадающий список фильтра с пунктом «Все» (значение null).
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 220,
    this.allLabel = 'Все',
  });

  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;
  final double width;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T?>(
            value: options.containsKey(value) ? value : null,
            isExpanded: true,
            isDense: true,
            items: [
              DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
              for (final entry in options.entries)
                DropdownMenuItem<T?>(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

/// Переключатель «Показывать удалённые».
class ShowDeletedSwitch extends StatelessWidget {
  const ShowDeletedSwitch(
      {super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: value, onChanged: onChanged),
            const SizedBox(width: 8),
            const Text('Показывать удалённые'),
          ],
        ),
      ),
    );
  }
}

/// Два числовых поля «Год от / до» с проверкой «от» ≤ «до».
/// Значение уходит наверх с задержкой и только если оно корректно.
class YearRangeFields extends StatefulWidget {
  const YearRangeFields({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 500),
  });

  final int? from;
  final int? to;
  final void Function(int? from, int? to) onChanged;
  final Duration debounce;

  @override
  State<YearRangeFields> createState() => _YearRangeFieldsState();
}

class _YearRangeFieldsState extends State<YearRangeFields> {
  late final TextEditingController _from =
      TextEditingController(text: _text(widget.from));
  late final TextEditingController _to =
      TextEditingController(text: _text(widget.to));
  Timer? _timer;
  String? _error;

  static String _text(int? value) => value?.toString() ?? '';

  static ({int? value, bool valid}) _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (value: null, valid: true);
    final n = int.tryParse(trimmed);
    if (n == null || n < 1900 || n > 2100) return (value: null, valid: false);
    return (value: n, valid: true);
  }

  @override
  void didUpdateWidget(YearRangeFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Сброс фильтров или переход по адресу — синхронизируем поля.
    if (widget.from != oldWidget.from &&
        _parse(_from.text).value != widget.from) {
      _from.text = _text(widget.from);
      _error = null;
    }
    if (widget.to != oldWidget.to && _parse(_to.text).value != widget.to) {
      _to.text = _text(widget.to);
      _error = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _timer?.cancel();
    final from = _parse(_from.text);
    final to = _parse(_to.text);
    String? error;
    if (!from.valid || !to.valid) {
      error = 'Год — от 1900 до 2100';
    } else if (from.value != null &&
        to.value != null &&
        from.value! > to.value!) {
      error = '«От» не может быть больше «до»';
    }
    setState(() => _error = error);
    if (error != null) return;
    _timer =
        Timer(widget.debounce, () => widget.onChanged(from.value, to.value));
  }

  Widget _field(TextEditingController controller, String label) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: controller,
        onChanged: _onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          errorText: _error == null ? null : '',
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_from, 'Год от'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('—'),
            ),
            _field(_to, 'Год до'),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
