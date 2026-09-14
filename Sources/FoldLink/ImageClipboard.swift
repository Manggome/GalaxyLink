import Foundation

enum ImageClipboard {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static func focusedPackage(_ output: String) -> String? {
        guard let line = output.split(separator: "\n").first(where: { $0.contains("mCurrentFocus=") }),
              let regex = try? NSRegularExpression(pattern: #"\s([a-zA-Z][a-zA-Z0-9_.]*)/"#),
              let match = regex.firstMatch(in: String(line), range: NSRange(location: 0, length: line.utf16.count)),
              let range = Range(match.range(at: 1), in: String(line)) else { return nil }
        return String(String(line)[range])
    }
    @MainActor static func paste(file: URL, serial: String, active: () -> Bool, progress: (String) -> Void) async throws -> String {
        guard let adb = Engine.path("adb"), active() else { throw Failure(message: "화면 연결을 확인하세요.") }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue > 0, size.intValue <= 25 * 1024 * 1024 else {
            throw Failure(message: "25MB 이하 이미지를 사용하세요.")
        }
        let id = String(file.deletingPathExtension().lastPathComponent)
        guard UUID(uuidString: id) != nil else { throw Failure(message: "이미지 식별자 오류") }
        func run(_ args: [String], input: URL? = nil, timeout: Double = 12) async -> (Int32, String) {
            await Engine.run(adb, ["-s", serial] + args, inputFile: input, timeoutSeconds: timeout)
        }
        let (_, before) = await run(["shell", "dumpsys", "window", "windows"])
        let target = focusedPackage(before)
        let (_, installed) = await run(["shell", "pm", "path", "local.foldlink.clipboard"])
        if !installed.contains("package:") {
            progress("처음 한 번 · 휴대폰 이미지 도우미 설치 중…")
            guard let apk = Bundle.main.url(forResource: "FoldLinkClipboard", withExtension: "apk") else { throw Failure(message: "이미지 도우미가 앱에 없습니다.") }
            let (code, output) = await run(["install", "-r", apk.path], timeout: 60)
            guard code == 0 && output.contains("Success") else { throw Failure(message: "도우미 설치가 거부됐습니다. 휴대폰의 설치 안내를 확인하세요.") }
        }
        guard active() else { throw Failure(message: "연결이 종료되었습니다.") }
        progress("이미지를 휴대폰으로 전송하는 중…")
        let uri = "content://local.foldlink.clipboard/images/" + id
        let (writeCode, writeOutput) = await run(["shell", "content", "write", "--uri", uri], input: file, timeout: 60)
        guard writeCode == 0 && !writeOutput.contains("Error") && !writeOutput.contains("Exception") else { throw Failure(message: "이미지 전송에 실패했습니다.") }
        guard active() else { throw Failure(message: "연결이 종료되었습니다.") }
        let (startCode, startOutput) = await run(["shell", "am", "start", "-W", "-n", "local.foldlink.clipboard/.PasteActivity", "--es", "id", id])
        guard startCode == 0 && !startOutput.contains("Error") && !startOutput.contains("Exception") else { throw Failure(message: "이미지 클립보드를 열지 못했습니다.") }
        var copied = false
        for _ in 0..<12 {
            let (_, output) = await run(["shell", "content", "query", "--uri", "content://local.foldlink.clipboard/status/" + id])
            if output.contains("copied=1") { copied = true; break }
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        guard copied else { throw Failure(message: "휴대폰의 잠금을 해제하고 다시 시도하세요.") }
        try await Task.sleep(nanoseconds: 300_000_000)
        let (_, after) = await run(["shell", "dumpsys", "window", "windows"])
        if active(), let target, focusedPackage(after) == target {
            let (code, _) = await run(["shell", "input", "keyevent", "279"])
            if code == 0 { return "이미지 붙여넣기 요청 완료 · 이미지 입력을 지원하는 앱에서 사용할 수 있습니다." }
        }
        return "이미지 복사 완료 · 휴대폰의 원하는 입력란에서 길게 눌러 붙여넣으세요."
    }
}
