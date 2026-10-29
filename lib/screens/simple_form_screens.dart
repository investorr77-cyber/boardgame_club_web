import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/designer.dart';
import '../models/genre.dart';
import '../models/publisher.dart';
import '../state/edit_notifiers.dart';
import '../widgets/form/entity_form.dart';
import '../widgets/form/validators.dart';
import 'edit_frame.dart';

// Формы авторов, жанров и издателей. Разметка и отправка общие (EntityForm),
// здесь только описание полей и сборка модели.

final _yearFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(4),
];

/// Общая форма без полей связей: описание полей + сборка модели.
class _SimpleForm<T> extends StatefulWidget {
  const _SimpleForm({
    super.key,
    required this.item,
    required this.title,
    required this.listPath,
    required this.fields,
    required this.initialValues,
    required this.build,
  });

  final T? item;
  final String title;
  final String listPath;
  final List<FieldGroup> fields;
  final Map<String, String> initialValues;
  final T Function(Map<String, String> values, T? original) build;

  @override
  State<_SimpleForm<T>> createState() => _SimpleFormState<T>();
}

class _SimpleFormState<T> extends State<_SimpleForm<T>> {
  int? _savedId;

  Future<Map<String, String>> _save(Map<String, String> values) async {
    final notifier = context.read<EntityEditNotifier<T>>();
    final saved = await notifier.save(widget.build(values, widget.item),
        isNew: widget.item == null);
    _savedId = (saved as dynamic).id as int;
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    return EntityForm(
      title: widget.title,
      isEditing: isEditing,
      initialValues: widget.initialValues,
      groups: widget.fields,
      onSubmit: _save,
      onDone: (saved) => closeForm(
        context,
        saved: saved,
        listPath: widget.listPath,
        savedId: _savedId,
        created: !isEditing,
      ),
    );
  }
}

class DesignerFormScreen extends StatelessWidget {
  const DesignerFormScreen({super.key, this.idParam});

  final String? idParam;

  @override
  Widget build(BuildContext context) {
    final title = idParam == null ? 'Новый автор' : 'Изменение автора';
    return EditFrame<Designer>(
      idParam: idParam,
      title: title,
      listPath: '/designers',
      builder: (context, d) => _SimpleForm<Designer>(
        key: ValueKey(d),
        item: d,
        title: title,
        listPath: '/designers',
        initialValues: d == null
            ? const {}
            : {
                'lastName': d.lastName,
                'firstName': d.firstName,
                'country': d.country,
                'birthYear': '${d.birthYear}',
              },
        fields: [
          FieldGroup(fields: [
            FieldSpec(
              name: 'lastName',
              label: 'Фамилия',
              validator:
                  all([notEmpty(), minLength(2), maxLength(40), letters()]),
            ),
            FieldSpec(
              name: 'firstName',
              label: 'Имя',
              validator:
                  all([notEmpty(), minLength(2), maxLength(40), letters()]),
            ),
            FieldSpec(
              name: 'country',
              label: 'Страна',
              validator:
                  all([notEmpty(), minLength(2), maxLength(40), letters()]),
            ),
            FieldSpec(
              name: 'birthYear',
              label: 'Год рождения',
              width: 150,
              keyboardType: TextInputType.number,
              inputFormatters: _yearFormatters,
              validator: all([notEmpty(), year(max: currentYear - 10)]),
            ),
          ]),
        ],
        build: (v, original) => Designer(
          id: original?.id ?? 0,
          lastName: v['lastName']!,
          firstName: v['firstName']!,
          country: v['country']!,
          birthYear: int.parse(v['birthYear']!),
          deletedAt: original?.deletedAt,
        ),
      ),
    );
  }
}

class GenreFormScreen extends StatelessWidget {
  const GenreFormScreen({super.key, this.idParam});

  final String? idParam;

  @override
  Widget build(BuildContext context) {
    final title = idParam == null ? 'Новый жанр' : 'Изменение жанра';
    return EditFrame<Genre>(
      idParam: idParam,
      title: title,
      listPath: '/genres',
      builder: (context, g) => _SimpleForm<Genre>(
        key: ValueKey(g),
        item: g,
        title: title,
        listPath: '/genres',
        initialValues: g == null
            ? const {}
            : {'name': g.name, 'description': g.description},
        fields: [
          FieldGroup(fields: [
            FieldSpec(
              name: 'name',
              label: 'Название',
              maxLength: 40,
              validator: all([notEmpty(), minLength(3), maxLength(40)]),
            ),
            FieldSpec(
              name: 'description',
              label: 'Описание (необязательно)',
              width: 576,
              maxLines: 3,
              maxLength: 200,
              validator: maxLength(200),
            ),
          ]),
        ],
        build: (v, original) => Genre(
          id: original?.id ?? 0,
          name: v['name']!,
          description: v['description']!,
          deletedAt: original?.deletedAt,
        ),
      ),
    );
  }
}

class PublisherFormScreen extends StatelessWidget {
  const PublisherFormScreen({super.key, this.idParam});

  final String? idParam;

  @override
  Widget build(BuildContext context) {
    final title = idParam == null ? 'Новый издатель' : 'Изменение издателя';
    return EditFrame<Publisher>(
      idParam: idParam,
      title: title,
      listPath: '/publishers',
      builder: (context, p) => _SimpleForm<Publisher>(
        key: ValueKey(p),
        item: p,
        title: title,
        listPath: '/publishers',
        initialValues: p == null
            ? const {}
            : {
                'name': p.name,
                'country': p.country,
                'foundedYear': '${p.foundedYear}',
                'email': p.email,
              },
        fields: [
          FieldGroup(fields: [
            FieldSpec(
              name: 'name',
              label: 'Название',
              validator: all([notEmpty(), minLength(2), maxLength(60)]),
            ),
            FieldSpec(
              name: 'country',
              label: 'Страна',
              validator:
                  all([notEmpty(), minLength(2), maxLength(40), letters()]),
            ),
            FieldSpec(
              name: 'foundedYear',
              label: 'Год основания',
              width: 150,
              keyboardType: TextInputType.number,
              inputFormatters: _yearFormatters,
              validator: all([notEmpty(), year(min: 1800)]),
            ),
            FieldSpec(
              name: 'email',
              label: 'Почта (необязательно)',
              keyboardType: TextInputType.emailAddress,
              validator: all([maxLength(100), email()]),
            ),
          ]),
        ],
        build: (v, original) => Publisher(
          id: original?.id ?? 0,
          name: v['name']!,
          country: v['country']!,
          foundedYear: int.parse(v['foundedYear']!),
          email: v['email']!,
          deletedAt: original?.deletedAt,
        ),
      ),
    );
  }
}
