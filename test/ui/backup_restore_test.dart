import 'package:account_vault/app/platform_services.dart';
import 'package:account_vault/ui/app.dart';
import 'package:account_vault/ui/screens/settings_screens.dart';
import 'package:account_vault/ui/theme/tokens.dart';
import 'package:account_vault/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// 안드로이드 새 버전 방식(앱 밖에 백업 저장 → 확인 → 앱 삭제 → 새로 설치 → 복원)이
/// 실제로 되는지: 백업 만들기·저장한 파일 확인·첫 화면 복원.
Future<void> realWait(WidgetTester tester, [int rounds = 20]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 300));
}

const _pw = 'fake-master-phrase-1';

void main() {
  test('안드로이드 파일 고르기는 확장자로 거르지 않는다(.vaultbackup 이 회색이 되지 않게)', () {
    expect(pickerExtensions('android', ['vaultbackup', 'json']), isNull);
    expect(pickerExtensions('windows', ['vaultbackup', 'json']), [
      'vaultbackup',
      'json',
    ]);
    expect(pickerExtensions('macos', const []), isNull);
  });

  test('저장한 백업 파일 확인: 같은 파일만 통과, 손상·다른 사용자·예전 백업은 거절', () async {
    final rig = await TestRig.create();
    addTearDown(rig.dispose);
    final app = rig.controller;
    await app.createProfile('나', _pw);
    final good = await app.exportBackup();

    expect((await app.checkSavedBackup(good)).ok, isTrue);
    final broken = await app.checkSavedBackup(
      good.replaceFirst('"data"', '"x"'),
    );
    expect(broken.ok, isFalse);
    expect((await app.checkSavedBackup('그냥 글자')).ok, isFalse);

    // 백업 뒤에 금고를 바꾸고 새로 백업 → 예전 파일은 "예전 백업"으로 거절
    await app.mutate((d) => d.prefs.displayName = '바뀜');
    await app.exportBackup();
    final old = await app.checkSavedBackup(good);
    expect(old.ok, isFalse);
    expect(old.message, contains('예전에 만든'));

    // 다른 사용자의 백업
    final other = await TestRig.create();
    addTearDown(other.dispose);
    await other.controller.createProfile('남', 'fake-master-phrase-2');
    final theirs = await other.controller.exportBackup();
    final r = await app.checkSavedBackup(theirs);
    expect(r.ok, isFalse);
    expect(r.message, contains('다른 사용자'));
    await app.lock();
    await other.controller.lock();
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('백업 화면(안드로이드): 공유 창으로 보내도 "저장함"이라 하지 않고, 다시 골라 확인한다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late TestRig rig;
    await tester.runAsync(() async {
      rig = await TestRig.create();
      await rig.controller.updateSettings((s) => s.autoLockSeconds = 0);
      await rig.controller.createProfile('나', _pw);
    });
    addTearDown(rig.dispose);
    rig.files.shareSheet = true;
    await tester.pumpWidget(
      AppScope(
        controller: rig.controller,
        child: AppTheme(
          palette: AppPalette.light,
          reduceMotion: true,
          child: const MaterialApp(home: BackupScreen()),
        ),
      ),
    );
    await realWait(tester, 3);
    expect(find.textContaining('앱을 삭제하면 금고도 함께 지워져요'), findsOneWidget);

    await tapText(tester, '백업 파일 만들기');
    await realWait(tester, 10);
    expect(rig.files.saved.keys.single, endsWith('.vaultbackup'));
    expect(find.textContaining('백업을 저장했어요'), findsNothing);
    expect(find.textContaining('저장한 백업 파일 확인'), findsWidgets);

    // 다른 파일을 고르면 확인 실패
    rig.files.toOpen = '{"format":"다른 앱"}';
    await tapText(tester, '저장한 백업 파일 확인');
    await realWait(tester, 10);
    expect(find.textContaining('이 앱에서 만든 백업 파일이 아니에요'), findsOneWidget);

    // 방금 저장한 파일을 고르면 통과
    rig.files.toOpen = rig.files.saved.values.single;
    await tapText(tester, '저장한 백업 파일 확인');
    await realWait(tester, 10);
    expect(find.textContaining('확인했어요'), findsOneWidget);
    await tester.runAsync(() => rig.controller.lock());
    expect(tester.takeException(), isNull);
  });

  testWidgets('앱 삭제 → 새로 설치 → 첫 화면 "백업 파일로 복원" → 같은 마스터 비밀번호로 열림', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late String backup;
    late String profileId;
    late TestRig fresh;
    await tester.runAsync(() async {
      // 예전 앱: 금고를 만들고 백업 파일을 앱 밖에 저장
      final old = await TestRig.create();
      await old.controller.createProfile('나', _pw);
      await old.controller.mutate((d) => d.prefs.displayName = '복원확인');
      profileId = old.controller.currentProfile!.id;
      backup = await old.controller.exportBackup();
      await old.controller.lock();
      old.dispose(); // = 앱 삭제(앱 자료 폴더 전체가 지워짐)

      fresh = await TestRig.create(); // = 새로 설치(빈 자료 폴더)
      await fresh.controller.updateSettings((s) => s.autoLockSeconds = 0);
    });
    addTearDown(fresh.dispose);
    fresh.biometric.available = false;
    expect(fresh.controller.profileList, isEmpty);

    await tester.pumpWidget(VaultApp(controller: fresh.controller));
    await realWait(tester, 3);
    expect(find.text('반가워요!'), findsOneWidget);

    // 고르기 취소 → 아무 일 없음
    fresh.files.toOpen = null;
    await tapText(tester, '쓰던 금고가 있어요 — 백업 파일로 복원');
    await realWait(tester, 3);
    expect(find.text('반가워요!'), findsOneWidget);

    fresh.files.toOpen = backup;
    await tapText(tester, '쓰던 금고가 있어요 — 백업 파일로 복원');
    await realWait(tester, 5);
    expect(find.text('백업의 마스터 비밀번호'), findsOneWidget);

    // 틀린 비밀번호 → 안내, 금고는 만들어지지 않음
    await tester.enterText(find.byType(TextField).last, 'wrong-pass-0000');
    await tapText(tester, '확인');
    await realWait(tester, 40);
    expect(find.textContaining('맞지 않아요'), findsOneWidget);
    expect(fresh.controller.profileList, isEmpty);
    await tapText(tester, '다시 시도');
    await realWait(tester, 5);

    await tester.enterText(find.byType(TextField).last, _pw);
    await tapText(tester, '확인');
    await realWait(tester, 60);
    expect(fresh.controller.profileList.single.id, profileId);
    expect(find.text('금고가 잠겨 있어요'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, _pw);
    await tapText(tester, '열기');
    await realWait(tester, 60);
    expect(fresh.controller.isUnlocked, isTrue);
    expect(fresh.controller.data.prefs.displayName, '복원확인');
    expect(fresh.controller.session?.hasDeviceUnlock, isFalse);
    expect(fresh.controller.profileList, hasLength(1));
    await tester.runAsync(() => fresh.controller.lock());
    expect(tester.takeException(), isNull);
  });
}
