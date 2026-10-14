import Flutter
import UIKit
import AVFoundation

public class ScanPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.orthotics.orthoscan/scan", binaryMessenger: registrar.messenger())
        let instance = ScanPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isLiDARAvailable":
            let available = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) != nil
            result(available)
        case "startScan":
            let args = call.arguments as? [String: Any]
            let patientId = args?["patientId"] as? String ?? ""
            presentScanner(patientId: patientId, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func presentScanner(patientId: String, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?.rootViewController else {
                result(FlutterError(code: "NO_ROOT_VC", message: "Cannot find root view controller", details: nil))
                return
            }
            let scanVC = TrueDepthScanViewController()
            scanVC.onScanComplete = { fileURL in
                result(["filePath": fileURL.path, "patientId": patientId])
            }
            scanVC.onCancel = {
                result(FlutterError(code: "CANCELLED", message: "User cancelled scan", details: nil))
            }
            scanVC.modalPresentationStyle = .fullScreen
            rootVC.present(scanVC, animated: true)
        }
    }
}
