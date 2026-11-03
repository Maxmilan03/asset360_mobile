import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.purpleiq.asset360/apps", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "openAuthenticator":
          // Google Authenticator registers the otpauth:// scheme.
          guard let url = URL(string: "otpauth://"), UIApplication.shared.canOpenURL(url) else {
            result(false)
            return
          }
          UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
        case "openAppSettings":
          guard let url = URL(string: UIApplication.openSettingsURLString) else {
            result(false)
            return
          }
          UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
        case "openUrl":
          guard let args = call.arguments as? [String: Any], let raw = args["url"] as? String,
                let url = URL(string: raw) else {
            result(false)
            return
          }
          UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
        case "deviceInfo":
          var info = utsname()
          uname(&info)
          let model = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
          }
          result("Apple \(model) · iOS \(UIDevice.current.systemVersion)")
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
