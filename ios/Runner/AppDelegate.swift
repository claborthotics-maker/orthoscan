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
 
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
 
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return result
    }
 
    let scanChannel = FlutterMethodChannel(
      name: "com.orthotics.orthoscan/scan",
      binaryMessenger: controller.binaryMessenger
    )
 
    scanChannel.setMethodCallHandler { [weak self] call, flutterResult in
      switch call.method {
      case "isLiDARAvailable":
        let lidarAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        print("LiDAR supportsSceneReconstruction: \(lidarAvailable)")
        flutterResult(lidarAvailable)
      case "startScan":
        let args = call.arguments as? [String: Any]
        let scanType = args?["scanType"] as? String ?? "directFoot"
        self?.startScan(scanType: scanType, result: flutterResult)
      default:
        flutterResult(FlutterMethodNotImplemented)
      }
    }
 
    return result
  }
 
  func startScan(scanType: String, result: @escaping FlutterResult) {
    guard let rootVC = window?.rootViewController else {
      result(FlutterError(code: "NO_VC", message: "No root view controller", details: nil))
      return
    }
    let scanVC = ScanViewController()
    scanVC.scanType = scanType
    scanVC.modalPresentationStyle = .fullScreen
    scanVC.onScanComplete = { filePath in
      result(filePath)
    }
    rootVC.present(scanVC, animated: true)
  }
}