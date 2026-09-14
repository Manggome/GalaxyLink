import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Finder requests the file only once the drop destination is known.
final class PhoneFilePromise: NSObject, NSFilePromiseProviderDelegate {
    let name: String
    let remote: String
    let serial: String
    let queue = OperationQueue()
    init(name: String, remote: String, serial: String) {
        self.name = name; self.remote = remote; self.serial = serial
        super.init(); queue.maxConcurrentOperationCount = 1
    }
    func filePromiseProvider(_ provider: NSFilePromiseProvider, fileNameForType type: String) -> String { name }
    func operationQueue(for provider: NSFilePromiseProvider) -> OperationQueue { queue }
    func filePromiseProvider(_ provider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        Task {
            let stage = url.deletingLastPathComponent().appendingPathComponent(".foldlink-" + UUID().uuidString + ".part")
            defer { try? FileManager.default.removeItem(at: stage) }
            guard let adb = Engine.path("adb") else { completionHandler(NSError(domain: "FoldLink", code: 1, userInfo: [NSLocalizedDescriptionKey: "ADB를 찾을 수 없습니다."])); return }
            let (code, output) = await Engine.run(adb, ["-s", serial, "pull", remote, stage.path], timeoutSeconds: 3600)
            guard code == 0 else { completionHandler(NSError(domain: "FoldLink", code: Int(code), userInfo: [NSLocalizedDescriptionKey: "파일 전송 실패: " + String(output.suffix(500))])); return }
            do { try FileManager.default.moveItem(at: stage, to: url); completionHandler(nil) }
            catch { completionHandler(error) }
        }
    }
}

final class RetainedFilePromiseProvider: NSFilePromiseProvider {
    private let owner: PhoneFilePromise
    init(type: String, owner: PhoneFilePromise) {
        self.owner = owner
        super.init()
        fileType = type
        delegate = owner
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
}

struct FileDragTable: NSViewRepresentable {
    @ObservedObject var browser: FileBrowser
    func makeCoordinator() -> Coordinator { Coordinator(browser) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let table = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "파일 이름"; column.width = 650
        table.addTableColumn(column)
        table.delegate = context.coordinator; table.dataSource = context.coordinator
        table.allowsMultipleSelection = true; table.rowHeight = 30
        table.setDraggingSourceOperationMask(.copy, forLocal: false)
        table.registerForDraggedTypes([.fileURL])
        table.target = context.coordinator; table.doubleAction = #selector(Coordinator.openFolder(_:))
        scroll.documentView = table; scroll.hasVerticalScroller = true
        context.coordinator.table = table
        return scroll
    }
    func updateNSView(_ view: NSScrollView, context: Context) {
        context.coordinator.browser = browser
        let signature = browser.serial + browser.path + browser.files.map { $0.name + ($0.folder ? "/" : "") }.joined(separator: "\0")
        if signature != context.coordinator.signature {
            context.coordinator.signature = signature
            context.coordinator.table?.reloadData()
        }
    }
    @MainActor final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var browser: FileBrowser
        weak var table: NSTableView?
        var signature = ""
        init(_ browser: FileBrowser) { self.browser = browser }
        func numberOfRows(in tableView: NSTableView) -> Int { browser.files.count }
        func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
            let file = browser.files[row]
            let cell = NSTableCellView()
            let text = NSTextField(labelWithString: (file.folder ? "📁  " : "📄  ") + file.name)
            text.frame = NSRect(x: 8, y: 5, width: 650, height: 20)
            cell.addSubview(text); cell.textField = text
            return cell
        }
        func tableViewSelectionDidChange(_ notification: Notification) {
            let row = table?.selectedRow ?? -1
            browser.selection = row >= 0 && row < browser.files.count ? browser.files[row].name : nil
        }
        @objc func openFolder(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard !browser.busy, row >= 0, row < browser.files.count, browser.files[row].folder else { return }
            let path = browser.path + "/" + browser.files[row].name
            Task { await browser.navigate(path) }
        }
        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard !browser.busy, !browser.serial.isEmpty, row < browser.files.count else { return nil }
            let file = browser.files[row]
            guard !file.folder else { return nil }
            let delegate = PhoneFilePromise(name: file.name, remote: browser.path + "/" + file.name, serial: browser.serial)
            let type = UTType(filenameExtension: (file.name as NSString).pathExtension) ?? .data
            return RetainedFilePromiseProvider(type: type.identifier, owner: delegate)
        }
        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
            guard !browser.busy, !browser.serial.isEmpty, info.draggingSource as? NSTableView !== tableView else { return [] }
            guard info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) else { return [] }
            tableView.setDropRow(-1, dropOperation: .above)
            return .copy
        }
        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard !browser.busy, !browser.serial.isEmpty,
                let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else { return false }
            Task { await browser.upload(urls) }
            return true
        }
    }
}
