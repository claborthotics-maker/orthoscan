# CL@B - Orthotic Lab Order App (formerly Orthoscan)

Designed and built by Chase Jahay - Compass Limb & Brace LLC

CL@B is a mobile app for orthotic clinicians to create and submit lab work orders digitally, and capture 3D foot scans using the iPhone TrueDepth camera.

---

## Features

- Work orders for Rebound, Poly Shell, and Partial Foot orthotics
- Type-specific PDF specs and product options
- Interactive foot diagram with mark, draw, and note tools
- Full-screen foot diagram editor with accurate coordinate scaling
- Patient management with required field validation
- Professional PDF generation and sharing
- Multiple clinician and clinic profiles
- Work order validation before submission
- Dark / Light mode toggle
- Configurable default delivery days
- Onboarding and tutorial carousel

### 3D Foot Scanning (iOS)
- TrueDepth front camera depth scanning via ARKit + AVFoundation
- Real-time cyan point cloud overlay during capture
- Depth-grid mesh triangulation with spatial vertex merging
- FOV angle guard to eliminate symmetric depth artifacts
- Binary STL export saved directly to patient record
- STL sharing via iOS share sheet
- Scans tab on patient profile with per-scan share buttons

---

## Tech Stack

- Flutter (Dart)
- Swift (iOS native — ARKit, SceneKit, AVFoundation)
- SQLite via sqflite
- PDF generation via pdf + printing packages
- SharedPreferences for persistent settings
- share_plus for STL file sharing

---

## Roadmap

- [x] iOS / iPadOS support
- [x] TrueDepth 3D foot scanning with STL export
- [x] Scan saved to patient record
- [ ] Mesh noise and spike filtering
- [ ] STL filename includes patient name + foot side
- [ ] TestFlight distribution
- [ ] Cloud sync via Google Cloud / Firebase
- [ ] HIPAA compliance (PIN lock + SQLite encryption)
- [ ] Foot diagram notes in PDF
- [ ] Press-and-hold tooltips with accommodation photos
- [ ] License key system

---

Built and maintained by Compass Orthotics and Prosthetics. Currently in active clinical testing.

## 3D foot scanning (TrueDepth)

Live scan screen: `ios/Runner/TrueDepthScanViewController.swift`. Reconstruction: `ios/Runner/MeshBuilder.swift` (class `LiveTSDF`). Exports an STL in millimetres for Fit Foot 360 / Fusion 360.

**How it works**
- Front TrueDepth camera with ARKit world tracking. Needs an iPhone X or newer; A14 or newer is the practical minimum (older chips untested).
- Every depth frame is fused into a TSDF volume. The volume is built once from the first 5 frames, between 0.18 and 0.43 m. Voxel size starts at 3 mm and grows in 15% steps if needed to stay under 6 million voxels. Truncation margin is 5 voxels.
- Object lock: only voxels within 0.25 m of the centre of the view at scan start are updated, so background clutter is ignored.
- Pose-jump gate: a frame is rejected if the camera pose steps more than 3 cm or 0.14 rad between integrated frames.
- Frame-to-model alignment: each frame is nudged onto the surface already built (6-DoF, 4 iterations) before it is fused. Frames that cannot be aligned are skipped.
- Live overlay is rebuilt every frame and drawn with the inverse alignment correction so it sits on the real foot.
- Mirror fix: the final mesh is flipped left-to-right with triangle winding reversed.
- Distance badge shows 20-40 cm; the scanner accepts 18-43 cm. Scans stop at 1000 frames. No smoothing is applied yet.

**Crash fix (memory leak)**
Long scans used to crash at roughly 350-700 frames. Cause: the live preview mesh was rebuilt every frame and each rebuild left about 7 MB of temporary objects behind, until iOS killed the app at its memory limit (about 3.4 GB on the iPhone 17 Pro). Fix: the preview mesh build is wrapped in an `autoreleasepool`. Memory now stays flat (about 600 MB) and a scan runs to the 1000-frame limit. The scan itself is unchanged.

**Known limits**
- If alignment fails on the very first frames, the model cannot grow and the scan stalls. Stop and start the scan again.
- Voxel size is 3 mm or a little more, depending on how the phone is held at the start.
- Back-camera (LiDAR) version not built yet.

**Baseline tags**
`scan-master-v1` to `v5` are the steps that built this scanner (mirror fix, faster overlay, object lock and jump gate, alignment, overlay correction). `scan-base` is the pre-fix baseline. `scan-base-v2` and `scan-master-v6` are the current baseline with the crash fix.
