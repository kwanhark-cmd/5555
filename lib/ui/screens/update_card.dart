import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../app/app_controller.dart';
import '../../core/log/app_logger.dart';
import '../../logic/update_check.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'backup_flow.dart';

/// 공개 내려받기 페이지(로그인 필요 없음).
const releasesPage = 'https://github.com/kwanhark-cmd/5555/releases/latest';

/// 기기마다 "기존 앱 삭제" 방법.
String deleteOldAppStep(String os) => switch (os) {
  'android' => '홈 화면에서 앱 아이콘을 길게 누르고 "삭제"(또는 설정 → 애플리케이션 → 구독·계정 비서 → 삭제)',
  'windows' => '윈도우 설정 → 앱 → 설치된 앱 → "구독·계정 비서" → 제거',
  'macos' => '응용 프로그램 폴더에서 앱을 휴지통으로 끌어 놓기',
  _ => '기존 앱 폴더를 지우기',
};

/// 기기마다 "새 앱 설치" 방법.
String installNewAppStep(String os) => switch (os) {
  'android' => '내려받은 APK 파일을 눌러 설치("이 출처 허용"을 켜야 할 수 있어요)',
  'windows' => '내려받은 설치 파일(…windows-setup.exe)을 실행해 설치',
  'macos' => '내려받은 zip 을 풀고 앱을 응용 프로그램 폴더로 끌어 놓은 뒤, 처음 한 번은 오른쪽 클릭 → "열기"',
  _ => '내려받은 파일을 풀고 account_vault 실행',
};

/// 새 버전으로 바꾸는 순서(모든 기기 같음): 백업 → 확인 → 내려받기 → 기존 앱 삭제 → 설치 → 복원.
/// 앱 안에서 내려받거나 덮어써 설치하지 않는다.
List<String> replaceSteps(String os) => [
  '① "백업 파일 만들기"를 누르고 드라이브·내 파일·USB·컴퓨터 등 앱 밖에 저장해요.',
  '② "저장한 백업 파일 확인"을 누르고 방금 저장한 파일을 골라 확인해요.',
  '③ "새 버전 내려받기"로 브라우저에서 새 설치 파일을 내려받아요.',
  '④ 기존 앱을 삭제해요: ${deleteOldAppStep(os)}.',
  '⑤ 새 앱을 설치해요: ${installNewAppStep(os)}.',
  '⑥ 새 앱 첫 화면에서 "쓰던 금고가 있어요 — 백업 파일로 복원"을 누르고, 백업을 만들 때의 마스터 비밀번호로 열어요. '
      '(컴퓨터에서 바로 잠금 화면이 나오면 금고가 남아 있는 것이니 그대로 열면 돼요.) 지문·얼굴 잠금은 설정에서 다시 켜 주세요.',
];

/// 설정 맨 위 "새 버전으로 바꾸기". 금고가 열린 상태에서만 보인다(설정 화면 자체가 잠금 해제 후).
/// 앱이 직접 내려받거나 설치하지 않는다. 기존 앱을 지우고 새 앱을 설치하는 순서를 버튼과 함께 안내하고,
/// 앱 밖에 저장한 백업 파일을 확인해야 내려받기 버튼이 켜진다.
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key, this.client});

  /// 테스트용 가짜 서버.
  final http.Client? client;

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  bool busy = false;
  String? message;
  StatusKind kind = StatusKind.progress;
  ReleaseInfo? release;
  bool checked = false;

  /// 이번에 백업 파일을 만들었는지, 저장한 파일을 확인했는지.
  bool backupMade = false;
  SavedBackupCheck? backupCheck;

  UpdateChecker get _checker => UpdateChecker(client: widget.client);

  Future<void> _check() async {
    final app = context.appRead;
    setState(() {
      busy = true;
      message = null;
      release = null;
    });
    try {
      final r = await _checker.latest();
      if (!mounted) return;
      final newer = compareVersions(r.version, app.services.appVersion) > 0;
      setState(() {
        checked = true;
        release = r;
        kind = newer ? StatusKind.caution : StatusKind.safe;
        message = newer
            ? '새 버전 ${r.version} 이 있어요. 아래 순서대로 바꿔 주세요.'
            : '지금 최신 버전(${app.services.appVersion})이에요.';
      });
    } on UpdateException catch (e) {
      log.warn('새 버전 확인 실패: ${e.message}');
      if (mounted) {
        setState(() {
          checked = true;
          kind = StatusKind.danger;
          message = '${e.message} 아래 순서는 그대로 따라 할 수 있어요.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// ① 백업 파일을 앱 밖에 저장.
  Future<void> _backup() async {
    final app = context.appRead;
    setState(() {
      busy = true;
      backupCheck = null;
    });
    try {
      final where = await saveBackupFile(app);
      if (!mounted) return;
      setState(() {
        backupMade = where != null;
        kind = where == null ? StatusKind.caution : StatusKind.progress;
        message = where == null
            ? '저장을 취소했어요. 백업 파일 없이 앱을 삭제하면 금고가 사라질 수 있어요.'
            : '백업 파일을 저장했어요. 이제 "저장한 백업 파일 확인"으로 저장됐는지 확인해 주세요.';
      });
    } catch (e) {
      log.error('새 버전 전 백업 실패', e);
      if (mounted) {
        setState(() {
          kind = StatusKind.danger;
          message = '백업 파일을 만들지 못했어요. 앱을 삭제하지 말고 다시 시도해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// ② 저장한 파일을 다시 골라 확인.
  Future<void> _verify() async {
    final app = context.appRead;
    setState(() => busy = true);
    try {
      final r = await pickAndCheckSavedBackup(app);
      if (mounted && r != null) setState(() => backupCheck = r);
    } catch (e) {
      log.error('백업 파일 확인 실패', e);
      if (mounted) {
        setState(
          () => backupCheck = const SavedBackupCheck(
            false,
            '백업 파일을 확인하지 못했어요. 다시 골라 주세요.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// ③ 브라우저로 내려받기(앱 밖 "다운로드" 폴더에 남는다). 확인된 백업이 있어야 열린다.
  Future<void> _download() async {
    final app = context.appRead;
    if (backupCheck?.ok != true) return;
    final asset = release?.assetFor(app.services.installer.os);
    final url =
        asset?.url ??
        ((release?.pageUrl.isNotEmpty ?? false)
            ? release!.pageUrl
            : releasesPage);
    final opened = await app.services.launcher.open(Uri.parse(url));
    log.info('새 버전 내려받기 열기');
    if (!mounted) return;
    setState(() {
      kind = opened ? StatusKind.safe : StatusKind.danger;
      message = opened
          ? '브라우저에서 내려받기를 시작했어요. 다 받은 뒤 ④~⑥ 순서대로 해 주세요.'
          : '브라우저를 열지 못했어요. 인터넷 주소창에 $releasesPage 를 넣어 내려받아 주세요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = Theme.of(context).textTheme;
    final os = app.services.installer.os;
    return FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Emoji3D('sparkles', size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('새 버전으로 바꾸기', style: t.titleLarge),
                    Text(
                      '지금 버전 ${app.services.appVersion}',
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          gap,
          Text(
            '새 버전은 기존 앱을 지우고 새 앱을 설치하는 방식이에요. '
            '앱을 지우면 금고도 지워질 수 있으니, 지우기 전에 꼭 백업 파일을 앱 밖에 저장하고 확인하세요.',
            style: t.bodyLarge,
          ),
          if (message != null) ...[gap, StatusBadge(kind, message!)],
          gap,
          if (!checked)
            BigButton(
              label: '새 버전 확인하기',
              icon: Icons.update_rounded,
              kind: ButtonKind.primary,
              onPressed: busy ? null : _check,
            )
          else
            ..._steps(t, os),
        ],
      ),
    );
  }

  /// 순서와 버튼. 내려받기는 저장한 백업 파일을 확인한 뒤에만 켜진다.
  List<Widget> _steps(TextTheme t, String os) => [
    FlatCard(
      status: StatusKind.caution,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('새 버전으로 바꾸는 순서', style: t.titleMedium),
          gap,
          for (final s in replaceSteps(os)) ...[
            Text(s, style: t.bodyLarge),
            const SizedBox(height: 6),
          ],
        ],
      ),
    ),
    if (backupCheck != null) ...[
      gap,
      StatusBadge(
        backupCheck!.ok ? StatusKind.safe : StatusKind.danger,
        backupCheck!.message,
      ),
    ],
    gap,
    if (busy)
      const Center(child: CircularProgressIndicator())
    else ...[
      BigButton(
        label: '① 백업 파일 만들기',
        icon: Icons.save_alt_rounded,
        kind: ButtonKind.primary,
        onPressed: _backup,
      ),
      gap,
      BigButton(
        label: '② 저장한 백업 파일 확인',
        icon: Icons.fact_check_rounded,
        kind: backupMade ? ButtonKind.primary : ButtonKind.plain,
        onPressed: _verify,
      ),
      gap,
      BigButton(
        label: '③ 새 버전 내려받기(브라우저)',
        icon: Icons.open_in_browser_rounded,
        kind: ButtonKind.caution,
        onPressed: backupCheck?.ok == true ? _download : null,
      ),
      if (backupCheck?.ok != true) ...[
        const SizedBox(height: 6),
        Text('백업 파일을 확인해야 내려받기 버튼이 켜져요.', style: t.bodyMedium),
      ],
    ],
  ];
}
