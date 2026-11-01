import 'package:flutter/material.dart';

class SafeChatText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const SafeChatText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(_strip(text), style: style);
  }

  String _strip(String s) {
    return s
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*', dotAll: true), (m) => m[1]!)
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m[1]!)
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '')
        .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);
  }
}
