import 'package:flutter/material.dart';

/// Пагинация: первая / предыдущая / следующая / последняя, номер страницы,
/// общее число записей и выбор размера страницы.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.size,
    required this.onPageChanged,
    required this.onSizeChanged,
    this.sizes = const [10, 25, 50],
  });

  final int page;
  final int totalPages;
  final int total;
  final int size;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSizeChanged;
  final List<int> sizes;

  @override
  Widget build(BuildContext context) {
    final canBack = page > 1;
    final canForward = page < totalPages;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Первая страница',
            icon: const Icon(Icons.first_page),
            onPressed: canBack ? () => onPageChanged(1) : null,
          ),
          IconButton(
            tooltip: 'Предыдущая страница',
            icon: const Icon(Icons.chevron_left),
            onPressed: canBack ? () => onPageChanged(page - 1) : null,
          ),
          Text('Страница $page из $totalPages'),
          IconButton(
            tooltip: 'Следующая страница',
            icon: const Icon(Icons.chevron_right),
            onPressed: canForward ? () => onPageChanged(page + 1) : null,
          ),
          IconButton(
            tooltip: 'Последняя страница',
            icon: const Icon(Icons.last_page),
            onPressed: canForward ? () => onPageChanged(totalPages) : null,
          ),
          const SizedBox(width: 8),
          Text('Всего: $total'),
          const SizedBox(width: 16),
          const Text('На странице:'),
          DropdownButton<int>(
            value: size,
            underline: const SizedBox.shrink(),
            items: [
              for (final s in sizes)
                DropdownMenuItem(value: s, child: Text('$s')),
            ],
            onChanged: (value) {
              if (value != null && value != size) onSizeChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
