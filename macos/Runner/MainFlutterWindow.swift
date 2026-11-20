import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "gingaf/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      if call.method == "resize" {
        if let args = call.arguments as? [String: Any],
           let width = args["width"] as? Double,
           let height = args["height"] as? Double {
          self.setContentSize(NSSize(width: width, height: height))
        }
        result(nil)
      } else if call.method == "autoResize" {
        if !self.isZoomed, let screen = self.screen {
          let sw = screen.frame.width
          let sh = screen.frame.height
          let w = min(1280, sw - 60)
          let h = min(720, sh - 100)
          self.setContentSize(NSSize(width: w, height: h))
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
