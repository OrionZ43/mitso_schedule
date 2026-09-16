import 'package:flutter/foundation.dart';

@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.text,
    required this.subject,
    required this.due,
    this.isUrgent = false,
    this.isDone = false,
  });

  final String id;
  final String text;
  final String subject;

  /// Срок в виде текста: `Завтра, 18:00`, `22 сентября`.
  final String due;

  /// Срочный или просроченный дедлайн — чип красится в `errorContainer`.
  final bool isUrgent;

  final bool isDone;

  TaskItem copyWith({bool? isDone}) => TaskItem(
    id: id,
    text: text,
    subject: subject,
    due: due,
    isUrgent: isUrgent,
    isDone: isDone ?? this.isDone,
  );
}
