# 진행 상황 (PROGRESS)

> 작업 브랜치: `claude/festive-franklin-pns33l` (끝날 때마다 `main` 에도 병합)
> 이어서 하려면: "PROGRESS.md를 읽고 이어서 진행"

## 개발 환경 준비 (새 세션이면)
```
curl -sS https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.9-stable.tar.xz | tar xJ -C /opt/sdk
apt-get install -y libgtk-3-dev libsecret-1-dev xvfb
export PATH=/opt/sdk/flutter/bin:$PATH
flutter test && flutter analyze && flutter build linux
```

## 완료
- 금고(암호화·잠금·복구 코드·생체 키·지연·손상 대비) + 테스트 12개 통과

## 다음
- 데이터 모델, 구독/만료 기능, 화면
