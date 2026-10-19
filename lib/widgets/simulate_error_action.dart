import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/failure_simulator.dart';

/// Переключатель «Сымитировать ошибку» в AppBar — для скриншота состояния ошибки.
class SimulateErrorAction extends StatelessWidget {
  const SimulateErrorAction({super.key, required this.onToggled});

  /// Вызывается после переключения (обычно — перезагрузка списка).
  final VoidCallback onToggled;

  @override
  Widget build(BuildContext context) {
    final simulator = context.watch<FailureSimulator>();
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Tooltip(
      message: 'Сымитировать ошибку загрузки',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wide) const Text('Сымитировать ошибку'),
          Switch(
            value: simulator.enabled,
            onChanged: (value) {
              simulator.enabled = value;
              onToggled();
            },
          ),
        ],
      ),
    );
  }
}
