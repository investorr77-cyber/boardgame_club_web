import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'repositories/board_game_repository.dart';
import 'repositories/designer_repository.dart';
import 'repositories/in_memory_board_game_repository.dart';
import 'repositories/in_memory_designer_repository.dart';
import 'repositories/reference_repository.dart';
import 'router.dart';
import 'state/designer_details_notifier.dart';
import 'state/designer_list_notifier.dart';
import 'state/failure_simulator.dart';
import 'state/game_details_notifier.dart';
import 'state/game_list_notifier.dart';
import 'state/reference_notifier.dart';

void main() {
  // Адреса без «#»: /games?search=... вместо /#/games?search=...
  usePathUrlStrategy();

  final failure = FailureSimulator();
  final games = InMemoryBoardGameRepository(shouldFail: () => failure.enabled);
  final designers =
      InMemoryDesignerRepository(shouldFail: () => failure.enabled);

  // MultiProvider оборачивает MaterialApp.router: провайдеры выше всех экранов,
  // иначе «Could not find the correct Provider».
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FailureSimulator>.value(value: failure),
        Provider<BoardGameRepository>.value(value: games),
        Provider<DesignerRepository>.value(value: designers),
        Provider<ReferenceRepository>(
            create: (_) => const ReferenceRepository()),
        ChangeNotifierProvider<GameListNotifier>(
          create: (context) =>
              GameListNotifier(context.read<BoardGameRepository>()),
        ),
        ChangeNotifierProvider<DesignerListNotifier>(
          create: (context) =>
              DesignerListNotifier(context.read<DesignerRepository>()),
        ),
        ChangeNotifierProvider<GameDetailsNotifier>(
          create: (context) => GameDetailsNotifier(
            context.read<BoardGameRepository>(),
            context.read<DesignerRepository>(),
          ),
        ),
        ChangeNotifierProvider<DesignerDetailsNotifier>(
          create: (context) => DesignerDetailsNotifier(
            context.read<DesignerRepository>(),
            context.read<BoardGameRepository>(),
          ),
        ),
        ChangeNotifierProvider<ReferenceNotifier>(
          create: (context) =>
              ReferenceNotifier(context.read<ReferenceRepository>()),
        ),
      ],
      child: const BoardGameClubApp(),
    ),
  );
}

class BoardGameClubApp extends StatelessWidget {
  const BoardGameClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Клуб настольных игр',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      routerConfig: appRouter,
    );
  }
}
