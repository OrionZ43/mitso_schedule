import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mitso_schedule/data/release_notes.dart';
import 'package:mitso_schedule/state/whats_new_controller.dart';

const List<ReleaseNotes> _notes = [
  ReleaseNotes(
    version: '1.10.0',
    headline: 'Десятая',
    notes: [ReleaseNote(icon: Symbols.star, title: 'Новое', text: 'Текст')],
  ),
  ReleaseNotes(
    version: '1.9.0',
    headline: 'Девятая',
    notes: [ReleaseNote(icon: Symbols.star, title: 'Старое', text: 'Текст')],
  ),
];

void main() {
  test('версии сравниваются по числам, а не по строкам', () {
    expect(compareVersions('1.10.0', '1.9.0'), 1);
    expect(compareVersions('1.2.0', '1.2.0'), 0);
    expect(compareVersions('1.2', '1.2.1'), -1);
  });

  test('показываем всё, что пропустили', () {
    expect(
      notesSince(
        '1.8.0',
        current: '1.10.0',
        notes: _notes,
      ).map((r) => r.version),
      ['1.10.0', '1.9.0'],
    );
  });

  test('версии новее установленной не показываются', () {
    expect(
      notesSince(
        '1.8.0',
        current: '1.9.0',
        notes: _notes,
      ).map((r) => r.version),
      ['1.9.0'],
    );
  });

  test('после своей версии показывать нечего', () {
    expect(notesSince('1.10.0', current: '1.10.0', notes: _notes), isEmpty);
  });

  test('номер сборки в версии не участвует', () {
    expect(versionOf('1.3.0 (6)'), '1.3.0');
    expect(versionOf('1.3.0'), '1.3.0');
  });

  test('у каждой заметки есть что показать', () {
    for (final ReleaseNotes release in kReleaseNotes) {
      expect(release.notes, isNotEmpty, reason: release.version);
      expect(release.headline, isNotEmpty, reason: release.version);
      for (final ReleaseNote note in release.notes) {
        expect(note.title, isNotEmpty);
        expect(note.text, isNotEmpty);
      }
    }
  });
}
