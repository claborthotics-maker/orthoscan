import Flutter
import UIKit
import AVFoundation

public class ScanPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.orthotics.orthoscan/scan",
                                           binaryMessenger: registrar.messenger())
        let instance = ScanPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isLiDARAvailable":
            // TrueDepth front camera is what we use; "LiDAR" label kept for Flutter compatibility
            let available = AVCaptureDevice.default(.builtInTrueDepthCamera,
                                                    for: .video, position: .front) != nil &&
                            ARFaceTrackingConfiguration.isSupported
            result(available)

        case "startScan":
            let args      = call.arguments as? [String: Any]
            let patientId = args?["patientId"] as? String ?? ""
            let footSide  = args?["footSide"]  as? String ?? "left"
            presentScanner(patientId: patientId, footSide: footSide, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func presentScanner(patientId: String,
                                 footSide: String,
                                 result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow })?.rootViewController else {
                result(FlutterError(code: "NO_ROOT_VC",
                                    message: "Cannot find root view controller",
                                    details: nil))
                return
            }

            let scanVC = TrueDepthScanViewController()
            scanVC.footSide = footSide   // pre-set from Flutter; UI can override
            scanVC.onScanComplete = { fileURL in
                result(["filePath": fileURL.path,
                        "patientId": patientId,
                        "footSide": footSide])
            }
            scanVC.onCancel = {
                result(FlutterError(code: "CANCELLED",
                                    message: "User cancelled scan",
                                    details: nil))
            }
            scanVC.modalPresentationStyle = .fullScreen
            rootVC.present(scanVC, animated: true)
        }
    }
}
