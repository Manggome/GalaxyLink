import XCTest
#if SWIFT_PACKAGE
@testable import FoldLink
#endif
final class CoreTests: XCTestCase {
    func testDevicesAndAuthorization() {
        let devices = Device.parse("List of devices attached\nabc device product:x model:Galaxy_Fold transport_id:1\ndef unauthorized usb:1\nghi offline\n* daemon started successfully *\n")
        XCTAssertEqual(devices.count, 3)
        XCTAssertEqual(devices[0].name, "Galaxy Fold")
        XCTAssertTrue(devices[0].ready)
        XCTAssertFalse(devices[1].ready)
    }
    func testChangingFrameSizesAndRotation() {
        let frames = ["INFO: Texture: 840x1920", "INFO: Texture: 1920x1840", "INFO: Texture: 1840x1920", "INFO: Texture: 840x1920"].compactMap(FrameSize.parse)
        XCTAssertEqual(frames.count, 4)
        XCTAssertEqual(frames.first, frames.last)
        XCTAssertNotEqual(frames[0], frames[1])
        XCTAssertNil(FrameSize.parse("INFO: Texture: 0x0"))
        XCTAssertNil(FrameSize.parse("unrelated 1080x2400"))
    }
    func testMirroringDoesNotPinFoldGeometry() {
        let args = Engine.arguments(serial: "USB-123", quality: 1920, audio: false, keyboard: true, top: true)
        XCTAssertEqual(Array(args.prefix(2)), ["--serial", "USB-123"])
        XCTAssertTrue(args.contains("--no-audio"))
        XCTAssertTrue(args.contains("--keyboard=sdk"))
        XCTAssertTrue(args.contains("--prefer-text"))
        XCTAssertFalse(args.contains { $0.contains("crop") || $0.contains("orientation") || $0.contains("new-display") || $0.contains("window-width") })
    }
}
