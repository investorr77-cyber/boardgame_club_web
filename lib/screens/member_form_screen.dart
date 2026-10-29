import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../state/edit_notifiers.dart' show EntityEditNotifier;
import '../widgets/form/entity_form.dart';
import '../widgets/form/validators.dart';
import 'edit_frame.dart';

/// Форма участника клуба. Клубная карта (связь «один к одному») редактируется
/// вложенной группой полей прямо здесь — отдельного экрана для неё нет.
class MemberFormScreen extends StatelessWidget {
  const MemberFormScreen({super.key, this.idParam});

  final String? idParam;

  @override
  Widget build(BuildContext context) {
    return EditFrame<Member>(
      idParam: idParam,
      title: idParam == null ? 'Новый участник' : 'Изменение участника',
      listPath: '/members',
      builder: (context, member) =>
          _MemberForm(key: ValueKey(member), member: member),
    );
  }
}

class _MemberForm extends StatefulWidget {
  const _MemberForm({super.key, required this.member});

  final Member? member;

  @override
  State<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<_MemberForm> {
  int? _savedId;

  static final _digits = [FilteringTextInputFormatter.digitsOnly];

  Map<String, String> get _initialValues {
    final m = widget.member;
    if (m == null) {
      return {'card.issuedYear': '$currentYear', 'card.maxGames': '2'};
    }
    return {
      'lastName': m.lastName,
      'firstName': m.firstName,
      'email': m.email,
      'phone': m.phone,
      'city': m.city,
      'card.number': m.card.number,
      'card.issuedYear': '${m.card.issuedYear}',
      'card.maxGames': '${m.card.maxGames}',
    };
  }

  Future<Map<String, String>> _save(Map<String, String> v) async {
    final notifier = context.read<EntityEditNotifier<Member>>();
    final original = widget.member;
    final cardNumber = v['card.number']!.toUpperCase();
    // Уникальность почты и номера карты проверяет сервер: ответ 422 с ключами
    // email и card.number EntityForm разложит по полям.
    final member = Member(
      id: original?.id ?? 0,
      lastName: v['lastName']!,
      firstName: v['firstName']!,
      email: v['email']!,
      phone: v['phone']!,
      city: v['city']!,
      card: MemberCard(
        number: cardNumber,
        issuedYear: int.parse(v['card.issuedYear']!),
        maxGames: int.parse(v['card.maxGames']!),
      ),
      deletedAt: original?.deletedAt,
    );
    final saved = await notifier.save(member, isNew: original == null);
    _savedId = saved.id;
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.member != null;
    return EntityForm(
      title: isEditing ? 'Изменение участника' : 'Новый участник',
      isEditing: isEditing,
      initialValues: _initialValues,
      onSubmit: _save,
      onDone: (saved) => closeForm(
        context,
        saved: saved,
        listPath: '/members',
        savedId: _savedId,
        created: !isEditing,
      ),
      groups: [
        FieldGroup(title: 'Участник', fields: [
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
            name: 'email',
            label: 'Почта',
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: all([notEmpty(), maxLength(100), email()]),
          ),
          FieldSpec(
            name: 'phone',
            label: 'Телефон',
            hint: '+79001234567',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
              LengthLimitingTextInputFormatter(12),
            ],
            validator: all([notEmpty(), phone()]),
          ),
          FieldSpec(
            name: 'city',
            label: 'Город',
            validator:
                all([notEmpty(), minLength(2), maxLength(40), letters()]),
          ),
        ]),
        FieldGroup(title: 'Клубная карта (связь «один к одному»)', fields: [
          FieldSpec(
            name: 'card.number',
            label: 'Номер карты',
            hint: 'BG-000123',
            inputFormatters: [LengthLimitingTextInputFormatter(9)],
            validator: all([notEmpty(), cardNumber()]),
          ),
          FieldSpec(
            name: 'card.issuedYear',
            label: 'Год выдачи',
            width: 160,
            keyboardType: TextInputType.number,
            inputFormatters: [..._digits, LengthLimitingTextInputFormatter(4)],
            validator: all([notEmpty(), year(min: 2000)]),
          ),
          FieldSpec(
            name: 'card.maxGames',
            label: 'Лимит игр на руках',
            width: 200,
            keyboardType: TextInputType.number,
            inputFormatters: _digits,
            validator: all([notEmpty(), positiveInt(max: 10)]),
          ),
        ]),
      ],
    );
  }
}
