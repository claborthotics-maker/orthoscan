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
