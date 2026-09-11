import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/color_palette.dart';
import '../../../../core/scanner/barcode_scanner_page.dart';

class FormLabel extends StatelessWidget {
  final String text;
  const FormLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.colors.textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );
}

class FormField_ extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController ctrl;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  const FormField_({
    super.key,
    required this.label,
    required this.ctrl,
    required this.icon,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onSaved,
    this.validator,
    this.onChanged,
  });

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: c == Colors.transparent
        ? BorderSide.none
        : BorderSide(color: c, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          inputFormatters: inputFormatters,
          style: TextStyle(color: colors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textFaint),
            prefixIcon: Icon(icon, color: colors.textFaint, size: 20),
            filled: true,
            fillColor: colors.surface,
            border: _border(Colors.transparent),
            enabledBorder: _border(Colors.transparent),
            focusedBorder: _border(colors.accent),
            errorBorder: _border(Colors.redAccent),
            focusedErrorBorder: _border(Colors.redAccent),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
          onSaved: onSaved,
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class ScanButton extends StatelessWidget {
  final ValueChanged<String> onScanned;
  const ScanButton({super.key, required this.onScanned});

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final codigo = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
        );
        if (codigo != null && codigo.isNotEmpty) onScanned(codigo);
      },
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.accent, width: 1.5),
        ),
        child: Icon(Icons.qr_code_scanner,
            color: context.colors.accent, size: 22),
      ),
    ),
  );
}

class FormDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const FormDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  /// Atalho para dropdowns simples de String.
  static FormDropdown<String> strings({
    Key? key,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) =>
      FormDropdown<String>(
        key: key,
        value: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: context.colors.surface,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
        icon:
        Icon(Icons.keyboard_arrow_down, color: context.colors.accent),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

class DateButton extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final VoidCallback onTap;
  const DateButton({
    super.key,
    required this.date,
    required this.hint,
    required this.onTap,
  });

  String get _label => date == null
      ? hint
      : '${date!.day.toString().padLeft(2, '0')}/'
      '${date!.month.toString().padLeft(2, '0')}/${date!.year}';

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: date != null ? context.colors.accent : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today,
            color: context.colors.textFaint, size: 20),
        const SizedBox(width: 12),
        Text(
          _label,
          style: TextStyle(
            color: date == null
                ? context.colors.textFaint
                : context.colors.textPrimary,
            fontSize: 15,
          ),
        ),
        const Spacer(),
        Icon(Icons.keyboard_arrow_down,
            color: context.colors.accent, size: 20),
      ]),
    ),
  );
}

class CategoriaEmptyWarning extends StatelessWidget {
  const CategoriaEmptyWarning({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.orangeAccent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded,
          color: Colors.orangeAccent, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Nenhuma categoria cadastrada. O produto pode ser salvo sem categoria, '
              'mas você pode criar uma antes de continuar.',
          style:
          TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      ),
    ]),
  );
}

/// Formatters reutilizáveis.
class FormFormatters {
  const FormFormatters._();
  static final digits = [FilteringTextInputFormatter.digitsOnly];
  static final decimal = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
  ];
  static const decimalKeyboard =
  TextInputType.numberWithOptions(decimal: true);
}