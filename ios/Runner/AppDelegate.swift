import UIKit
import Flutter
import ARKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    ScanPlugin.register(with: self.registrar(forPlugin: "ScanPlugin")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}