import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exceptions.dart';
import '../confirm_dialog.dart';

/// Описание текстового поля. Форма любой сущности строится по списку таких описаний.
class FieldSpec {
  const FieldSpec({
    required this.name,
    required this.label,
    this.validator,
    this.crossValidator,
    this.hint,
    this.helper,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.width = 280,
  });

  final String name;
  final String label;
  final FormFieldValidator<String>? validator;

  /// Проверка, зависящая от других полей (например, «свободно ≤ всего»).
  final String? Function(String value, Map<String, String> values)?
      crossValidator;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final double width;
}

/// Группа полей с заголовком. Отдельной группой показывается связь
/// «один к одному» (клубная карта участника), а в [children] — поля связей.
class FieldGroup {
  const FieldGroup({this.title, this.fields = const [], this.children = const []});

  final String? title;
  final List<FieldSpec> fields;
  final List<Widget> children;
}

/// Общий виджет формы для всех сущностей: разметка, проверка, отправка,
/// ошибки уникальности и предупреждение о несохранённых изменениях.
class EntityForm extends StatefulWidget {
  const EntityForm({
    super.key,
    required this.title,
    required this.isEditing,
    required this.groups,
    required this.initialValues,
    required this.onSubmit,
    required this.onDone,
  });

  final String title;
  final bool isEditing;
  final List<FieldGroup> groups;
  final Map<String, String> initialValues;

  /// Сохранение. Возвращает ошибки отдельных полей (например, нарушение
  /// уникальности) — они показываются под полями; пустой словарь — успех.
  final Future<Map<String, String>> Function(Map<String, String> values)
      onSubmit;

  /// Выход с формы: [saved] — после сохранения, иначе отмена.
  final void Function(bool saved) onDone;

  @override
  State<EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<EntityForm> {
  final _formKey = GlobalKey<FormState>();

  // Контроллеры заполняются в initState данными уже загруженной записи.
  // initialValue у полей не задаётся: controller и initialValue вместе
  // дают исключение.
  late final Map<String, TextEditingController> _controllers = {
    for (final group in widget.groups)
      for (final field in group.fields)
        field.name:
            TextEditingController(text: widget.initialValues[field.name] ?? ''),
  };

  final Map<String, String> _asyncErrors = {};
  bool _dirty = false;
  bool _saving = false;
  bool _submitted = false;

  Map<String, String> get _values => {
        for (final entry in _controllers.entries)
          entry.key: entry.value.text.trim(),
      };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  FormFieldValidator<String> _validatorFor(FieldSpec spec) => (value) {
        // Ошибку уникальности нашёл репозиторий — показываем её под полем.
        final asyncError = _asyncErrors[spec.name];
        if (asyncError != null) return asyncError;
        final error = spec.validator?.call(value);
        if (error != null) return error;
        return spec.crossValidator?.call(value?.trim() ?? '', _values);
      };

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _asyncErrors.clear();
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    Map<String, String> errors;
    try {
      errors = await widget.onSubmit(_values);
    } on ValidationException catch (e) {
      // 422: ошибки сервера раскладываются по полям — ключи совпадают
      // с именами полей. Ошибки полей связей и прочие — общим сообщением.
      final fieldNames = _controllers.keys.toSet();
      errors = {
        for (final entry in e.errors.entries)
          if (fieldNames.contains(entry.key)) entry.key: entry.value,
      };
      final other = [
        for (final entry in e.errors.entries)
          if (!fieldNames.contains(entry.key)) entry.value,
      ];
      if (other.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(other.join('\n'))));
      }
      if (other.isEmpty && errors.isEmpty && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      // Сохранение не удалось — форма остаётся открытой.
      if (errors.isEmpty) errors = {'_server': e.message};
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _asyncErrors.addAll(errors);
    });
    if (errors.isNotEmpty) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() => _dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone(true);
    });
  }

  Future<void> _cancel() async {
    if (_dirty) {
      final leave = await showConfirmDialog(
        context,
        title: 'Уйти без сохранения?',
        message: 'В форме есть несохранённые изменения. Они будут потеряны.',
        confirmLabel: 'Уйти',
        destructive: true,
      );
      if (!leave || !mounted) return;
      setState(() => _dirty = false);
    }
    // После перестроения PopScope уже разрешает уход.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Закрыть',
            icon: const Icon(Icons.close),
            onPressed: _cancel,
          ),
          title: Text(widget.title),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final group in widget.groups) _buildGroup(group),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : _cancel,
                        child: const Text('Отмена'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                            widget.isEditing ? 'Сохранить изменения' : 'Создать'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(FieldGroup group) {
    final content = LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final field in group.fields)
            SizedBox(
              width: field.width < constraints.maxWidth
                  ? field.width
                  : constraints.maxWidth,
              child: TextFormField(
                controller: _controllers[field.name],
                validator: _validatorFor(field),
                keyboardType: field.keyboardType,
                inputFormatters: field.inputFormatters,
                maxLength: field.maxLength,
                maxLines: field.maxLines,
                onChanged: (_) {
                  if (_asyncErrors.remove(field.name) != null) setState(() {});
                },
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.hint,
                  helperText: field.helper,
                  border: const OutlineInputBorder(),
                  errorMaxLines: 3,
                ),
              ),
            ),
          for (final child in group.children)
            SizedBox(width: constraints.maxWidth, child: child),
        ],
      ),
    );
    final title = group.title;
    if (title == null) {
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: content);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}
