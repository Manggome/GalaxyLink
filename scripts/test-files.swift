import Foundation
@main struct Tests {
 static func main() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let names = ["한글 사진.png", "quote'file.txt", "$(touch NOPE).txt", "line\nbreak.txt", ".hidden"]
  for name in names { try Data([0,255,13,10]).write(to: root.appendingPathComponent(name)) }
  let (code, result) = await Engine.run("/bin/sh", ["-c", FileProtocol.listing(root.path)])
  precondition(code == 0)
  precondition(Set(FileProtocol.parse(result).map(\.name)) == Set(names))
  precondition(!FileManager.default.fileExists(atPath: root.appendingPathComponent("NOPE").path))
  print("PASS: Korean, spaces, quotes, shell metacharacters, newlines and hidden filenames")
 }
}
