import 'package:flutter/material.dart';

import '../theme/color_palette.dart';
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final Widget? trailing;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Pesquisar...',
    this.trailing,
  });

  void _limparTexto() {
    controller.clear();
    onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final campo = Container(
      height: 46,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: colors.textSecondary, fontSize: 14),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: colors.textFaint, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: colors.textFaint, size: 20),
          suffixIcon: trailing != null
              ? null
              : ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
              icon: Icon(Icons.close, color: colors.textFaint, size: 18),
              onPressed: _limparTexto,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );

    if (trailing == null) return campo;

    return Row(children: [
      Expanded(child: campo),
      const SizedBox(width: 12),
      trailing!,
    ]);
  }
}