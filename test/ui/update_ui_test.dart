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
  test('안드로이드 순서는 백업(앱 밖 저장·확인)이 앱 삭제보다 먼저다', () {
    final backup = androidUpdateSteps.indexWhere(
      (s) => s.contains('백업 파일 만들기'),
    );
    final verify = androidUpdateSteps.indexWhere(
      (s) => s.contains('저장한 백업 파일 확인'),
    );
    final delete = androidUpdateSteps.indexWhere((s) => s.contains('삭제'));
    final restore = androidUpdateSteps.indexWhere((s) => s.contains('복원'));
    expect(backup, 0);
    expect(verify, greaterThan(backup));
    expect(delete, greaterThan(verify));
    expect(restore, greaterThan(delete));
    expect(androidUpdateSteps.first, contains('앱 밖'));
    expect(
      releasesPage,
      'https://github.com/kwanhark-cmd/5555/releases/latest',
    );
  });

  testWidgets('업데이트(안드로이드): 앱 안에서 설치하지 않고, 백업 저장·확인 뒤에만 브라우저로 내려받기', (
    tester,
  ) async {
    final apk = utf8.encode('fake new apk');
    late String hash;
    await tester.runAsync(
      () async => hash = await VaultCrypto().sha256Hex(apk),
    );
    final rig = await pumpCard(tester, 'android', fakeServer(apk, hash));
    rig.files.shareSheet = true;

    await tester.tap(find.text('새 버전 확인하기'));
    await realWait(tester);
    expect(find.textContaining('새 버전 99.0.0'), findsOneWidget);
    expect(find.text('백업하고 내려받아 설치'), findsNothing);
    expect(find.textContaining('앱을 삭제하면 금고도 함께 지워져요'), findsOneWidget);
    expect(find.textContaining('그대로 남'), findsNothing);
    expect(find.textContaining('덮어쓰기'), findsNothing);

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
    expect(rig.launcher.opened.single.toString(), 'https://dl/apk');
    expect(rig.installer.installed, isEmpty);
    expect(
      Directory('${rig.dir.path}/store/auto_backups').existsSync(),
      isFalse,
    );
    await tester.runAsync(() => rig.controller.lock());
    expect(tester.takeException(), isNull);
  });

  testWidgets('업데이트(윈도우): 확인 → 자동 백업 → 내려받기 → 해시 확인 → 설치', (tester) async {
    final exe = utf8.encode('fake new setup');
    late String hash;
    await tester.runAsync(
      () async => hash = await VaultCrypto().sha256Hex(exe),
    );
    final rig = await pumpCard(tester, 'windows', fakeServer(exe, hash));

    await tester.tap(find.text('새 버전 확인하기'));
    await realWait(tester);
    expect(find.textContaining('새 버전 99.0.0'), findsOneWidget);
    await tapText(tester, '백업하고 내려받아 설치');
    await realWait(tester, 3);
    expect(find.textContaining('복구 코드가 종이에'), findsOneWidget);
    await tapText(tester, '백업하고 내려받기');
    await realWait(tester, 30);
    expect(
      rig.installer.installed.single,
      endsWith('account_vault-99.0.0-windows-setup.exe'),
    );
    final backups = Directory('${rig.dir.path}/store/auto_backups').listSync();
    expect(backups.single.path, contains('before-update-99.0.0'));
    await tester.runAsync(() => rig.controller.lock());
    expect(tester.takeException(), isNull);
  });
}
