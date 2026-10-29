import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/app/app_info.dart';
import 'package:open_smart_home_lite/app/router/app_router.dart';
import 'package:open_smart_home_lite/features/updates/update_service.dart';

import '../widgets/app_widget_test.dart'
    show en, goTo, pumpApp, settle, unmount;

/// Answers GitHub's API and the release files from memory.
class _FakeGitHub implements HttpClientAdapter {
  _FakeGitHub({required this.apk, this.sums, this.status = 200});

  final List<int> apk;
  final String? sums;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    if (url.endsWith('/releases/latest')) {
      if (status != 200) return ResponseBody.fromString('', status);
      return ResponseBody.fromString(
        jsonEncode({
          'tag_name': 'v9.0.0',
          'body': 'Nove stvari',
          'assets': [
            {
              'name': 'app-armeabi-v7a-release.apk',
              'size': 1,
              'browser_download_url': 'https://dl/app-armeabi-v7a-release.apk',
            },
            {
              'name': 'app-arm64-v8a-release.apk',
              'size': apk.length,
              'browser_download_url': 'https://dl/app-arm64-v8a-release.apk',
            },
            {
              'name': 'SHA256SUMS',
              'size': 100,
              'browser_download_url': 'https://dl/SHA256SUMS',
            },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (url.endsWith('SHA256SUMS')) {
      return ResponseBody.fromString(sums ?? '', 200);
    }
    return ResponseBody.fromBytes(Uint8List.fromList(apk), 200);
  }

  @override
  void close({bool force = false}) {}
}

GitHubReleases _github(_FakeGitHub fake) =>
    GitHubReleases(dio: Dio()..httpClientAdapter = fake);

class _FakeInstaller implements UpdateInstallerPlatform {
  final installed = <String>[];

  @override
  bool get supported => true;

  @override
  Future<String> abi() async => 'arm64-v8a';

  @override
  Future<String> install(String path) async {
    installed.add(path);
    return 'started';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => '/tmp',
        );
  });

  test('versions compare by number, not text', () {
    expect(compareVersions('0.10.0', '0.9.9'), 1);
    expect(compareVersions('v1.2.0', '1.2.0+7'), 0);
    expect(compareVersions('1.2', '1.2.1'), -1);
  });

  final apk = utf8.encode('fake apk bytes');
  final goodSums =
      '${sha256.convert(apk)}  app-arm64-v8a-release.apk\n'
      '${sha256.convert([1])}  app-armeabi-v7a-release.apk\n';

  test('latest release: the APK for this ABI and its checksum list', () async {
    final r = (await _github(_FakeGitHub(apk: apk, sums: goodSums))
        .latest('o/r', 'arm64-v8a'))!;
    expect(r.version, '9.0.0');
    expect(r.apkName, 'app-arm64-v8a-release.apk');
    expect(r.checksumsUrl, 'https://dl/SHA256SUMS');
  });

  test(
    'a private or empty repository is "no releases", not an error',
    () async {
      expect(
        await _github(_FakeGitHub(apk: apk, status: 404))
            .latest('o/r', 'arm64-v8a'),
        isNull,
      );
    },
  );

  test('a download that does not match SHA256SUMS is rejected', () async {
    final bad = _github(
      _FakeGitHub(apk: apk, sums: '${'0' * 64}  app-arm64-v8a-release.apk'),
    );
    final r = (await bad.latest('o/r', 'arm64-v8a'))!;
    await expectLater(
      bad.download(r),
      throwsA(isA<UpdateVerificationException>()),
    );
    final good = _github(_FakeGitHub(apk: apk, sums: goodSums));
    final file = await good.download((await good.latest('o/r', 'arm64-v8a'))!);
    expect(await file.readAsBytes(), apk);
    await file.delete();
  });

  testWidgets('about screen: check, new version, verified install', (
    tester,
  ) async {
    final installer = _FakeInstaller();
    await pumpApp(
      tester,

      size: const Size(800, 1600),
      overrides: [
        githubReleasesProvider.overrideWithValue(
          _github(_FakeGitHub(apk: apk, sums: goodSums)),
        ),
        updateInstallerProvider.overrideWithValue(installer),
      ],
    );
    await settle(tester, 10);
    await goTo(tester, AppRoutes.settingsSection('about'));
    await settle(tester, 4);
    expect(find.text(en.updateCurrent(appVersion)), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('updateCheck')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settle(tester, 2);
    expect(find.text(en.updateAvailable('9.0.0')), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('updateInstall')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await settle(tester, 2);
    expect(installer.installed.single, endsWith('update-9.0.0.apk'));
    expect(find.text(en.updateInstalling), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('automatic checks are off until turned on', (tester) async {
    await pumpApp(
      tester,

      size: const Size(800, 1600),
      overrides: [updateInstallerProvider.overrideWithValue(_FakeInstaller())],
    );
    await settle(tester, 6);
    await goTo(tester, AppRoutes.settingsSection('about'));
    await settle(tester, 4);
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('updateAuto')),
    );
    expect(tile.value, isFalse);
    expect(find.byKey(const Key('updateBanner')), findsNothing);
    await unmount(tester);
  });

  testWidgets('the demo (mock server) offers no updates', (tester) async {
    await pumpApp(tester, size: const Size(800, 1600));
    await settle(tester, 6);
    await goTo(tester, AppRoutes.settingsSection('about'));
    await settle(tester, 4);
    expect(find.byKey(const Key('updateAuto')), findsNothing);
    await unmount(tester);
  });
}
