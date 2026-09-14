#!/usr/bin/env python3
"""Create a relocatable Apple Silicon .app staging folder for one-file sharing."""
from pathlib import Path
import subprocess, shutil, json, re, plistlib

ROOT = Path(__file__).resolve().parent.parent
STAGE = ROOT / '.build' / 'share-1.7'
APP = STAGE / 'FoldLink.app'
def run(*args):
    return subprocess.check_output([str(a) for a in args], text=True)
STAGE.mkdir(parents=True, exist_ok=True)
if APP.exists(): shutil.rmtree(APP)
shutil.copytree(ROOT / 'dist/FoldLink.app', APP)
BIN = APP / 'Contents/MacOS'
LIB = APP / 'Contents/Frameworks'
LIB.mkdir(exist_ok=True)
shutil.copy2('/opt/homebrew/bin/adb', BIN / 'adb')
licenses = APP / 'Contents/Resources/ThirdParty'
licenses.mkdir(exist_ok=True)
sources = APP / 'Contents/Resources/Sources'
if sources.exists(): shutil.rmtree(sources)
sources.mkdir()
for name in ['Sources', 'android-clipboard', 'scripts', 'vendor']:
    shutil.copytree(ROOT / name, sources / name)
shutil.copy2(ROOT / 'Package.swift', sources / 'Package.swift')
shutil.copy2(ROOT / 'README.md', sources / 'README.md')

def dependencies(file):
    return [line.strip().split(' (')[0] for line in run('otool','-L',file).splitlines()[1:] if ' (compatibility version' in line]

mapping = {}
canonical = {}
queue = [BIN / 'scrcpy-foldlink', BIN / 'adb']
recipes = set()
while queue:
    file = queue.pop()
    for path in dependencies(file):
        if not path.startswith('/opt/homebrew/'): continue
        original = Path(path).resolve()
        if original not in canonical:
            destination = LIB / original.name
            if destination.exists(): raise RuntimeError('Library name collision: ' + str(original))
            shutil.copy2(original, destination)
            canonical[original] = destination
            queue.append(original)
            parts = original.parts
            if 'Cellar' in parts:
                i = parts.index('Cellar')
                cellar = Path(*parts[:i+3])
                package = parts[i+1] + '-' + parts[i+2]
                if package not in recipes:
                    recipes.add(package)
                    folder = licenses / package
                    folder.mkdir(exist_ok=True)
                    for candidate in cellar.iterdir():
                        if candidate.is_file() and any(k in candidate.name.upper() for k in ['LICENSE','COPYING','NOTICE','AUTHORS']):
                            shutil.copy2(candidate, folder / candidate.name)
                    if (cellar / '.brew').exists(): shutil.copytree(cellar / '.brew', folder / 'homebrew-formula', dirs_exist_ok=True)
                    if (cellar / 'INSTALL_RECEIPT.json').exists(): shutil.copy2(cellar / 'INSTALL_RECEIPT.json', folder / 'INSTALL_RECEIPT.json')
        mapping[path] = canonical[original]

files = list(canonical.values()) + [BIN / 'scrcpy-foldlink', BIN / 'adb', BIN / 'FoldLink']
minimum = (13,0)
for file in files:
    # Remove stale signatures before changing load commands.
    subprocess.run(['codesign','--remove-signature',str(file)], capture_output=True)
    for old in dependencies(file):
        if old in mapping:
            prefix = '@loader_path/' if file.parent == LIB else '@executable_path/../Frameworks/'
            run('install_name_tool', '-change', old, prefix + mapping[old].name, file)
    if file.parent == LIB:
        run('install_name_tool','-id','@rpath/' + file.name,file)
    metadata = run('otool','-l',file)
    for value in re.findall(r'cmd LC_BUILD_VERSION\s+cmdsize \d+\s+platform \d+\s+minos ([\d.]+)',metadata):
        minimum = max(minimum, tuple(map(int,value.split('.'))))
    for old in dependencies(file):
        if old.startswith('/opt/homebrew/') or old.startswith('/Users/'):
            raise RuntimeError('Non-portable dependency: '+old)
    run('codesign','--force','--sign','-',file)

plist = APP / 'Contents/Info.plist'
info = plistlib.loads(plist.read_bytes())
info['LSMinimumSystemVersion'] = '.'.join(map(str,minimum))
plist.write_bytes(plistlib.dumps(info))
# ADB's bundled upstream notices.
for base in Path('/opt/homebrew/Caskroom/android-platform-tools').glob('*/platform-tools'):
    for name in ['NOTICE.txt','source.properties']:
        if (base/name).exists(): shutil.copy2(base/name, licenses/('adb-'+name))
(licenses/'libraries.json').write_text(json.dumps({str(k):str(v.relative_to(APP)) for k,v in canonical.items()},indent=2))
run('codesign','--force','--sign','-',APP)
run('codesign','--verify','--deep','--strict',APP)
link = STAGE / 'Applications'
if not link.exists(): link.symlink_to('/Applications')
readme = f'''Galaxy Link 1.7 — 팀 공유용

지원: Apple Silicon (M1/M2/M3/M4 등), macOS {info['LSMinimumSystemVersion']} 이상

1. FoldLink.app을 Applications 폴더로 드래그합니다.
2. 응용 프로그램에서 FoldLink를 실행합니다.
3. 휴대폰에서 개발자 옵션의 USB 디버깅 또는 무선 디버깅을 켜고 연결합니다.

Homebrew, scrcpy, ADB 별도 설치가 필요 없습니다.
이미지 붙여넣기 첫 사용 시 휴대폰에 이미지 도우미를 설치합니다.

Apple 공증/Developer ID 서명이 없는 내부 테스트 빌드입니다.
첫 실행이 차단되면 시스템 설정 → 개인정보 보호 및 보안에서 해당 앱의 ‘확인 없이 열기’를 사용하세요.
기기의 회사 보안 정책에 따라 실행이 제한될 수 있습니다.

맥 입력기 모드가 기본이며 Caps Lock으로 맥 한·영을 전환합니다.
Cmd/Ctrl+C,V,X 및 맥→휴대폰 이미지 붙여넣기를 지원합니다.
입력 문제 수정은 코드 테스트를 통과했으며 팀원 기기에서 실제 동작 확인이 필요합니다.

라이선스와 수정 소스: 앱 패키지의 Contents/Resources/ThirdParty 및 Sources
'''
(STAGE/'먼저 읽어주세요.txt').write_text(readme)
print('Staged:',APP)
print('Minimum macOS:',info['LSMinimumSystemVersion'])
print('Bundled libraries:',len(canonical))
