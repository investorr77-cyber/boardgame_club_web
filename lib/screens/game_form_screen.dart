import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/board_game.dart';
import '../state/edit_notifiers.dart' show EntityEditNotifier;
import '../state/reference_notifier.dart';
import '../widgets/form/entity_form.dart';
import '../widgets/form/relation_fields.dart';
import '../widgets/form/validators.dart';
import 'edit_frame.dart';

/// Форма игры со всеми типами связей: издатель (многие к одному),
/// авторы и жанры (многие ко многим).
class GameFormScreen extends StatelessWidget {
  const GameFormScreen({super.key, this.idParam});

  final String? idParam;

  @override
  Widget build(BuildContext context) {
    return EditFrame<BoardGame>(
      idParam: idParam,
      title: idParam == null ? 'Новая игра' : 'Изменение игры',
      listPath: '/games',
      builder: (context, game) => _GameForm(key: ValueKey(game), game: game),
    );
  }
}

class _GameForm extends StatefulWidget {
  const _GameForm({super.key, required this.game});

  final BoardGame? game;

  @override
  State<_GameForm> createState() => _GameFormState();
}

class _GameFormState extends State<_GameForm> {
  // Состояние полей связей — локальное состояние формы.
  late int? _publisherId = widget.game?.publisherId;
  late List<int> _designerIds = [...?widget.game?.designerIds];
  late List<int> _genreIds = [...?widget.game?.genreIds];
  bool _allDesigners = false;
  int? _savedId;

  static final _digits = [FilteringTextInputFormatter.digitsOnly];

  Map<String, String> get _initialValues {
    final g = widget.game;
    if (g == null) return const {};
    return {
      'title': g.title,
      'barcode': g.barcode,
      'year': '${g.year}',
      'playTimeMin': '${g.playTimeMin}',
      'minPlayers': '${g.minPlayers}',
      'maxPlayers': '${g.maxPlayers}',
      'copiesTotal': '${g.copiesTotal}',
      'copiesAvailable': '${g.copiesAvailable}',
    };
  }

  /// Каскад: после выбора издателя в списке авторов остаются те,
  /// кто уже выпускал игры у этого издателя. Null — показывать всех.
  Set<int>? _visibleDesigners(ReferenceNotifier refs) {
    final publisherId = _publisherId;
    if (publisherId == null || _allDesigners) return null;
    final ids = {
      for (final g in refs.games)
        if (g.publisherId == publisherId && g.id != widget.game?.id)
          ...g.designerIds,
    };
    return ids.isEmpty ? null : ids;
  }

  Future<Map<String, String>> _save(Map<String, String> v) async {
    final notifier = context.read<EntityEditNotifier<BoardGame>>();
    final original = widget.game;
    // Уникальность штрихкода проверяет сервер: ответ 422 с ключом barcode
    // EntityForm покажет под полем штрихкода.
    final game = BoardGame(
      id: original?.id ?? 0,
      title: v['title']!,
      barcode: v['barcode']!,
      year: int.parse(v['year']!),
      playTimeMin: int.parse(v['playTimeMin']!),
      minPlayers: int.parse(v['minPlayers']!),
      maxPlayers: int.parse(v['maxPlayers']!),
      publisherId: _publisherId!,
      designerIds: _designerIds,
      genreIds: _genreIds,
      copiesTotal: int.parse(v['copiesTotal']!),
      copiesAvailable: int.parse(v['copiesAvailable']!),
      deletedAt: original?.deletedAt,
    );
    final saved = await notifier.save(game, isNew: original == null);
    _savedId = saved.id;
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceNotifier>();
    final isEditing = widget.game != null;
    final visibleDesigners = _visibleDesigners(refs);
    return EntityForm(
      title: isEditing ? 'Изменение игры' : 'Новая игра',
      isEditing: isEditing,
      initialValues: _initialValues,
      onSubmit: _save,
      onDone: (saved) => closeForm(
        context,
        saved: saved,
        listPath: '/games',
        savedId: _savedId,
        created: !isEditing,
      ),
      groups: [
        FieldGroup(title: 'Основное', fields: [
          FieldSpec(
            name: 'title',
            label: 'Название',
            width: 576,
            maxLength: 100,
            validator: all([notEmpty(), minLength(2), maxLength(100)]),
          ),
          FieldSpec(
            name: 'barcode',
            label: 'Штрихкод EAN-13',
            hint: '4627110079192',
            keyboardType: TextInputType.number,
            inputFormatters: [..._digits, LengthLimitingTextInputFormatter(13)],
            validator: all([notEmpty(), ean13()]),
          ),
          FieldSpec(
            name: 'year',
            label: 'Год издания',
            width: 160,
            keyboardType: TextInputType.number,
            inputFormatters: [..._digits, LengthLimitingTextInputFormatter(4)],
            validator: all([notEmpty(), year()]),
          ),
          FieldSpec(
            name: 'playTimeMin',
            label: 'Партия, мин',
            width: 160,
            keyboardType: TextInputType.number,
            inputFormatters: _digits,
            validator: all([notEmpty(), positiveInt(max: 1440)]),
          ),
        ]),
        FieldGroup(title: 'Игроки и наличие в клубе', fields: [
          FieldSpec(
            name: 'minPlayers',
            label: 'Игроков от',
            width: 160,
            keyboardType: TextInputType.number,
            inputFormatters: _digits,
            validator: all([notEmpty(), intInRange(1, 20)]),
          ),
          FieldSpec(
            name: 'maxPlayers',
            label: 'Игроков до',
            width: 160,
            keyboardType: TextInputType.number,
            inputFormatters: _digits,
            validator: all([notEmpty(), intInRange(1, 100)]),
            crossValidator: (value, values) {
              final min = int.tryParse(values['minPlayers'] ?? '');
              final max = int.tryParse(value);
              return min != null && max != null && max < min
                  ? 'Не меньше, чем «от» ($min)'
                  : null;
            },
          ),
          FieldSpec(
            name: 'copiesTotal',
            label: 'Коробок в клубе',
            width: 190,
            keyboardType: TextInputType.number,
            inputFormatters: _digits,
            validator: all([notEmpty(), positiveInt(max: 100)]),
          ),
          FieldSpec(
            name: 'copiesAvailable',
            label: 'Свободно',
            width: 190,
            keyboardType: TextInputType.number,
            inputFormatters: _digits,
            validator: all([notEmpty(), intInRange(0, 100)]),
            crossValidator: (value, values) {
              final total = int.tryParse(values['copiesTotal'] ?? '');
              final free = int.tryParse(value);
              return total != null && free != null && free > total
                  ? 'Не больше, чем коробок в клубе ($total)'
                  : null;
            },
          ),
        ]),
        FieldGroup(title: 'Связи', children: [
          IdDropdownField(
            label: 'Издатель (многие к одному)',
            value: _publisherId,
            options: {
              for (final p in refs.publishers)
                if (!p.isDeleted || p.id == _publisherId) p.id: p.name,
            },
            emptyMessage: 'Выберите издателя',
            onChanged: (v) => setState(() => _publisherId = v),
          ),
          MultiChipField(
            label: 'Авторы (многие ко многим)',
            initialValue: _designerIds,
            options: {
              for (final d in refs.designers)
                if (!d.isDeleted || _designerIds.contains(d.id)) d.id: d.fullName,
            },
            visibleIds: visibleDesigners,
            emptyMessage: 'Выберите хотя бы одного автора',
            helper: visibleDesigners == null
                ? null
                : 'Показаны авторы, уже выпускавшие игры у выбранного издателя',
            header: _publisherId == null
                ? null
                : SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Показать всех авторов'),
                    value: _allDesigners,
                    onChanged: (v) => setState(() => _allDesigners = v),
                  ),
            onChanged: (v) => setState(() => _designerIds = v),
          ),
          MultiChipField(
            label: 'Жанры (многие ко многим)',
            initialValue: _genreIds,
            options: {
              for (final g in refs.genres)
                if (!g.isDeleted || _genreIds.contains(g.id)) g.id: g.name,
            },
            emptyMessage: 'Выберите хотя бы один жанр',
            onChanged: (v) => setState(() => _genreIds = v),
          ),
        ]),
      ],
    );
  }
}
