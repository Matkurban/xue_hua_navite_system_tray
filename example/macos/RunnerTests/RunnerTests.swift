import Cocoa
import FlutterMacOS
import XCTest

@testable import xue_hua_navite_system_tray

class RunnerTests: XCTestCase {

  func testGetCapabilities() {
    let messenger = MockBinaryMessenger()
    let channel = FlutterMethodChannel(
      name: "xue_hua_navite_system_tray",
      binaryMessenger: messenger
    )
    let plugin = XueHuaNaviteSystemTrayPlugin(channel: channel)

    let call = FlutterMethodCall(methodName: "getCapabilities", arguments: [:])

    let resultExpectation = expectation(description: "getCapabilities result block must be called.")
    plugin.handle(call) { result in
      let map = result as? [String: Any]
      XCTAssertNotNil(map)
      XCTAssertEqual(map?["platform"] as? String, "macos")
      XCTAssertEqual(map?["backendName"] as? String, "NSStatusItem")
      XCTAssertEqual(map?["supportsInlineTitle"] as? Bool, true)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}

private class MockBinaryMessenger: NSObject, FlutterBinaryMessenger {
  func send(onChannel channel: String, message: Data?) {}
  func send(
    onChannel channel: String,
    message: Data?,
    binaryReply callback: FlutterBinaryReply? = nil
  ) {}
  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
  ) -> FlutterBinaryMessengerConnection {
    return 0
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
