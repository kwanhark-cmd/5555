import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/services.dart';
import '../../core/log/app_logger.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';

/// 백업 파일 만들기·저장 확인·복원을 여러 화면(백업·업데이트·첫 화면·잠금 화면)이 함께 쓴다.
/// 안드로이드는 앱을 지우면 금고도 지워지므로, 앱 밖에 저장한 백업 파일이 유일한 사본이 된다.

/// 안드로이드에서 앱을 지우기 전에 보여 주는 경고(백업 화면·업데이트 카드).
const androidDeleteWarning =
    '안드로이드는 앱을 삭제하면 금고도 함께 지워져요. '
    '새 버전을 설치하기 전에 백업 파일을 앱 밖(드라이브·내 파일·컴퓨터)에 저장하고 '
    '"저장한 백업 파일 확인"으로 꼭 확인하세요.';

/// 백업 파일 이름(날짜만, 개인 정보 없음).
String backupFileName(DateTime d) =>
    '금고백업-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}.vaultbackup';

/// 백업 파일을 만들어 저장한다(컴퓨터: 저장 위치 고르기, 안드로이드: 공유 창).
/// 저장 위치 설명을 돌려준다(취소면 null). 실패하면 예외.
Future<String?> saveBackupFile(AppController app) async {
  final json = await app.exportBackup();
  final where = await app.services.files.saveText(
    backupFileName(app.now()),
    json,
  );
  log.info(where == null ? '백업 저장 취소' : '백업 내보냄');
  return where;
}

/// 저장 결과를 사용자에게 보여 줄 말. 공유 창은 저장됐는지 알 수 없으므로 확인을 시킨다.
String backupSavedMessage(String? where) {
  if (where == null) return '저장을 취소했어요.';
  if (where == sharedLocation) {
    return '백업 파일을 보냈어요. 드라이브·내 파일 등에 저장됐는지 "저장한 백업 파일 확인"으로 꼭 확인해 주세요.';
  }
  return '백업을 저장했어요. 마스터 비밀번호가 있어야 열 수 있어요.';
}

/// 앱 밖에 저장한 백업 파일을 다시 골라 확인한다. 고르기를 취소하면 null.
Future<SavedBackupCheck?> pickAndCheckSavedBackup(AppController app) async {
  final text = await app.services.files.openText(extensions: backupExtensions);
  if (text == null) return null;
  return app.checkSavedBackup(text);
}

/// 금고가 잠긴 상태(첫 화면·잠금 화면)에서 백업 파일로 복원한다.
/// 복원에 성공하면 [onRestored] 를 부른다. 실패는 여기서 안내한다(금고는 그대로).
Future<void> restoreFromBackupFile(
  BuildContext context, {
  required Future<void> Function() onRestored,
}) async {
  final app = context.appRead;
  Future<void> again() => context.mounted
      ? restoreFromBackupFile(context, onRestored: onRestored)
      : Future.value();
  final text = await app.services.files.openText(extensions: backupExtensions);
  if (text == null || !context.mounted) return;
  try {
    final info = await app.backups.inspect(text);
    if (!context.mounted) return;
    final pw = await showSafeDialog<String>(
      context,
      (ctx) => _BackupPasswordDialog(profileName: info.profileName),
    );
    if (pw == null || !context.mounted) return;
    if (!await app.backups.verifyPassword(info, pw, app.services.scratchDir)) {
      if (context.mounted) {
        await showErrorDialog(
          context,
          stage: FailStage.restore,
          message: '백업의 마스터 비밀번호가 맞지 않아요. 백업을 만들 때의 비밀번호를 넣어 주세요.',
          onRetry: again,
        );
      }
      return;
    }
    await app.backups.restore(info, app.services.appVersion);
    await app.reloadProfiles();
    log.info('잠긴 상태에서 백업 복원 완료');
    await onRestored();
  } on BackupException catch (e) {
    if (context.mounted) {
      await showErrorDialog(
        context,
        stage: FailStage.restore,
        message: e.message,
        nextActionLabel: '다른 파일 고르기',
        onNextAction: again,
      );
    }
  } catch (e) {
    log.error('복원 실패', e);
    if (context.mounted) {
      await showErrorDialog(
        context,
        stage: FailStage.restore,
        message: '복원하지 못했어요. 저장 공간을 확인해 주세요.',
        onRetry: again,
      );
    }
  }
}

/// 백업의 마스터 비밀번호 묻기. 입력 칸은 창이 완전히 닫힐 때 함께 정리된다.
class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.profileName});
  final String profileName;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('백업의 마스터 비밀번호'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('"${widget.profileName}" 백업을 만들 때의 마스터 비밀번호를 입력해 주세요.'),
          gap,
          BigField(
            controller: c,
            label: '마스터 비밀번호',
            obscure: true,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(context, v),
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
        onPressed: () => Navigator.pop(context),
      ),
      BigButton(
        label: '확인',
        expand: false,
        raised: false,
        onPressed: () => Navigator.pop(context, c.text),
      ),
    ],
  );
}
