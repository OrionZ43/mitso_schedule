import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;

/// Задача пользователя: что сделать, по какому предмету и к какому сроку.
@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.text,
    this.subject,
    this.dueAt,
    this.isDone = false,
  });

  final String id;
  final String text;

  /// Предмет из расписания; `null` — задача без предмета.
  final String? subject;

  /// Срок; `null` — без срока.
  final DateTime? dueAt;

  final bool isDone;

  /// Срок прошёл, а задача не закрыта.
  bool overdue(DateTime now) =>
      !isDone && dueAt != null && dueAt!.isBefore(DateUtils.dateOnly(now));

  /// На сегодня.
  bool today(DateTime now) => dueAt != null && DateUtils.isSameDay(dueAt, now);

  TaskItem copyWith({
    String? text,
    String? subject,
    bool clearSubject = false,
    DateTime? dueAt,
    bool clearDueAt = false,
    bool? isDone,
  }) => TaskItem(
    id: id,
    text: text ?? this.text,
    subject: clearSubject ? null : (subject ?? this.subject),
    dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
    isDone: isDone ?? this.isDone,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'subject': subject,
    'dueAt': dueAt?.toIso8601String(),
    'isDone': isDone,
  };

  factory TaskItem.fromJson(Map<String, Object?> json) => TaskItem(
    id: json['id']! as String,
    text: json['text']! as String,
    subject: json['subject'] as String?,
    dueAt: json['dueAt'] == null
        ? null
        : DateTime.parse(json['dueAt']! as String),
    isDone: json['isDone'] as bool? ?? false,
  );
}

/// Раздел списка задач: от просроченных к дальним.
enum TaskGroup {
  overdue('Просрочено'),
  today('Сегодня'),
  tomorrow('Завтра'),
  week('На этой неделе'),
  later('Позже'),
  someday('Без срока');

  const TaskGroup(this.title);

  final String title;

  /// Раздел задачи [task] на момент [now].
  static TaskGroup of(TaskItem task, DateTime now) {
    final DateTime? due = task.dueAt;
    if (due == null) return TaskGroup.someday;
    final DateTime today = DateUtils.dateOnly(now);
    final int days = DateUtils.dateOnly(due).difference(today).inDays;
    if (days < 0) return TaskGroup.overdue;
    if (days == 0) return TaskGroup.today;
    if (days == 1) return TaskGroup.tomorrow;
    if (days <= 7) return TaskGroup.week;
    return TaskGroup.later;
  }
}
