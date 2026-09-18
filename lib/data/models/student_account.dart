import 'package:flutter/foundation.dart';

/// Доступ к системе дистанционного обучения (Moodle).
@immutable
class MoodleAccess {
  const MoodleAccess({
    required this.group,
    required this.login,
    required this.password,
  });

  final String group;
  final String login;
  final String password;

  static const String url = 'https://sdo.mitso.by/';

  Map<String, Object?> toJson() => {
    'group': group,
    'login': login,
    'password': password,
  };

  factory MoodleAccess.fromJson(Map<String, Object?> json) => MoodleAccess(
    group: json['group']! as String,
    login: json['login']! as String,
    password: json['password']! as String,
  );
}

/// Лицевой счёт студента с student.mitso.by.
@immutable
class StudentAccount {
  const StudentAccount({
    required this.number,
    required this.fullName,
    required this.balance,
    required this.debt,
    required this.penalty,
    required this.asOf,
    required this.fetchedAt,
    this.moodle,
  });

  /// Номер лицевого счёта — он же логин.
  final String number;

  final String fullName;

  /// Баланс в рублях: отрицательный — долг перед университетом.
  final double balance;

  /// Основной долг.
  final double debt;

  /// Пеня за просрочку и процент за пользование чужими деньгами.
  final double penalty;

  /// Конец дня, на который сайт посчитал баланс.
  final DateTime asOf;

  /// Когда приложение получило эти данные.
  final DateTime fetchedAt;

  final MoodleAccess? moodle;

  /// Есть долг: минус на балансе или ненулевой основной долг с пеней.
  bool get inDebt => balance < 0 || debt > 0 || penalty > 0;

  /// Фамилия и инициалы: «Иванов И. И.».
  String get shortName {
    final List<String> parts = fullName.split(RegExp(r'\s+'));
    if (parts.length < 2) return fullName;
    final String initials = parts
        .skip(1)
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0]}.')
        .join(' ');
    return '${parts.first} $initials';
  }

  Map<String, Object?> toJson() => {
    'number': number,
    'fullName': fullName,
    'balance': balance,
    'debt': debt,
    'penalty': penalty,
    'asOf': asOf.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'moodle': moodle?.toJson(),
  };

  factory StudentAccount.fromJson(Map<String, Object?> json) => StudentAccount(
    number: json['number']! as String,
    fullName: json['fullName']! as String,
    balance: (json['balance']! as num).toDouble(),
    debt: (json['debt']! as num).toDouble(),
    penalty: (json['penalty']! as num).toDouble(),
    asOf: DateTime.parse(json['asOf']! as String),
    fetchedAt: DateTime.parse(json['fetchedAt']! as String),
    moodle: json['moodle'] == null
        ? null
        : MoodleAccess.fromJson(json['moodle']! as Map<String, Object?>),
  );
}
