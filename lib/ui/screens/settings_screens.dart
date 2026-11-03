import 'package:flutter/material.dart';

import '../../core/crypto/password_tools.dart';
import '../../core/log/app_logger.dart';
import '../../data/repository.dart';
import '../../logic/gmail.dart';
import '../../logic/mail_analysis.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'recovery_code_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _go(BuildContext c, Widget w) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isUnlocked) return const SizedBox.shrink();
    final s = app.settings;
    final t = Theme.of(context).textTheme;
    final prefs = app.data.prefs;
    return AppPage(
      title: '설정',
      children: [
        const SectionTitle('보기'),
        Text('글씨 크기', style: t.titleMedium),
        const SizedBox(height: 6),
        ChoiceChips<int>(
          values: const [0, 1, 2],
          selected: s.textScaleLevel,
          label: (i) => DeviceSettings.textScaleLabels[i],
          onSelected: (i) => app.updateSettings((x) => x.textScaleLevel = i),
        ),
        gap,
        Text('화면 모드', style: t.titleMedium),
        const SizedBox(height: 6),
        ChoiceChips<String>(
          values: const ['light', 'dark', 'contrast', 'system'],
          selected: s.themeMode,
          label: (m) => const {
            'light': '밝게',
            'dark': '어둡게',
            'contrast': '고대비',
            'system': '기기 설정 따라',
          }[m]!,
          onSelected: (m) => app.updateSettings((x) => x.themeMode = m),
        ),
        gap,
        SwitchRow(
          title: '움직임 줄이기',
          subtitle: '화면 움직임 효과를 꺼요',
          value: s.reduceMotion,
          onChanged: (v) => app.updateSettings((x) => x.reduceMotion = v),
        ),
        const SizedBox(height: 8),
        SwitchRow(
          title: '진동',
          subtitle: '버튼을 누를 때 살짝 진동',
          value: s.haptics,
          onChanged: (v) => app.updateSettings((x) => x.haptics = v),
        ),
        const SizedBox(height: 8),
        SwitchRow(
          title: '소리로 답 읽기',
          subtitle: '음성 비서가 답을 읽어 줘요',
          value: s.sound,
          onChanged: (v) => app.updateSettings((x) => x.sound = v),
        ),

        const SectionTitle('보안'),
        Text('자동 잠금', style: t.titleMedium),
        const SizedBox(height: 6),
        ChoiceChips<int>(
          values: const [60, 120, 300, 600],
          selected: s.autoLockSeconds,
          label: (v) => '${v ~/ 60}분',
          onSelected: (v) => app.updateSettings((x) => x.autoLockSeconds = v),
        ),
        gap,
        _BiometricRow(),
        const SizedBox(height: 8),
        SwitchRow(
          title: '유출된 비밀번호 확인',
          subtitle: '켜면 금고 건강 보고서에서 확인할 수 있어요(비밀번호는 보내지 않음)',
          value: prefs.breachCheckEnabled,
          onChanged: (v) => app.mutate((d) => d.prefs.breachCheckEnabled = v),
        ),
        gap,
        BigButton(
          label: '마스터 비밀번호 바꾸기',
          icon: Icons.password_rounded,
          kind: ButtonKind.plain,
          onPressed: () => _go(context, const ChangePasswordScreen()),
        ),
        gap,
        BigButton(
          label: '복구 코드 새로 만들기',
          icon: Icons.key_rounded,
          kind: ButtonKind.plain,
          onPressed: () => _go(context, const NewRecoveryCodeScreen()),
        ),

        const SectionTitle('연결'),
        _LinkTile(
          emoji: 'magic_wand',
          title: 'AI 연결(API 키)',
          status: prefs.aiConnected ? '연결됨' : '연결 안 됨',
          ok: prefs.aiConnected,
          onTap: () => _go(context, const AiSettingsScreen()),
        ),
        const SizedBox(height: 8),
        _LinkTile(
          emoji: 'envelope',
          title: '지메일 연결(읽기 전용)',
          status: prefs.gmailConnected ? '연결됨' : '연결 안 됨',
          ok: prefs.gmailConnected,
          onTap: () => _go(context, const GmailSettingsScreen()),
        ),
        const SizedBox(height: 8),
        Text('음성 서비스', style: t.titleMedium),
        const SizedBox(height: 6),
        ChoiceChips<String>(
          values: const ['device', 'external'],
          selected: s.voiceProvider,
          label: (v) => v == 'device' ? '기기 내장 음성(기본)' : '외부 서비스(준비 중)',
          onSelected: (v) => app.updateSettings((x) => x.voiceProvider = v),
        ),

        const SectionTitle('데이터'),
        BigButton(
          label: '백업 내보내기·복원',
          icon: Icons.inventory_2_rounded,
          kind: ButtonKind.accent,
          onPressed: () => _go(context, const BackupScreen()),
        ),
        gap,
        _ExchangeRate(),

        const SectionTitle('도움'),
        BigButton(
          label: '문제 신고(기록 내보내기)',
          icon: Icons.bug_report_rounded,
          kind: ButtonKind.plain,
          onPressed: () async {
            final txt = await log.exportText(
              appVersion: app.services.appVersion,
            );
            final where = await app.services.files.saveText('문제신고기록.txt', txt);
            if (context.mounted) {
              context.toast(
                where == null
                    ? '저장을 취소했어요.'
                    : '기록을 저장했어요. 이 파일을 보내 주세요. (비밀번호·계정 정보는 들어 있지 않아요)',
              );
            }
          },
        ),
        gap,
        FlatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow('앱 버전', app.services.appVersion),
              const InfoRow('아이폰 지원', '준비 중'),
              const InfoRow('그림', 'Microsoft Fluent Emoji 3D (MIT 라이선스)'),
              const InfoRow('글꼴', 'Noto Sans KR (SIL Open Font License)'),
            ],
          ),
        ),
        gap,
        BigButton(
          label: '오픈소스 라이선스 보기',
          kind: ButtonKind.plain,
          onPressed: () => showLicensePage(
            context: context,
            applicationName: '로그인 계정과 구독 결제 관리 비서',
            applicationVersion: app.services.appVersion,
          ),
        ),

        const SectionTitle('위험'),
        BigButton(
          label: '이 사용자 금고 초기화(모두 지우기)',
          icon: Icons.delete_forever_rounded,
          kind: ButtonKind.danger,
          onPressed: () => _reset(context),
        ),
      ],
    );
  }

  Future<void> _reset(BuildContext context) async {
    final app = context.appRead;
    final pw = await askMasterPassword(context, '초기화하려면 마스터 비밀번호를 입력해 주세요.');
    if (pw == null || !context.mounted) return;
    if (!await app.verifyMasterPassword(pw)) {
      if (context.mounted) context.toast('마스터 비밀번호가 맞지 않아요.');
      return;
    }
    if (!context.mounted) return;
    final ok = await confirmTwice(
      context,
      title: '금고 초기화',
      message: '이 사용자의 구독·계정·비밀번호가 모두 지워져요. 먼저 백업해 두셨나요?',
      confirmLabel: '모두 지우기',
    );
    if (!ok) return;
    await app.deleteCurrentProfile();
  }
}

Future<String?> askMasterPassword(BuildContext context, String message) async {
  final c = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('본인 확인'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            gap,
            BigField(
              controller: c,
              label: '마스터 비밀번호',
              obscure: true,
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
      ),
      actions: [
        BigButton(
          label: '취소',
          kind: ButtonKind.plain,
          expand: false,
          raised: false,
          onPressed: () => Navigator.pop(ctx),
        ),
        BigButton(
          label: '확인',
          expand: false,
          raised: false,
          onPressed: () => Navigator.pop(ctx, c.text),
        ),
      ],
    ),
  );
  c.dispose();
  return r;
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.emoji,
    required this.title,
    required this.status,
    required this.ok,
    required this.onTap,
  });
  final String emoji, title, status;
  final bool ok;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FlatCard(
    onTap: onTap,
    child: Row(
      children: [
        Emoji3D(emoji, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              StatusBadge(
                ok ? StatusKind.safe : StatusKind.progress,
                status,
                compact: true,
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, size: 32),
      ],
    ),
  );
}

class _BiometricRow extends StatefulWidget {
  @override
  State<_BiometricRow> createState() => _BiometricRowState();
}

class _BiometricRowState extends State<_BiometricRow> {
  bool? available;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await context.appRead.services.biometric.isAvailable();
      if (mounted) setState(() => available = ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final on = app.session?.hasDeviceUnlock ?? false;
    return SwitchRow(
      title: '지문·얼굴로 열기',
      subtitle: available == false
          ? '이 기기에서는 쓸 수 없어요'
          : '안 될 때는 마스터 비밀번호로 열 수 있어요',
      value: on,
      onChanged: available != true
          ? null
          : (v) async {
              if (v &&
                  !await app.services.biometric.authenticate(
                    '지문·얼굴 사용을 확인해요',
                  )) {
                return;
              }
              await app.setBiometric(v);
            },
    );
  }
}

class _ExchangeRate extends StatefulWidget {
  @override
  State<_ExchangeRate> createState() => _ExchangeRateState();
}

class _ExchangeRateState extends State<_ExchangeRate> {
  late final c = TextEditingController(
    text: '${context.appRead.data.prefs.usdToKrw}',
  );

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BigField(
    controller: c,
    label: '달러 환율(1달러 = ?원)',
    keyboard: TextInputType.number,
    onSubmitted: (v) async {
      final n = int.tryParse(v.replaceAll(',', ''));
      if (n == null || n < 100 || n > 5000) {
        context.toast('100~5000 사이 숫자로 적어 주세요.');
        return;
      }
      await context.appRead.mutate((d) => d.prefs.usdToKrw = n);
      if (context.mounted) context.toast('환율을 저장했어요.');
    },
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final old = TextEditingController(),
      pw = TextEditingController(),
      pw2 = TextEditingController();
  String? error;
  bool busy = false;

  @override
  void dispose() {
    old.dispose();
    pw.dispose();
    pw2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.appRead;
    if (pw.text.length < 8 || PasswordTools.strength(pw.text).score < 2) {
      return setState(() => error = '8글자 이상, 너무 쉽지 않은 비밀번호로 정해 주세요.');
    }
    if (pw.text != pw2.text) {
      return setState(() => error = '두 번 입력한 비밀번호가 달라요.');
    }
    setState(() => busy = true);
    if (!await app.verifyMasterPassword(old.text)) {
      setState(() {
        busy = false;
        error = '지금 마스터 비밀번호가 맞지 않아요.';
      });
      return;
    }
    await app.session!.changeMasterPassword(pw.text);
    log.info('마스터 비밀번호 변경');
    if (!mounted) return;
    context.toast('마스터 비밀번호를 바꿨어요. 종이에 적어 둔 것도 바꿔 주세요.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: '마스터 비밀번호 바꾸기',
    children: [
      BigField(controller: old, label: '지금 마스터 비밀번호', obscure: true),
      gap,
      BigField(controller: pw, label: '새 마스터 비밀번호', obscure: true),
      gap,
      BigField(
        controller: pw2,
        label: '새 비밀번호 한 번 더',
        obscure: true,
        onSubmitted: (_) => _save(),
      ),
      if (error != null) ...[gap, StatusBadge(StatusKind.danger, error!)],
      gapBig,
      busy
          ? const Center(child: CircularProgressIndicator())
          : BigButton(label: '바꾸기', kind: ButtonKind.safe, onPressed: _save),
    ],
  );
}

class NewRecoveryCodeScreen extends StatefulWidget {
  const NewRecoveryCodeScreen({super.key});

  @override
  State<NewRecoveryCodeScreen> createState() => _NewRecoveryCodeScreenState();
}

class _NewRecoveryCodeScreenState extends State<NewRecoveryCodeScreen> {
  String? code;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: '복구 코드 새로 만들기',
      children: [
        Text('새로 만들면 예전 복구 코드는 더 이상 쓸 수 없어요.', style: t.bodyLarge),
        gap,
        if (code == null)
          BigButton(
            label: '새로 만들기',
            kind: ButtonKind.caution,
            onPressed: () async {
              final app = context.appRead;
              final pw = await askMasterPassword(
                context,
                '복구 코드를 새로 만들려면 마스터 비밀번호를 입력해 주세요.',
              );
              if (pw == null) return;
              if (!await app.verifyMasterPassword(pw)) {
                if (context.mounted) context.toast('마스터 비밀번호가 맞지 않아요.');
                return;
              }
              final c = await app.session!.regenerateRecoveryCode();
              log.info('복구 코드 재발급');
              setState(() => code = c);
            },
          )
        else ...[
          RecoveryCodeView(code: code!),
          gap,
          Text(
            '종이에 적어 안전한 곳에 보관해 주세요. 이 화면을 나가면 다시 볼 수 없어요.',
            style: t.bodyLarge,
          ),
        ],
      ],
    );
  }
}

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final prefs = context.appRead.data.prefs;
  late final key = TextEditingController(text: prefs.aiApiKey);
  late final limit = TextEditingController(text: '${prefs.aiMonthlyLimitWon}');
  late String model = prefs.aiModel;

  @override
  void dispose() {
    key.dispose();
    limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = Theme.of(context).textTheme;
    final est = ClaudeMailAnalyzer(
      apiKey: '',
      model: model,
      usdToKrw: prefs.usdToKrw,
    ).estimateCostWon('가' * 1500);
    final m = '${app.now().year}-${app.now().month.toString().padLeft(2, '0')}';
    final used = prefs.aiUsageMonth == m ? prefs.aiUsageWon : 0;
    return AppPage(
      title: 'AI 연결',
      children: [
        Text(
          '결제 메일을 더 잘 알아보도록 Claude AI를 연결할 수 있어요. '
          'console.anthropic.com 에서 만든 API 키를 넣어 주세요. 키는 금고 안에 암호화되어 저장돼요.\n'
          '메일에서 필요한 부분만, 카드 번호는 가린 채 보내고, 보낸 내용은 저장하지 않아요.',
          style: t.bodyLarge,
        ),
        gap,
        BigField(controller: key, label: 'API 키', obscure: true),
        gap,
        Text('모델', style: t.titleMedium),
        const SizedBox(height: 6),
        ChoiceChips<String>(
          values: ClaudeMailAnalyzer.models.keys.toList(),
          selected: model,
          label: (m) => ClaudeMailAnalyzer.models[m]!,
          onSelected: (m) => setState(() => model = m),
        ),
        gap,
        FlatCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow('메일 1통 분석 예상 비용', '약 ${est.toStringAsFixed(1)}원'),
              InfoRow('이번 달 사용', '${used.toStringAsFixed(1)}원'),
            ],
          ),
        ),
        gap,
        BigField(
          controller: limit,
          label: '한 달 사용 한도(원)',
          keyboard: TextInputType.number,
        ),
        gapBig,
        BigButton(
          label: '저장',
          kind: ButtonKind.safe,
          icon: Icons.save_rounded,
          onPressed: () async {
            final l =
                int.tryParse(limit.text.replaceAll(',', '')) ??
                prefs.aiMonthlyLimitWon;
            await app.mutate((d) {
              d.prefs.aiApiKey = key.text.trim();
              d.prefs.aiModel = model;
              d.prefs.aiMonthlyLimitWon = l.clamp(0, 1000000);
            });
            if (context.mounted) {
              context.toast('저장했어요.');
              Navigator.pop(context);
            }
          },
        ),
        if (prefs.aiConnected) ...[
          gap,
          BigButton(
            label: '연결 끊기(키 지우기)',
            kind: ButtonKind.danger,
            onPressed: () async {
              await app.mutate((d) => d.prefs.aiApiKey = '');
              key.clear();
              if (context.mounted) context.toast('AI 연결을 끊었어요.');
            },
          ),
        ],
      ],
    );
  }
}

class GmailSettingsScreen extends StatefulWidget {
  const GmailSettingsScreen({super.key});

  @override
  State<GmailSettingsScreen> createState() => _GmailSettingsScreenState();
}

class _GmailSettingsScreenState extends State<GmailSettingsScreen> {
  late final prefs = context.appRead.data.prefs;
  late final clientId = TextEditingController(text: prefs.gmailClientId);
  late final secret = TextEditingController(text: prefs.gmailClientSecret);
  bool busy = false;

  @override
  void dispose() {
    clientId.dispose();
    secret.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final app = context.appRead;
    if (clientId.text.trim().isEmpty) {
      context.toast('먼저 클라이언트 ID를 넣어 주세요(README 의 지메일 연결법 참고).');
      return;
    }
    setState(() => busy = true);
    try {
      final oauth = GoogleOAuth(
        clientId: clientId.text.trim(),
        clientSecret: secret.text.trim(),
      );
      final rt = await oauth.signIn(app.services.launcher.open);
      await app.mutate((d) {
        d.prefs.gmailClientId = clientId.text.trim();
        d.prefs.gmailClientSecret = secret.text.trim();
        d.prefs.gmailRefreshToken = rt;
      });
      log.info('지메일 연결됨');
      if (mounted) context.toast('지메일을 연결했어요. 결제 메일 읽기만 해요.');
    } on GmailException catch (e) {
      if (mounted) context.toast(e.message);
    } catch (_) {
      if (mounted) context.toast('연결하지 못했어요. 잠시 뒤 다시 해 주세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = Theme.of(context).textTheme;
    final connected = app.data.prefs.gmailConnected;
    return AppPage(
      title: '지메일 연결',
      children: [
        StatusBadge(
          connected ? StatusKind.safe : StatusKind.progress,
          connected ? '연결됨(읽기 전용)' : '연결 안 됨',
        ),
        gap,
        Text(
          '결제 영수증·크레딧 안내 메일을 찾아 자동으로 채워 드려요. 메일은 읽기만 하고, 내용은 저장하지 않아요. '
          '연결하지 않아도 앱은 모두 쓸 수 있어요(직접 입력·메일 붙여넣기).\n\n'
          '연결하려면 구글 클라우드에서 "데스크톱 앱" OAuth 클라이언트 ID를 만들어 아래에 넣어 주세요. 방법은 README.md 에 있어요.',
          style: t.bodyLarge,
        ),
        gap,
        BigField(controller: clientId, label: '클라이언트 ID'),
        gap,
        BigField(controller: secret, label: '클라이언트 비밀번호(있으면)', obscure: true),
        gapBig,
        busy
            ? const Center(child: CircularProgressIndicator())
            : BigButton(
                label: connected ? '다시 연결' : '구글 계정으로 연결',
                icon: Icons.link_rounded,
                onPressed: _connect,
              ),
        if (connected) ...[
          gap,
          BigButton(
            label: '연결 끊기',
            kind: ButtonKind.danger,
            onPressed: () async {
              await app.mutate((d) => d.prefs.gmailRefreshToken = '');
              if (context.mounted) context.toast('지메일 연결을 끊었어요.');
            },
          ),
        ],
      ],
    );
  }
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool busy = false;

  Future<void> _export() async {
    final app = context.appRead;
    setState(() => busy = true);
    try {
      final info = app.currentProfile!;
      final json = await app.backups.export(
        info.id,
        info.name,
        app.services.appVersion,
      );
      final d = app.now();
      final name =
          '금고백업-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.vaultbackup';
      final where = await app.services.files.saveText(name, json);
      log.info('백업 내보냄');
      if (mounted) {
        context.toast(
          where == null ? '저장을 취소했어요.' : '백업을 저장했어요. 마스터 비밀번호가 있어야 열 수 있어요.',
        );
      }
    } catch (e) {
      log.error('백업 실패', e);
      if (mounted) context.toast('백업하지 못했어요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    final app = context.appRead;
    final text = await app.services.files.openText(
      extensions: ['vaultbackup', 'json'],
    );
    if (text == null || !mounted) return;
    setState(() => busy = true);
    try {
      final info = await app.backups.inspect(text);
      if (!mounted) return;
      setState(() => busy = false);
      final pw = await askMasterPassword(
        context,
        '"${info.profileName}" 백업을 만들 때의 마스터 비밀번호를 입력해 주세요.',
      );
      if (pw == null || !mounted) return;
      setState(() => busy = true);
      if (!await app.backups.verifyPassword(
        info,
        pw,
        app.services.scratchDir,
      )) {
        if (mounted) context.toast('백업의 마스터 비밀번호가 맞지 않아요.');
        return;
      }
      if (!mounted) return;
      final ok = await confirmTwice(
        context,
        title: '백업으로 복원',
        message:
            '"${info.profileName}"의 금고를 백업 내용으로 바꿀까요? 지금 데이터는 먼저 자동으로 백업해 둘게요.',
        confirmLabel: '복원',
      );
      if (!ok) return;
      final auto = await app.backups.restore(info, app.services.appVersion);
      log.info('백업 복원 완료');
      await app.reloadProfiles();
      await app.lock(reason: 'restore');
      if (auto != null) log.info('복원 전 자동 백업 저장됨');
    } on BackupException catch (e) {
      if (mounted) context.toast(e.message);
    } catch (e) {
      log.error('복원 실패', e);
      if (mounted) context.toast('복원하지 못했어요. 지금 데이터는 그대로예요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: '백업',
      children: [
        const Center(child: Emoji3D('package', size: 96)),
        gap,
        Text(
          '백업 파일은 금고와 똑같이 암호화되어 있어요. 열 때 그 당시의 마스터 비밀번호가 필요해요.\n'
          '휴대폰을 바꾸거나 고장 날 때를 대비해 가끔 백업해 USB 등에 보관하세요.',
          style: t.bodyLarge,
        ),
        gapBig,
        if (busy)
          const Center(child: CircularProgressIndicator())
        else ...[
          BigButton(
            label: '백업 파일 만들기',
            icon: Icons.download_rounded,
            kind: ButtonKind.safe,
            onPressed: _export,
          ),
          gap,
          BigButton(
            label: '백업 파일로 복원',
            icon: Icons.restore_rounded,
            kind: ButtonKind.caution,
            onPressed: _restore,
          ),
          gap,
          Text(
            '복원하면 안전을 위해 금고가 잠겨요. 백업의 마스터 비밀번호로 다시 열어 주세요.',
            style: t.bodyMedium,
          ),
        ],
      ],
    );
  }
}
