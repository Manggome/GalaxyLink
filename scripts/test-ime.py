#!/usr/bin/env python3
"""End-to-end Unicode regression on the disposable emulator only."""
import subprocess, socket, struct, time, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
ADB = '/opt/homebrew/bin/adb'
SERIAL = 'emulator-5554'
IME = 'local.foldlink.clipboard/.LinkInputMethod'
def adb(*args):
    return subprocess.check_output([ADB, '-s', SERIAL, *args], text=True).strip()
old = adb('shell', 'settings', 'get', 'secure', 'default_input_method')
server = None
port = None
try:
    print(adb('install', '--no-incremental', '-r', str(ROOT / '.build/clipboard/FoldLinkClipboard.apk')))
    for _ in range(30):
        if IME in adb('shell', 'ime', 'list', '-a', '-s'): break
        time.sleep(.2)
    assert IME in adb('shell', 'ime', 'list', '-a', '-s')
    adb('shell', 'am', 'force-stop', 'local.foldlink.clipboard')
    adb('shell', 'ime', 'enable', IME)
    print(adb('shell', 'ime', 'set', IME))
    time.sleep(2)
    print(adb('shell', 'ime', 'set', IME))
    adb('shell', 'am', 'start', '-W', '-n', 'local.foldlink.clipboard/.KeyboardTestActivity')
    time.sleep(1)
    assert IME == adb('shell', 'settings', 'get', 'secure', 'default_input_method'), adb('shell', 'settings', 'get', 'secure', 'default_input_method')
    adb('push', str(ROOT / '.build/server/scrcpy-server'), '/data/local/tmp/galaxylink-ime-test.jar')
    port = adb('forward', 'tcp:0', 'localabstract:scrcpy_71a8b001')
    server = subprocess.Popen([ADB, '-s', SERIAL, 'shell', 'CLASSPATH=/data/local/tmp/galaxylink-ime-test.jar', 'app_process', '/', 'com.genymobile.scrcpy.Server', '4.1', 'scid=71a8b001', 'tunnel_forward=true', 'video=false', 'audio=false', 'control=true', 'send_device_meta=false', 'send_dummy_byte=false'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    time.sleep(1)
    with socket.create_connection(('127.0.0.1', int(port)), timeout=5) as sock:
        expected = '한글 abc 연속입력 123 테스트가나다라마바사😀'
        started = time.monotonic()
        for c in expected:
            payload = c.encode()
            sock.sendall(b'\x01' + struct.pack('>I', len(payload)) + payload)
        # Physical Enter down/up, then immediately resume typing on the new line.
        for action in (0, 1):
            sock.sendall(b'\x00' + struct.pack('>BIII', action, 66, 0, 0))
        tail = '다음 줄 end'
        for c in tail:
            payload = c.encode()
            sock.sendall(b'\x01' + struct.pack('>I', len(payload)) + payload)
        expected += '\n' + tail
        result = ''
        for _ in range(40):
            result = adb('shell', 'content', 'query', '--uri', 'content://local.foldlink.clipboard/typing/00000000-0000-0000-0000-000000000000')
            if 'text=' + expected + ', clipboardChanges=0' in result: break
            time.sleep(.05)
        assert 'text=' + expected + ', clipboardChanges=0' in result, result
        print('PASS: real scrcpy control stream → IME; exact continuous Korean/emoji, no extra newline, no clipboard changes; %.2fs including adb verification' % (time.monotonic() - started))
finally:
    if server:
        server.terminate()
        try:
            output, _ = server.communicate(timeout=5)
            print(output.decode(errors="replace")[-2000:])
        except subprocess.TimeoutExpired: server.kill(); server.communicate()
    if port: adb('forward', '--remove', 'tcp:' + port)
    adb('shell', 'settings', 'put', 'secure', 'default_input_method', old)
    adb('shell', 'ime', 'disable', IME)
    adb('shell', 'am', 'force-stop', 'local.foldlink.clipboard')
    adb('shell', 'rm', '-f', '/data/local/tmp/galaxylink-ime-test.jar')
