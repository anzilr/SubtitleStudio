import 'package:flutter/material.dart';

class HelpCategory {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<HelpSection> sections;

  const HelpCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.sections,
  });
}

class HelpSection {
  final String title;
  final String content;
  final List<String> steps;

  const HelpSection({
    required this.title,
    required this.content,
    required this.steps,
  });
}
