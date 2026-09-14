import AppKit
@main struct DragTests {
 @MainActor static func main() async throws {
  let serial = CommandLine.arguments[1]
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("FoldLink-test-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let name = root.lastPathComponent + " 한글 ' image.bin"
  let source = root.appendingPathComponent(name)
  let bytes = Data((0..<256000).map { UInt8($0 % 251) })
  try bytes.write(to: source)
  let browser = FileBrowser(); browser.serial = serial
  await browser.upload([source])
  precondition(browser.status.contains("1개 파일 전송 완료"), browser.status)
  let remote = browser.path + "/" + name
  let delegate = PhoneFilePromise(name: name, remote: remote, serial: serial)
  let provider = RetainedFilePromiseProvider(type: "public.data", owner: delegate)
  let target = root.appendingPathComponent("received.bin")
  let error: Error? = await withCheckedContinuation { continuation in
   delegate.filePromiseProvider(provider, writePromiseTo: target) { continuation.resume(returning: $0) }
  }
  if let error { throw error }
  let received = try Data(contentsOf: target)
  precondition(received == bytes)
  let duplicate: Error? = await withCheckedContinuation { continuation in
   delegate.filePromiseProvider(provider, writePromiseTo: target) { continuation.resume(returning: $0) }
  }
  precondition(duplicate != nil)
  let unchanged = try Data(contentsOf: target)
  precondition(unchanged == bytes)
  _ = await Engine.run(Engine.path("adb")!, ["-s", serial, "shell", "rm -f " + FileProtocol.quote(remote)])
  print("PASS: drag upload and Finder file promise roundtrip, Korean/quotes, overwrite protection")
 }
}
