import 'package:go_router/go_router.dart';

import 'models/designer_query.dart';
import 'models/game_query.dart';
import 'screens/designer_details_screen.dart';
import 'screens/designers_screen.dart';
import 'screens/game_details_screen.dart';
import 'screens/games_screen.dart';
import 'screens/home_screen.dart';
import 'screens/not_found_screen.dart';

/// Маршруты. Условия отбора списков берутся из state.uri.queryParameters.
final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/games',
      builder: (context, state) => GamesScreen(
        query: GameQuery.fromQueryParameters(state.uri.queryParameters),
      ),
    ),
    GoRoute(
      path: '/games/:id',
      builder: (context, state) =>
          GameDetailsScreen(idParam: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/designers',
      builder: (context, state) => DesignersScreen(
        query: DesignerQuery.fromQueryParameters(state.uri.queryParameters),
      ),
    ),
    GoRoute(
      path: '/designers/:id',
      builder: (context, state) =>
          DesignerDetailsScreen(idParam: state.pathParameters['id'] ?? ''),
    ),
  ],
  errorBuilder: (context, state) =>
      NotFoundScreen(location: state.uri.toString()),
);
