import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../models/lesson.dart';

/// Страница пришла, но расписания в ней нет: сайт отклонил запрос или
/// поменял разметку.
class ScheduleParseException implements Exception {
  const ScheduleParseException(this.message);

  final String message;

  @override
  String toString() => 'ScheduleParseException: $message';
}

/// Разбор ответа `POST /frontend/web/schedule/group-schedule` и
/// `…/teacher-schedule` на apps.mitso.by.
///
/// Разметка ответа:
/// ```html
/// <div id="schedule-content">
///   <div class="weekly-schedule" id="schedule-Текущая неделя">
///     <h2>Понедельник, 14 сентября</h2>
///     <div class="table-responsive"><table>…
///       <tr><td>09.45-11.05</td>
///           <td>Правовое регулирование…(лек) Клименко Т. В.</td>
///           <td>71</td></tr>
/// ```
/// Сервер отдаёт в одном ответе все доступные недели (текущую и следующую).
abstract final class ScheduleParser {
  /// [today] — опорная дата для года: на сайте даты без года.
  static List<ScheduleWeek> parse(String body, {required DateTime today}) {
    final Document document = html.parse(body);
    final Element? content = document.getElementById('schedule-content');
    if (content == null) {
      throw const ScheduleParseException('на странице нет #schedule-content');
    }

    final List<ScheduleWeek> weeks = [];
    for (final Element block in content.querySelectorAll('.weekly-schedule')) {
      final String id = block.id;
      final String label = id.startsWith('schedule-')
          ? id.substring('schedule-'.length)
          : id;
      weeks.add(ScheduleWeek(label: label, days: _parseDays(block, today)));
    }

    if (weeks.isEmpty) {
      throw const ScheduleParseException('в #schedule-content нет недель');
    }
    return weeks;
  }

  static List<ScheduleDay> _parseDays(Element week, DateTime today) {
    final List<ScheduleDay> days = [];
    DateTime? date;

    // Заголовок дня и таблица идут соседями: h2, div.table-responsive, h2, …
    for (final Element child in week.children) {
      if (child.localName == 'h2') {
        date = parseDayHeading(child.text, today: today);
      } else if (date != null) {
        final Element? table = child.localName == 'table'
            ? child
            : child.querySelector('table');
        if (table == null) continue;
        days.add(ScheduleDay(date: date, lessons: _parseRows(table)));
        date = null;
      }
    }
    return days;
  }

  static List<Lesson> _parseRows(Element table) {
    final List<Lesson> lessons = [];
    for (final Element row in table.querySelectorAll('tbody tr')) {
      final List<Element> cells = row.querySelectorAll('td');
      if (cells.length < 2) continue;

      // У студента три колонки: время, дисциплина с преподавателем,
      // аудитория. У преподавателя — четыре: между дисциплиной и аудиторией
      // стоит группа.
      final bool byTeacher = cells.length > 3;
      final Lesson? lesson = parseRow(
        time: cells[0].text,
        description: cells[1].text,
        group: byTeacher ? cells[2].text : '',
        room: byTeacher
            ? cells[3].text
            : (cells.length > 2 ? cells[2].text : ''),
      );
      if (lesson != null) lessons.add(lesson);
    }
    return lessons;
  }

  /// Одна строка таблицы; `null` для пустого слота «(нет занятий)».
  static Lesson? parseRow({
    required String time,
    required String description,
    required String room,
    String group = '',
  }) {
    final String text = _clean(description);
    if (text.isEmpty || text == '(нет занятий)') return null;

    final (String start, String end) = parseTime(time);

    // «1. Название(тип) Фамилия И. О.»: номер подгруппы необязателен, тип —
    // последние скобки (в самом названии тоже бывают скобки).
    final RegExpMatch? match = _lessonPattern.firstMatch(text);
    final int? subgroup = match?.group(1) == null
        ? null
        : int.parse(match!.group(1)!);
    final String title = match == null ? text : match.group(2)!.trim();
    final String rawType = match == null ? '' : match.group(3)!.trim();
    final String teacher = match == null ? '' : match.group(4)!.trim();

    final (LessonType type, String typeLabel) = parseType(rawType);
    final String cleanRoom = _clean(room);
    final String cleanGroup = _clean(group);

    return Lesson(
      start: start,
      end: end,
      title: title,
      type: type,
      typeLabel: typeLabel,
      teacher: teacher.isEmpty ? null : teacher,
      group: cleanGroup.isEmpty ? null : cleanGroup,
      room: cleanRoom.isEmpty ? null : cleanRoom,
      subgroup: subgroup,
    );
  }

  static final RegExp _lessonPattern = RegExp(
    r'^(?:(\d+)\.\s+)?(.*)\(([^()]*)\)\s*(.*)$',
  );

  /// `08.15-9.35` → (`08:15`, `09:35`).
  static (String, String) parseTime(String raw) {
    final RegExpMatch? m = RegExp(
      r'(\d{1,2})[.:](\d{2})\s*[-–—]\s*(\d{1,2})[.:](\d{2})',
    ).firstMatch(raw);
    if (m == null) {
      throw ScheduleParseException('не разобрано время «${raw.trim()}»');
    }
    String hhmm(String h, String m) => '${h.padLeft(2, '0')}:$m';
    return (hhmm(m.group(1)!, m.group(2)!), hhmm(m.group(3)!, m.group(4)!));
  }

  /// Сокращение типа с сайта → тип и подпись бейджа.
  static (LessonType, String) parseType(String raw) {
    final String t = raw.toLowerCase();
    if (t.startsWith('лек')) {
      return (LessonType.lecture, LessonType.lecture.label);
    }
    if (t.startsWith('лаб')) return (LessonType.lab, LessonType.lab.label);
    if (t.contains('практ') || t.contains('сем')) {
      return (LessonType.practice, LessonType.practice.label);
    }
    if (t.startsWith('экз')) return (LessonType.other, 'Экзамен');
    if (t.startsWith('зач')) return (LessonType.other, 'Зачёт');
    if (t.startsWith('конс')) return (LessonType.other, 'Консультация');
    if (t.isEmpty) return (LessonType.other, LessonType.other.label);
    return (LessonType.other, raw[0].toUpperCase() + raw.substring(1));
  }

  /// `Понедельник, 14 сентября` → дата. Год берётся ближайший к [today]:
  /// в январе «28 декабря» — это прошлый год, в декабре «5 января» — следующий.
  static DateTime parseDayHeading(String heading, {required DateTime today}) {
    final RegExpMatch? m = RegExp(
      r'(\d{1,2})\s+([А-Яа-яЁё]+)',
    ).firstMatch(heading);
    final int? month = m == null ? null : _months[m.group(2)!.toLowerCase()];
    if (m == null || month == null) {
      throw ScheduleParseException('не разобрана дата «${heading.trim()}»');
    }
    final int day = int.parse(m.group(1)!);
    final DateTime base = DateTime(today.year, today.month, today.day);

    DateTime? best;
    for (final int year in [today.year - 1, today.year, today.year + 1]) {
      final DateTime candidate = DateTime(year, month, day);
      if (best == null ||
          candidate.difference(base).abs() < best.difference(base).abs()) {
        best = candidate;
      }
    }
    return best!;
  }

  static const Map<String, int> _months = {
    'января': 1,
    'февраля': 2,
    'марта': 3,
    'апреля': 4,
    'мая': 5,
    'июня': 6,
    'июля': 7,
    'августа': 8,
    'сентября': 9,
    'октября': 10,
    'ноября': 11,
    'декабря': 12,
  };

  /// Схлопывает пробелы, включая неразрывные.
  static String _clean(String s) => s.replaceAll(RegExp(r'[\s ]+'), ' ').trim();
}
