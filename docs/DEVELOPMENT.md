# 개발 안내

Galaxy Link는 SwiftUI 앱과 수정한 scrcpy 4.1, Android 입력·이미지 도우미로 구성됩니다. 예전 이름인 FoldLink가 내부 경로와 실행 파일명에 남아 있습니다. 업데이트 호환성을 위해 번들 식별자도 그대로 사용합니다.

## 준비할 것

현재 빌드 스크립트는 Apple Silicon 맥의 Homebrew 경로(`/opt/homebrew`)를 사용합니다.

- Xcode Command Line Tools
- Homebrew: `scrcpy`, `android-platform-tools`, `uv`, `pkgconf`, `openjdk`
- Android SDK: platform 35, build-tools 35.0.0

Android SDK의 기본 경로는 `~/Library/Android/sdk`입니다. 다른 곳에 설치했다면 `ANDROID_SDK_ROOT`를 지정하세요.

## 빌드

```sh
bash scripts/build.sh
```

결과는 `dist/FoldLink.app`에 생성됩니다. 이 앱은 로컬 Homebrew 라이브러리를 사용하므로 다른 맥에 전달할 때는 아래 패키징 과정도 필요합니다.

1.8부터 한글 입력에 수정한 Android 서버를 사용합니다. 클라이언트만 교체하거나 Homebrew의 원본 서버를 넣으면 새 입력 방식이 동작하지 않습니다. `build.sh`는 클라이언트, 서버, 도우미를 함께 빌드합니다.

## 공유용 DMG

```sh
python3 scripts/package-share.py
hdiutil create -volname "Galaxy Link" -srcfolder .build/share-1.8.1 -ov -format UDZO dist/GalaxyLink-1.8.1-AppleSilicon.dmg
```

패키징 스크립트는 ADB와 필요한 라이브러리, 도우미, 엔진 소스와 라이선스를 묶습니다. 현재 배포 대상은 Apple Silicon · macOS 26 이상입니다. 로컬 서명을 사용하며 Developer ID 서명이나 공증은 하지 않습니다.

`.build/`와 `dist/`는 Git에서 제외합니다. 도우미의 개발 서명 키는 `.build/clipboard/development.keystore`에 있습니다. 기존 도우미를 업데이트하려면 같은 키가 필요하므로 보관하되 저장소에는 올리지 마세요.

## 테스트

```sh
bash scripts/test.sh
bash scripts/test-video-window.sh
bash scripts/test-clipboard.sh
```

기기 목록과 연결 상태, 무선 주소 처리, 창 크기 전환, 복사·붙여넣기 경로 등을 확인합니다.

한글 입력 테스트는 별도로 실행합니다.

```sh
python3 scripts/test-ime.py
```

이 테스트는 `emulator-5554` 전용입니다. 도우미를 설치하고 테스트 중에만 입력기를 선택합니다. 실제 scrcpy 제어 소켓으로 한글·영문·공백·엔터를 보내고, 결과 문자열과 클립보드 변경 여부를 확인한 뒤 기존 입력기로 복원합니다.

삼성 노트 등 실제 앱에서의 입력, 폴더블 화면 전환과 터치 위치, 소리, 케이블 재연결은 실기기에서 따로 확인해야 합니다. 에뮬레이터 테스트 통과가 모든 갤럭시 앱의 동작을 보장하지는 않습니다.

## 입력과 클립보드

한글은 맥에서 조합한 뒤 휴대폰의 `Galaxy Link 입력기`로 보냅니다. 입력기는 `InputConnection.commitText()`를 사용하고, 엔터 같은 키도 같은 입력 연결로 전달해 순서를 맞춥니다. 일반 타이핑은 클립보드를 바꾸지 않습니다.

입력기는 편집 내용을 읽거나 저장하지 않고, 네트워크 권한도 사용하지 않습니다. 입력 요청을 받는 provider는 호출자 UID를 검사해 ADB shell/root만 허용합니다. 입력기 사용 설정은 사용자가 휴대폰에서 직접 합니다.

‘맥 입력기 사용’ 옵션을 끄면 기존 UHID 물리 키보드 모드를 사용합니다. 이 경우 휴대폰에서 키보드 배열을 설정해야 합니다.

텍스트 복사·붙여넣기는 양방향, 이미지 붙여넣기는 맥에서 휴대폰 방향을 지원합니다. 이미지 도우미는 사진 보관함이나 연락처 권한을 사용하지 않습니다. 이미지 저장소에 쓰는 작업은 ADB shell로 제한하고, 붙여넣는 앱에는 해당 이미지의 임시 읽기 권한만 줍니다.

이미지는 PNG 기준 최대 25MB입니다. 도우미에 저장된 이미지는 다음 전송 시 24시간이 지난 것을 정리합니다. 자동 붙여넣기는 전송 전후 같은 앱이 활성화된 경우에만 요청하며, 메시지를 자동 전송하지는 않습니다.

## 화면과 파일 전송

특정 모델의 해상도를 고정하지 않고 기본 디스플레이의 크기 변경을 따라갑니다. 접힘 센서 값을 읽는 방식은 아닙니다. 영상 창의 크기 전환은 0.36초이며, 전체 화면이나 ‘동작 줄이기’ 설정에서는 생략합니다.

파일 전송은 ADB로 공유 저장소에 접근합니다. 원본을 유지하고 기존 파일을 덮어쓰지 않으며, 한 파일당 최대 대기 시간은 1시간입니다. 연결이 끊기면 `.foldlink-*.part` 파일이나 예약한 빈 파일이 남을 수 있습니다.

## 아이콘과 엔진

- `Assets/AppIcon.png`: 아이콘 원본
- `Assets/AppIcon.icns`: macOS 아이콘
- `Assets/IconPrompt.md`: 이미지 생성 기록
- `scripts/icon.sh`: 크기별 아이콘 변환
- `vendor/scrcpy-4.1`: scrcpy 소스와 Apache-2.0 라이선스
- `vendor/FOLDLINK-CHANGES.md`: 엔진 수정 내역

공식 문서: [scrcpy](https://github.com/Genymobile/scrcpy), [Android 무선 디버깅](https://developer.android.com/tools/adb#connect-to-a-device-over-wi-fi).
