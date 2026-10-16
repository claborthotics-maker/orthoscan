import UIKit
import ARKit
import SceneKit
import simd

// MARK: - TrueDepthScanViewController
// ARFaceTrackingConfiguration + isWorldTrackingEnabled = true
// Per-frame: unproject TrueDepth pixels → transform to world space → accumulate in voxel grid
// Live overlay: project world points back to screen every 10 frames as colored point cloud
// On Stop: run marching cubes on voxel grid → SCNGeometry preview → STL export

class TrueDepthScanViewController: UIViewController, ARSessionDelegate {

    // MARK: - Public callbacks
    var onScanComplete: ((URL) -> Void)?
    var onCancel:       (() -> Void)?
    var footSide: String = "left"   // "left" or "right", set by caller

    // MARK: - AR
    private let arSession = ARSession()
    private var arConfig: ARFaceTrackingConfiguration?

    // MARK: - World-space accumulation
    private let accumQueue = DispatchQueue(label: "com.clab.accum", qos: .userInteractive)
    private var worldPoints = [SIMD3<Float>]()          // accumulated world-space points
    private var voxelGrid   = VoxelGrid(cellSize: 0.002) // 2 mm cells
    private var frameCount  = 0
    private let maxFrames   = 350
    private var overlayUpdateCounter = 0

    // MARK: - Scan state
    private enum ScanPhase { case footSelection, idle, scanning, processing, preview }
    private var phase: ScanPhase = .footSelection

    // MARK: - Depth filter params
    private let minDepth: Float = 0.10
    private let maxDepth: Float = 0.45

    // MARK: - UI
    private var arSceneView: ARSCNView!
    private var overlayImageView: UIImageView!
    private var sceneView: SCNView!
    private var distanceBadge: UILabel!
    private var statusLabel: UILabel!
    private var frameCountLabel: UILabel!
    private var captureButton: UIButton!
    private var cancelButton: UIButton!
    private var submitButton: UIButton!
    private var rescanButton: UIButton!
    private var footSelectionView: UIView!

    // built mesh stored for export
    private var builtMeshNode: SCNNode?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Don't start AR until foot is selected
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSession.pause()
    }

    // MARK: - UI Construction

    private func buildUI() {
        // AR live camera view
        arSceneView = ARSCNView(frame: view.bounds)
        arSceneView.session = arSession
        arSceneView.automaticallyUpdatesLighting = true
        arSceneView.scene = SCNScene()
        view.addSubview(arSceneView)

        // Transparent overlay for live point cloud dots
        overlayImageView = UIImageView(frame: view.bounds)
        overlayImageView.contentMode = .scaleToFill
        overlayImageView.isUserInteractionEnabled = false
        overlayImageView.isHidden = true
        view.addSubview(overlayImageView)

        // 3D preview (hidden until scan complete)
        sceneView = SCNView(frame: view.bounds)
        sceneView.backgroundColor = UIColor(white: 0.08, alpha: 1)
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.isHidden = true
        view.addSubview(sceneView)

        // Distance badge
        distanceBadge = UILabel()
        distanceBadge.font = .systemFont(ofSize: 15, weight: .semibold)
        distanceBadge.textAlignment = .center
        distanceBadge.layer.cornerRadius = 12
        distanceBadge.layer.masksToBounds = true
        distanceBadge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(distanceBadge)

        // Status label
        statusLabel = UILabel()
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        // Frame counter
        frameCountLabel = UILabel()
        frameCountLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        frameCountLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        frameCountLabel.textAlignment = .right
        frameCountLabel.translatesAutoresizingMaskIntoConstraints = false
        frameCountLabel.isHidden = true
        view.addSubview(frameCountLabel)

        // Buttons
        cancelButton  = makeButton(title: "Cancel",    style: .secondary)
        captureButton = makeButton(title: "Scan Foot", style: .primary)
        submitButton  = makeButton(title: "Save Scan", style: .confirm)
        rescanButton  = makeButton(title: "Rescan",    style: .secondary)

        cancelButton.addTarget(self,  action: #selector(cancelTapped),  for: .touchUpInside)
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        submitButton.addTarget(self,  action: #selector(submitTapped),  for: .touchUpInside)
        rescanButton.addTarget(self,  action: #selector(rescanTapped),  for: .touchUpInside)

        submitButton.isHidden = true
        rescanButton.isHidden = true
        captureButton.isHidden = true
        cancelButton.isHidden = true

        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, captureButton, submitButton, rescanButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            distanceBadge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            distanceBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            distanceBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            distanceBadge.heightAnchor.constraint(equalToConstant: 36),

            statusLabel.topAnchor.constraint(equalTo: distanceBadge.bottomAnchor, constant: 6),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            frameCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            frameCountLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),

            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 52),
        ])

        updateDistanceBadge(text: "Select Foot", color: .systemBlue)
        statusLabel.text = ""

        buildFootSelectionView()
    }

    private func buildFootSelectionView() {
        footSelectionView = UIView(frame: view.bounds)
        footSelectionView.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        view.addSubview(footSelectionView)

        let title = UILabel()
        title.text = "Which foot are you scanning?"
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        title.textColor = .white
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        footSelectionView.addSubview(title)

        let subtitle = UILabel()
        subtitle.text = "Scan one foot at a time.\nThe STL will be labelled with the foot selected."
        subtitle.font = .systemFont(ofSize: 14, weight: .regular)
        subtitle.textColor = UIColor.white.withAlphaComponent(0.7)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 2
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        footSelectionView.addSubview(subtitle)

        let leftBtn  = makeFootButton(title: "👣  Left Foot",  color: .systemBlue)
        let rightBtn = makeFootButton(title: "👣  Right Foot", color: .systemGreen)
        leftBtn.tag  = 0
        rightBtn.tag = 1
        leftBtn.addTarget(self,  action: #selector(footSelected(_:)), for: .touchUpInside)
        rightBtn.addTarget(self, action: #selector(footSelected(_:)), for: .touchUpInside)

        let btnStack = UIStackView(arrangedSubviews: [leftBtn, rightBtn])
        btnStack.axis = .horizontal
        btnStack.spacing = 16
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        footSelectionView.addSubview(btnStack)

        let cancelLbl = UIButton(type: .system)
        cancelLbl.setTitle("Cancel", for: .normal)
        cancelLbl.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        cancelLbl.translatesAutoresizingMaskIntoConstraints = false
        cancelLbl.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        footSelectionView.addSubview(cancelLbl)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: footSelectionView.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: footSelectionView.centerYAnchor, constant: -80),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            subtitle.centerXAnchor.constraint(equalTo: footSelectionView.centerXAnchor),
            subtitle.leadingAnchor.constraint(equalTo: footSelectionView.leadingAnchor, constant: 30),
            subtitle.trailingAnchor.constraint(equalTo: footSelectionView.trailingAnchor, constant: -30),

            btnStack.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 36),
            btnStack.centerXAnchor.constraint(equalTo: footSelectionView.centerXAnchor),
            btnStack.leadingAnchor.constraint(equalTo: footSelectionView.leadingAnchor, constant: 30),
            btnStack.trailingAnchor.constraint(equalTo: footSelectionView.trailingAnchor, constant: -30),
            btnStack.heightAnchor.constraint(equalToConstant: 64),

            cancelLbl.topAnchor.constraint(equalTo: btnStack.bottomAnchor, constant: 24),
            cancelLbl.centerXAnchor.constraint(equalTo: footSelectionView.centerXAnchor),
        ])
    }

    // MARK: - AR Session

    private func startARSession() {
        guard ARFaceTrackingConfiguration.isSupported else {
            showError("Face/TrueDepth camera not supported on this device.")
            return
        }
        let config = ARFaceTrackingConfiguration()
        config.isWorldTrackingEnabled = true
        config.maximumNumberOfTrackedFaces = 0  // we only want depth, no face mesh needed
        arConfig = config
        arSession.delegate = self
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Distance badge update (always)
        if let depthMap = frame.capturedDepthData?.depthDataMap {
            let dist = sampleCentreDepth(depthMap)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateDistanceUI(metres: dist)
            }
        }

        guard phase == .scanning else { return }
        guard frameCount < maxFrames else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.phase == .scanning else { return }
                self.stopScanAndProcess()
            }
            return
        }

        guard let depthData = frame.capturedDepthData else { return }
        guard depthData.depthDataAccuracy == .absolute else { return }

        let cameraPose = frame.camera.transform  // camera-to-world 4x4

        accumQueue.async { [weak self] in
            guard let self = self else { return }
            self.integrateFrame(depthData: depthData, pose: cameraPose)
            self.frameCount += 1

            self.overlayUpdateCounter += 1
            if self.overlayUpdateCounter % 10 == 0 {
                let pts = self.voxelGrid.occupiedCentres()
                let proj = self.projectToScreen(worldPoints: pts, frame: frame)
                DispatchQueue.main.async { [weak self] in
                    self?.renderLiveOverlay(screenPoints: proj)
                }
            }

            let fc = self.frameCount
            DispatchQueue.main.async { [weak self] in
                self?.frameCountLabel.text = "\(fc)/\(self.maxFrames)"
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.showError("AR session failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Depth Integration

    private func integrateFrame(depthData: AVDepthData, pose: simd_float4x4) {
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let pixelBuffer = converted.depthDataMap
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let floats = base.bindMemory(to: Float.self, capacity: w * h)

        // Get intrinsics from depth data
        guard let cal = converted.cameraCalibrationData else { return }
        let ref = cal.intrinsicMatrixReferenceDimensions
        let scaleX = Float(w) / Float(ref.width)
        let scaleY = Float(h) / Float(ref.height)
        let m = cal.intrinsicMatrix
        let fx = m[0][0] * scaleX
        let fy = m[1][1] * scaleY
        let cx = m[2][0] * scaleX
        let cy = m[2][1] * scaleY

        // Subsample: every 4th pixel in each axis for speed
        let step = 4
        for row in stride(from: 0, to: h, by: step) {
            for col in stride(from: 0, to: w, by: step) {
                let z = floats[row * w + col]
                guard z >= minDepth, z <= maxDepth, z.isFinite else { continue }

                // Camera-space point
                let xc = (Float(col) - cx) * z / fx
                let yc = (Float(row) - cy) * z / fy
                let camPt = SIMD4<Float>(xc, yc, z, 1.0)

                // World-space point
                let worldPt4 = pose * camPt
                let worldPt = SIMD3<Float>(worldPt4.x, worldPt4.y, worldPt4.z)

                voxelGrid.insert(worldPt)
            }
        }
    }

    // MARK: - Live Overlay

    private func sampleCentreDepth(_ pixelBuffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }
        let floats = base.bindMemory(to: Float.self, capacity: w * h)
        let cx = w / 2, cy = h / 2, patch = 15
        var vals = [Float]()
        for r in max(0, cy-patch)..<min(h, cy+patch) {
            for c in max(0, cx-patch)..<min(w, cx+patch) {
                let v = floats[r * w + c]
                if v > 0 { vals.append(v) }
            }
        }
        if vals.isEmpty { return 0 }
        vals.sort()
        return vals[vals.count / 2]
    }

    private func projectToScreen(worldPoints: [SIMD3<Float>], frame: ARFrame) -> [CGPoint] {
        // Project world-space points to 2D screen coords using ARFrame camera
        let viewportSize = arSceneView.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0 else { return [] }

        var result = [CGPoint]()
        result.reserveCapacity(worldPoints.count)

        let projMatrix = frame.camera.projectionMatrix(for: .portrait,
                                                        viewportSize: viewportSize,
                                                        zNear: 0.001, zFar: 10)
        let viewMatrix = frame.camera.viewMatrix(for: .portrait)
        let pvMatrix   = projMatrix * viewMatrix

        for wp in worldPoints {
            let clip = pvMatrix * SIMD4<Float>(wp.x, wp.y, wp.z, 1.0)
            guard clip.w > 0 else { continue }
            let ndc = SIMD2<Float>(clip.x / clip.w, clip.y / clip.w)
            guard ndc.x >= -1, ndc.x <= 1, ndc.y >= -1, ndc.y <= 1 else { continue }
            let sx = CGFloat((ndc.x + 1) * 0.5) * viewportSize.width
            let sy = CGFloat((1 - (ndc.y + 1) * 0.5)) * viewportSize.height
            result.append(CGPoint(x: sx, y: sy))
        }
        return result
    }

    private func renderLiveOverlay(screenPoints: [CGPoint]) {
        let size = view.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { UIGraphicsEndImageContext(); return }

        // Draw colored point cloud — cyan/green gradient by density
        let dotR: CGFloat = 2.5
        ctx.setFillColor(UIColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 0.75).cgColor)
        for pt in screenPoints {
            ctx.fillEllipse(in: CGRect(x: pt.x - dotR, y: pt.y - dotR,
                                       width: dotR * 2, height: dotR * 2))
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        overlayImageView.image = img
    }

    // MARK: - Scan Control

    @objc private func footSelected(_ sender: UIButton) {
        footSide = sender.tag == 0 ? "left" : "right"
        UIView.animate(withDuration: 0.25) {
            self.footSelectionView.alpha = 0
        } completion: { _ in
            self.footSelectionView.removeFromSuperview()
        }
        phase = .idle
        cancelButton.isHidden  = false
        captureButton.isHidden = false
        let sideText = footSide.capitalized
        updateDistanceBadge(text: "\(sideText) Foot — Position", color: .systemGray)
        statusLabel.text = "Hold phone 15–45 cm above foot\nStart at heel, rotate around foot"
        startARSession()
    }

    @objc private func captureTapped() {
        if phase == .idle {
            phase = .scanning
            frameCount = 0
            overlayUpdateCounter = 0
            voxelGrid = VoxelGrid(cellSize: 0.002)
            worldPoints = []

            captureButton.setTitle("Stop Scan", for: .normal)
            captureButton.backgroundColor = .systemRed
            overlayImageView.isHidden = false
            frameCountLabel.isHidden = false
            updateDistanceBadge(text: "Scanning \(footSide.capitalized) Foot", color: .systemRed)
            statusLabel.text = "Move around the foot slowly\nTap Stop when covered"

        } else if phase == .scanning {
            guard frameCount >= 20 else {
                statusLabel.text = "Keep scanning — need more frames"
                return
            }
            stopScanAndProcess()
        }
    }

    private func stopScanAndProcess() {
        phase = .processing
        overlayImageView.isHidden = true
        frameCountLabel.isHidden = true
        captureButton.isEnabled = false
        updateDistanceBadge(text: "Processing...", color: .systemOrange)
        statusLabel.text = "Building mesh from \(frameCount) frames..."

        accumQueue.async { [weak self] in
            guard let self = self else { return }
            let pts = self.voxelGrid.occupiedCentres()
            guard pts.count > 500 else {
                DispatchQueue.main.async { self.showError("Not enough geometry — rescan and move around the foot more.") }
                return
            }

            DispatchQueue.main.async { self.statusLabel.text = "Running marching cubes..." }

            let geometry = MeshBuilder.buildMeshFromPoints(pts, footSide: self.footSide)
            guard let geo = geometry else {
                DispatchQueue.main.async { self.showError("Mesh build failed — try scanning again.") }
                return
            }

            DispatchQueue.main.async { self.showPreview(geometry: geo) }
        }
    }

    @objc private func cancelTapped() {
        arSession.pause()
        onCancel?()
        dismiss(animated: true)
    }

    @objc private func submitTapped() {
        guard let node = builtMeshNode, let geo = node.geometry else { return }
        statusLabel.text = "Exporting STL..."
        submitButton.isEnabled = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let url = MeshBuilder.exportSTL(from: geo, footSide: self.footSide) {
                DispatchQueue.main.async {
                    self.onScanComplete?(url)
                    self.dismiss(animated: true)
                }
            } else {
                DispatchQueue.main.async {
                    self.showError("STL export failed.")
                    self.submitButton.isEnabled = true
                }
            }
        }
    }

    @objc private func rescanTapped() {
        builtMeshNode?.removeFromParentNode()
        builtMeshNode = nil
        sceneView.isHidden  = true
        arSceneView.isHidden = false
        overlayImageView.isHidden = true
        overlayImageView.image    = nil
        submitButton.isHidden = true
        rescanButton.isHidden = true
        captureButton.isHidden = false
        captureButton.isEnabled = true
        captureButton.setTitle("Scan Foot", for: .normal)
        captureButton.backgroundColor = .systemBlue
        cancelButton.isHidden = false
        frameCountLabel.isHidden = true
        phase = .idle
        frameCount = 0
        voxelGrid  = VoxelGrid(cellSize: 0.002)
        worldPoints = []
        let side = footSide.capitalized
        updateDistanceBadge(text: "\(side) Foot — Position", color: .systemGray)
        statusLabel.text = "Hold phone 15–45 cm above foot"
        // Restart AR
        if let cfg = arConfig { arSession.run(cfg, options: [.resetTracking]) }
    }

    // MARK: - Preview

    private func showPreview(geometry: SCNGeometry) {
        phase = .preview
        arSession.pause()

        let scene  = SCNScene()
        let node   = SCNNode(geometry: geometry)
        let (bMin, bMax) = node.boundingBox
        node.position = SCNVector3(-(bMin.x + bMax.x) / 2,
                                   -(bMin.y + bMax.y) / 2,
                                   -(bMin.z + bMax.z) / 2)
        scene.rootNode.addChildNode(node)
        builtMeshNode = node

        let maxDim  = Swift.max(bMax.x - bMin.x, Swift.max(bMax.y - bMin.y, bMax.z - bMin.z))
        let camDist = maxDim * 2.5
        let camNode = SCNNode()
        camNode.camera        = SCNCamera()
        camNode.camera?.zNear = 0.001
        camNode.camera?.zFar  = 20.0
        camNode.position = SCNVector3(0, 0, Float(camDist))
        scene.rootNode.addChildNode(camNode)

        sceneView.scene       = scene
        sceneView.pointOfView  = camNode
        sceneView.autoenablesDefaultLighting = true
        sceneView.isHidden    = false
        arSceneView.isHidden  = true
        overlayImageView.isHidden = true

        captureButton.isHidden = true
        cancelButton.isHidden  = true
        submitButton.isHidden  = false
        rescanButton.isHidden  = false

        updateDistanceBadge(text: "Scan Ready ✓", color: .systemGreen)
        statusLabel.text = "Rotate to inspect — Save or Rescan"
    }

    // MARK: - Helpers

    private func updateDistanceUI(metres: Float) {
        guard phase == .idle || phase == .scanning else { return }
        if metres == 0 {
            if phase == .idle { updateDistanceBadge(text: "No foot detected", color: .systemGray) }
        } else if metres < minDepth {
            updateDistanceBadge(text: "Too close — move back", color: .systemRed)
            if phase == .idle { statusLabel.text = String(format: "%.0f cm — minimum 10 cm", metres * 100) }
        } else if metres > maxDepth {
            updateDistanceBadge(text: "Move closer", color: .systemOrange)
            if phase == .idle { statusLabel.text = String(format: "%.0f cm — maximum 45 cm", metres * 100) }
        } else if phase == .idle {
            updateDistanceBadge(text: String(format: "✓  %.0f cm", metres * 100), color: .systemGreen)
            statusLabel.text = "Good distance — tap Scan Foot"
        }
    }

    private func updateDistanceBadge(text: String, color: UIColor) {
        distanceBadge.text = text
        distanceBadge.backgroundColor = color.withAlphaComponent(0.85)
        distanceBadge.textColor = .white
    }

    private func showError(_ msg: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Scan Error", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.rescanTapped()
            })
            self.present(alert, animated: true)
        }
    }

    private func makeButton(title: String, style: ButtonStyle) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.layer.cornerRadius = 12
        btn.layer.masksToBounds = true
        switch style {
        case .primary:   btn.backgroundColor = .systemBlue;              btn.setTitleColor(.white, for: .normal)
        case .secondary: btn.backgroundColor = UIColor(white:0.2,alpha:0.9); btn.setTitleColor(.white, for: .normal)
        case .confirm:   btn.backgroundColor = .systemGreen;             btn.setTitleColor(.white, for: .normal)
        }
        return btn
    }

    private func makeFootButton(title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = color
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 14
        btn.layer.masksToBounds = true
        return btn
    }

    private enum ButtonStyle { case primary, secondary, confirm }
}

// MARK: - VoxelGrid
// Hash-based 3D grid for deduplicating world-space points across frames.
// Cell size 2 mm → no two points closer than 2 mm are stored separately.

struct VoxelGrid {
    let cellSize: Float
    private var cells = Set<SIMD3<Int32>>()

    init(cellSize: Float) { self.cellSize = cellSize }

    mutating func insert(_ point: SIMD3<Float>) {
        let key = SIMD3<Int32>(
            Int32(floor(point.x / cellSize)),
            Int32(floor(point.y / cellSize)),
            Int32(floor(point.z / cellSize))
        )
        cells.insert(key)
    }

    func occupiedCentres() -> [SIMD3<Float>] {
        return cells.map { k in
            SIMD3<Float>(
                (Float(k.x) + 0.5) * cellSize,
                (Float(k.y) + 0.5) * cellSize,
                (Float(k.z) + 0.5) * cellSize
            )
        }
    }
}


