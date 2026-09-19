import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../state/mitso_providers.dart';
import 'update_checker.dart';
import 'update_downloader.dart';
import 'update_http.dart';
import 'update_installer.dart';
import 'update_manifest.dart';

/// Проверка обновлений. В тестах переопределяется подстановкой.
final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  final UpdateChecker checker = UpdateChecker();
  ref.onDispose(checker.close);
  return checker;
});

/// Установка скачанного файла. В тестах переопределяется подстановкой.
final updateInstallerProvider = Provider<UpdateInstallPort>(
  (ref) => const UpdateInstaller(),
);

/// Может ли приложение поставить обновление само. Если нет — экрану остаётся
/// открыть страницу релиза.
final updateInstallSupportedProvider = Provider<bool>(
  (ref) => ref.watch(updateInstallerProvider).isSupported,
);

/// Куда складывать скачанное: временная папка приложения. Система вправе её
/// очистить, поэтому проверенный файл — только ускорение повторной попытки.
final updateDownloaderProvider = FutureProvider<UpdateDownloader>((ref) async {
  final Directory temp = await getTemporaryDirectory();
  final UpdateDownloader downloader = UpdateDownloader(
    directory: Directory(p.join(temp.path, 'mitso-update')),
  );
  ref.onDispose(downloader.close);
  return downloader;
}, retry: noRetry);

/// Текущая сборка и ключи файлов под это устройство.
@immutable
class UpdateTarget {
  const UpdateTarget({required this.build, required this.assetKeys});

  /// Номер сборки (`+N` из pubspec).
  final int build;

  /// Ключи файлов в порядке предпочтения, см. [kUpdateAssetKeys].
  final List<String> assetKeys;
}

/// Сведения об этой сборке и устройстве. В тестах переопределяются
/// подстановкой: `PackageInfo` и `DeviceInfoPlugin` ходят в платформу.
final updateTargetProvider = FutureProvider<UpdateTarget>(
  (ref) async => UpdateTarget(
    build: await currentBuildNumber(),
    assetKeys: currentAssetKeys(),
  ),
  retry: noRetry,
);

/// Версия этой сборки для экрана «О приложении»: «1.0.0 (12)». В тестах
/// переопределяется: `PackageInfo` ходит в платформу.
final appVersionProvider = FutureProvider<String>((ref) async {
  final PackageInfo info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}, retry: noRetry);

/// Что сейчас делает обновление.
enum UpdatePhase {
  /// Ничего не запущено: либо обновления нет, либо его ещё не начали ставить.
  available,

  /// Идёт загрузка, доля — в [UpdateState.progress].
  downloading,

  /// Файл скачан и проверен, открывается установщик.
  installing,

  /// Последняя попытка сорвалась, причина — в [UpdateState.error].
  failed,
}

/// Состояние обновления: проверка → загрузка → установка.
@immutable
class UpdateState {
  const UpdateState({
    this.update,
    this.phase = UpdatePhase.available,
    this.progress = 0,
    this.error,
    this.dismissed = false,
    this.checking = false,
    this.outcome,
    this.checkedAt,
  });

  /// Найденное обновление; `null` — не найдено или ещё не проверяли.
  final AvailableUpdate? update;

  final UpdatePhase phase;

  /// Доля загрузки от 0 до 1.
  final double progress;

  /// Текст ошибки для пользователя (только в фазе [UpdatePhase.failed]).
  final String? error;

  /// Пользователь нажал «Позже».
  final bool dismissed;

  /// Идёт проверка.
  final bool checking;

  /// Чем кончилась последняя проверка; `null` — ещё не проверяли.
  final UpdateCheckOutcome? outcome;

  /// Когда закончилась последняя проверка.
  final DateTime? checkedAt;

  /// Есть что предложить пользователю и он это ещё не отложил. Обязательное
  /// обновление не прячется.
  bool get isVisible => update != null && (!dismissed || update!.isMandatory);

  /// Файл под это устройство есть — можно ставить из приложения.
  bool get hasFile => update?.asset != null;

  /// Идёт загрузка или установка: кнопки блокируются, повторная проверка
  /// откладывается.
  bool get isBusy =>
      phase == UpdatePhase.downloading || phase == UpdatePhase.installing;

  /// [error] не переносится: текст ошибки живёт до следующего действия
  /// пользователя, иначе он остаётся висеть на экране после удачной попытки.
  UpdateState copyWith({
    UpdatePhase? phase,
    double? progress,
    String? error,
    bool? dismissed,
    bool? checking,
    UpdateCheckOutcome? outcome,
    DateTime? checkedAt,
  }) => UpdateState(
    update: update,
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    error: error,
    dismissed: dismissed ?? this.dismissed,
    checking: checking ?? this.checking,
    outcome: outcome ?? this.outcome,
    checkedAt: checkedAt ?? this.checkedAt,
  );
}

/// Состояние обновления для экрана: проверка при первом обращении и по
/// кнопке, загрузка с прогрессом, запуск установки. Ошибок наружу не отдаёт —
/// всё, что случилось, лежит в [UpdateState].
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// Есть ли о чём сообщить точкой на значке настроек и на вкладке «Профиль».
///
/// Отдельный провайдер с `select`: иначе оболочка приложения перестраивалась
/// бы на каждый процент загрузки.
final updateBadgeProvider = Provider<bool>(
  (ref) => ref.watch(
    updateControllerProvider.select((UpdateState s) => s.isVisible),
  ),
);

/// Обновление, которое нельзя отложить: сборка ниже `minSupportedBuild`.
final mandatoryUpdateProvider = Provider<bool>(
  (ref) => ref.watch(
    updateControllerProvider.select(
      (UpdateState s) => s.update?.isMandatory ?? false,
    ),
  ),
);

class UpdateController extends Notifier<UpdateState> {
  UpdateCancelToken? _cancelToken;
  double _lastProgress = 0;

  @override
  UpdateState build() {
    if (!ref.watch(updateCheckerProvider).isEnabled) {
      // Ключей подписи нет — в сеть не ходим и экрану говорим прямо.
      return const UpdateState(outcome: UpdateCheckOutcome.disabled);
    }
    ref.onDispose(() => _cancelToken?.cancel());
    // Первая проверка — когда экран впервые обратился к провайдеру.
    _check();
    return const UpdateState(checking: true);
  }

  /// Проверить ещё раз — кнопка на экране обновлений. Пока идёт загрузка или
  /// установка, ничего не делает.
  Future<void> checkNow() async {
    if (state.checking || state.isBusy) return;
    state = state.copyWith(checking: true);
    await _check();
  }

  Future<void> _check() async {
    try {
      final UpdateTarget target = await ref.read(updateTargetProvider.future);
      final UpdateCheckResult result = await ref
          .read(updateCheckerProvider)
          .checkDetailed(
            currentBuild: target.build,
            assetKeys: target.assetKeys,
          );
      if (!ref.mounted) return;
      if (result.outcome == UpdateCheckOutcome.failed) {
        // Найденное раньше обновление из-за сбоя сети не теряем.
        state = state.copyWith(
          checking: false,
          outcome: result.outcome,
          checkedAt: _now(),
        );
      } else {
        state = UpdateState(
          update: result.update,
          outcome: result.outcome,
          checkedAt: _now(),
        );
      }
    } catch (error) {
      debugPrint('[Обновления] Проверка не удалась: $error');
      if (!ref.mounted) return;
      state = state.copyWith(
        checking: false,
        outcome: UpdateCheckOutcome.failed,
        checkedAt: _now(),
      );
    }
  }

  /// Скачивает файл и открывает установщик. Повторный вызов во время работы
  /// ничего не делает; уже скачанный и проверенный файл не качается заново.
  Future<void> downloadAndInstall() async {
    final UpdateAsset? asset = state.update?.asset;
    if (asset == null || state.isBusy) return;

    _lastProgress = 0;
    final UpdateCancelToken cancelToken = UpdateCancelToken();
    _cancelToken = cancelToken;
    state = state.copyWith(phase: UpdatePhase.downloading, progress: 0);
    try {
      final UpdateDownloader downloader = await ref.read(
        updateDownloaderProvider.future,
      );
      final File file = await downloader.download(
        asset,
        onProgress: _onProgress,
        cancelToken: cancelToken,
      );
      if (!ref.mounted) return;

      state = state.copyWith(phase: UpdatePhase.installing, progress: 1);
      await ref.read(updateInstallerProvider).install(file);

      // На Android открылся системный установщик. Если его закрыли, кнопку
      // можно нажать ещё раз — файл уже скачан и проверен.
      if (ref.mounted) state = state.copyWith(phase: UpdatePhase.available);
    } on UpdateInstallException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(phase: UpdatePhase.failed, error: error.message);
      }
    } on UpdateCancelled {
      // Отмена — не ошибка: возвращаемся к предложению обновиться.
      if (ref.mounted) {
        state = state.copyWith(phase: UpdatePhase.available, progress: 0);
      }
    } catch (error) {
      debugPrint('[Обновления] Обновление не удалось: $error');
      if (ref.mounted) {
        state = state.copyWith(
          phase: UpdatePhase.failed,
          error: state.phase == UpdatePhase.installing
              ? 'Не удалось запустить установку'
              : 'Не удалось скачать обновление',
        );
      }
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  /// Отменяет загрузку. Скачанный кусок остаётся: следующая попытка продолжит
  /// с места обрыва.
  void cancelDownload() {
    if (state.phase != UpdatePhase.downloading) return;
    _cancelToken?.cancel();
  }

  /// «Позже» — скрыть до перезапуска приложения. Обязательное обновление
  /// не скрывается.
  void dismiss() {
    if (state.update?.isMandatory ?? false) return;
    state = state.copyWith(dismissed: true);
  }

  /// Прогресс в состояние — не чаще раза в процент, иначе экран
  /// перерисовывается на каждом пакете из сети.
  void _onProgress(double progress) {
    if (!ref.mounted) return;
    if (progress - _lastProgress < 0.01 && progress < 1) return;
    _lastProgress = progress;
    state = state.copyWith(progress: progress);
  }

  DateTime _now() => ref.read(clockProvider)();
}
