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

/// 안드로이드 새 버전 순서. 앱을 지우면 금고도 지워지므로 백업 파일(앱 밖 저장·확인)이 언제나 먼저다.
const androidUpdateSteps = [
  '① "백업 파일 만들기"를 누르고 드라이브·내 파일·컴퓨터 등 앱 밖에 저장해요.',
  '② "저장한 백업 파일 확인"을 누르고 방금 저장한 파일을 골라 확인해요.',
  '③ "새 버전 내려받기"로 브라우저에서 새 설치 파일(APK)을 내려받아요.',
  '④ 그다음에 기존 앱을 삭제해요(삭제하면 앱 안의 금고도 지워져요).',
  '⑤ 내려받은 파일을 눌러 설치해요.',
  '⑥ 새 앱 첫 화면에서 "쓰던 금고가 있어요 — 백업 파일로 복원"을 누르고, 백업을 만들 때의 마스터 비밀번호로 열어요. 지문·얼굴 잠금은 설정에서 다시 켜 주세요.',
];

/// 설정 맨 위 "업데이트 확인". 금고가 열린 상태에서만 보인다(설정 화면 자체가 잠금 해제 후).
/// 자동으로 내려받지 않는다.
/// - 컴퓨터(윈도우·맥·리눅스): 확인 → 사용자가 누르면 자동 백업 → 내려받기 → 해시 확인 → 설치(덮어쓰기).
/// - 안드로이드: 앱 안에서 설치하지 않는다. 백업 파일 저장 → 확인 → 브라우저로 내려받기 →
///   기존 앱 삭제 → 설치 → 첫 화면에서 복원 순서를 안내한다.
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key, this.client});

  /// 테스트용 가짜 서버.
  final http.Client? client;

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  bool busy = false;
  double? progress;
  String? message;
  StatusKind kind = StatusKind.progress;
  ReleaseInfo? release;

  /// 안드로이드: 이번에 백업 파일을 만들었는지, 저장한 파일을 확인했는지.
  bool backupMade = false;
  SavedBackupCheck? backupCheck;

  bool get _android => context.appRead.services.installer.os == 'android';

  UpdateChecker get _checker => UpdateChecker(client: widget.client);

  Future<void> _check() async {
    final app = context.appRead;
    setState(() {
      busy = true;
      message = null;
      release = null;
      backupMade = false;
      backupCheck = null;
    });
    try {
      final r = await _checker.latest();
      if (!mounted) return;
      if (compareVersions(r.version, app.services.appVersion) > 0) {
        setState(() {
          release = r;
          kind = StatusKind.caution;
          message = '새 버전 ${r.version} 이 있어요.';
        });
      } else {
        setState(() {
          kind = StatusKind.safe;
          message = '지금 최신 버전(${app.services.appVersion})이에요.';
        });
      }
    } on UpdateException catch (e) {
      log.warn('업데이트 확인 실패: ${e.message}');
      if (mounted) {
        setState(() {
          kind = StatusKind.danger;
          message = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// 안드로이드 ①: 백업 파일을 앱 밖에 저장.
  Future<void> _androidBackup() async {
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
            ? '저장을 취소했어요. 백업 파일 없이 앱을 삭제하면 금고가 사라져요.'
            : '백업 파일을 보냈어요. 이제 "저장한 백업 파일 확인"으로 저장됐는지 확인해 주세요.';
      });
    } catch (e) {
      log.error('업데이트 전 백업 실패', e);
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

  /// 안드로이드 ②: 저장한 파일을 다시 골라 확인.
  Future<void> _androidVerify() async {
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

  /// 안드로이드 ③: 브라우저로 내려받기(앱 밖 "다운로드" 폴더에 남는다). 확인된 백업이 있어야 열린다.
  Future<void> _androidDownload() async {
    final app = context.appRead;
    final r = release;
    if (r == null || backupCheck?.ok != true) return;
    final asset = r.assetFor('android');
    final url = asset?.url ?? (r.pageUrl.isEmpty ? releasesPage : r.pageUrl);
    final opened = await app.services.launcher.open(Uri.parse(url));
    log.info('안드로이드 새 버전 내려받기 열기');
    if (!mounted) return;
    setState(() {
      kind = opened ? StatusKind.safe : StatusKind.danger;
      message = opened
          ? '브라우저에서 내려받기를 시작했어요. 다 받은 뒤 ④~⑥ 순서대로 해 주세요.'
          : '브라우저를 열지 못했어요. 인터넷 주소창에 $releasesPage 를 넣어 내려받아 주세요.';
    });
  }

  Future<void> _install() async {
    final app = context.appRead;
    final r = release;
    // 안드로이드는 앱 안에서 설치하지 않는다(서명이 달라 덮어쓰기가 거부되고, 앱을 지우면 금고도 지워짐).
    if (r == null || _android) return;
    final asset = r.assetFor(app.services.installer.os);
    if (asset == null) {
      setState(() {
        kind = StatusKind.caution;
        message = '이 기기용 설치 파일이 아직 없어요. 다음 버전을 기다려 주세요.';
      });
      return;
    }
    final ok = await confirmDialog(
      context,
      title: '새 버전 설치',
      message:
          '설치 전에 꼭 확인해 주세요:\n'
          '• 복구 코드가 종이에 적혀 있나요?\n'
          '• 컴퓨터에서는 설치가 덮어쓰기예요. 금고는 사용자 자료 폴더에 그대로 남고 같은 마스터 비밀번호로 열려요.\n\n'
          '지금 금고를 자동으로 백업한 뒤 내려받을게요.',
      confirmLabel: '백업하고 내려받기',
    );
    if (!ok || !mounted) return;
    setState(() {
      busy = true;
      progress = 0;
      message = '금고를 백업하는 중…';
      kind = StatusKind.progress;
    });
    try {
      await app.backupBeforeUpdate(r.version);
      if (!mounted) return;
      setState(() => message = '내려받는 중…');
      final dir = await app.services.installer.downloadDir();
      final file = await _checker.download(
        r,
        asset,
        dir,
        onProgress: (v) {
          if (mounted) setState(() => progress = v);
        },
      );
      if (!mounted) return;
      setState(() => message = '파일 확인 완료(해시 일치). 설치를 시작해요.');
      final msg = await app.services.installer.install(file);
      log.info('업데이트 설치 시작');
      if (mounted) {
        setState(() {
          kind = StatusKind.safe;
          message = msg;
        });
      }
    } on UpdateException catch (e) {
      log.warn('업데이트 실패(내려받기·해시): ${e.message}');
      if (mounted) {
        setState(() {
          kind = StatusKind.danger;
          message = e.message;
        });
      }
    } catch (e) {
      log.error('업데이트 실패', e);
      if (mounted) {
        setState(() {
          kind = StatusKind.danger;
          message = '업데이트하지 못했어요. 금고는 그대로예요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = Theme.of(context).textTheme;
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
                    Text('업데이트 확인', style: t.titleLarge),
                    Text(
                      '지금 버전 ${app.services.appVersion}',
                      style: t.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (message != null) ...[gap, StatusBadge(kind, message!)],
          if (progress != null) ...[
            gap,
            LinearProgressIndicator(value: progress, minHeight: 10),
          ],
          if (release != null && release!.notes.isNotEmpty) ...[
            gap,
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(AppTokens.s3),
              decoration: BoxDecoration(
                color: context.palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppTokens.radiusButton),
              ),
              child: SingleChildScrollView(
                child: Text(
                  release!.notes.split('### 파일 확인값').first.trim(),
                  style: t.bodyMedium,
                ),
              ),
            ),
          ],
          if (release != null && app.services.installer.os == 'android')
            ..._androidSteps(t)
          else ...[
            gap,
            if (busy)
              const Center(child: CircularProgressIndicator())
            else if (release != null)
              BigButton(
                label: '백업하고 내려받아 설치',
                icon: Icons.system_update_rounded,
                kind: ButtonKind.caution,
                onPressed: _install,
              )
            else
              BigButton(
                label: '새 버전 확인하기',
                icon: Icons.update_rounded,
                kind: ButtonKind.primary,
                onPressed: _check,
              ),
          ],
        ],
      ),
    );
  }

  /// 안드로이드 새 버전 순서와 버튼. 내려받기는 저장한 백업 파일을 확인한 뒤에만 열린다.
  List<Widget> _androidSteps(TextTheme t) => [
    gap,
    FlatCard(
      status: StatusKind.caution,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('안드로이드 새 버전 설치 순서', style: t.titleMedium),
          const SizedBox(height: 4),
          Text(
            '안드로이드는 앱을 삭제하면 금고도 함께 지워져요. '
            '앱을 삭제하기 전에 반드시 백업 파일을 앱 밖에 저장하고 확인하세요.',
            style: t.bodyLarge,
          ),
          gap,
          for (final s in androidUpdateSteps) ...[
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
        onPressed: _androidBackup,
      ),
      gap,
      BigButton(
        label: '② 저장한 백업 파일 확인',
        icon: Icons.fact_check_rounded,
        kind: backupMade ? ButtonKind.primary : ButtonKind.plain,
        onPressed: _androidVerify,
      ),
      gap,
      BigButton(
        label: '③ 새 버전 내려받기(브라우저)',
        icon: Icons.open_in_browser_rounded,
        kind: ButtonKind.caution,
        onPressed: backupCheck?.ok == true ? _androidDownload : null,
      ),
      if (backupCheck?.ok != true) ...[
        const SizedBox(height: 6),
        Text('백업 파일을 확인해야 내려받기 버튼이 켜져요.', style: t.bodyMedium),
      ],
    ],
  ];
}
