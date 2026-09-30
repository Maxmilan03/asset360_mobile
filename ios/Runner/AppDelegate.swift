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
        guard call.method == "openAuthenticator" else {
          result(FlutterMethodNotImplemented)
          return
        }
        // Google Authenticator registers the otpauth:// scheme.
        guard let url = URL(string: "otpauth://"), UIApplication.shared.canOpenURL(url) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
