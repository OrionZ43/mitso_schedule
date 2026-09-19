import 'dart:convert';

/// Публичные ключи, которыми подписан манифест обновлений (Ed25519, base64).
///
/// Ключ карты — kid, он совпадает с полем `kid` в `mitso-update.json`.
///
/// Пара ключей создаётся командой
/// `dart run tool/update_signing.dart keygen <kid> <путь вне репозитория>`:
/// приватная часть остаётся на диске у выпускающего релизы и в репозиторий не
/// попадает, а напечатанную публичную строку нужно вписать сюда.
///
/// Пока карта пуста, приложение не принимает ни одного манифеста — проверка
/// обновлений выключена и в сеть не ходит.
///
/// Смена ключа: добавить новый kid рядом со старым, выпустить версию,
/// подписанную старым ключом, и только потом подписывать новым — иначе
/// установленные копии приложения не примут релиз.
const Map<String, String> kUpdateSigningKeys = <String, String>{
  'z43-2026': 'MIMWOjq2Fs3pwyzIe5CMO0kMBZlWli+9KjUA+2xqH9A=',
};

/// Разбирает [keys] из base64 в байты: kid → 32 байта публичного ключа.
Map<String, List<int>> decodeUpdateSigningKeys([
  Map<String, String> keys = kUpdateSigningKeys,
]) => <String, List<int>>{
  for (final MapEntry<String, String> entry in keys.entries)
    entry.key: base64Decode(entry.value),
};
