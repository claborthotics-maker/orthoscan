import UIKit
import ARKit

class ScanViewController: UIViewController, ARSessionDelegate {
    
    var arView: UIView!
    var meshAnchors: [ARAnchor] = []
    var onScanComplete: ((String?) -> Void)?
    var scanType: String = "directFoot"
    var session: ARSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            setupARSession()
        } else {
            showLiDARUnavailable()
        }
        setupUI()
    }
    
    func showLiDARUnavailable() {
        let label = UILabel()
        label.text = "LiDAR not available on this device"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }
    
    func setupARSession() {
        session = ARSession()
        session?.delegate = self
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .automatic
        session?.run(config)
    }
    
    func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = scanType == "directFoot" ? "Scan Direct Foot" : "Scan Impression Box"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture Scan", for: .normal)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.backgroundColor = UIColor(red: 0.06, green: 0.20, blue: 0.38, alpha: 1.0)
        captureButton.layer.cornerRadius = 25
        captureButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureScan), for: .touchUpInside)
        view.addSubview(captureButton)
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelScan), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 200),
            captureButton.heightAnchor.constraint(equalToConstant: 50),
            cancelButton.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -16),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
                    meshAnchors[index] = meshAnchor
                }
            }
        }
    }
    
    @objc func captureScan() {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            exportToSTL()
        } else {
            onScanComplete?(nil)
            dismiss(animated: true)
        }
    }
    
    @objc func cancelScan() {
        session?.pause()
        onScanComplete?(nil)
        dismiss(animated: true)
    }
    
    func exportToSTL() {
        guard !meshAnchors.isEmpty else {
            showAlert("No scan data captured yet.")
            return
        }
        
        var stlData = Data()
        let header = String(repeating: " ", count: 80).data(using: .utf8)!
        stlData.append(header)
        
        var totalTriangles: UInt32 = 0
        var triangleData = Data()
        
        for anchor in meshAnchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            let geometry = meshAnchor.geometry
            let transform = meshAnchor.transform
            let vertexBuffer = geometry.vertices
            let faceBuffer = geometry.faces
            let vertexCount = vertexBuffer.count
            let faceCount = faceBuffer.count
            
            var vertices: [SIMD3<Float>] = []
            for i in 0..<vertexCount {
                let offset = i * vertexBuffer.stride
                let x = vertexBuffer.buffer.contents().load(fromByteOffset: offset + 0, as: Float.self)
                let y = vertexBuffer.buffer.contents().load(fromByteOffset: offset + 4, as: Float.self)
                let z = vertexBuffer.buffer.contents().load(fromByteOffset: offset + 8, as: Float.self)
                let localVertex = SIMD4<Float>(x, y, z, 1.0)
                let worldVertex = transform * localVertex
                vertices.append(SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z))
            }
            
            for i in 0..<faceCount {
                let offset = i * faceBuffer.bytesPerIndex * 3
                var idx0: UInt32 = 0
                var idx1: UInt32 = 0
                var idx2: UInt32 = 0
                if faceBuffer.bytesPerIndex == 2 {
                    idx0 = UInt32(faceBuffer.buffer.contents().load(fromByteOffset: offset, as: UInt16.self))
                    idx1 = UInt32(faceBuffer.buffer.contents().load(fromByteOffset: offset + 2, as: UInt16.self))
                    idx2 = UInt32(faceBuffer.buffer.contents().load(fromByteOffset: offset + 4, as: UInt16.self))
                } else {
                    idx0 = faceBuffer.buffer.contents().load(fromByteOffset: offset, as: UInt32.self)
                    idx1 = faceBuffer.buffer.contents().load(fromByteOffset: offset + 4, as: UInt32.self)
                    idx2 = faceBuffer.buffer.contents().load(fromByteOffset: offset + 8, as: UInt32.self)
                }
                guard Int(idx0) < vertices.count, Int(idx1) < vertices.count, Int(idx2) < vertices.count else { continue }
                let v0 = vertices[Int(idx0)]
                let v1 = vertices[Int(idx1)]
                let v2 = vertices[Int(idx2)]
                let edge1 = v1 - v0
                let edge2 = v2 - v0
                let normal = normalize(cross(edge1, edge2))
                var triangle = Data()
                triangle.append(contentsOf: withUnsafeBytes(of: normal.x) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: normal.y) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: normal.z) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v0.x) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v0.y) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v0.z) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v1.x) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v1.y) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v1.z) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v2.x) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v2.y) { Array($0) })
                triangle.append(contentsOf: withUnsafeBytes(of: v2.z) { Array($0) })
                triangle.append(contentsOf: [0x00, 0x00])
                triangleData.append(triangle)
                totalTriangles += 1
            }
        }
        
        var triangleCount = totalTriangles
        stlData.append(Data(bytes: &triangleCount, count: 4))
        stlData.append(triangleData)
        
        let fileName = "scan_\(Int(Date().timeIntervalSince1970)).stl"
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent(fileName)
        
        do {
            try stlData.write(to: fileURL)
            session?.pause()
            onScanComplete?(fileURL.path)
            dismiss(animated: true)
        } catch {
            showAlert("Failed to save scan: \(error.localizedDescription)")
        }
    }
    
    func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Scan", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
