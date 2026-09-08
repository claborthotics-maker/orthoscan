import Flutter
import UIKit
import ARKit

class ScanPlugin: NSObject, FlutterPlugin {
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.orthotics.orthoscan/scan",
            binaryMessenger: registrar.messenger()
        )
        let instance = ScanPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isLiDARAvailable":
            result(ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh))
        case "startScan":
            let args = call.arguments as? [String: Any]
            let scanType = args?["scanType"] as? String ?? "directFoot"
            startScan(scanType: scanType, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func startScan(scanType: String, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let rootVC = UIApplication.shared.windows.first?.rootViewController else {
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
}
