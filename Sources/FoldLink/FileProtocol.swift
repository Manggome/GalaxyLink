import Foundation

struct PhoneFile: Identifiable {
    let name: String
    let folder: Bool
    var id: String { name }
}

enum FileProtocol {
    static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    static func listing(_ path: String) -> String {
        "cd " + quote(path) + " || exit; for f in .* *; do [ \"$f\" = . ] && continue; [ \"$f\" = .. ] && continue; [ -L \"$f\" ] && continue; if [ -d \"$f\" ]; then printf 'd\\000%s\\000' \"$f\"; elif [ -f \"$f\" ]; then printf 'f\\000%s\\000' \"$f\"; fi; done"
    }
    static func parse(_ text: String) -> [PhoneFile] {
        let fields = text.components(separatedBy: "\0")
        var result: [PhoneFile] = []
        for i in stride(from: 0, to: fields.count - 1, by: 2) {
            guard ["d", "f"].contains(fields[i]), !fields[i+1].isEmpty, !fields[i+1].contains("/"), ![".", ".."].contains(fields[i+1]) else { continue }
            result.append(PhoneFile(name: fields[i+1], folder: fields[i] == "d"))
        }
        return result.sorted { $0.folder != $1.folder ? $0.folder : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

