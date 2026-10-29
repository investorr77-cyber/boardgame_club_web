import 'package:flutter/material.dart';

/// Связь «многие к одному»: выпадающий список. Значение — id (int), а не объект:
/// объекты сравниваются по ==, и без переопределения ==/hashCode выбранное
/// значение перестало бы совпадать с элементом списка.
class IdDropdownField extends StatelessWidget {
  const IdDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.emptyMessage = 'Выберите значение',
    this.helper,
  });

  final String label;
  final int? value;
  final Map<int, String> options;
  final ValueChanged<int?> onChanged;
  final String emptyMessage;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      // Значения нет среди вариантов — передаём null, иначе исключение.
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      validator: (selected) => selected == null ? emptyMessage : null,
    );
  }
}

/// Связь «многие ко многим»: набор FilterChip внутри собственного поля формы.
/// Участвует в общем validate() наравне с текстовыми полями.
class MultiChipField extends FormField<List<int>> {
  MultiChipField({
    super.key,
    required String label,
    required List<int> initialValue,
    required Map<int, String> options,
    required ValueChanged<List<int>> onChanged,
    Set<int>? visibleIds,
    String emptyMessage = 'Выберите хотя бы одно значение',
    String? helper,
    Widget? header,
  }) : super(
          initialValue: initialValue,
          validator: (value) =>
              (value == null || value.isEmpty) ? emptyMessage : null,
          builder: (field) {
            final selected = field.value ?? const <int>[];
            // Выбранные значения видны всегда, даже если фильтр их скрыл.
            final entries = [
              for (final entry in options.entries)
                if (visibleIds == null ||
                    visibleIds.contains(entry.key) ||
                    selected.contains(entry.key))
                  entry,
            ];
            return InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                helperText: helper,
                helperMaxLines: 2,
                errorText: field.errorText,
                border: const OutlineInputBorder(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (header != null) header,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: selected.contains(entry.key),
                          onSelected: (_) {
                            final next = [...selected];
                            if (selected.contains(entry.key)) {
                              next.remove(entry.key);
                            } else {
                              next.add(entry.key);
                            }
                            field
                                .didChange(next); // сообщаем форме об изменении
                            onChanged(next);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
}
