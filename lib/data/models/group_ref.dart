import 'package:flutter/foundation.dart';

/// Выбранная группа: идентификаторы для запросов к apps.mitso.by и подписи.
///
/// Идентификаторы на сайте транслитерированы (`E\`konomicheskij`,
/// `Dnevnaya`, `3 kurs`, `2423 UIR`), подписи — по-русски.
@immutable
class GroupRef {
  const GroupRef({
    required this.facultyId,
    required this.facultyName,
    required this.formId,
    required this.formName,
    required this.courseId,
    required this.courseName,
    required this.groupId,
    required this.groupName,
  });

  final String facultyId;
  final String facultyName;
  final String formId;
  final String formName;
  final String courseId;
  final String courseName;
  final String groupId;
  final String groupName;

  /// `3 курс · Экономический`.
  String get details => '$courseName · $facultyName';

  Map<String, String> toJson() => {
    'facultyId': facultyId,
    'facultyName': facultyName,
    'formId': formId,
    'formName': formName,
    'courseId': courseId,
    'courseName': courseName,
    'groupId': groupId,
    'groupName': groupName,
  };

  factory GroupRef.fromJson(Map<String, Object?> json) => GroupRef(
    facultyId: json['facultyId']! as String,
    facultyName: json['facultyName']! as String,
    formId: json['formId']! as String,
    formName: json['formName']! as String,
    courseId: json['courseId']! as String,
    courseName: json['courseName']! as String,
    groupId: json['groupId']! as String,
    groupName: json['groupName']! as String,
  );

  @override
  bool operator ==(Object other) =>
      other is GroupRef &&
      other.facultyId == facultyId &&
      other.formId == formId &&
      other.courseId == courseId &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(facultyId, formId, courseId, groupId);
}
