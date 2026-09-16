import 'package:flutter/foundation.dart';

@immutable
class StudentProfile {
  const StudentProfile({
    required this.name,
    required this.initials,
    required this.group,
    required this.course,
    required this.moodleLogin,
    required this.moodlePassword,
  });

  final String name;
  final String initials;
  final String group;

  /// `3 курс · ИКТиУ`
  final String course;

  final String moodleLogin;
  final String moodlePassword;
}
