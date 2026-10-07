import UIKit
import RealityKit
import ARKit
import Accelerate

class ScanViewController: UIViewController, ARSessionDelegate {
    
    var arView: ARView!
    var onScanComplete: ((String?) -> Void)?
    var scanType: String = "directFoot"
    var isCapturing = false
    var capturedPoints: [SIMD3<Float>] = []
    var capturedNormals: [SIMD3<Float>] = []
    var statusLabel: UILabel!
    var captureButton: UIButton!
    var pointCountLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupARView()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView.session.pause()
    }
    
    func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.session.delegate = self
        arView.debugOptions = [.showSceneUnderstanding]
        view.addSubview(arView)
    }
    
    func startSession() {
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .meshWithClassification
        config.environmentTexturing = .automatic
        config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = scanType == "directFoot" ? "Scan Direct Foot" : "Scan Impression Box"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        titleLabel.layer.cornerRadius = 8
        titleLabel.clipsToBounds = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        statusLabel = UILabel()
        statusLabel.text = "Hold device 1–2 ft from object and move slowly"
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 13)
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        pointCountLabel = UILabel()
        pointCountLabel.text = "Points: 0"
        pointCountLabel.textColor = UIColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1.0)
        pointCountLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        pointCountLabel.textAlignment = .center
        pointCountLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        pointCountLabel.layer.cornerRadius = 8
        pointCountLabel.clipsToBounds = true
        pointCountLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pointCountLabel)
        
        captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture Scan", for: .normal)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.backgroundColor = UIColor(red: 0.06, green: 0.20, blue: 0.38, alpha: 0.9)
        captureButton.layer.cornerRadius = 25
        captureButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureScan), for: .touchUpInside)
        view.addSubview(captureButton)
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        cancelButton.layer.cornerRadius = 16
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelScan), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            titleLabel.heightAnchor.constraint(equalToConstant: 44),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            pointCountLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            pointCountLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pointCountLabel.widthAnchor.constraint(equalToConstant: 160),
            pointCountLabel.heightAnchor.constraint(equalToConstant: 28),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 200),
            captureButton.heightAnchor.constraint(equalToConstant: 50),
            cancelButton.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -16),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 100),
            cancelButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthMap = frame.smoothedSceneDepth?.depthMap,
              let confidenceMap = frame.smoothedSceneDepth?.confidenceMap else { return }
        
        sampleDepthFrame(frame: frame, depthMap: depthMap, confidenceMap: confidenceMap)
    }
    
    func sampleDepthFrame(frame: ARFrame, depthMap: CVPixelBuffer, confidenceMap: CVPixelBuffer) {
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        let stride = 8 // sample every 8th pixel for performance
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
        }
        
        guard let depthPtr = CVPixelBufferGetBaseAddress(depthMap),
              let confPtr = CVPixelBufferGetBaseAddress(confidenceMap) else { return }
        
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let confBytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
        
        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        let cx = intrinsics[2][0]
        let cy = intrinsics[2][1]
        
        let cameraTransform = frame.camera.transform
        var newPoints: [SIMD3<Float>] = []
        
        for y in stride(from: 0, to: depthHeight, by: stride) {
            for x in stride(from: 0, to: depthWidth, by: stride) {
                let confOffset = y * confBytesPerRow + x
                let confidence = confPtr.load(fromByteOffset: confOffset, as: UInt8.self)
                guard confidence >= 2 else { continue } // high confidence only
                
                let depthOffset = y * depthBytesPerRow + x * 4
                let depth = depthPtr.load(fromByteOffset: depthOffset, as: Float.self)
                guard depth > 0.1 && depth < 2.0 else { continue } // 10cm to 2m
                
                // unproject to camera space
                let xCamera = (Float(x) - cx) * depth / fx
                let yCamera = (Float(y) - cy) * depth / fy
                let pointCamera = SIMD4<Float>(xCamera, -yCamera, -depth, 1.0)
                let pointWorld = cameraTransform * pointCamera
                
                newPoints.append(SIMD3<Float>(pointWorld.x, pointWorld.y, pointWorld.z))
            }
        }
        
        DispatchQueue.main.async {
            self.capturedPoints.append(contentsOf: newPoints)
            // keep point cloud manageable — deduplicate aggressively
            if self.capturedPoints.count > 500_000 {
                self.capturedPoints = Array(self.capturedPoints.suffix(500_000))
            }
            self.pointCountLabel.text = "Points: \(self.capturedPoints.count)"
            if self.capturedPoints.count > 50_000 {
                self.statusLabel.text = "Good coverage — tap Capture when ready"
                self.captureButton.backgroundColor = UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 0.9)
            }
        }
    }
    
    @objc func captureScan() {
        guard capturedPoints.count > 1000 else {
            showAlert("Not enough scan data yet. Move slowly around the object at 1–2 feet.")
            return
        }
        arView.session.pause()
        statusLabel.text = "Processing scan…"
        captureButton.isEnabled = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.exportToSTL()
        }
    }
    
    @objc func cancelScan() {
        arView.session.pause()
        onScanComplete?(nil)
        dismiss(animated: true)
    }
    
    func exportToSTL() {
        // Voxel downsample to reduce noise and duplicates
        let voxelSize: Float = 0.003 // 3mm voxels
        var voxelGrid: [SIMD3<Int>: SIMD3<Float>] = [:]
        
        for point in capturedPoints {
            let voxel = SIMD3<Int>(
                Int(point.x / voxelSize),
                Int(point.y / voxelSize),
                Int(point.z / voxelSize)
            )
            voxelGrid[voxel] = point
        }
        
        let cleanedPoints = Array(voxelGrid.values)
        
        // Write as PLY point cloud (more useful than STL for point data)
        var ply = "ply\nformat binary_little_endian 1.0\n"
        ply += "element vertex \(cleanedPoints.count)\n"
        ply += "property float x\nproperty float y\nproperty float z\n"
        ply += "end_header\n"
        
        var plyData = ply.data(using: .utf8)!
        for point in cleanedPoints {
            plyData.append(contentsOf: withUnsafeBytes(of: point.x) { Array($0) })
            plyData.append(contentsOf: withUnsafeBytes(of: point.y) { Array($0) })
            plyData.append(contentsOf: withUnsafeBytes(of: point.z) { Array($0) })
        }
        
        let fileName = "scan_\(Int(Date().timeIntervalSince1970)).ply"
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent(fileName)
        
        do {
            try plyData.write(to: fileURL)
            DispatchQueue.main.async {
                self.onScanComplete?(fileURL.path)
                self.dismiss(animated: true)
            }
        } catch {
            DispatchQueue.main.async {
                self.showAlert("Failed to save scan: \(error.localizedDescription)")
                self.captureButton.isEnabled = true
            }
        }
    }
    
    func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Scan", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}