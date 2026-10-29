import 'package:flutter/material.dart';

import '../models/board_game.dart';
import '../models/designer.dart';
import '../models/designer_query.dart';
import '../models/game_query.dart';
import '../models/genre.dart';
import '../models/member.dart';
import '../models/publisher.dart';
import '../models/simple_query.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_controls.dart';
import 'entity_list_screen.dart';

// Настройки списков пяти сущностей. Код экрана общий (EntityListScreen),
// здесь только колонки, фильтры и подписи.

String playersText(BoardGame g) => g.minPlayers == g.maxPlayers
    ? '${g.minPlayers} игр.'
    : '${g.minPlayers}–${g.maxPlayers} игр.';

final gamesListConfig = EntityListConfig<BoardGame, GameQuery>(
  title: 'Игры',
  path: '/games',
  searchHint: 'Поиск по названию или штрихкоду',
  idOf: (g) => g.id,
  isDeleted: (g) => g.isDeleted,
  nameOf: (g) => g.title,
  subtitleOf: (g, refs) => '${g.year} · ${g.playTimeMin} мин · '
      '${playersText(g)} · ${refs.publisherName(g.publisherId)}',
  columns: (refs) => [
    TableColumnSpec(
        label: 'Название', sortField: 'title', build: (g) => Text(g.title)),
    TableColumnSpec(
        label: 'Год',
        sortField: 'year',
        numeric: true,
        build: (g) => Text('${g.year}')),
    TableColumnSpec(
        label: 'Время партии',
        sortField: 'playTimeMin',
        numeric: true,
        build: (g) => Text('${g.playTimeMin} мин')),
    TableColumnSpec(label: 'Игроки', build: (g) => Text(playersText(g))),
    TableColumnSpec(
        label: 'Издатель',
        build: (g) => Text(refs.publisherName(g.publisherId))),
    TableColumnSpec(
        label: 'Свободно',
        numeric: true,
        build: (g) => Text('${g.copiesAvailable} из ${g.copiesTotal}')),
    TableColumnSpec(label: 'Штрихкод', build: (g) => Text(g.barcode)),
  ],
  update: (q, {search, sortField, sortAscending, page, size, includeDeleted}) =>
      q.copyWith(
    search: search,
    sortField: sortField,
    sortAscending: sortAscending,
    page: page,
    size: size,
    includeDeleted: includeDeleted,
  ),
  reset: (q) => GameQuery(
      size: q.size, sortField: q.sortField, sortAscending: q.sortAscending),
  activeFilterCount: (q) => [q.genreId, q.publisherId, q.yearFrom, q.yearTo]
      .where((v) => v != null)
      .length,
  filters: (q, refs, apply) => [
    FilterDropdown<int>(
      label: 'Жанр',
      value: q.genreId,
      options: {
        for (final g in refs.genres)
          if (!g.isDeleted) g.id: g.name
      },
      onChanged: (v) => apply(q.copyWith(genreId: v)),
    ),
    FilterDropdown<int>(
      label: 'Издатель',
      value: q.publisherId,
      options: {
        for (final p in refs.publishers)
          if (!p.isDeleted) p.id: p.name
      },
      onChanged: (v) => apply(q.copyWith(publisherId: v)),
    ),
    YearRangeFields(
      from: q.yearFrom,
      to: q.yearTo,
      onChanged: (from, to) => apply(q.copyWith(yearFrom: from, yearTo: to)),
    ),
  ],
);

final designersListConfig = EntityListConfig<Designer, DesignerQuery>(
  title: 'Авторы',
  path: '/designers',
  searchHint: 'Поиск по фамилии или стране',
  idOf: (d) => d.id,
  isDeleted: (d) => d.isDeleted,
  nameOf: (d) => d.fullName,
  subtitleOf: (d, refs) => '${d.country} · ${d.birthYear} г. р.',
  columns: (refs) => [
    TableColumnSpec(
        label: 'Фамилия',
        sortField: 'lastName',
        build: (d) => Text(d.lastName)),
    TableColumnSpec(label: 'Имя', build: (d) => Text(d.firstName)),
    TableColumnSpec(
        label: 'Страна', sortField: 'country', build: (d) => Text(d.country)),
    TableColumnSpec(
        label: 'Год рождения',
        sortField: 'birthYear',
        numeric: true,
        build: (d) => Text('${d.birthYear}')),
    TableColumnSpec(
        label: 'Игр',
        numeric: true,
        build: (d) => Text(
            '${refs.games.where((g) => g.designerIds.contains(d.id)).length}')),
  ],
  update: (q, {search, sortField, sortAscending, page, size, includeDeleted}) =>
      q.copyWith(
    search: search,
    sortField: sortField,
    sortAscending: sortAscending,
    page: page,
    size: size,
    includeDeleted: includeDeleted,
  ),
  reset: (q) => DesignerQuery(
      size: q.size, sortField: q.sortField, sortAscending: q.sortAscending),
  activeFilterCount: (q) => q.country != null ? 1 : 0,
  filters: (q, refs, apply) => [
    FilterDropdown<String>(
      label: 'Страна',
      value: q.country,
      options: {for (final c in refs.designerCountries) c: c},
      onChanged: (v) => apply(q.copyWith(country: v)),
    ),
  ],
);

SimpleQuery _updateSimple(SimpleQuery q,
        {String? search,
        String? sortField,
        bool? sortAscending,
        int? page,
        int? size,
        bool? includeDeleted}) =>
    q.copyWith(
      search: search,
      sortField: sortField,
      sortAscending: sortAscending,
      page: page,
      size: size,
      includeDeleted: includeDeleted,
    );

SimpleQuery _resetSimple(SimpleQuery q) => SimpleQuery(
      defaultSortField: q.defaultSortField,
      size: q.size,
      sortField: q.sortField,
      sortAscending: q.sortAscending,
    );

final genresListConfig = EntityListConfig<Genre, SimpleQuery>(
  title: 'Жанры',
  path: '/genres',
  searchHint: 'Поиск по названию или описанию',
  idOf: (g) => g.id,
  isDeleted: (g) => g.isDeleted,
  nameOf: (g) => g.name,
  subtitleOf: (g, refs) =>
      g.description.isEmpty ? 'Без описания' : g.description,
  columns: (refs) => [
    TableColumnSpec(
        label: 'Название', sortField: 'name', build: (g) => Text(g.name)),
    TableColumnSpec(
        label: 'Описание',
        build: (g) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(g.description, overflow: TextOverflow.ellipsis))),
    TableColumnSpec(
        label: 'Игр',
        numeric: true,
        build: (g) => Text(
            '${refs.games.where((game) => game.genreIds.contains(g.id)).length}')),
  ],
  update: _updateSimple,
  reset: _resetSimple,
  activeFilterCount: (q) => 0,
  filters: (q, refs, apply) => const [],
);

final publishersListConfig = EntityListConfig<Publisher, SimpleQuery>(
  title: 'Издатели',
  path: '/publishers',
  searchHint: 'Поиск по названию или стране',
  idOf: (p) => p.id,
  isDeleted: (p) => p.isDeleted,
  nameOf: (p) => p.name,
  subtitleOf: (p, refs) => '${p.country} · с ${p.foundedYear} г.',
  columns: (refs) => [
    TableColumnSpec(
        label: 'Название', sortField: 'name', build: (p) => Text(p.name)),
    TableColumnSpec(
        label: 'Страна', sortField: 'country', build: (p) => Text(p.country)),
    TableColumnSpec(
        label: 'Год основания',
        sortField: 'foundedYear',
        numeric: true,
        build: (p) => Text('${p.foundedYear}')),
    TableColumnSpec(
        label: 'Почта', build: (p) => Text(p.email.isEmpty ? '—' : p.email)),
    TableColumnSpec(
        label: 'Игр',
        numeric: true,
        build: (p) =>
            Text('${refs.games.where((g) => g.publisherId == p.id).length}')),
  ],
  update: _updateSimple,
  reset: _resetSimple,
  activeFilterCount: (q) => q.filter != null ? 1 : 0,
  filters: (q, refs, apply) => [
    FilterDropdown<String>(
      label: 'Страна',
      value: q.filter,
      options: {for (final c in refs.publisherCountries) c: c},
      onChanged: (v) => apply(q.copyWith(filter: v)),
    ),
  ],
);

final membersListConfig = EntityListConfig<Member, SimpleQuery>(
  title: 'Участники клуба',
  path: '/members',
  searchHint: 'Поиск по фамилии, почте или номеру карты',
  idOf: (m) => m.id,
  isDeleted: (m) => m.isDeleted,
  nameOf: (m) => m.fullName,
  subtitleOf: (m, refs) => '${m.city} · ${m.email} · карта ${m.card.number}',
  columns: (refs) => [
    TableColumnSpec(
        label: 'Фамилия',
        sortField: 'lastName',
        build: (m) => Text(m.lastName)),
    TableColumnSpec(label: 'Имя', build: (m) => Text(m.firstName)),
    TableColumnSpec(
        label: 'Город', sortField: 'city', build: (m) => Text(m.city)),
    TableColumnSpec(
        label: 'Почта', sortField: 'email', build: (m) => Text(m.email)),
    TableColumnSpec(label: 'Клубная карта', build: (m) => Text(m.card.number)),
    TableColumnSpec(
        label: 'Лимит игр',
        numeric: true,
        build: (m) => Text('${m.card.maxGames}')),
  ],
  update: _updateSimple,
  reset: _resetSimple,
  activeFilterCount: (q) => q.filter != null ? 1 : 0,
  filters: (q, refs, apply) => [
    FilterDropdown<String>(
      label: 'Город',
      value: q.filter,
      options: {for (final c in refs.memberCities) c: c},
      onChanged: (v) => apply(q.copyWith(filter: v)),
    ),
  ],
);
