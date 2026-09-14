import SwiftUI

struct WirelessView: View {
    @ObservedObject var model: Model
    @Environment(\.dismiss) private var dismiss
    @State private var pairingAddress = ""
    @State private var pairingCode = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("갤럭시 무선 연결", systemImage: "wifi").font(.title2.bold())
                Spacer()
                Button("완료") { dismiss() }.disabled(model.wirelessBusy)
            }
            Text("맥과 갤럭시를 같은 Wi-Fi에 연결하세요. 휴대폰의 설정 → 개발자 옵션 → 무선 디버깅을 켜고, 해당 메뉴를 여세요.")
                .font(.callout).foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("01  처음 한 번 · 기기 페어링").font(.headline)
                    Text("휴대폰에서 ‘페어링 코드로 기기 페어링’을 누르세요. 그 창에 표시된 주소와 코드를 입력하세요.").font(.caption).foregroundStyle(.secondary)
                    TextField("페어링 주소 · 예: 192.168.0.12:37123", text: $pairingAddress)
                        .accessibilityLabel("페어링 IP와 포트")
                    SecureField("6자리 페어링 코드", text: $pairingCode)
                    Button("페어링") {
                        let code = pairingCode
                        pairingCode = ""
                        Task { await model.pair(address: pairingAddress, code: code) }
                    }.disabled(Wireless.endpoint(pairingAddress) == nil || !Wireless.validCode(pairingCode))
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("02  Wi-Fi 연결").font(.headline)
                    Text("페어링 창을 닫고 무선 디버깅 첫 화면의 ‘IP 주소 및 포트’를 입력하세요. 위의 페어링 포트와 다릅니다.").font(.caption).foregroundStyle(.secondary)
                    TextField("연결 주소 · 예: 192.168.0.12:40567", text: $model.connectionAddress)
                        .accessibilityLabel("연결 IP와 포트")
                    Button("무선 연결") { Task { await model.connectWireless() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(Wireless.endpoint(model.connectionAddress) == nil)
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .top, spacing: 10) {
                if model.wirelessBusy { ProgressView().controlSize(.small) }
                Text(model.wirelessStatus).font(.callout).textSelection(.enabled)
            }.frame(minHeight: 44, alignment: .top)
            Text("다음부터는 페어링 없이 02번부터 진행하면 됩니다. 연결 포트는 바뀔 수 있어 휴대폰에서 현재 값을 확인하세요.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(26).frame(width: 520).textFieldStyle(.roundedBorder)
            .disabled(model.wirelessBusy).interactiveDismissDisabled(model.wirelessBusy)
            .onDisappear { pairingCode = "" }
    }
}
