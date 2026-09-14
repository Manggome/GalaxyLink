import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var model: Model?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { MainActor.assumeIsolated { Self.model?.stop() } }
}

@main struct FoldLinkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = Model()
    var body: some Scene {
        WindowGroup("Galaxy Link") {
            ContentView(model: model).onAppear { AppDelegate.model = model }
        }.defaultSize(width: 850, height: 660)
    }
}

struct ContentView: View {
    @ObservedObject var model: Model
    @State private var showLogs = false
    @State private var showWireless = false
    @State private var showFiles = false
    @State private var wireless = false
    private var visibleDevices: [Device] { model.devices.filter { $0.wireless == wireless } }
    private func selectDevice() {
        guard !model.running else { return }
        if !visibleDevices.contains(where: { $0.id == model.selected }) {
            model.selected = visibleDevices.first(where: \.ready)?.id ?? visibleDevices.first?.id ?? ""
        }
    }
    private let mint = Color(red: 0.45, green: 0.91, blue: 0.75)
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    if let icon = NSImage(named: "AppIcon") { Image(nsImage: icon).resizable().frame(width: 40, height: 40) }
                    Text("Galaxy Link").font(.title2.bold())
                }
                Text("GALAXY × MAC").font(.caption.weight(.semibold)).tracking(3).foregroundStyle(mint)
                Text("갤럭시와 맥을\n하나의 작업 공간으로")
                    .font(.title2.bold()).lineSpacing(5)
                VStack(spacing: 10) {
                    connectionTab("무선 연결", detail: "같은 Wi-Fi에서 화면 연결", icon: "wifi", value: true)
                    connectionTab("유선 연결", detail: "USB로 화면 연결 · 파일 전송", icon: "cable.connector", value: false)
                }
                Spacer()
                Label("화면 · 키보드 · 클립보드", systemImage: "macbook.and.iphone")
                    .font(.caption).foregroundStyle(.secondary)
                Text("일반 갤럭시부터 폴더블까지\n화면 크기에 맞춰 자연스럽게 연결됩니다.")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(30).frame(width: 270).frame(maxHeight: .infinity).background(Color(red: 0.07, green: 0.12, blue: 0.14))
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(wireless ? "무선 연결" : "유선 연결").font(.title.bold())
                            Text(wireless ? "같은 Wi-Fi에서 케이블 없이 갤럭시를 사용하세요." : "USB 케이블로 갤럭시 화면과 파일을 연결하세요.").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Circle().fill(model.running ? mint : .gray).frame(width: 9, height: 9)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("연결된 기기", systemImage: "iphone").font(.headline)
                            Spacer()
                            Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                                .disabled(model.scanning).help("기기 다시 검색")
                        }
                        if visibleDevices.isEmpty {
                            Text("아직 연결된 기기가 없습니다").foregroundStyle(.secondary).padding(.vertical, 8)
                        } else {
                            Picker("기기", selection: $model.selected) {
                                ForEach(visibleDevices) { device in Text("\(device.name) · \(device.id)").tag(device.id) }
                            }.labelsHidden().disabled(model.running)
                        }
                        Text(model.running ? model.status : (visibleDevices.first(where: { $0.id == model.selected })?.status ?? (wireless ? "Wi-Fi 연결 설정에서 갤럭시를 연결하세요" : "USB 케이블을 연결하고 휴대폰에서 디버깅을 허용하세요"))).font(.callout).foregroundStyle(model.running ? mint : .secondary)
                        if let frame = model.frame {
                            Text("전송 해상도  \(frame.width) × \(frame.height)").font(.system(.caption, design: .monospaced))
                        }
                    }.padding(18).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                    if wireless {
                        Button { showWireless = true } label: {
                            Label("Wi-Fi 연결 설정 / 페어링", systemImage: "wifi").frame(maxWidth: .infinity).padding(.vertical, 5)
                        }.disabled(model.running || !model.available)
                    } else {
                        GroupBox {
                            HStack(spacing: 16) {
                                Image(systemName: "folder.badge.arrow.up").font(.title2).foregroundStyle(mint)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("파일 전송").font(.headline)
                                    Text("Finder와 갤럭시 사이에서 파일을 끌어 옮기세요.").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("파일 열기") { showFiles = true }
                                    .disabled(!model.devices.contains { $0.ready && !$0.wireless })
                            }.padding(10)
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("화질", selection: $model.quality) {
                            Text("빠르게 · 1280").tag(1280)
                            Text("균형 · 1920").tag(1920)
                            Text("선명하게 · 2560").tag(2560)
                        }
                        Toggle("맥에서 휴대폰 소리 재생", isOn: $model.audio)
                        Toggle("맥 입력기 사용 · 한글 조합 입력 (권장)", isOn: $model.keyboard)
                        if model.keyboard {
                            Button(model.keyboardSetupBusy ? "입력기 준비 중…" : "한글 입력기 설치·설정") { Task { await model.prepareKeyboard() } }
                                .disabled(model.keyboardSetupBusy || model.selected.isEmpty)
                            Text(model.keyboardStatus).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Caps Lock → 맥 한·영 전환 · 한글은 입력기로 직접 전달\n폴더블 기기는 접기·펼치기 애니메이션 자동 적용")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(model.clipboardStatus).font(.caption).foregroundStyle(.secondary)
                        Text("이미지 첫 붙여넣기 시 휴대폰에 FoldLink 이미지 도우미를 설치합니다.").font(.caption2).foregroundStyle(.secondary)
                        Toggle("휴대폰 화면을 항상 맨 위에", isOn: $model.top)
                    }.disabled(model.running)
                    Button { model.running ? model.stop() : model.start() } label: {
                        Label(model.running ? "연결 종료" : "화면 연결", systemImage: model.running ? "stop.fill" : "play.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.buttonStyle(.borderedProminent).tint(mint).foregroundStyle(.black)
                        .disabled(!model.running && (!model.canStart || !visibleDevices.contains { $0.id == model.selected }))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("처음 연결하시나요?").font(.headline)
                        Text(wireless ? "1. 맥과 갤럭시를 같은 Wi-Fi에 연결하세요.\n2. 개발자 옵션에서 무선 디버깅을 켜세요.\n3. 위의 Wi-Fi 연결 설정에서 페어링과 연결을 진행하세요." : "1. 휴대폰 설정 → 휴대전화 정보 → 소프트웨어 정보에서 빌드번호를 7번 누르세요.\n2. 개발자 옵션에서 USB 디버깅을 켜세요.\n3. 데이터 전송이 가능한 USB 케이블로 연결하고, 휴대폰에 뜨는 디버깅 허용을 승인하세요.")
                            .font(.caption).foregroundStyle(.secondary).lineSpacing(5)
                        Text("한글은 맥 입력기로 조합한 뒤 휴대폰에 입력됩니다. 연결 중 입력 모드를 바꾸려면 종료 후 다시 연결하세요. 화면 제어 단축키는 오른쪽 Option 키를 사용합니다.")
                            .font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                    }
                    if !model.available { Text("필수 도구가 없습니다. 터미널에서 brew install scrcpy android-platform-tools 를 실행하세요.").font(.caption).foregroundStyle(.orange) }
                    DisclosureGroup("연결 기록", isExpanded: $showLogs) {
                        ScrollView { Text(model.logs.isEmpty ? "아직 기록이 없습니다." : model.logs).font(.system(size: 10, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 130)
                    }.font(.caption).foregroundStyle(.secondary)
                }.padding(28)
            }
        }.frame(minWidth: 820, minHeight: 680).preferredColorScheme(.dark)
            .sheet(isPresented: $showWireless) { WirelessView(model: model) }
            .sheet(isPresented: $showFiles) { FilesView(model: model, usbOnly: true) }
            .onChange(of: wireless) { selectDevice() }
            .task {
                while !Task.isCancelled {
                    await model.refresh()
                    selectDevice()
                    do { try await Task.sleep(nanoseconds: 3_000_000_000) } catch { break }
                }
            }
    }
    private func connectionTab(_ title: String, detail: String, icon: String, value: Bool) -> some View {
        Button { wireless = value; selectDevice() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).frame(width: 25)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(wireless == value ? mint.opacity(0.18) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(wireless == value ? mint : .white)
        }.buttonStyle(.plain).disabled(model.running)
    }

}
