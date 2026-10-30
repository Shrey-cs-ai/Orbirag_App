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
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
  }
}
