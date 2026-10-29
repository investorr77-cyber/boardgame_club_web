import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/api_exceptions.dart';
import 'core/config.dart';
import 'core/supabase_errors.dart';
import 'models/board_game.dart';
import 'models/designer.dart';
import 'models/designer_query.dart';
import 'models/game_query.dart';
import 'models/genre.dart';
import 'models/member.dart';
import 'models/publisher.dart';
import 'models/simple_query.dart';
import 'repositories/api/api_repositories.dart';
import 'repositories/api/auth_api.dart';
import 'repositories/api/club_api.dart';
import 'repositories/board_game_repository.dart';
import 'repositories/designer_repository.dart';
import 'repositories/reference_repositories.dart';
import 'repositories/supabase/supabase_auth_api.dart';
import 'repositories/supabase/supabase_club_api.dart';
import 'repositories/supabase/supabase_repositories.dart';
import 'router.dart';
import 'state/auth_notifier.dart';
import 'state/club_notifiers.dart';
import 'state/data_changes.dart';
import 'state/details_notifiers.dart';
import 'state/edit_notifiers.dart';
import 'state/entity_list_notifier.dart';
import 'state/failure_simulator.dart';
import 'state/list_notifiers.dart';
import 'state/reference_notifier.dart';
import 'state/storage_notifier.dart';
import 'widgets/inactivity_watcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Адреса без «#»: /games?search=... вместо /#/games?search=...
  usePathUrlStrategy();

  // Сессия: токены и профиль лежат в localStorage и переживают перезагрузку.
  final prefs = await SharedPreferences.getInstance();
  final auth = AuthNotifier(
    prefs,
    useSupabase ? SupabaseAuthApi() : AuthApi(),
    inactivityTimeout: const Duration(seconds: inactivitySeconds),
    maxSession: const Duration(minutes: sessionMaxMinutes),
  );
  await auth.restore(); // до построения дерева виджетов

  final failure = FailureSimulator();
  // Все запросы к защищённым адресам уходят с заголовком Authorization;
  // при 401 интерсептор обновляет токен и повторяет запрос.
  final dio = buildDio(
    // Supabase: REST-интерфейс базы (PostgREST) и ключ проекта в заголовке.
    baseUrl: useSupabase ? '$supabaseUrl/rest/v1' : apiBaseUrl,
    headers: useSupabase ? const {'apikey': supabaseKey} : const {},
    errorMapper: useSupabase ? mapSupabaseError : mapHttpError,
    simulateOnClient: useSupabase,
    debugParams: useSupabase ? const {} : null,
    simulateFailure: () => failure.enabled,
    tokenProvider: () => auth.accessToken,
    refreshSession: auth.refreshTokens,
    onSessionExpired: () =>
        auth.logout(reason: 'Сессия истекла. Войдите снова.'),
  );
  // Источник данных выбирается при сборке; экраны и notifier'ы общие.
  final LoanApi loanApi = useSupabase ? SupabaseLoanApi(dio) : LoanApi(dio);
  final AdminApi adminApi = useSupabase ? SupabaseAdminApi(dio) : AdminApi(dio);
  final BoardGameRepository games = useSupabase
      ? SupabaseBoardGameRepository(dio)
      : ApiBoardGameRepository(dio);
  final DesignerRepository designers = useSupabase
      ? SupabaseDesignerRepository(dio)
      : ApiDesignerRepository(dio);
  final GenreRepository genres =
      useSupabase ? SupabaseGenreRepository(dio) : ApiGenreRepository(dio);
  final PublisherRepository publishers = useSupabase
      ? SupabasePublisherRepository(dio)
      : ApiPublisherRepository(dio);
  final MemberRepository members =
      useSupabase ? SupabaseMemberRepository(dio) : ApiMemberRepository(dio);
  const notices = <String>[];
  final changes = DataChanges();

  // MultiProvider оборачивает MaterialApp.router: провайдеры выше всех экранов,
  // иначе «Could not find the correct Provider».
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: auth),
        ChangeNotifierProvider<FailureSimulator>.value(value: failure),
        ChangeNotifierProvider<MyLoansNotifier>(
            create: (_) => MyLoansNotifier(loanApi)),
        ChangeNotifierProvider<LoansNotifier>(
            create: (_) => LoansNotifier(loanApi, changes: changes)),
        ChangeNotifierProvider<UsersNotifier>(
            create: (_) => UsersNotifier(adminApi)),
        ChangeNotifierProvider<StatsNotifier>(
            create: (_) => StatsNotifier(adminApi)),
        ChangeNotifierProvider<DataChanges>.value(value: changes),
        Provider<Dio>.value(value: dio),
        Provider<BoardGameRepository>.value(value: games),
        Provider<DesignerRepository>.value(value: designers),
        Provider<GenreRepository>.value(value: genres),
        Provider<PublisherRepository>.value(value: publishers),
        Provider<MemberRepository>.value(value: members),
        ChangeNotifierProvider<StorageNotifier>(
          create: (_) => StorageNotifier(
            notices: notices,
            // Начальный набор восстанавливает сервер.
            resetters: [adminApi.resetData],
            changes: changes,
          ),
        ),
        ChangeNotifierProvider<ReferenceNotifier>(
          create: (_) => ReferenceNotifier(
            auth: auth,
            games: games,
            designers: designers,
            genres: genres,
            publishers: publishers,
            members: members,
            changes: changes,
          ),
        ),
        // Списки
        ChangeNotifierProvider<EntityListNotifier<BoardGame, GameQuery>>(
          create: (_) => GameListNotifier(games, changes: changes),
        ),
        ChangeNotifierProvider<EntityListNotifier<Designer, DesignerQuery>>(
          create: (_) => DesignerListNotifier(designers, changes: changes),
        ),
        ChangeNotifierProvider<EntityListNotifier<Genre, SimpleQuery>>(
          create: (_) => SimpleListNotifier<Genre>(genres,
              defaultSortField: 'name',
              idOfItem: (g) => g.id,
              changes: changes),
        ),
        ChangeNotifierProvider<EntityListNotifier<Publisher, SimpleQuery>>(
          create: (_) =>
              PublisherListNotifier(publishers, games, changes: changes),
        ),
        ChangeNotifierProvider<EntityListNotifier<Member, SimpleQuery>>(
          create: (_) => SimpleListNotifier<Member>(members,
              defaultSortField: 'lastName',
              idOfItem: (m) => m.id,
              changes: changes),
        ),
        // Карточки
        ChangeNotifierProvider<EntityDetailsNotifier<BoardGame>>(
          create: (_) =>
              GameDetailsNotifier(games, designers, changes: changes),
        ),
        ChangeNotifierProvider<EntityDetailsNotifier<Designer>>(
          create: (_) =>
              DesignerDetailsNotifier(designers, games, changes: changes),
        ),
        ChangeNotifierProvider<EntityDetailsNotifier<Genre>>(
          create: (_) => EntityDetailsNotifier<Genre>(
            load: genres.findById,
            related: (genre) async =>
                (await games.findAll(includeDeleted: true))
                    .where((g) => g.genreIds.contains(genre.id))
                    .toList(),
            changes: changes,
          ),
        ),
        ChangeNotifierProvider<EntityDetailsNotifier<Publisher>>(
          create: (_) => EntityDetailsNotifier<Publisher>(
            load: publishers.findById,
            related: (publisher) async =>
                (await games.findAll(includeDeleted: true))
                    .where((g) => g.publisherId == publisher.id)
                    .toList(),
            changes: changes,
          ),
        ),
        ChangeNotifierProvider<EntityDetailsNotifier<Member>>(
          create: (_) => EntityDetailsNotifier<Member>(
              load: members.findById, changes: changes),
        ),
        // Формы
        ChangeNotifierProvider<EntityEditNotifier<BoardGame>>(
          create: (_) => GameEditNotifier(games, changes: changes),
        ),
        ChangeNotifierProvider<EntityEditNotifier<Designer>>(
          create: (_) =>
              EntityEditNotifier<Designer>(designers, changes: changes),
        ),
        ChangeNotifierProvider<EntityEditNotifier<Genre>>(
          create: (_) => EntityEditNotifier<Genre>(genres, changes: changes),
        ),
        ChangeNotifierProvider<EntityEditNotifier<Publisher>>(
          create: (_) =>
              EntityEditNotifier<Publisher>(publishers, changes: changes),
        ),
        ChangeNotifierProvider<EntityEditNotifier<Member>>(
          create: (_) => MemberEditNotifier(members, changes: changes),
        ),
      ],
      child: BoardGameClubApp(notices: notices),
    ),
  );
}

class BoardGameClubApp extends StatefulWidget {
  const BoardGameClubApp({super.key, this.notices = const []});

  /// Сообщения о хранилище, показанные при запуске.
  final List<String> notices;

  @override
  State<BoardGameClubApp> createState() => _BoardGameClubAppState();
}

class _BoardGameClubAppState extends State<BoardGameClubApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final _router = buildRouter(context.read<AuthNotifier>());

  @override
  void initState() {
    super.initState();
    if (widget.notices.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(widget.notices.join('\n')),
        duration: const Duration(seconds: 10),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Клуб настольных игр',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      routerConfig: _router,
      // Выход по бездействию отслеживается на уровне всего приложения.
      builder: (context, child) {
        final auth = context.watch<AuthNotifier>();
        return InactivityWatcher(
          enabled: auth.isAuthenticated,
          timeout: auth.inactivityTimeout,
          onActivity: auth.touch,
          onWarning: () =>
              _messengerKey.currentState?.showSnackBar(const SnackBar(
            content:
                Text('Сеанс завершится через 30 секунд из-за бездействия.'),
            duration: Duration(seconds: 25),
          )),
          onTimeout: () {
            _messengerKey.currentState?.hideCurrentSnackBar();
            auth.logout(
                reason: 'Сеанс завершён из-за бездействия '
                    '( мин без действий).');
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
