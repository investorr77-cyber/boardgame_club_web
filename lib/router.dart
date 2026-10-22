import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'models/board_game.dart';
import 'models/designer.dart';
import 'models/designer_query.dart';
import 'models/game_query.dart';
import 'models/genre.dart';
import 'models/member.dart';
import 'models/publisher.dart';
import 'models/simple_query.dart';
import 'repositories/in_memory_reference_repositories.dart';
import 'screens/details_configs.dart';
import 'screens/entity_details_screen.dart';
import 'screens/entity_list_screen.dart';
import 'screens/game_form_screen.dart';
import 'screens/home_screen.dart';
import 'screens/list_configs.dart';
import 'screens/member_form_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/simple_form_screens.dart';

/// Маршруты сущности: список, создание, карточка, изменение.
/// '/x/new' объявлен раньше '/x/:id', иначе «new» принялся бы за id.
List<GoRoute> _entityRoutes({
  required String path,
  required Widget Function(Map<String, String> params) list,
  required Widget Function(String id) details,
  required Widget Function(String? id) form,
}) =>
    [
      GoRoute(path: path, builder: (context, state) => list(state.uri.queryParameters)),
      GoRoute(path: '$path/new', builder: (context, state) => form(null)),
      GoRoute(
        path: '$path/:id',
        builder: (context, state) => details(state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '$path/:id/edit',
        builder: (context, state) => form(state.pathParameters['id'] ?? ''),
      ),
    ];

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    ..._entityRoutes(
      path: '/games',
      list: (p) => EntityListScreen<BoardGame, GameQuery>(
          config: gamesListConfig, query: GameQuery.fromQueryParameters(p)),
      details: (id) =>
          EntityDetailsScreen<BoardGame>(config: gameDetailsConfig, idParam: id),
      form: (id) => GameFormScreen(idParam: id),
    ),
    ..._entityRoutes(
      path: '/designers',
      list: (p) => EntityListScreen<Designer, DesignerQuery>(
          config: designersListConfig,
          query: DesignerQuery.fromQueryParameters(p)),
      details: (id) => EntityDetailsScreen<Designer>(
          config: designerDetailsConfig, idParam: id),
      form: (id) => DesignerFormScreen(idParam: id),
    ),
    ..._entityRoutes(
      path: '/genres',
      list: (p) => EntityListScreen<Genre, SimpleQuery>(
        config: genresListConfig,
        query: SimpleQuery.fromQueryParameters(p,
            sortFields: InMemoryGenreRepository.sortFields,
            defaultSortField: 'name'),
      ),
      details: (id) =>
          EntityDetailsScreen<Genre>(config: genreDetailsConfig, idParam: id),
      form: (id) => GenreFormScreen(idParam: id),
    ),
    ..._entityRoutes(
      path: '/publishers',
      list: (p) => EntityListScreen<Publisher, SimpleQuery>(
        config: publishersListConfig,
        query: SimpleQuery.fromQueryParameters(p,
            sortFields: InMemoryPublisherRepository.sortFields,
            defaultSortField: 'name'),
      ),
      details: (id) => EntityDetailsScreen<Publisher>(
          config: publisherDetailsConfig, idParam: id),
      form: (id) => PublisherFormScreen(idParam: id),
    ),
    ..._entityRoutes(
      path: '/members',
      list: (p) => EntityListScreen<Member, SimpleQuery>(
        config: membersListConfig,
        query: SimpleQuery.fromQueryParameters(p,
            sortFields: InMemoryMemberRepository.sortFields,
            defaultSortField: 'lastName'),
      ),
      details: (id) =>
          EntityDetailsScreen<Member>(config: memberDetailsConfig, idParam: id),
      form: (id) => MemberFormScreen(idParam: id),
    ),
  ],
  errorBuilder: (context, state) =>
      NotFoundScreen(location: state.uri.toString()),
);
