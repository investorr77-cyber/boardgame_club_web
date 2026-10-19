# Практическая работа 2 — Клуб настольных игр (Flutter Web)

Каталог клуба настольных игр из двух сущностей: игры (`BoardGame`, аналог Book) и авторы
(`Designer`, аналог Author). Состояние хранится в provider, код разделён на слои. Есть поиск,
фильтры, сортировка, пагинация, логическое и физическое удаление, а условия отбора хранятся
в адресной строке. Данные лежат в памяти: 30 игр и 12 авторов. После перезагрузки страницы
восстанавливается начальный набор.

## Запуск

```
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
flutter build web
```

## 1. Схема слоёв

```
models  →  repositories  →  state (notifier)  →  screens / widgets
```

| Слой | Содержимое | От чего зависит |
|---|---|---|
| `models/` | `BoardGame`, `Designer`, `Genre`, `Publisher`, `PageResult<T>`, `GameQuery`, `DesignerQuery` | ни от чего |
| `repositories/` | интерфейсы `BoardGameRepository`, `DesignerRepository`, их in-memory реализации, `ReferenceRepository`, seed-данные в `repositories/seed/` | `models` |
| `state/` | `GameListNotifier`, `DesignerListNotifier` (общая база `EntityListNotifier`), `GameDetailsNotifier`, `DesignerDetailsNotifier`, `ReferenceNotifier`, `LoadStatus` | `models`, интерфейсы `repositories` |
| `screens/` | главная, списки, карточки, 404 | `models`, `state`, `widgets` |
| `widgets/` | `EntityTable<T>`, `EntityCardList<T>`, `PaginationBar`, `state_views`, `confirm_dialog`, `SearchField` | `models`, `state` |

**Почему виджеты не обращаются к репозиторию.** Экран отвечает только за отображение и
реакцию на действия пользователя. Загрузку, статус (`idle/loading/success/error`), выделение,
повторный запрос после удаления и переход на предыдущую страницу ведёт notifier. Отсюда три
следствия:

- Логика списка лежит в одном месте и не дублируется в каждом экране.
- В ПР4 in-memory репозиторий заменит HTTP-клиент с тем же интерфейсом. Поменяется только
  строка в `main.dart`, а экраны и notifier'ы останутся прежними.
- Репозиторий и notifier можно тестировать без UI (`test/`).

Ни один файл в `screens/` и `widgets/` не импортирует `repositories/`. Справочники жанров и
издателей экраны тоже получают через `ReferenceNotifier`, а карточки загружают через
details-notifier'ы. `MultiProvider` оборачивает `MaterialApp.router`, поэтому все провайдеры
доступны любому экрану. `setState` используется только для локального состояния: текста
поиска, полей года и кнопки очистки.

## 2. Почему таблица вынесена в обобщённый `EntityTable<T>`

Таблица игр и таблица авторов отличаются только набором колонок и действиями. Всё остальное у
них одинаковое:

- колонка флажков и флажок «выбрать все на странице»;
- сортировка по клику на заголовок со стрелкой в активной колонке;
- приглушённые удалённые строки с пометкой «удалено»;
- колонка действий;
- двумерная прокрутка, из-за которой таблица не уезжает за край.

Поэтому `EntityTable<T>` принимает список `TableColumnSpec<T>` (подпись, поле сортировки,
признак числовой колонки, функция построения ячейки), функцию `idOf` и обработчики. Внутри
таблицы нет ничего про игры или авторов. Экран игр передаёт 7 колонок, экран авторов — 4.
Код таблицы не копируется: исправление или улучшение сразу работает в обоих списках, а для
новой сущности в ПР3–ПР4 достаточно описать колонки. По тому же принципу сделан
`EntityCardList<T>` для узких экранов.

## 3. Ошибка в `deleteMany`

**Было (методичка):**

```dart
final i = _books.indexWhere((b) => b.id == id && !b[i].isDeleted);
```

**Почему не компилировалось:**

1. Внутри замыкания `b` — это один объект `Book`, а не список. У класса нет оператора `[]`,
   поэтому `b[i]` — ошибка компиляции: `The operator '[]' isn't defined for the type 'Book'`.
2. Переменная `i` в замыкании ещё не объявлена. Её значение появится только после того, как
   `indexWhere` вернёт результат, а обращаться к локальной переменной в её собственном
   инициализаторе нельзя.

**Стало:** проверяется сам элемент.

```dart
final i = _games.indexWhere((b) => b.id == id && !b.isDeleted);
if (i == -1) continue;
_games[i] = _games[i].copyWith(deletedAt: now);
count++;
```

Метод возвращает число реально удалённых записей. Уже удалённые и несуществующие id не
считаются; это проверяет тест «deleteMany возвращает число только неудалённых записей».
Объяснение оставлено комментарием в `lib/repositories/in_memory_board_game_repository.dart`.
Та же логика есть в `InMemoryDesignerRepository`.

## 4. Как выполнены требования

| Требование | Где |
|---|---|
| Модели с `copyWith(clearDeletedAt)`, `isDeleted`, `fullName` | `lib/models/` |
| `PageResult<T>`: `totalPages`, `hasPrevious`, `hasNext`, `empty()` | `lib/models/page_result.dart` |
| `GameQuery` / `DesignerQuery`: `_unset`, сброс page в 1, `toQueryParameters` / `fromQueryParameters`, `==` / `hashCode` | `lib/models/*_query.dart` |
| Задержка 250 мс, поиск, фильтры, сортировка, пагинация без `clamp` | `lib/repositories/in_memory_*.dart`, `paging.dart` |
| Имитация ошибки | переключатель «Сымитировать ошибку» в AppBar (`FailureSimulator`) |
| Notifier: load / applyQuery / выделение / удаления / переход на предыдущую страницу | `lib/state/entity_list_notifier.dart` |
| Адрес — источник правды, `addPostFrameCallback`, `context.go` | `lib/screens/games_screen.dart`, `designers_screen.dart` |
| 404, несуществующий и нечисловой id | `not_found_screen.dart`, `*_details_screen.dart` |
| Поиск с задержкой 400 мс | `lib/widgets/search_field.dart` |
| Карточки при ширине < 600 px | `LayoutBuilder` в экранах списков |
| Тесты (25 проверок) | `test/repositories_test.dart`, `test/query_url_test.dart` |

Примеры адресов:

- `/games?search=каркассон&genreId=2&sort=year,desc&page=1`
- `/games?genreId=5&publisherId=2&yearFrom=2010&yearTo=2020`
- `/designers?country=Германия&sort=birthYear,desc`
- `/games/9999`, `/games/abc`, `/qwerty`

## 5. Скриншоты

> Вставьте свои скриншоты из браузера.

1. Таблица игр на широком окне.
2. Карточки на узком окне (360 px, DevTools → Toggle device toolbar).
3. Применённые фильтры, вместе с адресной строкой.
4. Выделение нескольких записей и полоса «Выбрано: N».
5. Пустой результат: жанр «Детективная», в нём нет игр.
6. Ошибка: включите «Сымитировать ошибку» в AppBar.
7. Адресная строка с параметрами отбора.
