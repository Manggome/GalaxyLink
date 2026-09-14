import SwiftUI
import AppKit

@MainActor final class FileBrowser: ObservableObject {
    @Published var path = "/sdcard/Download"
    @Published var files: [PhoneFile] = []
    @Published var selection: String?
    @Published var busy = false
    @Published var status = "기기를 선택하세요"
    @Published var serial = ""
    @Published var lastSaved: URL?
    private func run(_ args: [String], timeout: Double = 20) async -> (Int32, String) {
        guard let adb = Engine.path("adb"), !serial.isEmpty else { return (-1, "기기를 연결하세요") }
        return await Engine.run(adb, ["-s", serial] + args, timeoutSeconds: timeout)
    }
    func refresh() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        selection = nil
        let (code, output) = await run(["shell", FileProtocol.listing(path)])
        if code == 0 { files = FileProtocol.parse(output); status = "\(files.count)개 항목 · 전송은 원본을 유지하는 복사 방식입니다" }
        else { files = []; status = "폴더 열기 실패: " + String(output.suffix(600)) }
    }
    func navigate(_ target: String) async { guard !busy else { return }; path = target; await refresh() }
    func upload() async {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        await upload(panel.urls)
    }
    func upload(_ urls: [URL]) async {
        guard !busy, !serial.isEmpty, !urls.isEmpty else { return }
        guard urls.allSatisfy({ (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }) else { status = "파일만 전송할 수 있습니다. 폴더는 압축 후 보내세요."; return }
        busy = true
        var successes = 0
        for file in urls {
            status = "보내는 중: \(file.lastPathComponent) (\(successes + 1)/\(urls.count))"
            let name = file.lastPathComponent
            let target = path + "/" + name
            // Reserve the exact final name with noclobber: never overwrite a phone file.
            let (reserve, _) = await run(["shell", "set -C; : > " + FileProtocol.quote(target)])
            guard reserve == 0 else { status = "전송 중단: 같은 이름이 있거나 폴더에 쓸 수 없습니다 — \(name)"; busy = false; return }
            let temp = path + "/.foldlink-" + UUID().uuidString + ".part"
            let (code, output) = await run(["push", file.path, temp], timeout: 3600)
            if code != 0 {
                _ = await run(["shell", "rm -f " + FileProtocol.quote(temp) + " " + FileProtocol.quote(target)])
                status = "전송 실패 (\(successes)개 완료): " + String(output.suffix(600)); busy = false; return
            }
            let (finish, error) = await run(["shell", "mv -f " + FileProtocol.quote(temp) + " " + FileProtocol.quote(target)])
            guard finish == 0 else { status = "전송 마무리 실패: " + error; busy = false; return }
            successes += 1
        }
        busy = false; await refresh(); status = "휴대폰으로 \(successes)개 파일 전송 완료"
    }
    func download() async {
        guard let file = files.first(where: { $0.id == selection }), !file.folder else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.prompt = "여기에 저장"; panel.message = "저장할 맥 폴더를 선택하세요. 같은 이름은 덮어쓰지 않습니다."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let target = destination.appendingPathComponent(file.name)
        guard !FileManager.default.fileExists(atPath: target.path) else { status = "같은 이름의 파일이 있습니다. 다른 저장 폴더를 선택하세요."; return }
        let staging = destination.appendingPathComponent(".foldlink-" + UUID().uuidString + ".part")
        busy = true; defer { busy = false; try? FileManager.default.removeItem(at: staging) }
        status = "가져오는 중: \(file.name)"
        let (code, output) = await run(["pull", path + "/" + file.name, staging.path], timeout: 3600)
        guard code == 0 else { status = "전송 실패: " + String(output.suffix(600)); return }
        do { try FileManager.default.moveItem(at: staging, to: target); lastSaved = target; status = "맥에 저장 완료: \(file.name)" }
        catch { status = "저장 실패: " + error.localizedDescription }
    }
}

struct FilesView: View {
    @ObservedObject var model: Model
    var usbOnly = false
    @StateObject private var browser = FileBrowser()
    @Environment(\.dismiss) private var dismiss
    private var ready: [Device] { model.devices.filter { $0.ready && (!usbOnly || !$0.wireless) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Label("갤럭시 파일 전송", systemImage: "folder.badge.arrow.up").font(.title2.bold()); Spacer(); Button("닫기") { dismiss() }.disabled(browser.busy) }
            Picker("기기", selection: $browser.serial) {
                Text("선택하세요").tag("")
                ForEach(ready) { device in Text("\(device.wireless ? "Wi-Fi" : "USB") · \(device.name) · \(device.id)").tag(device.id) }
            }.disabled(browser.busy)
            HStack {
                ForEach([("저장소", "/sdcard"), ("다운로드", "/sdcard/Download"), ("사진", "/sdcard/DCIM"), ("그림", "/sdcard/Pictures")], id: \.1) { name, path in
                    Button(name) { Task { await browser.navigate(path) } }
                }
                Spacer()
                Button("상위 폴더") { Task { await browser.navigate((browser.path as NSString).deletingLastPathComponent) } }.disabled(browser.path == "/sdcard")
                Button { Task { await browser.refresh() } } label: { Image(systemName: "arrow.clockwise") }
            }.disabled(browser.busy || browser.serial.isEmpty)
            Text(browser.path).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            FileDragTable(browser: browser).frame(minHeight: 260)
            Text("Finder 파일을 목록에 놓으면 보내기 · 휴대폰 파일을 Finder로 끌면 저장").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("맥 → 휴대폰 보내기…") { Task { await browser.upload() } }
                    .disabled(browser.busy || browser.serial.isEmpty)
                Button("선택 파일 → 맥 저장…") { Task { await browser.download() } }
                    .disabled(browser.busy || !browser.files.contains { $0.id == browser.selection && !$0.folder })
                Spacer()
                if let saved = browser.lastSaved { Button("Finder에서 보기") { NSWorkspace.shared.activateFileViewerSelecting([saved]) } }
            }
            HStack { if browser.busy { ProgressView().controlSize(.small) }; Text(browser.status).font(.callout).textSelection(.enabled) }.frame(minHeight: 40)
            Text("USB 디버깅을 허용하면 사용할 수 있습니다. 공유 저장소의 파일을 전송하며, 앱 전용 보호 폴더는 접근할 수 없습니다. 폴더 전체 전송은 지원하지 않습니다.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 740, height: 580)
            .interactiveDismissDisabled(browser.busy)
            .onChange(of: browser.serial) { _ in Task { await browser.navigate("/sdcard/Download") } }
            .onAppear { browser.serial = ready.first(where: { !$0.wireless })?.id ?? ready.first?.id ?? "" }
    }
}
