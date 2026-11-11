// ignore_for_file: avoid_print — 개발자용 점검 도구라 화면 출력이 목적
// 실제 Releases 를 앱의 업데이트 확인 코드로 읽어 보는 점검 도구.
import 'package:account_vault/logic/update_check.dart';

Future<void> main() async {
  final r = await UpdateChecker().latest();
  print('버전 ${r.version}, 해시 ${r.hashes.length}개');
  for (final os in ['android', 'windows', 'macos', 'linux']) {
    final a = r.assetFor(os);
    print('$os: ${a?.name} 해시=${a == null ? '-' : (r.hashes[a.name] != null)}');
  }
}
