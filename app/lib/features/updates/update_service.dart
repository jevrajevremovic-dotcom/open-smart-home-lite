import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_info.dart';
import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/storage/app_preferences.dart';

/// Where releases come from: `owner/repo` on GitHub (a brand sets its own
/// with `updates=` in brand.properties).
const updateRepo = String.fromEnvironment(
  'UPDATE_REPO',
  defaultValue: 'jevrajevremovic-dotcom/open-smart-home',
);

/// A published release with an APK for this device.
@immutable
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.apkName,
    required this.apkUrl,
    required this.size,
    required this.checksumsUrl,
  });

  final String version;
  final String notes;
  final String apkName;
  final String apkUrl;
  final int size;

  /// `SHA256SUMS` of the release; without it nothing is installed.
  final String? checksumsUrl;
}

/// `1.2.10` > `1.2.9`; a leading `v` and a `+build` suffix are ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
    for (final p
        in v.replaceFirst(RegExp('^v'), '').split('+').first.split('.'))
      int.tryParse(p) ?? 0,
  ];
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// GitHub's public release API (no token: public data only). The request
/// tells GitHub this device's address and that the app checks for updates —
/// which is why automatic checks are opt-in.
class GitHubReleases {
  GitHubReleases({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 5),
              headers: {
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'OpenSmartHome/$appVersion',
              },
            ),
          );

  final Dio _dio;

  /// The newest release with an APK for [abi]; `null` when there is none
  /// (or the repository is not public).
  Future<ReleaseInfo?> latest(String repo, String abi) async {
    final Response<Object?> r;
    try {
      r = await _dio.get<Object?>(
        'https://api.github.com/repos/$repo/releases/latest',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    final json = r.data;
    if (json is! Map) return null;
    final assets = [
      for (final a in (json['assets'] as List?) ?? const [])
        if (a is Map) a,
    ];
    final apk =
        assets.where((a) => '${a['name']}'.contains(abi)).firstOrNull ??
        assets.where((a) => '${a['name']}'.endsWith('.apk')).firstOrNull;
    if (apk == null) return null;
    final sums = assets.where((a) => a['name'] == 'SHA256SUMS').firstOrNull;
    return ReleaseInfo(
      version: '${json['tag_name']}'.replaceFirst(RegExp('^v'), ''),
      notes: '${json['body'] ?? ''}',
      apkName: '${apk['name']}',
      apkUrl: '${apk['browser_download_url']}',
      size: apk['size'] is int ? apk['size']! as int : 0,
      checksumsUrl: sums == null ? null : '${sums['browser_download_url']}',
    );
  }

  /// Downloads [release]'s APK and checks it against `SHA256SUMS`; throws
  /// [UpdateVerificationException] (and deletes the file) on a mismatch.
  Future<File> download(
    ReleaseInfo release, {
    void Function(double)? onProgress,
  }) async {
    final sumsUrl = release.checksumsUrl;
    if (sumsUrl == null) {
      throw const UpdateVerificationException('no SHA256SUMS');
    }
    final sums = (await _dio.get<String>(
      sumsUrl,
      options: Options(responseType: ResponseType.plain),
    )).data;
    final expected = sums
        ?.split('\n')
        .map((l) => l.trim().split(RegExp(r'\s+')))
        .where(
          (p) => p.length == 2 && p[1].replaceFirst('*', '') == release.apkName,
        )
        .map((p) => p[0].toLowerCase())
        .firstOrNull;
    if (expected == null) {
      throw const UpdateVerificationException('APK not in SHA256SUMS');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/update-${release.version}.apk');
    await _dio.download(
      release.apkUrl,
      file.path,
      onReceiveProgress: (got, total) {
        if (total > 0) onProgress?.call(got / total);
      },
    );
    final actual = (await sha256.bind(file.openRead()).first).toString();
    if (actual != expected) {
      await file.delete();
      throw const UpdateVerificationException('checksum mismatch');
    }
    return file;
  }
}

class UpdateVerificationException implements Exception {
  const UpdateVerificationException(this.reason);

  final String reason;

  @override
  String toString() => 'UpdateVerificationException($reason)';
}

/// Android's installer (UpdateInstaller.kt).
abstract interface class UpdateInstallerPlatform {
  bool get supported;

  /// The device's main ABI (`arm64-v8a`…).
  Future<String> abi();

  /// `started`, `needs_permission`, or `unsupported`.
  Future<String> install(String path);
}

class AndroidUpdateInstaller implements UpdateInstallerPlatform {
  static const _channel = MethodChannel('org.opensmarthome/updater');

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String> abi() async =>
      await _channel.invokeMethod<String>('abi') ?? 'arm64-v8a';

  @override
  Future<String> install(String path) async =>
      await _channel.invokeMethod<String>('install', {'path': path}) ??
      'unsupported';
}

final githubReleasesProvider = Provider<GitHubReleases>(
  (ref) => GitHubReleases(),
);
final updateInstallerProvider = Provider<UpdateInstallerPlatform>(
  // The demo (mock server) never updates itself to the real app.
  (ref) => ref.watch(appConfigProvider).mockMode
      ? const _NoUpdates()
      : AndroidUpdateInstaller(),
);

class _NoUpdates implements UpdateInstallerPlatform {
  const _NoUpdates();

  @override
  bool get supported => false;

  @override
  Future<String> abi() async => '';

  @override
  Future<String> install(String path) async => 'unsupported';
}

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

/// No release found (none published, or the repository is private).
class UpdateNoReleases extends UpdateState {
  const UpdateNoReleases();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release);
  final ReleaseInfo release;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.release, this.progress);
  final ReleaseInfo release;
  final double progress;
}

/// Handed to Android's installer (it may ask to confirm, then restarts us).
class UpdateInstalling extends UpdateState {
  const UpdateInstalling(this.release);
  final ReleaseInfo release;
}

/// "Install unknown apps" has to be allowed for this app first.
class UpdateNeedsPermission extends UpdateState {
  const UpdateNeedsPermission(this.release);
  final ReleaseInfo release;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed({required this.verification});

  /// The download did not match its published checksum.
  final bool verification;
}

/// Opt-in: check GitHub for a new release when the app starts.
class AutoUpdateCheckController extends Notifier<bool> {
  static const _key = 'updates.auto';

  @override
  bool build() =>
      ref.watch(appPreferencesProvider).readJson(_key)?['enabled'] == true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(appPreferencesProvider)
        .writeJson(_key, enabled ? {'enabled': true} : null);
    if (enabled) unawaited(ref.read(updateProvider.notifier).check());
  }
}

final autoUpdateCheckProvider =
    NotifierProvider<AutoUpdateCheckController, bool>(
      AutoUpdateCheckController.new,
    );

class UpdateController extends Notifier<UpdateState> {
  static final _log = AppLogger('Updates');

  @override
  UpdateState build() {
    // Once per start, when the household turned it on.
    if (ref.read(autoUpdateCheckProvider) &&
        ref.read(updateInstallerProvider).supported) {
      Future.microtask(check);
    }
    return const UpdateIdle();
  }

  Future<void> check() async {
    final installer = ref.read(updateInstallerProvider);
    if (!installer.supported || state is UpdateChecking) return;
    state = const UpdateChecking();
    try {
      final release = await ref
          .read(githubReleasesProvider)
          .latest(updateRepo, await installer.abi());
      state = release == null
          ? const UpdateNoReleases()
          : compareVersions(release.version, appVersion) > 0
          ? UpdateAvailable(release)
          : const UpdateUpToDate();
    } on Object catch (e) {
      _log.warning('check failed', e.runtimeType);
      state = const UpdateFailed(verification: false);
    }
  }

  Future<void> install(ReleaseInfo release) async {
    final installer = ref.read(updateInstallerProvider);
    try {
      state = UpdateDownloading(release, 0);
      final file = await ref
          .read(githubReleasesProvider)
          .download(
            release,
            onProgress: (p) => state = UpdateDownloading(release, p),
          );
      final result = await installer.install(file.path);
      state = result == 'needs_permission'
          ? UpdateNeedsPermission(release)
          : UpdateInstalling(release);
    } on UpdateVerificationException catch (e) {
      _log.warning('update rejected: ${e.reason}');
      state = const UpdateFailed(verification: true);
    } on Object catch (e) {
      _log.warning('update failed', e.runtimeType);
      state = const UpdateFailed(verification: false);
    }
  }
}

final updateProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);
