import 'package:flutter/material.dart';

import '../../logic/alerts.dart';
import '../../logic/cleanup.dart';
import '../../logic/money.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'accounts_screens.dart';
import 'cleanup_screens.dart';
import 'credits_screens.dart';
import 'settings_screens.dart';
import 'subscriptions_screens.dart';
import 'voice_screen.dart';

StatusKind statusOf(AlertItem a) =>
    a.level == AlertLevel.danger ? StatusKind.danger : StatusKind.caution;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 알림이 절전 때문에 안 왔을 수 있으니 앱을 열면 밀린 알림을 먼저 보여 준다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMissed());
  }

  Future<void> _showMissed() async {
    final app = context.appRead;
    if (!app.isUnlocked) return;
    final missed = app.takeUnseenAlerts();
    if (missed.isEmpty || !mounted) return;
    // 알림은 화면 + 음성으로(소리 설정이 켜져 있을 때). 금고가 열린 뒤에만 읽는다.
    if (app.settings.sound) {
      app.services.tts.speak(
        '확인할 알림이 ${missed.length}건 있어요. ${missed.take(3).map((a) => '${a.title}, ${a.detail}').join('. ')}',
      );
    }
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            const Emoji3D('bell', size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '확인할 알림 ${missed.length}건',
                style: Theme.of(c).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in missed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FlatCard(
                      status: statusOf(a),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusBadge(
                            statusOf(a),
                            a.level == AlertLevel.danger ? '위험' : '확인 필요',
                            compact: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.title,
                            style: Theme.of(c).textTheme.titleMedium,
                          ),
                          Text(
                            a.detail,
                            style: Theme.of(c).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          BigButton(
            label: '확인했어요',
            expand: false,
            raised: false,
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }

  void _go(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isUnlocked) return const SizedBox.shrink();
    final d = app.data;
    final now = app.now();
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final sum = summarize(d);
    final task = todayTask(d, now);
    final alerts = computeAlerts(d, now);
    final creditAlerts = alerts.where((a) => a.isCredit).length;
    final health = vaultHealth(d, now);
    final unused =
        unusedSubscriptions(d, now).length +
        d.subscriptions.where((s) => s.isCancelCandidate).length;
    final name = app.currentProfile?.name ?? '';

    return Scaffold(
      bottomNavigationBar: const ClipboardBanner(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                const LockAnimation(open: true, size: 56),
                const Mascot(MascotMood.unlocked, size: 56),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('$name님, 안녕하세요', style: t.headlineMedium),
                  ),
                ),
              ],
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: BigButton(
                    label: '잠그기',
                    icon: Icons.lock_rounded,
                    kind: ButtonKind.plain,
                    onPressed: () => app.lock(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BigButton(
                    label: '말로 묻기',
                    icon: Icons.mic_rounded,
                    kind: ButtonKind.accent,
                    onPressed: () => _go(const VoiceScreen()),
                  ),
                ),
              ],
            ),
            gap,
            const TipBubble(
              id: 'home',
              text: '큰 버튼을 눌러 원하는 곳으로 가세요. 2분 동안 아무것도 안 하면 금고가 자동으로 잠겨요.',
            ),
            // 오늘 할 일
            FlatCard(
              status: task == null ? StatusKind.safe : statusOf(task),
              onTap: task == null
                  ? null
                  : () => _go(
                      task.isCredit
                          ? const CreditsScreen()
                          : const SubscriptionsScreen(),
                    ),
              child: Row(
                children: [
                  Emoji3D(
                    task == null
                        ? 'check_mark_button'
                        : (task.isCredit ? 'hourglass_not_done' : 'calendar'),
                    size: 52,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘 할 일',
                          style: t.titleMedium?.copyWith(color: p.textMuted),
                        ),
                        Text(
                          task?.title ?? '오늘은 할 일이 없어요',
                          style: t.titleLarge,
                        ),
                        if (task != null) Text(task.detail, style: t.bodyLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            gap,
            // 이번 달 지출(큰 숫자 하나)
            FlatCard(
              onTap: () => _go(const SubscriptionsScreen()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 달 구독료',
                    style: t.titleMedium?.copyWith(color: p.textMuted),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatWon(sum.monthly),
                      style: TextStyle(
                        fontSize: AppTokens.fontBigNumber,
                        fontWeight: FontWeight.w900,
                        color: p.primary,
                      ),
                    ),
                  ),
                  Text(
                    '구독 ${sum.activeCount}개 · 1년이면 ${formatWon(sum.yearly)}',
                    style: t.bodyLarge,
                  ),
                ],
              ),
            ),
            gapBig,
            LayoutBuilder(
              builder: (context, c) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final cols = (c.maxWidth / (170 * scale)).floor().clamp(1, 3);
                final tiles = <Widget>[
                  Tile3D(
                    emoji: 'credit_card',
                    title: '구독 결제',
                    subtitle: '월 요금·결제일·카드',
                    onTap: () => _go(const SubscriptionsScreen()),
                  ),
                  Tile3D(
                    emoji: 'alarm_clock',
                    title: '만료 알림',
                    subtitle: '크레딧·체험판 마감일',
                    badge: creditAlerts > 0 ? '$creditAlerts건' : null,
                    badgeKind:
                        alerts.any(
                          (a) => a.isCredit && a.level == AlertLevel.danger,
                        )
                        ? StatusKind.danger
                        : StatusKind.caution,
                    onTap: () => _go(const CreditsScreen()),
                  ),
                  Tile3D(
                    emoji: 'key',
                    title: '계정·비밀번호',
                    subtitle: '아이디·가입 이메일·비밀번호',
                    onTap: () => _go(const AccountsScreen()),
                  ),
                  Tile3D(
                    emoji: 'broom',
                    title: '정리 도우미',
                    subtitle: '해지 추천·비밀번호 점검',
                    badge: unused + health.issues.length > 0
                        ? '${unused + health.issues.length}건'
                        : null,
                    onTap: () => _go(const CleanupScreen()),
                  ),
                  Tile3D(
                    emoji: 'microphone',
                    title: '음성 비서',
                    subtitle: '말로 묻고 아침 브리핑',
                    onTap: () => _go(const VoiceScreen()),
                  ),
                  Tile3D(
                    emoji: 'gear',
                    title: '설정',
                    subtitle: '글씨·화면·백업·연결',
                    onTap: () => _go(const SettingsScreen()),
                  ),
                ];
                final rows = <Widget>[];
                for (var i = 0; i < tiles.length; i += cols) {
                  final slice = tiles.sublist(
                    i,
                    (i + cols).clamp(0, tiles.length),
                  );
                  rows.add(
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var j = 0; j < cols; j++) ...[
                            if (j > 0) const SizedBox(width: 12),
                            Expanded(
                              child: j < slice.length
                                  ? slice[j]
                                  : const SizedBox(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                  rows.add(const SizedBox(height: 14));
                }
                return Column(children: rows);
              },
            ),
          ],
        ),
      ),
    );
  }
}
