import 'models/certificate.dart';
import 'models/lesson.dart';
import 'models/student_profile.dart';
import 'models/task_item.dart';

/// Моковые данные — один в один из макета
/// `docs/Расписание - Material 3 Expressive.dc.html`.
abstract final class MockData {
  /// Индекс дня, открытого по умолчанию (среда).
  static const int initialDayIndex = 2;

  /// Дата в шапке вкладки «Расписание».
  static const String headerDate = 'Среда, 16 сентября';

  static const StudentProfile profile = StudentProfile(
    name: 'Артём Кузнецов',
    initials: 'АК',
    group: '2423 УИР',
    course: '3 курс · ИКТиУ',
    moodleLogin: '000000',
    moodlePassword: 'пароль-скрыт',
  );

  static const String syncStatus = 'Синхронизировано с ботом · 2 мин назад';

  /// Пропущено часов всего.
  static const int missedHours = 14;

  /// Допустимый лимит пропусков.
  static const int missedLimitHours = 40;

  /// Из них оправдано справками.
  static const int justifiedHours = 8;

  /// Из них без справки.
  static const int unjustifiedHours = 6;

  static const List<String> searchFilters = [
    'Группы',
    'Преподаватели',
    'Аудитории',
  ];

  static const String searchHint = 'Поиск группы, препода, аудитории';

  static const List<({String label, String kind})> recentSearches = [
    (label: '2423 УИР', kind: 'Группа'),
    (label: 'Соколова А. В.', kind: 'Преподаватель'),
    (label: 'ауд. 415', kind: 'Аудитория'),
  ];

  // Не const: у ScheduleDay есть поле DateTime, а его конструктор не константный.
  static final List<ScheduleDay> week = [
    ScheduleDay(
      key: 'mon',
      shortName: 'Пн',
      dayNumber: '14',
      date: DateTime(2026, 9, 14),
      title: 'Понедельник',
      lessons: [
        Lesson(
          start: '10:20',
          end: '11:55',
          title: 'Теория вероятностей',
          type: LessonType.lecture,
          teacher: 'Соколова А. В.',
          room: 'ауд. 312',
        ),
        Lesson(
          start: '12:25',
          end: '14:00',
          title: 'Операционные системы',
          type: LessonType.practice,
          teacher: 'Гаврилов Р. О.',
          room: 'ауд. 407',
        ),
        Lesson(
          start: '14:10',
          end: '15:45',
          title: 'Философия',
          type: LessonType.lecture,
          teacher: 'Белова Н. К.',
          room: 'ауд. 118',
        ),
      ],
    ),
    ScheduleDay(
      key: 'tue',
      shortName: 'Вт',
      dayNumber: '15',
      date: DateTime(2026, 9, 15),
      title: 'Вторник',
      lessons: [
        Lesson(
          start: '08:30',
          end: '10:05',
          title: 'Дискретная математика',
          type: LessonType.lecture,
          teacher: 'Соколова А. В.',
          room: 'ауд. 312',
        ),
        Lesson(
          start: '10:20',
          end: '11:55',
          title: 'Сети и телекоммуникации',
          type: LessonType.lab,
          teacher: 'Ким А. С.',
          room: 'ауд. 503',
        ),
        Lesson(
          start: '12:25',
          end: '14:00',
          title: 'Английский язык',
          type: LessonType.practice,
          teacher: 'Литвинова Е. Н.',
          room: 'ауд. 108',
        ),
        Lesson(
          start: '14:10',
          end: '15:45',
          title: 'Физическая культура',
          type: LessonType.practice,
          teacher: 'Орлов П. В.',
          room: 'Спортзал',
        ),
      ],
    ),
    ScheduleDay(
      key: 'wed',
      shortName: 'Ср',
      dayNumber: '16',
      date: DateTime(2026, 9, 16),
      title: 'Среда',
      lessons: [
        Lesson(
          start: '08:30',
          end: '10:05',
          title: 'Математический анализ',
          type: LessonType.lecture,
          teacher: 'Соколова А. В.',
          room: 'ауд. 312',
        ),
        Lesson(
          start: '10:20',
          end: '11:55',
          title: 'Базы данных',
          type: LessonType.practice,
          teacher: 'Иванов Д. С.',
          room: 'ауд. 415',
          isNow: true,
          timeLeft: '32 мин',
          progress: 0.66,
        ),
        Lesson(
          start: '12:25',
          end: '14:00',
          title: 'Архитектура ЭВМ',
          type: LessonType.lecture,
          teacher: 'Мельников И. П.',
          room: 'ауд. 201',
        ),
        Lesson(
          start: '14:10',
          end: '15:45',
          title: 'Английский язык',
          type: LessonType.practice,
          teacher: 'Литвинова Е. Н.',
          room: 'ауд. 108',
        ),
      ],
    ),
    ScheduleDay(
      key: 'thu',
      shortName: 'Чт',
      dayNumber: '17',
      date: DateTime(2026, 9, 17),
      title: 'Четверг',
      lessons: [
        Lesson(
          start: '10:20',
          end: '11:55',
          title: 'Базы данных',
          type: LessonType.lab,
          teacher: 'Иванов Д. С.',
          room: 'ауд. 415',
        ),
        Lesson(
          start: '12:25',
          end: '14:00',
          title: 'Web-технологии',
          type: LessonType.practice,
          teacher: 'Ким А. С.',
          room: 'ауд. 503',
        ),
        Lesson(
          start: '14:10',
          end: '15:45',
          title: 'Экономика',
          type: LessonType.lecture,
          teacher: 'Белова Н. К.',
          room: 'ауд. 118',
        ),
      ],
    ),
    ScheduleDay(
      key: 'fri',
      shortName: 'Пт',
      dayNumber: '18',
      date: DateTime(2026, 9, 18),
      title: 'Пятница',
      lessons: [
        Lesson(
          start: '08:30',
          end: '10:05',
          title: 'Архитектура ЭВМ',
          type: LessonType.lab,
          teacher: 'Мельников И. П.',
          room: 'ауд. 201',
        ),
        Lesson(
          start: '10:20',
          end: '11:55',
          title: 'Математический анализ',
          type: LessonType.practice,
          teacher: 'Соколова А. В.',
          room: 'ауд. 312',
        ),
      ],
    ),
    ScheduleDay(
      key: 'sat',
      shortName: 'Сб',
      dayNumber: '19',
      date: DateTime(2026, 9, 19),
      title: 'Суббота',
      lessons: [],
    ),
  ];

  static const List<Certificate> certificates = [
    Certificate(
      id: '1',
      title: 'ОРВИ, справка №1042',
      period: '12 — 15 сентября · 8 ч',
      status: CertificateStatus.pending,
      note: 'Отправлено 15 сент, 18:24',
    ),
    Certificate(
      id: '2',
      title: 'Соревнования по волейболу',
      period: '2 — 4 сентября · 6 ч',
      status: CertificateStatus.approved,
      note: 'Проверено куратором',
    ),
    Certificate(
      id: '3',
      title: 'Фото справки от 28 августа',
      period: '28 августа · 4 ч',
      status: CertificateStatus.rejected,
      note: 'Причина: нечитаемое фото',
    ),
  ];

  static const List<TaskItem> tasks = [
    TaskItem(
      id: '1',
      text: 'Сдать лабораторную №3',
      subject: 'Базы данных',
      due: 'Завтра, 18:00',
      isUrgent: true,
    ),
    TaskItem(
      id: '2',
      text: 'Подготовить доклад по архитектуре ЭВМ',
      subject: 'Архитектура ЭВМ',
      due: '22 сентября',
    ),
    TaskItem(
      id: '3',
      text: 'Эссе на английском, 250 слов',
      subject: 'Английский язык',
      due: '25 сентября',
    ),
    TaskItem(
      id: '4',
      text: 'Закрыть тест в Moodle',
      subject: 'Мат. анализ',
      due: 'Сегодня, 23:59',
      isUrgent: true,
      isDone: true,
    ),
  ];
}
