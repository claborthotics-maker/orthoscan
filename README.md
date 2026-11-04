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
- Distance badge shows 20-40 cm; the scanner accepts 18-43 cm. Scans stop at 1000 frames.

**Smoothing**
The exported (final) mesh gets very light Taubin smoothing: lambda 0.33, mu -0.34, 4 passes. Taubin alternates a pull toward the neighbours' average with a push back out, so it removes small ripples without shrinking the foot. In testing on a noisy sphere, 4 passes cut surface noise by about a third with no measurable shrinkage; on real scans (2 passes) vertices moved about 0.2-0.25 mm on average and the overall size changed by under 0.25 mm. Vertices on open mesh edges are held fixed. The live overlay is not smoothed. A `[SMOOTH]` line in the debug log shows how far vertices moved and the mesh size before and after. To turn it off set `smoothEnabled = false` in `MeshBuilder.swift`; to change the strength edit `smoothLambda`, `smoothMu` or `smoothIterations` there.

**Single-skin mesh (inner back wall removed)**
A TSDF scan fills a band of voxels about 15 mm behind the skin it sees, then stops. The mesh builder used to read the jump from that band to never-seen voxels as a second surface, which produced a rippled inner wall behind the real skin. Mesh cells that touch voxels with too little weight (under `minWeight`) are now skipped, so only the real outer skin is built. The outer skin is unchanged; the scan's outer rim loses about one voxel (roughly 3 mm) where it was thinly seen. The exported STL is now a single open sheet, not a two-layer shell. Applies to the final STL and the live overlay. To bring the inner layer back set `trimBackWall = false` in `MeshBuilder.swift`. The `[TRIM]` log line shows how many cells were skipped.

The underside of the sheet (seen from behind) is drawn light grey instead of black. This is display only, not part of the STL; change `backFaceColor` in `MeshBuilder.swift` to adjust it.

Dimensional accuracy: smoothing and rim trimming move the surface by under about a millimetre in tests on the scanner's own mesh. A tape-measure check against a real foot or a known object is still recommended.

**Crash fix (memory leak)**
Long scans used to crash at roughly 350-700 frames. Cause: the live preview mesh was rebuilt every frame and each rebuild left about 7 MB of temporary objects behind, until iOS killed the app at its memory limit (about 3.4 GB on the iPhone 17 Pro). Fix: the preview mesh build is wrapped in an `autoreleasepool`. Memory now stays flat (about 600 MB) and a scan runs to the 1000-frame limit. The scan itself is unchanged.

**Known limits**
- If alignment fails on the very first frames, the model cannot grow and the scan stalls. Stop and start the scan again.
- Voxel size is 3 mm or a little more, depending on how the phone is held at the start.
- Back-camera (LiDAR) version not built yet.

**Baseline tags**
`scan-master-v1` to `v5` are the steps that built this scanner (mirror fix, faster overlay, object lock and jump gate, alignment, overlay correction). `scan-base` is the pre-fix baseline. `scan-base-v2` and `scan-master-v6` are the baseline with the crash fix. `scan-master-v7` adds the light final-mesh smoothing. `scan-master-v8` removes the inner back wall and adds the grey underside.

## Smoothing strength (6 passes)

The final-mesh Taubin smoothing now runs 6 passes (was 4), with lambda 0.33 and mu -0.34 unchanged. It is applied to the exported STL only, and open-edge vertices stay fixed. On a real foot scan (about 18.6k vertices) it moved vertices 0.53 mm on average and 1.58 mm at most, with no change in overall bounding-box size. The ripples on skin are visibly reduced. To change the strength, edit `smoothIterations` in `ios/Runner/MeshBuilder.swift`.

## Underside colour and shading

The inside (underside) of the scan shell is now shown in a muted steel blue, lit with the same physically based material as the outside, so it picks up light and shadow and no longer looks flat. This replaces the earlier flat light-grey underside. The material flips its surface direction so the inside catches light. This is display only: the exported STL is unchanged. To change the colour, edit `backFaceColor` in `ios/Runner/MeshBuilder.swift`.

## Patient scan list and sharing

- The grey "Scan N" subtitle under each scan in the patient profile was removed; each row shows the scan file name only.
- The email subject now shows the patient's name (it was printing the literal text `${widget.patient.fullName}`).
- Sharing a scan now finds the file by name in the app's current Documents folder when the saved path no longer exists. iOS changes the app container path on reinstall and update, which left saved absolute paths stale and stopped the STL attaching to email. If the file is truly gone, the app shows "Scan file is missing: <name>".
