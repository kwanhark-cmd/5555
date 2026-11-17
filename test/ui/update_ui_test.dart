import 'dart:convert';
import 'dart:io';

import 'package:account_vault/core/crypto/vault_crypto.dart';
import 'package:account_vault/logic/update_check.dart';
import 'package:account_vault/ui/screens/update_card.dart';
import 'package:account_vault/ui/theme/tokens.dart';
import 'package:account_vault/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

Future<void> realWait(WidgetTester tester, [int rounds = 20]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 가짜 릴리스 서버: 안드로이드·윈도우 설치 파일과 해시 표.
MockClient fakeServer(List<int> file, String hash) => MockClient((req) async {
  if (req.url.toString() == releasesApi) {
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'tag_name': 'v99.0.0',
          'html_url':
              'https://github.com/kwanhark-cmd/5555/releases/tag/v99.0.0',
          'body':
              '## 바뀐 것\n- 가짜\n\n'
              '| account_vault-99.0.0-android.apk | `$hash` |\n'
              '| account_vault-99.0.0-windows-setup.exe | `$hash` |',
          'assets': [
            {
              'name': 'account_vault-99.0.0-android.apk',
              'browser_download_url': 'https://dl/apk',
              'size': file.length,
            },
            {
              'name': 'account_vault-99.0.0-windows-setup.exe',
              'browser_download_url': 'https://dl/exe',
              'size': file.length,
            },
          ],
        }),
      ),
      200,
    );
  }
  return http.Response.bytes(file, 200);
});

Future<TestRig> pumpCard(
  WidgetTester tester,
  String os,
  http.Client client,
) async {
  tester.view.physicalSize = const Size(420, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late TestRig rig;
  await tester.runAsync(() async {
    rig = await TestRig.create();
    await rig.controller.updateSettings((s) => s.autoLockSeconds = 0);
    await rig.controller.createProfile('a', 'fake-master-phrase-1');
  });
  addTearDown(rig.dispose);
  rig.installer.osName = os;
  await tester.pumpWidget(
    AppScope(
      controller: rig.controller,
      child: AppTheme(
        palette: AppPalette.light,
        reduceMotion: true,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: [UpdateCard(client: client)]),
          ),
        ),
      ),
    ),
  );
  return rig;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 300));
}

bool enabled(WidgetTester tester, String label) {
  final b = tester.widget<BigButton>(
    find.ancestor(of: find.text(label), matching: find.byType(BigButton)),
  );
  return b.onPressed != null;
}

void main() {
  test('모든 기기: 백업(앱 밖 저장·확인) → 내려받기 → 기존 앱 삭제 → 설치 → 복원 순서', () {
    for (final os in ['android', 'windows', 'macos', 'linux']) {
      final steps = replaceSteps(os);
      int at(String w) => steps.indexWhere((s) => s.contains(w));
      expect(at('백업 파일 만들기'), 0, reason: os);
      expect(steps.first, contains('앱 밖'));
      expect(at('저장한 백업 파일 확인'), greaterThan(at('백업 파일 만들기')));
      expect(at('내려받기'), greaterThan(at('저장한 백업 파일 확인')));
      expect(at('기존 앱을 삭제'), greaterThan(at('내려받기')), reason: os);
      expect(at('새 앱을 설치'), greaterThan(at('기존 앱을 삭제')), reason: os);
      expect(at('백업 파일로 복원'), greaterThan(at('새 앱을 설치')), reason: os);
    }
    expect(deleteOldAppStep('windows'), contains('제거'));
    expect(deleteOldAppStep('macos'), contains('휴지통'));
    expect(
      releasesPage,
      'https://github.com/kwanhark-cmd/5555/releases/latest',
    );
  });

  for (final (os, expectedUrl) in [
    ('android', 'https://dl/apk'),
    ('windows', 'https://dl/exe'),
    // 가짜 서버에 맥·리눅스 파일이 없으면 릴리스 페이지를 연다
    ('macos', 'https://github.com/kwanhark-cmd/5555/releases/tag/v99.0.0'),
    ('linux', 'https://github.com/kwanhark-cmd/5555/releases/tag/v99.0.0'),
  ]) {
    testWidgets('새 버전($os): 앱 안 설치 없음 — 백업 저장·확인 뒤에만 브라우저로 내려받기', (
      tester,
    ) async {
      final file = utf8.encode('fake new app');
      late String hash;
      await tester.runAsync(
        () async => hash = await VaultCrypto().sha256Hex(file),
      );
      final rig = await pumpCard(tester, os, fakeServer(file, hash));
      if (os == 'android') rig.files.shareSheet = true;

      expect(find.text('새 버전으로 바꾸기'), findsOneWidget);
      expect(find.textContaining('기존 앱을 지우고 새 앱을 설치하는 방식'), findsOneWidget);
      await tester.tap(find.text('새 버전 확인하기'));
      await realWait(tester);
      expect(find.textContaining('새 버전 99.0.0'), findsOneWidget);
      expect(find.text('백업하고 내려받아 설치'), findsNothing);
      expect(find.textContaining(deleteOldAppStep(os)), findsOneWidget);

      // 백업 확인 전에는 내려받기 버튼이 꺼져 있다
      expect(enabled(tester, '③ 새 버전 내려받기(브라우저)'), isFalse);

      await tapText(tester, '① 백업 파일 만들기');
      await realWait(tester, 10);
      expect(rig.files.saved.keys.single, endsWith('.vaultbackup'));
      expect(enabled(tester, '③ 새 버전 내려받기(브라우저)'), isFalse);

      // 다른 파일을 고르면 여전히 꺼짐
      rig.files.toOpen = '아무 글자';
      await tapText(tester, '② 저장한 백업 파일 확인');
      await realWait(tester, 10);
      expect(enabled(tester, '③ 새 버전 내려받기(브라우저)'), isFalse);

      rig.files.toOpen = rig.files.saved.values.single;
      await tapText(tester, '② 저장한 백업 파일 확인');
      await realWait(tester, 10);
      expect(find.textContaining('확인했어요'), findsOneWidget);
      expect(enabled(tester, '③ 새 버전 내려받기(브라우저)'), isTrue);

      await tapText(tester, '③ 새 버전 내려받기(브라우저)');
      await realWait(tester, 3);
      expect(rig.launcher.opened.single.toString(), expectedUrl);
      // 앱이 스스로 내려받거나 설치·백업 폴더에 쓰지 않는다
      expect(
        Directory('${rig.dir.path}/store/auto_backups').existsSync(),
        isFalse,
      );
      await tester.runAsync(() => rig.controller.lock());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('인터넷이 안 돼도 바꾸는 순서와 백업 버튼은 그대로 보임', (tester) async {
    final rig = await pumpCard(
      tester,
      'windows',
      MockClient((_) async => throw const SocketException('x')),
    );
    await tester.tap(find.text('새 버전 확인하기'));
    await realWait(tester);
    expect(find.textContaining('인터넷 연결'), findsOneWidget);
    expect(find.text('① 백업 파일 만들기'), findsOneWidget);
    await tester.runAsync(() => rig.controller.lock());
    expect(tester.takeException(), isNull);
  });
}
