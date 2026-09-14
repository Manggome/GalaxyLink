import Foundation

struct Device: Identifiable, Equatable {
    let id: String
    let state: String
    let name: String
    var ready: Bool { state == "device" }
    var wireless: Bool { id.contains(":") || id.contains("._adb-tls-connect.") }
    var status: String { ready ? (wireless ? "Wi-Fi · 연결 가능" : "USB · 연결 가능") : state == "unauthorized" ? "휴대폰에서 디버깅 허용 또는 무선 페어링 필요" : "오프라인 · USB 또는 Wi-Fi 연결을 확인하세요" }
    static func parse(_ text: String) -> [Device] {
        text.split(separator: "\n").compactMap { line in
            let fields = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard fields.count >= 2, ["device", "unauthorized", "offline"].contains(fields[1]) else { return nil }
            let model = fields.first(where: { $0.hasPrefix("model:") }).map { String($0.dropFirst(6)).replacingOccurrences(of: "_", with: " ") }
            return Device(id: fields[0], state: fields[1], name: model ?? "Galaxy / Android")
        }
    }
}

struct FrameSize: Equatable {
    let width: Int
    let height: Int
    var expanded: Bool { Double(min(width, height)) / Double(max(width, height)) > 0.68 }
    static func parse(_ line: String) -> FrameSize? {
        guard line.contains("Texture:"), let regex = try? NSRegularExpression(pattern: #"Texture:\s*(\d+)x(\d+)"#),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let wr = Range(match.range(at: 1), in: line), let hr = Range(match.range(at: 2), in: line),
              let w = Int(line[wr]), let h = Int(line[hr]), w > 0, h > 0 else { return nil }
        return FrameSize(width: w, height: h)
    }
}

enum Wireless {
    // Android's pairing screen displays IPv4:port. Require the explicit port,
    // because the secure pairing and connection endpoints are different.
    static func endpoint(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = value.split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count == 2, let port = Int(pieces[1]), (1...65535).contains(port),
              pieces[1].allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let octets = pieces[0].split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, octets.allSatisfy({ part in
            !part.isEmpty && part.count <= 3 && part.allSatisfy({ $0.isASCII && $0.isNumber }) && Int(part).map { (0...255).contains($0) } == true
        }) else { return nil }
        return value
    }
    static func validCode(_ code: String) -> Bool { code.count == 6 && code.allSatisfy { $0.isASCII && $0.isNumber } }
    static func succeeded(_ output: String, pairing: Bool) -> Bool {
        let text = output.lowercased()
        return pairing ? text.contains("successfully paired to") : (text.hasPrefix("connected to ") || text.hasPrefix("already connected to "))
    }
}

enum Engine {
    static func path(_ name: String) -> String? {
        if let executable = Bundle.main.executableURL {
            let bundled = executable.deletingLastPathComponent().appendingPathComponent(name == "scrcpy" ? "scrcpy-foldlink" : name).path
            if FileManager.default.isExecutableFile(atPath: bundled) { return bundled }
        }
        return ["/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/"].map { $0 + name }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["ADB"] = path("adb")
        if let resources = Bundle.main.resourceURL {
            let server = resources.appendingPathComponent("scrcpy-server").path
            if FileManager.default.fileExists(atPath: server) {
                env["SCRCPY_SERVER_PATH"] = server
                env["SCRCPY_ICON_DIR"] = resources.path
            }
        }
        return env
    }
    static func arguments(serial: String, quality: Int, audio: Bool, keyboard: Bool, top: Bool) -> [String] {
        var args = ["--serial", serial, "--window-title=FoldLink · Galaxy", "--display-id=0", "--max-size=\(quality)", "--max-fps=60", "--video-codec=h264", "--window-height=800", "--shortcut-mod=ralt"]
        if !audio { args.append("--no-audio") }
        if keyboard { args += ["--keyboard=sdk", "--prefer-text"] }
        else { args.append("--keyboard=uhid") }
        if top { args.append("--always-on-top") }
        // No crop, fixed capture orientation or virtual display: follow the real active screen.
        return args
    }
    static func run(_ executable: String, _ arguments: [String], input: String? = nil, inputFile: URL? = nil, timeoutSeconds: Double = 12) async -> (Int32, String) {
        await Task.detached {
            let p = Process(), pipe = Pipe()
            p.executableURL = URL(fileURLWithPath: executable)
            p.arguments = arguments; p.environment = environment
            p.standardOutput = pipe; p.standardError = pipe
            let stdin = Pipe()
            p.standardInput = stdin
            do {
                let file = try inputFile.map { try FileHandle(forReadingFrom: $0) }
                defer { try? file?.close() }
                if let file { p.standardInput = file }
                try p.run()
                if let input { stdin.fileHandleForWriting.write(Data(input.utf8)) }
                try? stdin.fileHandleForWriting.close()
                let timeout = DispatchWorkItem { if p.isRunning { p.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit(); timeout.cancel()
                return (p.terminationStatus, String(decoding: data, as: UTF8.self))
            } catch { return (-1, error.localizedDescription) }
        }.value
    }
}
