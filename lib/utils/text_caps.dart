import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'input_formatters.dart';

// Auto-capitalization rules for text fields, chosen by field label.
TextCapitalization capitalizationFor(String label) {
  final l = label.toLowerCase();
  if (l.contains('email') || l.contains('phone') || l.contains('zip') || l.contains('birth')) {
    return TextCapitalization.none;
  }
  if (l.contains('patient id') || l.contains('license') || l.startsWith('state')) {
    return TextCapitalization.characters;
  }
  return TextCapitalization.words;
}

// Emails should not be autocorrected.
bool autocorrectFor(String label) => label.toLowerCase().contains('email') == false;

// Keyboard type chosen by field label (null means the normal keyboard).
TextInputType? keyboardFor(String label) {
  final l = label.toLowerCase();
  if (l.contains('phone')) return TextInputType.phone;
  if (l.contains('birth') || l.contains('zip')) return TextInputType.number;
  if (l.contains('email')) return TextInputType.emailAddress;
  return null;
}

// Formatting and length limits chosen by field label.
List<TextInputFormatter> formattersFor(String label) {
  final l = label.toLowerCase();
  if (l.contains('phone')) return [PhoneInputFormatter()];
  if (l.contains('birth')) return [DobInputFormatter()];
  if (l.contains('zip')) return [ZipInputFormatter()];
  if (l.startsWith('state')) {
    return [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')), LengthLimitingTextInputFormatter(2)];
  }
  if (l.contains('email')) {
    return [FilteringTextInputFormatter.deny(RegExp(r'\s')), LengthLimitingTextInputFormatter(60)];
  }
  if (l.contains('first name') || l.contains('last name') || l.contains('city')) {
    return [LengthLimitingTextInputFormatter(30)];
  }
  if (l.contains('patient id') || l.contains('license')) {
    return [LengthLimitingTextInputFormatter(20)];
  }
  if (l.contains('clinic name') || l.contains('full name') || l.contains('name / number')) {
    return [LengthLimitingTextInputFormatter(40)];
  }
  if (l.contains('address')) return [LengthLimitingTextInputFormatter(50)];
  return [];
}
