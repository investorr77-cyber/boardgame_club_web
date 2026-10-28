import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/board_game.dart';
import '../models/designer.dart';
import '../models/genre.dart';
import '../models/member.dart';
import '../models/permissions.dart';
import '../models/publisher.dart';
import '../state/auth_notifier.dart';
import '../state/details_notifiers.dart';
import 'club_screens.dart';
import 'entity_details_screen.dart';

// Настройки карточек пяти сущностей. Код экрана общий (EntityDetailsScreen).

final gameDetailsConfig = EntityDetailsConfig<BoardGame>(
  path: '/games',
  entityTitle: 'Игра',
  titleOf: (g) => g.title,
  isDeleted: (g) => g.isDeleted,
  sections: (g, refs) => [
    DetailsSection(rows: [
      ('Штрихкод (EAN-13)', g.barcode),
      ('Год издания', '${g.year}'),
      ('Время партии', '${g.playTimeMin} мин'),
      (
        'Игроков',
        g.minPlayers == g.maxPlayers
            ? '${g.minPlayers}'
            : '${g.minPlayers}–${g.maxPlayers}'
      ),
      ('Издатель', refs.publisherName(g.publisherId)),
      ('Коробок в клубе', '${g.copiesTotal}'),
      ('Свободно', '${g.copiesAvailable}'),
    ]),
  ],
  extra: (context, g, notifier, refs) {
    final designers =
        notifier is GameDetailsNotifier ? notifier.designers : const <Designer>[];
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    // Кнопку выдачи видит только сотрудник: участнику она всё равно не разрешена.
    final canIssue = context.watch<AuthNotifier>().can(Operation.issueLoans);

    return [
      if (canIssue && !g.isDeleted) ...[
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => showIssueLoanDialog(context, gameId: g.id, title: g.title),
          icon: const Icon(Icons.outbox_outlined),
          label: Text('Оформить выдачу (свободно ${g.copiesAvailable})'),
        ),
      ],
      const SizedBox(height: 16),
      Text('Жанры', style: titleStyle),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in g.genreIds)
            ActionChip(
              label: Text(refs.genreName(id)),
              onPressed: () => context.push('/genres/$id'),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text('Авторы', style: titleStyle),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final d in designers)
            ActionChip(
              avatar: const Icon(Icons.person_outline, size: 18),
              label: Text(d.fullName),
              onPressed: () => context.push('/designers/${d.id}'),
            ),
        ],
      ),
    ];
  },
);

final designerDetailsConfig = EntityDetailsConfig<Designer>(
  path: '/designers',
  entityTitle: 'Автор',
  titleOf: (d) => d.fullName,
  isDeleted: (d) => d.isDeleted,
  sections: (d, refs) => [
    DetailsSection(rows: [
      ('Фамилия', d.lastName),
      ('Имя', d.firstName),
      ('Страна', d.country),
      ('Год рождения', '${d.birthYear}'),
    ]),
  ],
  relatedTitle: 'Игры автора',
);

final genreDetailsConfig = EntityDetailsConfig<Genre>(
  path: '/genres',
  entityTitle: 'Жанр',
  titleOf: (g) => g.name,
  isDeleted: (g) => g.isDeleted,
  sections: (g, refs) => [
    DetailsSection(rows: [
      ('Название', g.name),
      ('Описание', g.description),
    ]),
  ],
  relatedTitle: 'Игры жанра',
);

final publisherDetailsConfig = EntityDetailsConfig<Publisher>(
  path: '/publishers',
  entityTitle: 'Издатель',
  titleOf: (p) => p.name,
  isDeleted: (p) => p.isDeleted,
  sections: (p, refs) => [
    DetailsSection(rows: [
      ('Название', p.name),
      ('Страна', p.country),
      ('Год основания', '${p.foundedYear}'),
      ('Почта', p.email),
    ]),
  ],
  relatedTitle: 'Игры издателя',
);

final memberDetailsConfig = EntityDetailsConfig<Member>(
  path: '/members',
  entityTitle: 'Участник клуба',
  titleOf: (m) => m.fullName,
  isDeleted: (m) => m.isDeleted,
  sections: (m, refs) => [
    DetailsSection(rows: [
      ('Фамилия', m.lastName),
      ('Имя', m.firstName),
      ('Почта', m.email),
      ('Телефон', m.phone),
      ('Город', m.city),
    ]),
    DetailsSection(title: 'Клубная карта (один к одному)', rows: [
      ('Номер', m.card.number),
      ('Год выдачи', '${m.card.issuedYear}'),
      ('Лимит игр на руках', '${m.card.maxGames}'),
    ]),
  ],
);
