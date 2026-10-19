import 'package:flutter/material.dart';

/// Каркас экрана списка: поиск, фильтры (на узком экране — в ExpansionTile),
/// полоса выделения, содержимое и пагинация. Ширина ограничена на больших мониторах.
class ListPageLayout extends StatelessWidget {
  const ListPageLayout({
    super.key,
    required this.search,
    required this.filters,
    required this.activeFilterCount,
    required this.content,
    required this.pagination,
    this.selectionBar,
  });

  final Widget search;
  final Widget filters;
  final int activeFilterCount;
  final Widget content;
  final Widget pagination;
  final Widget? selectionBar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 600;
            final filterTitle = activeFilterCount > 0
                ? 'Фильтры ($activeFilterCount)'
                : 'Фильтры';
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 8),
                  if (narrow)
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        leading: const Icon(Icons.tune),
                        title: Text(filterTitle),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        expandedAlignment: Alignment.centerLeft,
                        children: [filters],
                      ),
                    )
                  else
                    filters,
                  if (selectionBar != null) ...[
                    const SizedBox(height: 8),
                    selectionBar!,
                  ],
                  const SizedBox(height: 8),
                  Expanded(child: content),
                  pagination,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
