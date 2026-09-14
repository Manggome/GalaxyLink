import AppKit
import SwiftUI

@MainActor final class Model: ObservableObject {
    @Published var devices: [Device] = []
    @Published var selected = ""
    @Published var status = "USB 케이블로 갤럭시를 연결하세요"
    @Published var logs = ""
    @Published var running = false
    @Published var scanning = false
    @Published var frame: FrameSize?
    @Published var quality = 1920
    @Published var audio = true
    @Published var keyboard = true
    @Published var keyboardSetupBusy = false
    @Published var keyboardStatus = "한글 입력은 휴대폰에서 Galaxy Link 입력기를 선택하세요."
    @Published var top = false
    @Published var wirelessBusy = false
    @Published var wirelessStatus = "같은 Wi-Fi에 연결하고 휴대폰의 무선 디버깅을 켜세요."
    @Published var connectionAddress = UserDefaults.standard.string(forKey: "wirelessAddress") ?? ""
    @Published var foldTransitions = 0
    @Published var clipboardStatus = "⌘C / ⌘V · Ctrl+C / V · 이미지 붙여넣기"
    private var clipboardBusy = false
    private var clipboardDirectory: URL?
    private var process: Process?
    private var reader: Task<Void, Never>?
    var available: Bool { Engine.path("scrcpy") != nil && Engine.path("adb") != nil }
    var canStart: Bool { available && !running && !wirelessBusy && !keyboardSetupBusy && devices.contains { $0.id == selected && $0.ready } }

    func pair(address: String, code: String) async {
        guard !wirelessBusy, !running, let adb = Engine.path("adb"),
              let endpoint = Wireless.endpoint(address), Wireless.validCode(code) else {
            wirelessStatus = "페어링 IP:포트와 숫자 6자리 코드를 확인하세요."; return
        }
        wirelessBusy = true; wirelessStatus = "휴대폰과 페어링 중…"
        defer { wirelessBusy = false }
        // Pass the one-time code on stdin; never put it in process arguments or logs.
        let (result, output) = await Engine.run(adb, ["pair", endpoint], input: code + "\n")
        if result == 0 && Wireless.succeeded(output, pairing: true) {
            wirelessStatus = "페어링 완료! 무선 디버깅 첫 화면의 연결 IP:포트를 입력하세요."
            append("무선 페어링 완료")
            await refresh()
        } else {
            wirelessStatus = "페어링 실패 · 코드 입력 창을 열어 둔 채 새 코드와 페어링 포트를 확인하세요."
            append("무선 페어링 실패 · 같은 Wi-Fi, 코드 유효 시간, 페어링 포트를 확인하세요.")
        }
    }

    func connectWireless() async {
        guard !wirelessBusy, !running, let adb = Engine.path("adb"), let endpoint = Wireless.endpoint(connectionAddress) else {
            wirelessStatus = "연결 주소를 IPv4:포트 형식으로 입력하세요."; return
        }
        wirelessBusy = true; wirelessStatus = "Wi-Fi로 연결 중…"
        defer { wirelessBusy = false }
        let (result, output) = await Engine.run(adb, ["connect", endpoint])
        if result == 0 && Wireless.succeeded(output.trimmingCharacters(in: .whitespacesAndNewlines), pairing: false) {
            connectionAddress = endpoint
            UserDefaults.standard.set(endpoint, forKey: "wirelessAddress")
            await refresh()
            selected = endpoint
            wirelessStatus = "무선 연결 완료 · 창을 닫고 ‘화면 연결’을 누르세요."
            append("Wi-Fi 기기 연결 완료")
        } else {
            wirelessStatus = "연결 실패 · 페어링 포트가 아닌 첫 화면의 연결 포트인지 확인하세요. Wi-Fi나 무선 디버깅을 다시 켰다면 포트가 바뀔 수 있습니다."
            append("무선 연결 실패: " + output)
        }
    }

    func refresh() async {
        guard !scanning else { return }; scanning = true
        defer { scanning = false }
        guard let adb = Engine.path("adb") else { status = "ADB가 없습니다. README의 설치 안내를 확인하세요."; return }
        let (code, output) = await Engine.run(adb, ["devices", "-l"])
        guard code == 0 else { if !running { status = "기기 검색 실패 · 연결 기록을 확인하세요" }; append(output); return }
        devices = Device.parse(output)
        if !devices.contains(where: { $0.id == selected }) { selected = devices.first(where: \.ready)?.id ?? devices.first?.id ?? "" }
        if !running { status = devices.first(where: { $0.id == selected })?.status ?? "USB 또는 Wi-Fi로 갤럭시를 연결하세요" }
    }
    func prepareKeyboard() async {
        guard !running, !keyboardSetupBusy, let adb = Engine.path("adb"),
              devices.contains(where: { $0.id == selected && $0.ready }),
              let apk = Bundle.main.url(forResource: "FoldLinkClipboard", withExtension: "apk") else { return }
        keyboardSetupBusy = true; defer { keyboardSetupBusy = false }
        let serial = selected
        keyboardStatus = "Galaxy Link 입력기 설치 중…"
        let (code, output) = await Engine.run(adb, ["-s", serial, "install", "--no-incremental", "-r", apk.path], timeoutSeconds: 60)
        guard code == 0 && output.contains("Success") else { keyboardStatus = "입력기 설치 실패 · 휴대폰 설치 허용 상태를 확인하세요."; return }
        _ = await Engine.run(adb, ["-s", serial, "shell", "am", "start", "-a", "android.settings.INPUT_METHOD_SETTINGS"])
        keyboardStatus = "휴대폰에서 Galaxy Link 입력기를 켜고 기본 키보드로 선택한 뒤 화면을 연결하세요. 입력기 하단에서 다른 키보드로 돌아갈 수 있습니다."
    }
    func start() {
        guard canStart else { return }
        let serial = selected
        keyboardSetupBusy = true
        Task {
            defer { keyboardSetupBusy = false }
            if keyboard, let adb = Engine.path("adb") {
                keyboardSetupBusy = true
                let (_, current) = await Engine.run(adb, ["-s", serial, "shell", "settings", "get", "secure", "default_input_method"])
                keyboardSetupBusy = false
                guard current.contains("local.foldlink.clipboard/") && current.contains("LinkInputMethod") else {
                    keyboardStatus = "한글 입력기 설치·설정을 누른 뒤 휴대폰에서 Galaxy Link 입력기를 선택하세요."
                    status = "한글 입력기 설정이 필요합니다"; return
                }
            }
            guard selected == serial else { return }
            keyboardSetupBusy = false
            launchMirror()
        }
    }
    private func launchMirror() {
        guard canStart, let executable = Engine.path("scrcpy") else { return }
        let p = Process(), pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = Engine.arguments(serial: selected, quality: quality, audio: audio, keyboard: keyboard, top: top)
        p.environment = Engine.environment
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FoldLink-clipboard-" + UUID().uuidString)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { status = "클립보드 임시 폴더 생성 실패"; return }
        clipboardDirectory = directory
        p.environment?["FOLDLINK_CLIPBOARD_DIR"] = directory.path
        p.standardOutput = pipe; p.standardError = pipe
        p.terminationHandler = { [weak self] ended in
            Task { @MainActor in
                guard let self, self.process === ended else { return }
                self.process = nil; self.running = false; self.frame = nil
                self.status = ended.terminationStatus == 0 ? "화면 연결이 종료되었습니다" : "연결이 끊겼습니다 · 휴대폰 잠금을 해제하고 다시 연결하세요"
            }
        }
        do {
            try p.run(); process = p; running = true; frame = nil
            status = "갤럭시 화면을 여는 중…"
            append("—— 화면 연결 시작 ——")
            reader = Task.detached { [weak self] in
                var pending = Data()
                while true {
                    let data = pipe.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    pending.append(data)
                    while let end = pending.firstIndex(of: 10) {
                        let line = String(decoding: pending[..<end], as: UTF8.self)
                        pending.removeSubrange(...end)
                        await self?.receive(line, from: p)
                    }
                }
                if !pending.isEmpty { await self?.receive(String(decoding: pending, as: UTF8.self), from: p) }
            }
        } catch { status = "실행 실패: \(error.localizedDescription)" }
    }
    private func receive(_ line: String, from p: Process) {
        guard process === p else { return }
        if line.hasPrefix("FOLDLINK_IMAGE_ERROR:") {
            clipboardStatus = String(line.dropFirst("FOLDLINK_IMAGE_ERROR:".count)); return
        }
        if line.hasPrefix("FOLDLINK_IMAGE:"), let directory = clipboardDirectory {
            let filename = String(line.dropFirst("FOLDLINK_IMAGE:".count))
            guard filename.hasSuffix(".png"), UUID(uuidString: String(filename.dropLast(4))) != nil else { return }
            let file = directory.appendingPathComponent(filename)
            if clipboardBusy { try? FileManager.default.removeItem(at: file); return }
            clipboardBusy = true
            let serial = selected
            Task {
                defer { clipboardBusy = false; try? FileManager.default.removeItem(at: file) }
                do {
                    let result = try await ImageClipboard.paste(file: file, serial: serial,
                        active: { self.process === p && p.isRunning },
                        progress: { self.clipboardStatus = $0 })
                    clipboardStatus = result
                } catch { clipboardStatus = "이미지 붙여넣기 실패: " + error.localizedDescription }
                append(clipboardStatus)
            }
            return
        }
        if line.contains("Galaxy Link input unavailable") {
            keyboardStatus = "휴대폰에서 Galaxy Link 입력기를 선택하고 입력란을 클릭하세요."
        }
        append(line)
        if let size = FrameSize.parse(line) {
            if let previous = frame, previous.expanded != size.expanded { foldTransitions += 1 }
            frame = size
            status = "화면 연결 중 · 화면 크기 자동 반영"
        }
    }
    func stop() {
        let old = process
        process = nil
        if let old, old.isRunning { old.terminate() }
        running = false; frame = nil; status = "화면 연결이 종료되었습니다"
    }
    func append(_ text: String) { logs = String((logs + text + "\n").suffix(16000)) }
}
