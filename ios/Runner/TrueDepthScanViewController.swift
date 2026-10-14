import UIKit
import AVFoundation
import SceneKit
import simd
import CoreMotion

// MARK: - TrueDepthScanViewController
// Front-facing TrueDepth scanner with Comb-style live coverage UX.
// Normal camera preview runs in background. A pixel grid overlay shows
// red = not yet captured, fades out as depth frames fill in each cell.

class TrueDepthScanViewController: UIViewController {

    // MARK: Outlets / subviews
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var coverageOverlay: UIImageView!          // Comb-style coverage map
    private var sceneView: SCNView!
    private var ovalGuideView: OvalGuideView!
    private var distanceBadge: UILabel!
    private var statusLabel: UILabel!
    private var captureButton: UIButton!
    private var cancelButton: UIButton!
    private var submitButton: UIButton!
    private var rescanButton: UIButton!

    // MARK: AVFoundation
    private let session = AVCaptureSession()
    private let depthOutput = AVCaptureDepthDataOutput()
    private var videoOutput: AVCaptureVideoDataOutput!
    private let depthQueue = DispatchQueue(label: "com.clab.depth", qos: .userInteractive)

    // MARK: Capture state
    private enum ScanPhase { case idle, scanning, processing, preview }
    private var phase: ScanPhase = .idle

    private var depthFrames: [[[Float]]] = []
    private var calibration: AVCameraCalibrationData?
    private var depthWidth  = 0
    private var depthHeight = 0
    private var isAutoCapturing = false

    // MARK: Coverage grid
    // Grid cells: coverageCols x coverageRows
    // Each cell tracks how many depth frames have contributed a valid pixel.
    private let coverageCols = 48
    private let coverageRows = 64
    private var coverageHits: [[Int]] = []      // [row][col] hit count
    private let coverageThreshold = 3           // hits needed to consider a cell "captured"
    private var coverageRenderTimer: Timer?
    private var lastCoverageUpdate: CFTimeInterval = 0

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
        resetCoverageGrid()
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
        coverageRenderTimer?.invalidate()
    }

    // MARK: - Coverage grid reset
    private func resetCoverageGrid() {
        coverageHits = Array(repeating: Array(repeating: 0, count: coverageCols),
                             count: coverageRows)
    }

    // MARK: - UI Construction
    private func buildUI() {
        // Camera preview (full screen, bottom layer)
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        // Comb-style coverage overlay (above camera, below guide)
        coverageOverlay = UIImageView(frame: view.bounds)
        coverageOverlay.contentMode = .scaleToFill
        coverageOverlay.isHidden = true
        coverageOverlay.isUserInteractionEnabled = false
        view.addSubview(coverageOverlay)

        // SceneKit 3D preview (hidden until mesh is ready)
        sceneView = SCNView(frame: view.bounds)
        sceneView.backgroundColor = UIColor(white: 0.08, alpha: 1)
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.isHidden = true
        view.addSubview(sceneView)

        // Oval foot-framing guide
        ovalGuideView = OvalGuideView(frame: view.bounds)
        ovalGuideView.isUserInteractionEnabled = false
        view.addSubview(ovalGuideView)

        // Distance badge (top centre)
        distanceBadge = UILabel()
        distanceBadge.font = .systemFont(ofSize: 15, weight: .semibold)
        distanceBadge.textAlignment = .center
        distanceBadge.layer.cornerRadius = 12
        distanceBadge.layer.masksToBounds = true
        distanceBadge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(distanceBadge)

        // Status label (below badge)
        statusLabel = UILabel()
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        // Cancel button (bottom left)
        cancelButton = makeButton(title: "Cancel", style: .secondary)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        // Capture button (bottom centre)
        captureButton = makeButton(title: "Scan Foot", style: .primary)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)

        // Submit button (hidden until preview)
        submitButton = makeButton(title: "Save Scan", style: .confirm)
        submitButton.isHidden = true
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        // Rescan button (hidden until preview)
        rescanButton = makeButton(title: "Rescan", style: .secondary)
        rescanButton.isHidden = true
        rescanButton.addTarget(self, action: #selector(rescanTapped), for: .touchUpInside)

        // Bottom button stack
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

    // MARK: - AVFoundation Setup
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

    // MARK: - Motion / Stability
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

    // MARK: - Capture Actions
    @objc private func captureTapped() {
        if phase == .idle {
            phase = .scanning
            depthFrames = []
            resetCoverageGrid()
            isAutoCapturing = true
            captureButton.setTitle("Stop Scan", for: .normal)
            captureButton.backgroundColor = UIColor.systemRed

            // Show the coverage overlay
            coverageOverlay.isHidden = false
            startCoverageRenderTimer()

            updateDistanceBadge(text: "Scanning...", color: .systemRed)
            statusLabel.text = "Move around the foot, tap Stop when done"

        } else if phase == .scanning {
            guard depthFrames.count >= 10 else {
                statusLabel.text = "Keep scanning - need more frames"
                return
            }
            isAutoCapturing = false
            coverageRenderTimer?.invalidate()
            coverageOverlay.isHidden = true
            captureButton.isEnabled = false
            processAccumulatedFrames()
        }
    }

    @objc private func cancelTapped() {
        session.stopRunning()
        coverageRenderTimer?.invalidate()
        onCancel?()
        dismiss(animated: true)
    }

    @objc private func submitTapped() {
        guard let node = builtMeshNode,
              let geo = node.geometry else { return }
        statusLabel.text = "Saving..."
        submitButton.isEnabled = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let url = MeshBuilder.exportSTL(from: geo) {
                DispatchQueue.main.async {
                    self.onScanComplete?(url)
                    self.dismiss(animated: true)
                }
            } else {
                DispatchQueue.main.async {
                    self.showError("Failed to export STL.")
                    self.submitButton.isEnabled = true
                }
            }
        }
    }

    @objc private func rescanTapped() {
        builtMeshNode?.removeFromParentNode()
        builtMeshNode = nil
        sceneView.isHidden = true
        previewLayer.isHidden = false
        ovalGuideView.isHidden = false
        coverageOverlay.isHidden = true
        coverageOverlay.image = nil
        submitButton.isHidden = true
        rescanButton.isHidden = true
        captureButton.isHidden = false
        captureButton.isEnabled = true
        captureButton.setTitle("Scan Foot", for: .normal)
        captureButton.backgroundColor = UIColor.systemBlue
        cancelButton.isHidden = false
        phase = .idle
        depthFrames = []
        resetCoverageGrid()
        updateDistanceBadge(text: "Position foot in frame", color: .systemGray)
        statusLabel.text = "Hold phone 20-40 cm above foot"
        startPreviewSession()
    }

    // MARK: - Coverage Overlay Rendering
    private func startCoverageRenderTimer() {
        coverageRenderTimer?.invalidate()
        coverageRenderTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] _ in
            self?.renderCoverageOverlay()
        }
    }

    private func renderCoverageOverlay() {
        let rows = coverageRows
        let cols = coverageCols
        let hits = coverageHits

        var pixels = [UInt8](repeating: 0, count: rows * cols * 4)
        for r in 0..<rows {
            for c in 0..<cols {
                let idx = (r * cols + c) * 4
                let hit = hits[r][c]
                if hit >= coverageThreshold {
                    pixels[idx]   = 0
                    pixels[idx+1] = 0
                    pixels[idx+2] = 0
                    pixels[idx+3] = 0
                } else {
                    let progress = Float(hit) / Float(coverageThreshold)
                    let alpha = UInt8(200 - Int(progress * 180))
                    pixels[idx]   = 220
                    pixels[idx+1] = 40
                    pixels[idx+2] = 40
                    pixels[idx+3] = alpha
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels,
                                  width: cols,
                                  height: rows,
                                  bitsPerComponent: 8,
                                  bytesPerRow: cols * 4,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cgImg = ctx.makeImage() else { return }

        let uiImg = UIImage(cgImage: cgImg)
        coverageOverlay.image = uiImg
    }

    // MARK: - Update coverage grid from a depth frame
    private func updateCoverageGrid(floats: UnsafePointer<Float>, w: Int, h: Int) {
        let rowStep = Float(h) / Float(coverageRows)
        let colStep = Float(w) / Float(coverageCols)

        for gr in 0..<coverageRows {
            for gc in 0..<coverageCols {
                let pr = Int(Float(gr) * rowStep + rowStep * 0.5)
                let pc = Int(Float(gc) * colStep + colStep * 0.5)
                let clampedRow = min(max(pr, 0), h-1)
                let clampedCol = min(max(pc, 0), w-1)
                let z = floats[clampedRow * w + clampedCol]
                if z >= minDepth && z <= maxDepth {
                    let r = gr, c = gc
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if self.coverageHits[r][c] < self.coverageThreshold + 1 {
                            self.coverageHits[r][c] += 1
                        }
                    }
                }
            }
        }
    }

    // MARK: - Frame Processing
    private func processAccumulatedFrames() {
        phase = .processing
        DispatchQueue.main.async {
            self.statusLabel.text = "Building mesh..."
            self.updateDistanceBadge(text: "Processing", color: .systemOrange)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let frames = self.depthFrames
            guard !frames.isEmpty,
                  let cal = self.calibration else { return }

            let fused = Self.medianFuse(frames: frames,
                                        width: self.depthWidth,
                                        height: self.depthHeight)

            let points = Self.unproject(depth: fused,
                                        calibration: cal,
                                        minD: self.minDepth,
                                        maxD: self.maxDepth,
                                        floorMargin: self.floorMargin)

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

            DispatchQueue.main.async {
                self.showPreview(geometry: geometry)
            }
        }
    }

    // MARK: - Median Fusion
    private static func medianFuse(frames: [[[Float]]], width: Int, height: Int) -> [[Float]] {
        var result = Array(repeating: Array(repeating: Float(0), count: width), count: height)
        for row in 0..<height {
            for col in 0..<width {
                var vals = [Float]()
                vals.reserveCapacity(frames.count)
                for frame in frames {
                    let v = frame[row][col]
                    if v > 0 { vals.append(v) }
                }
                if vals.isEmpty { continue }
                vals.sort()
                result[row][col] = vals[vals.count / 2]
            }
        }
        return result
    }

    // MARK: - Back-Projection
    private static func unproject(depth: [[Float]],
                                   calibration: AVCameraCalibrationData,
                                   minD: Float, maxD: Float,
                                   floorMargin: Float) -> [SIMD3<Float>] {
        let h = depth.count
        guard h > 0 else { return [] }
        let w = depth[0].count

        let intrinsics = calibration.intrinsicMatrix
        let refDims = calibration.intrinsicMatrixReferenceDimensions
        let scaleX = Float(w)  / Float(refDims.width)
        let scaleY = Float(h) / Float(refDims.height)
        let fx = intrinsics[0][0] * scaleX
        let fy = intrinsics[1][1] * scaleY
        let cx = intrinsics[2][0] * scaleX
        let cy = intrinsics[2][1] * scaleY

        let colStart = Int(Float(w) * 0.10)
        let colEnd   = Int(Float(w) * 0.90)
        let rowStart = Int(Float(h) * 0.10)
        let rowEnd   = Int(Float(h) * 0.90)

        var points = [SIMD3<Float>]()
        points.reserveCapacity(w * h / 4)

        for row in rowStart..<rowEnd {
            for col in colStart..<colEnd {
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

    // MARK: - Preview
    private func showPreview(geometry: SCNGeometry) {
        phase = .preview
        session.stopRunning()

        let scene = SCNScene()
        let node = SCNNode(geometry: geometry)

        let (bboxMin, bboxMax) = node.boundingBox
        let centreX = (bboxMin.x + bboxMax.x) / 2
        let centreY = (bboxMin.y + bboxMax.y) / 2
        let centreZ = (bboxMin.z + bboxMax.z) / 2
        node.position = SCNVector3(-centreX, -centreY, -centreZ)
        scene.rootNode.addChildNode(node)
        builtMeshNode = node

        let dimX = bboxMax.x - bboxMin.x
        let dimY = bboxMax.y - bboxMin.y
        let dimZ = bboxMax.z - bboxMin.z
        let maxDim = Swift.max(dimX, Swift.max(dimY, dimZ))
        let camDist = maxDim * 2.5

        let camNode = SCNNode()
        camNode.camera = SCNCamera()
        camNode.camera?.zNear = 0.001
        camNode.camera?.zFar  = 10.0
        camNode.position = SCNVector3(0, 0, camDist)
        scene.rootNode.addChildNode(camNode)

        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(0, camDist, camDist)
        scene.rootNode.addChildNode(lightNode)

        sceneView.scene = scene
        sceneView.pointOfView = camNode
        sceneView.autoenablesDefaultLighting = true
        sceneView.isHidden = false
        previewLayer.isHidden = true
        ovalGuideView.isHidden = true
        coverageOverlay.isHidden = true

        captureButton.isHidden = true
        cancelButton.isHidden = true
        submitButton.isHidden = false
        rescanButton.isHidden = false

        updateDistanceBadge(text: "Scan Ready", color: .systemGreen)
        statusLabel.text = "Rotate to inspect - Save or Rescan"
    }

    // MARK: - Helpers
    private func updateDistanceBadge(text: String, color: UIColor) {
        distanceBadge.text = text
        distanceBadge.backgroundColor = color.withAlphaComponent(0.85)
        distanceBadge.textColor = .white
    }

    private func showError(_ msg: String) {
        let alert = UIAlertController(title: "Scan Error", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.rescanTapped()
        })
        present(alert, animated: true)
    }

    private func makeButton(title: String, style: ButtonStyle) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.layer.cornerRadius = 12
        btn.layer.masksToBounds = true
        switch style {
        case .primary:
            btn.backgroundColor = UIColor.systemBlue
            btn.setTitleColor(.white, for: .normal)
        case .secondary:
            btn.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
            btn.setTitleColor(.white, for: .normal)
        case .confirm:
            btn.backgroundColor = UIColor.systemGreen
            btn.setTitleColor(.white, for: .normal)
        }
        return btn
    }

    private enum ButtonStyle { case primary, secondary, confirm }
}

// MARK: - AVCaptureDepthDataOutputDelegate
extension TrueDepthScanViewController: AVCaptureDepthDataOutputDelegate {

    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime,
                         connection: AVCaptureConnection) {

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
                let v = floats[row * w + col]
                if v > 0 { centre.append(v) }
            }
        }
        centre.sort()
        let medianDist = centre.isEmpty ? Float(0) : centre[centre.count / 2]

        DispatchQueue.main.async { [weak self] in
            self?.updateDistanceUI(metres: medianDist)
        }

        guard phase == .scanning, isAutoCapturing else { return }
        guard isStable else { return }
        guard converted.depthDataAccuracy == .absolute else { return }

        updateCoverageGrid(floats: floats, w: w, h: h)

        if calibration == nil {
            calibration = converted.cameraCalibrationData
            depthWidth  = w
            depthHeight = h
        }

        guard depthFrames.count < 300 else { return }

        var frame = Array(repeating: Array(repeating: Float(0), count: w), count: h)
        for row in 0..<h {
            for col in 0..<w {
                frame[row][col] = floats[row * w + col]
            }
        }
        depthFrames.append(frame)

        let count = depthFrames.count
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusLabel.text = "Scanning... \(count) frames captured"
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
                statusLabel.text = isStable ? "Tap 'Scan Foot' to begin" : "Hold steady..."
            }
        }
    }
}

// MARK: - Array variance helper
private extension Array where Element == Double {
    func variance() -> Double {
        guard count > 1 else { return 0 }
        let mean = reduce(0, +) / Double(count)
        return map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(count)
    }
}

// MARK: - OvalGuideView
private class OvalGuideView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let ovalRect = CGRect(x: rect.width * 0.10,
                              y: rect.height * 0.25,
                              width: rect.width * 0.80,
                              height: rect.height * 0.50)
        let path = UIBezierPath(ovalIn: ovalRect)

        let outer = UIBezierPath(rect: rect)
        outer.append(path)
        outer.usesEvenOddFillRule = true
        UIColor.black.withAlphaComponent(0.45).setFill()
        outer.fill()

        UIColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 2.5
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.7)
        ]
        ("Align foot/ankle within oval" as NSString)
            .draw(at: CGPoint(x: ovalRect.midX - 95, y: ovalRect.maxY + 8), withAttributes: attrs)
    }
}
