import 'package:account_vault/app/app_controller.dart';
import 'package:account_vault/logic/alerts.dart';
import 'package:account_vault/ui/app.dart';
import 'package:account_vault/ui/screens/accounts_screens.dart';
import 'package:account_vault/ui/screens/cleanup_screens.dart';
import 'package:account_vault/ui/screens/credits_screens.dart';
import 'package:account_vault/ui/screens/mail_screens.dart';
import 'package:account_vault/ui/screens/recovery_code_view.dart';
import 'package:account_vault/ui/screens/settings_screens.dart';
import 'package:account_vault/ui/screens/subscriptions_screens.dart';
import 'package:account_vault/ui/screens/voice_screen.dart';
import 'package:account_vault/ui/theme/tokens.dart';
import 'package:account_vault/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// 디자인 자동 검사:
/// - 가장 작은 화면(360×640) + 가장 큰 글씨(아주 크게) + 밝은/어두운/고대비 모드
/// - 모든 화면에서 잘림·겹침(넘침 오류)이 없어야 한다.
/// - 색 대비 WCAG AA, 움직임 줄이기.

typedef ScreenBuilder = Widget Function(AppController app);

final screens = <String, ScreenBuilder>{
  '구독 목록': (_) => const SubscriptionsScreen(),
  '구독 상세': (a) => SubscriptionDetailScreen(id: a.data.subscriptions.first.id),
  '구독 상세(긴 이름)': (a) =>
      SubscriptionDetailScreen(id: a.data.subscriptions[2].id),
  '구독 추가': (_) => const SubscriptionEditScreen(),
  '만료 알림': (_) => const CreditsScreen(),
  '마감일 수정': (a) => CreditEditScreen(existing: a.data.credits.first),
  '계정 목록': (_) => const AccountsScreen(),
  '계정 상세': (a) => AccountDetailScreen(id: a.data.accounts.first.id),
  '계정 수정': (a) => AccountEditScreen(existing: a.data.accounts.first),
  '비밀번호 만들기': (_) => const GeneratorScreen(),
  '정리 도우미': (_) => const CleanupScreen(),
  '건강 보고서': (_) => const HealthScreen(),
  '음성 비서': (_) => const VoiceScreen(),
  '메일로 채우기': (_) => const MailImportScreen(),
  '설정': (_) => const SettingsScreen(),
  '비밀번호 바꾸기': (_) => const ChangePasswordScreen(),
  '복구 코드 새로': (_) => const NewRecoveryCodeScreen(),
  'AI 연결': (_) => const AiSettingsScreen(),
  '지메일 연결': (_) => const GmailSettingsScreen(),
  '백업': (_) => const BackupScreen(),
  '복구 코드 보기': (_) => const AppPage(
    title: '복구 코드',
    children: [RecoveryCodeView(code: '7K3QD-M9XAT-2B4CE-HJKMN-PQRST')],
  ),
};

Future<TestRig> unlockedRig(
  WidgetTester tester, {
  required String theme,
  required int textLevel,
}) async {
  late TestRig rig;
  await tester.runAsync(() async {
    rig = await TestRig.create();
    final app = rig.controller;
    await app.updateSettings((s) {
      s.autoLockSeconds = 0; // 테스트 중 타이머 없음
      s.themeMode = theme;
      s.textScaleLevel = textLevel;
      s.tipsShown = {};
    });
    await app.createProfile('아주 긴 이름의 테스트 사용자', 'fake-master-phrase-1');
    await app.mutate((d) {
      final s = sampleData(app.now());
      d.subscriptions.addAll(s.subscriptions);
      d.credits.addAll(s.credits);
      d.accounts.addAll(s.accounts);
      markSeen(d, computeAlerts(d, app.now())); // 밀린 알림 창은 따로 검사
    });
  });
  addTearDown(rig.dispose);
  return rig;
}

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// 누를 수 있는 것은 모두 48×48 이상(화면에 그려진 것만).
void checkTouchTargets(WidgetTester tester, String screen) {
  final targets = find.byWidgetPredicate(
    (w) => w is Press3D || w is ButtonStyleButton || w is IconButton,
  );
  expect(targets, findsWidgets, reason: '"$screen" 화면에 버튼이 없음');
  for (final el in targets.evaluate()) {
    final box = el.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final s = box.size;
    expect(
      s.width >= AppTokens.minTouch - 0.01 &&
          s.height >= AppTokens.minTouch - 0.01,
      isTrue,
      reason: '"$screen" 화면 ${el.widget.runtimeType} 크기 $s',
    );
  }
}

void main() {
  const variants = [
    ('light', 2), // 가장 큰 글씨 + 밝게
    ('dark', 2), // 가장 큰 글씨 + 어둡게
    ('contrast', 2), // 가장 큰 글씨 + 고대비
    ('light', 0), // 보통 글씨
  ];

  for (final (theme, level) in variants) {
    for (final size in const [Size(360, 640), Size(360, 9000)]) {
      testWidgets(
        '홈: $theme / 글씨 $level / ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
          setSize(tester, size);
          final rig = await unlockedRig(tester, theme: theme, textLevel: level);
          await tester.pumpWidget(VaultApp(controller: rig.controller));
          await settle(tester);
          expect(find.text('잠그기'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '모든 화면: $theme / 글씨 $level / ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
          setSize(tester, size);
          final rig = await unlockedRig(tester, theme: theme, textLevel: level);
          await tester.pumpWidget(VaultApp(controller: rig.controller));
          await settle(tester);
          final nav = tester.state<NavigatorState>(
            find.byType(Navigator).first,
          );
          for (final e in screens.entries) {
            nav.push(
              MaterialPageRoute(builder: (_) => e.value(rig.controller)),
            );
            await settle(tester);
            final err = tester.takeException();
            if (err is FlutterError) debugPrint(err.toStringDeep());
            expect(err, isNull, reason: '"${e.key}" 화면에서 오류: $err');
            checkTouchTargets(tester, e.key);
            nav.pop();
            await settle(tester);
          }
        },
      );
    }

    testWidgets('잠금 화면·첫 실행 마법사: $theme / 글씨 $level / 360×640', (tester) async {
      setSize(tester, const Size(360, 640));
      late TestRig rig;
      await tester.runAsync(() async {
        rig = await TestRig.create();
        await rig.controller.updateSettings((s) {
          s.themeMode = theme;
          s.textScaleLevel = level;
          s.autoLockSeconds = 0;
        });
      });
      addTearDown(rig.dispose);
      await tester.pumpWidget(VaultApp(controller: rig.controller));
      await settle(tester);
      expect(find.text('반가워요!'), findsOneWidget);
      await tester.ensureVisible(find.text('다음'));
      await tester.pump();
      await tester.tap(find.text('다음'));
      await settle(tester);
      expect(find.text('마스터 비밀번호 정하기'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 잠금 화면(사용자 2명)
      await tester.runAsync(() async {
        await rig.controller.createProfile('가', 'fake-master-phrase-1');
        await rig.controller.createProfile('나', 'fake-master-phrase-2');
        rig.controller.endOnboarding();
        await rig.controller.lock();
      });
      await settle(tester);
      expect(find.text('금고가 잠겨 있어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('밀린 알림 창(가장 큰 글씨, 360×640)', (tester) async {
    setSize(tester, const Size(360, 640));
    late TestRig rig;
    await tester.runAsync(() async {
      rig = await TestRig.create();
      await rig.controller.updateSettings((s) {
        s.autoLockSeconds = 0;
        s.textScaleLevel = 2;
      });
      await rig.controller.createProfile('a', 'fake-master-phrase-1');
      await rig.controller.mutate(
        (d) => d.credits.addAll(sampleData(rig.controller.now()).credits),
      );
    });
    addTearDown(rig.dispose);
    await tester.pumpWidget(VaultApp(controller: rig.controller));
    await settle(tester);
    expect(find.textContaining('확인할 알림'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('가장 먼저 눈에 띄는 것이 가장 중요한 것: 큰 숫자 > 오늘 할 일 > 이번 주 결제 > 타일 > 상태 띠', (
    tester,
  ) async {
    setSize(tester, const Size(400, 3000));
    final rig = await unlockedRig(tester, theme: 'light', textLevel: 1);
    await tester.pumpWidget(VaultApp(controller: rig.controller));
    await settle(tester);
    // 화면에서 가장 큰 글자 = 이번 달 구독료 숫자
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.data != null && t.style?.fontSize != null)
        .toList();
    texts.sort((a, b) => b.style!.fontSize!.compareTo(a.style!.fontSize!));
    expect(texts.first.data, endsWith('원'));
    expect(find.text('이번 달 구독료'), findsOneWidget);
    double y(String text) => tester.getTopLeft(find.text(text).first).dy;
    expect(y('이번 달 구독료'), lessThan(y('오늘 할 일')));
    expect(y('오늘 할 일'), lessThan(y('이번 주 결제 예정')));
    expect(y('이번 주 결제 예정'), lessThan(y('구독 결제')));
    expect(y('구독 결제'), lessThan(y('연결 상태')));
    // 같은 크기 상자 3개 이상 나란히 없음: 타일은 한 줄에 최대 2개
    final tileTops = <double, int>{};
    for (final e
        in find
            .text('구독 결제')
            .evaluate()
            .followedBy(find.text('계정·비밀번호').evaluate())
            .followedBy(find.text('금고 건강').evaluate())
            .followedBy(find.text('만료 알림').evaluate())) {
      final top = tester.getTopLeft(find.byWidget(e.widget)).dy.roundToDouble();
      tileTops[top] = (tileTops[top] ?? 0) + 1;
    }
    expect(tileTops.values.every((n) => n <= 2), isTrue);
  });

  testWidgets('연결 상태가 저장 즉시 홈에 반영', (tester) async {
    setSize(tester, const Size(400, 3000));
    final rig = await unlockedRig(tester, theme: 'light', textLevel: 1);
    await tester.pumpWidget(VaultApp(controller: rig.controller));
    await settle(tester);
    expect(find.text('지메일: 연결 안 함'), findsOneWidget);
    expect(find.text('AI: 연결 안 함'), findsOneWidget);
    await tester.runAsync(
      () => rig.controller.mutate((d) {
        d.prefs.gmailRefreshToken = 'fake';
        d.prefs.aiApiKey = 'fake';
      }),
    );
    await settle(tester);
    expect(find.text('지메일: 연결됨'), findsOneWidget);
    expect(find.text('AI: 연결됨'), findsOneWidget);
  });

  const minText = AppTokens.minTextContrast;

  test('보기 쉬움 기준값: 본문·버튼 글자 대비 7:1 이상', () {
    expect(minText, greaterThanOrEqualTo(7));
  });

  test('색 테마 4종 × 밝게/어둡게: 주요 버튼·주요색 글자 대비 7:1', () {
    for (final base in [AppPalette.light, AppPalette.dark]) {
      for (final theme in AppPalette.colorThemes.keys) {
        final p = base.withColorTheme(theme);
        expect(
          contrastRatio(p.onPrimary, p.primary),
          greaterThanOrEqualTo(minText),
          reason: '${p.name} 버튼',
        );
        expect(
          contrastRatio(p.onPrimary, pressedColor(p.primary, p.onPrimary)),
          greaterThanOrEqualTo(minText),
          reason: '${p.name} 누른 버튼',
        );
        expect(
          contrastRatio(p.primary, p.surface),
          greaterThanOrEqualTo(minText),
          reason: '${p.name} 글자',
        );
        expect(p.outline, base.outline, reason: '${p.name} 테두리 유지');
      }
    }
    expect(
      AppPalette.contrast.withColorTheme('plum'),
      same(AppPalette.contrast),
    );
  });

  group('색 대비(본문·버튼 7:1, 테두리 4.5:1)', () {
    for (final p in AppPalette.all) {
      test(p.name, () {
        void check(
          Color fg,
          Color bg,
          String what, [
          double min = minText,
        ]) => expect(
          contrastRatio(fg, bg),
          greaterThanOrEqualTo(min),
          reason:
              '${p.name}: $what ${contrastRatio(fg, bg).toStringAsFixed(2)}',
        );
        for (final bg in [
          p.background,
          p.surface,
          p.surfaceAlt,
          p.tileTop,
          p.tileBottom,
        ]) {
          check(p.text, bg, '본문 글자');
          check(p.textMuted, bg, '설명 글자(흐린 회색 금지)');
          check(p.outline, bg, '테두리 버튼·입력칸 테두리', 4.5);
          check(p.focusRing, bg, '초점 고리', 4.5);
        }
        for (final bg in [p.background, p.surface, p.surfaceAlt]) {
          for (final k in StatusKind.values) {
            check(p.status(k), bg, '상태색 $k 글자');
          }
        }
        for (final k in StatusKind.values) {
          check(p.onStatusFill(k), p.statusFill(k), '상태 배지 $k');
        }
        for (final k in ButtonKind.values) {
          final (bg, fg) = BigButton.colorsFor(p, k);
          check(fg, bg, '버튼 $k');
          check(fg, BigButton.pressedFor(p, k), '누른 버튼 $k');
          // 누른 모습이 눈에 보이게 달라짐
          expect(
            BigButton.pressedFor(p, k),
            isNot(bg),
            reason: '${p.name}: 누른 버튼 $k 바탕이 그대로',
          );
        }
        // 테두리 버튼 바탕은 화면 바탕과 같은 계열(글자는 본문색)
        expect(BigButton.colorsFor(p, ButtonKind.plain).$2, p.text);
      });
    }
  });

  test('위험 버튼은 모든 모드에서 분명한 빨강', () {
    for (final p in AppPalette.all) {
      final (bg, _) = BigButton.colorsFor(p, ButtonKind.danger);
      final hsv = HSVColor.fromColor(bg);
      final hue = hsv.hue;
      expect(
        hue <= 10 || hue >= 350,
        isTrue,
        reason: '${p.name}: 위험 버튼 색상각 $hue',
      );
      expect(
        hsv.saturation,
        greaterThanOrEqualTo(0.5),
        reason: '${p.name}: 위험 버튼 채도',
      );
      expect(p.danger, isNot(p.primary));
    }
  });

  test('글자·버튼 크기 규칙(디자인 값)', () {
    expect(AppTokens.buttonHeight, greaterThanOrEqualTo(52));
    expect(AppTokens.minTouch, greaterThanOrEqualTo(48));
    expect(AppTokens.fontButton, greaterThanOrEqualTo(17));
    expect(AppTokens.fontBody, greaterThanOrEqualTo(16));
    expect(AppTokens.fontSmall, greaterThanOrEqualTo(16));
    expect(AppTokens.fontBadge, greaterThanOrEqualTo(16));
    expect(AppTokens.fontBadgeCompact, greaterThanOrEqualTo(16));
    expect(AppTokens.outlineWidth, greaterThanOrEqualTo(2));
    expect(AppTokens.focusRingWidth, greaterThanOrEqualTo(2));
  });

  group('앱 테마(ThemeData) 규칙', () {
    for (final p in AppPalette.all) {
      test(p.name, () {
        final t = buildTheme(p);
        final tt = t.textTheme;
        for (final (name, style) in [
          ('bodyLarge', tt.bodyLarge),
          ('bodyMedium', tt.bodyMedium),
          ('bodySmall', tt.bodySmall),
          ('titleMedium', tt.titleMedium),
          ('labelLarge', tt.labelLarge),
          ('labelMedium', tt.labelMedium),
          ('labelSmall', tt.labelSmall),
        ]) {
          expect(
            style!.fontSize,
            greaterThanOrEqualTo(16),
            reason: '${p.name}: $name 글자 크기',
          );
        }
        expect(tt.labelLarge!.fontSize, greaterThanOrEqualTo(17));
        expect(tt.labelLarge!.fontWeight, FontWeight.w700);
        expect(tt.bodyLarge!.color, p.text);
        expect(tt.bodyMedium!.color, p.text);

        const none = <WidgetState>{};
        const pressed = {WidgetState.pressed};
        const focused = {WidgetState.focused};
        for (final (name, style) in [
          ('filled', t.filledButtonTheme.style!),
          ('elevated', t.elevatedButtonTheme.style!),
          ('outlined', t.outlinedButtonTheme.style!),
        ]) {
          final min = style.minimumSize!.resolve(none)!;
          expect(min.height, greaterThanOrEqualTo(52), reason: '$name 높이');
          expect(min.width, greaterThanOrEqualTo(48), reason: '$name 너비');
          final ts = style.textStyle!.resolve(none)!;
          expect(ts.fontSize, greaterThanOrEqualTo(17), reason: '$name 글자');
          expect(ts.fontWeight, FontWeight.w700);
          final bg = style.backgroundColor!.resolve(none)!;
          final fg = style.foregroundColor!.resolve(none)!;
          expect(
            contrastRatio(fg, bg),
            greaterThanOrEqualTo(minText),
            reason: '${p.name} $name 글자 대비',
          );
          expect(style.overlayColor!.resolve(pressed), isNotNull);
          expect(style.overlayColor!.resolve(focused), isNotNull);
          final ring = style.side!.resolve(focused)!;
          expect(ring.width, greaterThanOrEqualTo(2), reason: '$name 초점');
        }
        final filled = t.filledButtonTheme.style!;
        expect(filled.backgroundColor!.resolve(none), p.primary);
        expect(
          filled.backgroundColor!.resolve(pressed),
          isNot(p.primary),
          reason: '누른 모습',
        );
        final outlined = t.outlinedButtonTheme.style!;
        final side = outlined.side!.resolve(none)!;
        expect(side.width, greaterThanOrEqualTo(2));
        expect(side.color, p.outline);
        final textBtn = t.textButtonTheme.style!;
        expect(
          textBtn.minimumSize!.resolve(none)!.height,
          greaterThanOrEqualTo(48),
        );
        expect(
          textBtn.textStyle!.resolve(none)!.fontSize,
          greaterThanOrEqualTo(17),
        );
        expect(
          t.iconButtonTheme.style!.minimumSize!.resolve(none)!.shortestSide,
          greaterThanOrEqualTo(48),
        );
        expect(t.materialTapTargetSize, MaterialTapTargetSize.padded);
        final input = t.inputDecorationTheme;
        final enabledSide =
            (input.enabledBorder! as OutlineInputBorder).borderSide;
        expect(enabledSide.width, greaterThanOrEqualTo(2));
        expect(enabledSide.color, p.outline);
        expect(input.helperStyle!.fontSize, greaterThanOrEqualTo(16));
        expect(input.errorStyle!.fontSize, greaterThanOrEqualTo(16));
      });
    }
  });

  for (final p in AppPalette.all) {
    testWidgets('큰 버튼 실제 모습: ${p.name}', (tester) async {
      setSize(tester, const Size(360, 1400));
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(p),
          home: AppTheme(
            palette: p,
            reduceMotion: true,
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Focus(focusNode: focus, child: const SizedBox()),
                  for (final k in ButtonKind.values)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: BigButton(
                        key: ValueKey(k),
                        label: '버튼 $k',
                        kind: k,
                        expand: false,
                        onPressed: () {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final k in ButtonKind.values) {
        final f = find.byKey(ValueKey(k));
        final size = tester.getSize(f);
        expect(size.height, greaterThanOrEqualTo(52), reason: '$k 높이');
        expect(size.width, greaterThanOrEqualTo(48), reason: '$k 너비');
        final text = tester.widget<Text>(
          find.descendant(of: f, matching: find.byType(Text)),
        );
        expect(text.style!.fontSize, greaterThanOrEqualTo(17));
        expect(text.style!.fontWeight, FontWeight.w700);
        final box = tester.widget<AnimatedContainer>(
          find.descendant(of: f, matching: find.byType(AnimatedContainer)),
        );
        final deco = box.decoration! as BoxDecoration;
        if (k == ButtonKind.plain) {
          final b = deco.border! as Border;
          expect(b.top.width, greaterThanOrEqualTo(2), reason: '테두리 버튼');
          expect(b.top.color, p.outline);
        }
        // 누르는 동안 바탕색이 바뀜
        final g = await tester.startGesture(tester.getCenter(f));
        await tester.pump();
        final down = tester.widget<AnimatedContainer>(
          find.descendant(of: f, matching: find.byType(AnimatedContainer)),
        );
        expect(
          (down.decoration! as BoxDecoration).color,
          isNot(deco.color),
          reason: '$k 누른 모습',
        );
        await g.cancel();
        await tester.pump();
      }
      // 키보드 초점: Tab 으로 첫 버튼에 가면 초점 고리가 보임
      CustomPaint ring() => tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byKey(const ValueKey(ButtonKind.primary)),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(ring().foregroundPainter, isNull);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(ring().foregroundPainter, isNotNull, reason: '초점 고리');
    });
  }

  testWidgets('움직임 줄이기: 애니메이션 시간이 0', (tester) async {
    late Duration d1, d2;
    await tester.pumpWidget(
      AppTheme(
        palette: AppPalette.light,
        reduceMotion: true,
        child: Builder(
          builder: (c) {
            d1 = c.motion(AppTokens.lockAnimation);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      AppTheme(
        palette: AppPalette.light,
        reduceMotion: false,
        child: Builder(
          builder: (c) {
            d2 = c.motion(AppTokens.lockAnimation);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(d1, Duration.zero);
    expect(d2, AppTokens.lockAnimation);
    expect(AppTokens.lockAnimation.inMilliseconds, lessThan(1000));
  });
}
