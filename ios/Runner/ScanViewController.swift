import UIKit
import ARKit
import SceneKit

class ScanViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    var sceneView: ARSCNView!
    var meshAnchors: [ARAnchor] = []
    var onScanComplete: ((String?) -> Void)?
    var scanType: String = "directFoot"
    var isScanning = false
    var captureButton: UIButton!
    var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupARView()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .automatic
        sceneView.session.run(config)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func setupARView() {
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.debugOptions = [.showSceneUnderstanding]
        view.addSubview(sceneView)
    }
    
    func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = scanType == "directFoot" ? "Scan Direct Foot" : "Scan Impression Box"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        titleLabel.layer.cornerRadius = 8
        titleLabel.clipsToBounds = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        statusLabel = UILabel()
        statusLabel.text = "Move slowly around the object to scan"
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
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
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
                DispatchQueue.main.async {
                    self.statusLabel.text = "Scanning… \(self.meshAnchors.count) mesh patches captured"
                }
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
        guard !meshAnchors.isEmpty else {
            showAlert("No scan data yet. Move the camera slowly around the object first.")
            return
        }
        exportToSTL()
    }
    
    @objc func cancelScan() {
        sceneView.session.pause()
        onScanComplete?(nil)
        dismiss(animated: true)
    }
    
    func exportToSTL() {
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
            sceneView.session.pause()
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