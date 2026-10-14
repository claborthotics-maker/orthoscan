import UIKit
import AVFoundation
import SceneKit
import simd
import CoreMotion

// MARK: - TrueDepthScanViewController
// Front-facing TrueDepth scanner optimized for foot & lower-limb orthotics capture.
// Accumulates 90 depth frames, median-fuses them, filters to foot range (15–60 cm),
// excludes floor/ceiling/background planes, builds a mesh, and exports binary STL.

class TrueDepthScanViewController: UIViewController {

    // MARK: Outlets / subviews
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var sceneView: SCNView!
    private var ovalGuideView: OvalGuideView!
    private var distanceBadge: UILabel!
    private var statusLabel: UILabel!
    private var progressRing: ProgressRingView!
    private var captureButton: UIButton!
    private var cancelButton: UIButton!
    private var submitButton: UIButton!
    private var rescanButton: UIButton!

    // MARK: AVFoundation
    private let session = AVCaptureSession()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let depthQueue = DispatchQueue(label: "com.clab.depth", qos: .userInteractive)

    // MARK: Capture state
    private enum ScanPhase { case idle, scanning, processing, preview }
    private var phase: ScanPhase = .idle

    private var depthFrames: [[[Float]]] = []
    private var calibration: AVCameraCalibrationData?
    private var depthWidth  = 0
    private var depthHeight = 0
    private let targetFrames = 90
    private var isAutoCapturing = false

    // MARK: Motion (stability check)
    private let motionManager = CMMotionManager()
    private var isStable = false

    // MARK: Result
    private var builtMeshNode: SCNNode?
    var onScanComplete: ((URL) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: Foot-specific depth constants (metres)
    private let minDepth: Float  = 0.15
    private let maxDepth: Float  = 0.60
    private let floorMargin: Float = 0.03

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildUI()
        configureCapture()
        startMotionMonitoring()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if phase == .idle { startPreviewSession() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
        motionManager.stopAccelerometerUpdates()
    }

    // MARK: - UI Construction
    private func buildUI() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        sceneView = SCNView(frame: view.bounds)
        sceneView.backgroundColor = UIColor(white: 0.08, alpha: 1)
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.isHidden = true
        view.addSubview(sceneView)

        ovalGuideView = OvalGuideView(frame: view.bounds)
        ovalGuideView.isUserInteractionEnabled = false
        view.addSubview(ovalGuideView)

        distanceBadge = UILabel()
        distanceBadge.font = .systemFont(ofSize: 15, weight: .semibold)
        distanceBadge.textAlignment = .center
        distanceBadge.layer.cornerRadius = 12
        distanceBadge.layer.masksToBounds = true
        distanceBadge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(distanceBadge)

        statusLabel = UILabel()
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        progressRing = ProgressRingView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        progressRing.center = view.center
        progressRing.isHidden = true
        view.addSubview(progressRing)

        cancelButton = makeButton(title: "Cancel", style: .secondary)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        captureButton = makeButton(title: "Scan Foot", style: .primary)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)

        submitButton = makeButton(title: "Save Scan", style: .confirm)
        submitButton.isHidden = true
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        rescanButton = makeButton(title: "Rescan", style: .secondary)
        rescanButton.isHidden = true
        rescanButton.addTarget(self, action: #selector(rescanTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [cancelButton, captureButton, submitButton, rescanButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            distanceBadge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            distanceBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            distanceBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            distanceBadge.heightAnchor.constraint(equalToConstant: 36),
            statusLabel.topAnchor.constraint(equalTo: distanceBadge.bottomAnchor, constant: 6),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.heightAnchor.constraint(equalToConstant: 52),
        ])

        updateDistanceBadge(text: "Position foot in frame", color: .systemGray)
        statusLabel.text = "Hold phone 20-40 cm above foot"
    }

    private func configureCapture() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showError("TrueDepth camera not available on this device.")
            return
        }
        session.addInput(input)
        depthOutput.isFilteringEnabled = true
        depthOutput.alwaysDiscardsLateDepthData = true
        guard session.canAddOutput(depthOutput) else { return }
        session.addOutput(depthOutput)
        depthOutput.setDelegate(self, callbackQueue: depthQueue)
        if let connection = depthOutput.connection(with: .depthData) {
            connection.isEnabled = true
        }
        session.commitConfiguration()
    }

    private func startPreviewSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    private func startMotionMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        var recentMags: [Double] = []
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            let mag = sqrt(d.acceleration.x*d.acceleration.x +
                           d.acceleration.y*d.acceleration.y +
                           d.acceleration.z*d.acceleration.z)
            recentMags.append(mag)
            if recentMags.count > 10 { recentMags.removeFirst() }
            let variance = recentMags.variance()
            self?.isStable = variance < 0.002
        }
    }

    @objc private func captureTapped() {
        guard phase == .idle else { return }
        phase = .scanning
        depthFrames = []
        isAutoCapturing = true
        captureButton.isEnabled = false
        progressRing.isHidden = false
        progressRing.setProgress(0)
        updateDistanceBadge(text: "Scanning...", color: .systemGreen)
        statusLabel.text = "Hold steady - \(targetFrames) frames"
    }

    @objc private func cancelTapped() {
        session.stopRunning()
        onCancel?()
        dismiss(animated: true)
    }

    @objc private func submitTapped() {
        guard let node = builtMeshNode, let geo = node.geometry else { return }
        statusLabel.text = "Saving..."
        submitButton.isEnabled = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let url = MeshBuilder.exportSTL(from: geo) {
                DispatchQueue.main.async { self.onScanComplete?(url); self.dismiss(animated: true) }
            } else {
                DispatchQueue.main.async { self.showError("Failed to export STL."); self.submitButton.isEnabled = true }
            }
        }
    }

    @objc private func rescanTapped() {
        builtMeshNode?.removeFromParentNode()
        builtMeshNode = nil
        sceneView.isHidden = true
        previewLayer.isHidden = false
        ovalGuideView.isHidden = false
        progressRing.isHidden = true
        progressRing.setProgress(0)
        submitButton.isHidden = true
        rescanButton.isHidden = true
        captureButton.isHidden = false
        cancelButton.isHidden = false
        captureButton.isEnabled = true
        phase = .idle
        depthFrames = []
        updateDistanceBadge(text: "Position foot in frame", color: .systemGray)
        statusLabel.text = "Hold phone 20-40 cm above foot"
        startPreviewSession()
    }

    private func processAccumulatedFrames() {
        phase = .processing
        DispatchQueue.main.async {
            self.statusLabel.text = "Building mesh..."
            self.updateDistanceBadge(text: "Processing", color: .systemOrange)
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let frames = self.depthFrames
            guard !frames.isEmpty, let cal = self.calibration else { return }
            let fused = Self.medianFuse(frames: frames, width: self.depthWidth, height: self.depthHeight)
            let points = Self.unproject(depth: fused, calibration: cal, minD: self.minDepth, maxD: self.maxDepth, floorMargin: self.floorMargin)
            guard points.count > 500 else {
                DispatchQueue.main.async { self.showError("Not enough foot geometry captured. Try again.") }
                self.phase = .idle
                return
            }
            guard let geometry = MeshBuilder.buildMesh(from: points) else {
                DispatchQueue.main.async { self.showError("Mesh build failed. Try again.") }
                self.phase = .idle
                return
            }
            DispatchQueue.main.async { self.showPreview(geometry: geometry) }
        }
    }

    private static func medianFuse(frames: [[[Float]]], width: Int, height: Int) -> [[Float]] {
        var result = Array(repeating: Array(repeating: Float(0), count: width), count: height)
        for row in 0..<height {
            for col in 0..<width {
                var vals = [Float]()
                vals.reserveCapacity(frames.count)
                for frame in frames { let v = frame[row][col]; if v > 0 { vals.append(v) } }
                if vals.isEmpty { continue }
                vals.sort()
                result[row][col] = vals[vals.count / 2]
            }
        }
        return result
    }

    private static func unproject(depth: [[Float]], calibration: AVCameraCalibrationData, minD: Float, maxD: Float, floorMargin: Float) -> [SIMD3<Float>] {
        let h = depth.count
        guard h > 0 else { return [] }
        let w = depth[0].count
        let intrinsics = calibration.intrinsicMatrix
        let refDims = calibration.intrinsicMatrixReferenceDimensions
        let scaleX = Float(w) / Float(refDims.width)
        let scaleY = Float(h) / Float(refDims.height)
        let fx = intrinsics[0][0] * scaleX
        let fy = intrinsics[1][1] * scaleY
        let cx = intrinsics[2][0] * scaleX
        let cy = intrinsics[2][1] * scaleY
        let colStart = Int(Float(w) * 0.10), colEnd = Int(Float(w) * 0.90)
        let rowStart = Int(Float(h) * 0.10), rowEnd = Int(Float(h) * 0.90)
        var points = [SIMD3<Float>]()
        points.reserveCapacity(w * h / 4)
        for row in Swift.stride(from: rowStart, to: rowEnd, by: 2) {
            for col in Swift.stride(from: colStart, to: colEnd, by: 2) {
                let z = depth[row][col]
                guard z >= minD, z <= maxD else { continue }
                let x = (Float(col) - cx) * z / fx
                let y = (Float(row) - cy) * z / fy
                points.append(SIMD3(x, y, z))
            }
        }
        if points.isEmpty { return points }
        let maxY = points.map { $0.y }.max()!
        points = points.filter { $0.y < (maxY - floorMargin) }
        return points
    }

    private func showPreview(geometry: SCNGeometry) {
        phase = .preview
        session.stopRunning()
        let scene = SCNScene()
        let node = SCNNode(geometry: geometry)
        let (min, max) = node.boundingBox
        let centre = SIMD3<Float>((min.x+max.x)/2, (min.y+max.y)/2, (min.z+max.z)/2)
        node.position = SCNVector3(-centre.x, -centre.y, -centre.z)
        scene.rootNode.addChildNode(node)
        builtMeshNode = node
        let camNode = SCNNode()
        camNode.camera = SCNCamera()
        camNode.position = SCNVector3(0, 0, 0.5)
        scene.rootNode.addChildNode(camNode)
        sceneView.scene = scene
        sceneView.pointOfView = camNode
        sceneView.isHidden = false
        previewLayer.isHidden = true
        ovalGuideView.isHidden = true
        progressRing.isHidden = true
        captureButton.isHidden = true
        cancelButton.isHidden = true
        submitButton.isHidden = false
        rescanButton.isHidden = false
        updateDistanceBadge(text: "Scan Ready", color: .systemGreen)
        statusLabel.text = "Rotate to inspect - Save or Rescan"
    }

    private func updateDistanceBadge(text: String, color: UIColor) {
        distanceBadge.text = text
        distanceBadge.backgroundColor = color.withAlphaComponent(0.85)
        distanceBadge.textColor = .white
    }

    private func showError(_ msg: String) {
        let alert = UIAlertController(title: "Scan Error", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.rescanTapped() })
        present(alert, animated: true)
    }

    private func makeButton(title: String, style: ButtonStyle) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.layer.cornerRadius = 12
        btn.layer.masksToBounds = true
        switch style {
        case .primary:   btn.backgroundColor = .systemBlue;  btn.setTitleColor(.white, for: .normal)
        case .secondary: btn.backgroundColor = UIColor(white: 0.2, alpha: 0.9); btn.setTitleColor(.white, for: .normal)
        case .confirm:   btn.backgroundColor = .systemGreen; btn.setTitleColor(.white, for: .normal)
        }
        return btn
    }

    private enum ButtonStyle { case primary, secondary, confirm }
}

extension TrueDepthScanViewController: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let pixelBuffer = converted.depthDataMap
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let floats = base.bindMemory(to: Float.self, capacity: w * h)
        let cx = w / 2, cy = h / 2, patch = 20
        var centre = [Float]()
        for row in (cy-patch)...(cy+patch) {
            for col in (cx-patch)...(cx+patch) {
                let v = floats[row * w + col]; if v > 0 { centre.append(v) }
            }
        }
        centre.sort()
        let medianDist = centre.isEmpty ? Float(0) : centre[centre.count / 2]
        DispatchQueue.main.async { [weak self] in self?.updateDistanceUI(metres: medianDist) }
        guard phase == .scanning, isAutoCapturing else { return }
        guard isStable else { return }
        guard converted.depthDataAccuracy == .absolute else { return }
        if calibration == nil { calibration = converted.cameraCalibrationData; depthWidth = w; depthHeight = h }
        var frame = Array(repeating: Array(repeating: Float(0), count: w), count: h)
        for row in 0..<h { for col in 0..<w { frame[row][col] = floats[row * w + col] } }
        depthFrames.append(frame)
        let count = depthFrames.count
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.progressRing.setProgress(Float(count) / Float(self.targetFrames))
            self.statusLabel.text = "Scanning... \(count)/\(self.targetFrames) frames"
            if count >= self.targetFrames { self.isAutoCapturing = false; self.processAccumulatedFrames() }
        }
    }

    private func updateDistanceUI(metres: Float) {
        guard phase == .idle || phase == .scanning else { return }
        if metres == 0 {
            updateDistanceBadge(text: "No foot detected", color: .systemGray)
            statusLabel.text = "Point camera at foot"
        } else if metres < minDepth {
            updateDistanceBadge(text: "Move back - too close", color: .systemRed)
            statusLabel.text = String(format: "%.0f cm (min 15 cm)", metres * 100)
        } else if metres > maxDepth {
            updateDistanceBadge(text: "Move closer", color: .systemOrange)
            statusLabel.text = String(format: "%.0f cm (max 60 cm)", metres * 100)
        } else {
            let cm = Int(metres * 100)
            if phase == .idle {
                updateDistanceBadge(text: "Good - \(cm) cm", color: .systemGreen)
                statusLabel.text = isStable ? "Tap Scan Foot to begin" : "Hold steady..."
            }
        }
    }
}

private extension Array where Element == Double {
    func variance() -> Double {
        guard count > 1 else { return 0 }
        let mean = reduce(0, +) / Double(count)
        return map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(count)
    }
}

private class OvalGuideView: UIView {
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        let ovalRect = CGRect(x: rect.width*0.10, y: rect.height*0.25, width: rect.width*0.80, height: rect.height*0.50)
        let path = UIBezierPath(ovalIn: ovalRect)
        let outer = UIBezierPath(rect: rect); outer.append(path); outer.usesEvenOddFillRule = true
        UIColor.black.withAlphaComponent(0.45).setFill(); outer.fill()
        UIColor.white.withAlphaComponent(0.9).setStroke(); path.lineWidth = 2.5; path.stroke()
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: UIColor.white.withAlphaComponent(0.7)]
        ("Align foot/ankle within oval" as NSString).draw(at: CGPoint(x: ovalRect.midX - 95, y: ovalRect.maxY + 8), withAttributes: attrs)
    }
}

private class ProgressRingView: UIView {
    private let trackLayer = CAShapeLayer()
    private let fillLayer  = CAShapeLayer()
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = .clear
        let r = min(frame.width, frame.height) / 2 - 6
        let centre = CGPoint(x: frame.width/2, y: frame.height/2)
        let path = UIBezierPath(arcCenter: centre, radius: r, startAngle: -.pi/2, endAngle: 3*.pi/2, clockwise: true)
        trackLayer.path = path.cgPath; trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.2).cgColor
        trackLayer.fillColor = UIColor.clear.cgColor; trackLayer.lineWidth = 5; layer.addSublayer(trackLayer)
        fillLayer.path = path.cgPath; fillLayer.strokeColor = UIColor.systemGreen.cgColor
        fillLayer.fillColor = UIColor.clear.cgColor; fillLayer.lineWidth = 5
        fillLayer.lineCap = .round; fillLayer.strokeEnd = 0; layer.addSublayer(fillLayer)
    }
    required init?(coder: NSCoder) { fatalError() }
    func setProgress(_ p: Float) { fillLayer.strokeEnd = CGFloat(p) }
}
