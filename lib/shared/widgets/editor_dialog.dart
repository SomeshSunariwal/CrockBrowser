import 'package:flutter/material.dart';

class CrockEditorField extends StatelessWidget {
  const CrockEditorField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.autocorrect = true,
  });
  final String label;
  final String? hintText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus, autocorrect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final suggestions = autocorrect && keyboardType != TextInputType.url;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            autofocus: autofocus,
            autocorrect: suggestions,
            enableSuggestions: suggestions,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(hintText: hintText),
          ),
        ),
      ],
    );
  }
}
