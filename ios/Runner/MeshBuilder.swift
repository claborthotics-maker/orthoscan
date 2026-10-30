import SceneKit
import ARKit
import simd

struct DepthFrame {
    let width:  Int
    let height: Int
    let pixels: [Float]
    let pose:   simd_float4x4
    let fx: Float
    let fy: Float
    let cx: Float
    let cy: Float
}

// KinectFusion-style projective TSDF
// For each voxel, project into camera, look up depth, compute SDF
// Based on Newcombe et al. 2011 and Curless & Levoy 1996
class LiveTSDF {

    // Faithful port of andyzeng/tsdf-fusion-python (TSDFVolume.integrate + marching cubes at level 0).
    private(set) var voxelSize: Float = 0.003
    private var truncMargin: Float = 0.015
    private var zMin: Float = 0.10
    private var zMax: Float = 0.45
    private let obsWeight: Float = 1.0
    // Clutter filters (added on top of the reference algorithm; tune these two numbers)
    private let minWeight: Float = 3.0          // voxels observed fewer times than this count as empty
    private let minPieceFraction: Float = 0.08  // drop mesh pieces smaller than this fraction of the largest piece
    // Depth clean-up / confidence weighting (added on top of the reference algorithm)
    private let depthEdgeSpread: Float = 0.015  // reject a pixel if its 3x3 window spans more than this (metres)
    private let minAngleWeight: Float = 0.15    // floor for the viewing-angle weight
    // Depth smoothing per frame (bilateral). Depth differences above ~3x this are treated as edges (metres). 0 = off.
    private let depthSmoothSigma: Float = 0.004

    private var tsdf:    [Float] = []
    private var weights: [Float] = []
    private var colors:  [SIMD3<Float>] = []
    private var nx = 0, ny = 0, nz = 0
    private var volOrigin = SIMD3<Float>.zero
    private var dbgCount = 0
    private let stateLock = NSLock()   // integration and mesh extraction run on different threads
    private(set) var initialised = false
    private(set) var lastGeometry: SCNGeometry?

    func initialise(frames: [DepthFrame], step: Int = 2) {
        var samples = [Float]()
        for f in frames {
            let w = f.width, h = f.height
            for r in (h * 3 / 8)..<(h * 5 / 8) {
                for c in (w * 3 / 8)..<(w * 5 / 8) {
                    let z = f.pixels[r * w + c]
                    if z > 0.15, z < 0.60, z.isFinite { samples.append(z) }
                }
            }
        }
        guard samples.count > 200 else {
            print("[TSDF] init FAILED: only \(samples.count) valid centre pixels (need >200). Hold 20-35cm, foot centred.")
            initialised = false; return
        }
        samples.sort()
        let ref = samples[samples.count / 2]
        // fixed depth window: the 20-40 cm scan range plus a margin for surface relief
        zMin = 0.18
        zMax = 0.43

        var lo = SIMD3<Float>(repeating:  Float.greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
        for f in frames {
            let w = Float(f.width), h = Float(f.height)
            let pix: [(Float, Float)] = [(0, 0), (w, 0), (0, h), (w, h)]
            for z in [zMin, zMax] {
                for (u, v) in pix {
                    let xc =  (u - f.cx) * z / f.fx
                    let yc = -(v - f.cy) * z / f.fy
                    let wp = f.pose * SIMD4<Float>(xc, yc, -z, 1.0)
                    let p = SIMD3<Float>(wp.x, wp.y, wp.z)
                    lo = simd_min(lo, p); hi = simd_max(hi, p)
                }
            }
        }
        let extent = hi - lo
        var vs: Float = 0.0034
        func gridDims(_ v: Float) -> (Int, Int, Int) {
            return (max(2, Int(ceil(extent.x / v))), max(2, Int(ceil(extent.y / v))), max(2, Int(ceil(extent.z / v))))
        }
        var d = gridDims(vs)
        while d.0 * d.1 * d.2 > 6_000_000 { vs *= 1.15; d = gridDims(vs) }
        voxelSize = vs
        truncMargin = 5.0 * vs
        nx = d.0; ny = d.1; nz = d.2
        volOrigin = lo
        let count = nx * ny * nz
        tsdf    = [Float](repeating: 1.0, count: count)
        weights = [Float](repeating: 0.0, count: count)
        colors  = [SIMD3<Float>](repeating: SIMD3<Float>(0.8, 0.8, 0.8), count: count)
        print("[TSDF] ref=\(String(format: "%.3f", ref))m window=[\(String(format: "%.3f", zMin)),\(String(format: "%.3f", zMax))] voxel=\(String(format: "%.4f", vs)) grid=\(nx)x\(ny)x\(nz) count=\(count) extent=(\(String(format: "%.3f", extent.x)),\(String(format: "%.3f", extent.y)),\(String(format: "%.3f", extent.z)))")
        let dbgMax = volOrigin + vs * SIMD3<Float>(Float(nx), Float(ny), Float(nz))
        print("[VOL] init min=(\(String(format: "%.3f", volOrigin.x)),\(String(format: "%.3f", volOrigin.y)),\(String(format: "%.3f", volOrigin.z))) max=(\(String(format: "%.3f", dbgMax.x)),\(String(format: "%.3f", dbgMax.y)),\(String(format: "%.3f", dbgMax.z)))")
        initialised = true
    }

    func integrate(frame: DepthFrame, colorImage: CVPixelBuffer?, step: Int = 2) {
        guard initialised else { return }
        integrateFrame(frame, colorBuffer: colorImage)
    }

    private func integrateFrame(_ frame: DepthFrame, colorBuffer: CVPixelBuffer?) {
        let w = frame.width, h = frame.height
        let fx = frame.fx, fy = frame.fy, cx = frame.cx, cy = frame.cy
        let invPose = simd_inverse(frame.pose)
        let t0 = CFAbsoluteTimeGetCurrent()
        let (depthPx, weightPx) = prepareDepth(frame)

        var yBase:    UnsafeMutablePointer<UInt8>? = nil
        var cbcrBase: UnsafeMutablePointer<UInt8>? = nil
        var colorW = 0, colorH = 0, yBPR = 0, cbcrBPR = 0
        if let cb = colorBuffer {
            CVPixelBufferLockBaseAddress(cb, .readOnly)
            colorW = CVPixelBufferGetWidth(cb)
            colorH = CVPixelBufferGetHeight(cb)
            if CVPixelBufferGetPlaneCount(cb) >= 2 {
                if let p0 = CVPixelBufferGetBaseAddressOfPlane(cb, 0) { yBase    = p0.assumingMemoryBound(to: UInt8.self) }
                if let p1 = CVPixelBufferGetBaseAddressOfPlane(cb, 1) { cbcrBase = p1.assumingMemoryBound(to: UInt8.self) }
                yBPR    = CVPixelBufferGetBytesPerRowOfPlane(cb, 0)
                cbcrBPR = CVPixelBufferGetBytesPerRowOfPlane(cb, 1)
            }
        }
        defer { if let cb = colorBuffer { CVPixelBufferUnlockBaseAddress(cb, .readOnly) } }
        let haveColor = (yBase != nil && cbcrBase != nil && colorW > 0)
        let sx = haveColor ? Float(colorW) / Float(w) : 0
        let sy = haveColor ? Float(colorH) / Float(h) : 0

        // Voxel update, run in parallel over z-slices (every voxel is written by exactly one slice).
        let gnx = nx, gny = ny, gnz = nz
        let gOrigin = volOrigin, gVoxel = voxelSize, gTrunc = truncMargin
        let gZMin = zMin, gZMax = zMax
        let yB0 = yBase, cb0 = cbcrBase
        let cW = colorW, cH = colorH, yRow = yBPR, cbRow = cbcrBPR
        stateLock.lock()
        var perSlice = [Int](repeating: 0, count: gnz)
        tsdf.withUnsafeMutableBufferPointer { tsdfP in
            weights.withUnsafeMutableBufferPointer { wtsP in
                colors.withUnsafeMutableBufferPointer { colP in
                    perSlice.withUnsafeMutableBufferPointer { cntP in
                        depthPx.withUnsafeBufferPointer { dP in
                            weightPx.withUnsafeBufferPointer { oP in
                                DispatchQueue.concurrentPerform(iterations: gnz) { (iz: Int) in
                                    var cnt = 0
                                    for iy in 0..<gny {
                                        for ix in 0..<gnx {
                                            // andyzeng vox2world: world = vol_origin + voxel_size * voxel_index
                                            let wp = gOrigin + gVoxel * SIMD3<Float>(Float(ix), Float(iy), Float(iz))
                                            // andyzeng: cam_pts = inv(cam_pose) @ world_pt
                                            let ch = invPose * SIMD4<Float>(wp.x, wp.y, wp.z, 1.0)
                                            // ARKit camera looks down -Z  =>  depth along the optical axis is -z
                                            let pixZ = -ch.z
                                            if pixZ < 0.001 { continue }
                                            // andyzeng cam2pix, with image-v pointing down while ARKit camera-y points up
                                            let pu = Int((fx * ch.x / pixZ + cx).rounded())
                                            let pv = Int((-fy * ch.y / pixZ + cy).rounded())
                                            if pu < 0 || pu >= w || pv < 0 || pv >= h { continue }

                                            let depthVal = dP[pv * w + pu]
                                            // 0 = no reading; the window rejects floor/background (NaN fails both tests)
                                            if (depthVal >= gZMin && depthVal <= gZMax) == false { continue }

                                            let depthDiff = depthVal - pixZ
                                            if depthDiff < -gTrunc { continue }
                                            let dist = min(1.0, depthDiff / gTrunc)

                                            let i = ix + iy * gnx + iz * gnx * gny
                                            let obsW = oP[pv * w + pu]
                                            let wOld = wtsP[i]
                                            let wNew = wOld + obsW
                                            tsdfP[i] = (wOld * tsdfP[i] + obsW * dist) / wNew
                                            wtsP[i] = wNew
                                            cnt += 1

                                            if haveColor, let yB = yB0, let cbB = cb0 {
                                                let imgX = min(cW - 1, max(0, Int(Float(pu) * sx)))
                                                let imgY = min(cH - 1, max(0, Int(Float(pv) * sy)))
                                                let yVal  = Float(yB[imgY * yRow + imgX]) / 255.0
                                                let cbVal = Float(cbB[(imgY / 2) * cbRow + (imgX & ~1)    ]) / 255.0 - 0.5
                                                let crVal = Float(cbB[(imgY / 2) * cbRow + (imgX & ~1) + 1]) / 255.0 - 0.5
                                                let nc = SIMD3<Float>(
                                                    max(0, min(1, yVal + 1.402 * crVal)),
                                                    max(0, min(1, yVal - 0.344136 * cbVal - 0.714136 * crVal)),
                                                    max(0, min(1, yVal + 1.772 * cbVal)))
                                                colP[i] = (wOld * colP[i] + obsW * nc) / wNew
                                            }
                                        }
                                    }
                                    cntP[iz] = cnt
                                }
                            }
                        }
                    }
                }
            }
        }
        let touched = perSlice.reduce(0, +)
        stateLock.unlock()
        dbgCount += 1
        if dbgCount % 10 == 1 {
            let vmin = volOrigin
            let vmax = volOrigin + voxelSize * SIMD3<Float>(Float(nx), Float(ny), Float(nz))
            var nValid = 0, nWin = 0, nIn = 0
            var py = 0
            while py < h {
                var px = 0
                while px < w {
                    let d = frame.pixels[py * w + px]
                    if d > 0 {
                        nValid += 1
                        if d >= zMin && d <= zMax {
                            nWin += 1
                            let pc = SIMD4<Float>((Float(px) - cx) * d / fx, -(Float(py) - cy) * d / fy, -d, 1.0)
                            let pw = frame.pose * pc
                            if pw.x >= vmin.x && pw.x <= vmax.x && pw.y >= vmin.y && pw.y <= vmax.y && pw.z >= vmin.z && pw.z <= vmax.z { nIn += 1 }
                        }
                    }
                    px += 4
                }
                py += 4
            }
            let rawPx = frame.pixels.reduce(0) { $0 + ($1 > 0 ? 1 : 0) }
            let keptPx = depthPx.reduce(0) { $0 + ($1 > 0 ? 1 : 0) }
            print("[VOL] f=\(dbgCount) valid=\(nValid) inWindow=\(nWin) inVolume=\(nIn) touched=\(touched) rawPx=\(rawPx) keptPx=\(keptPx) ms=\(Int((CFAbsoluteTimeGetCurrent() - t0) * 1000))")
        }
        if touched == 0 { print("[TSDF] integrate: 0 voxels updated this frame (pose/projection mismatch, or nothing inside the depth window)") }
    }

    // Per-frame depth clean-up and per-pixel confidence (added on top of the reference algorithm):
    //  - 3x3 median over valid neighbours; a pixel with fewer than 4 valid neighbours, or whose 3x3 window spans
    //    more than depthEdgeSpread (depth edge / flying pixel), is rejected (set to 0 = no reading).
    //  - weight = (refZ / z)^2 (depth noise grows with distance, capped at 4) * viewing-angle term
    //    |cos(angle between view ray and surface normal)| (normal from +-5 px neighbours, floor minAngleWeight).
    private func prepareDepth(_ frame: DepthFrame) -> ([Float], [Float]) {
        let w = frame.width, h = frame.height
        let fx = frame.fx, fy = frame.fy, cx = frame.cx, cy = frame.cy
        let src = frame.pixels
        var out = [Float](repeating: 0, count: w * h)
        var wt  = [Float](repeating: 0, count: w * h)
        if w < 12 || h < 12 { return (src, [Float](repeating: obsWeight, count: w * h)) }

        var win = [Float](repeating: 0, count: 9)
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                if src[y * w + x] <= 0 { continue }
                var k = 0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let v = src[(y + dy) * w + (x + dx)]
                        if v > 0 {
                            var j = k
                            while j > 0 && win[j - 1] > v { win[j] = win[j - 1]; j -= 1 }
                            win[j] = v
                            k += 1
                        }
                    }
                }
                if k < 5 { continue }
                if win[k - 1] - win[0] > depthEdgeSpread { continue }
                out[y * w + x] = win[k / 2]
            }
        }

        let refZ: Float = 0.30
        // Depth-aware smoothing (bilateral): average each pixel with its 5x5 neighbours, weighted by pixel distance and by
        // depth difference, so noise is evened out but real depth edges are kept. Never creates new depth readings.
        if depthSmoothSigma > 0 {
            var sm = out
            let sigma = depthSmoothSigma
            var spatial = [Float](repeating: 0, count: 25)
            for dy in -2...2 {
                for dx in -2...2 {
                    spatial[(dy + 2) * 5 + (dx + 2)] = exp(-Float(dx * dx + dy * dy) / 4.5)
                }
            }
            let bands = 8
            out.withUnsafeBufferPointer { inP in
                sm.withUnsafeMutableBufferPointer { smP in
                    spatial.withUnsafeBufferPointer { spP in
                        guard let ip = inP.baseAddress, let op = smP.baseAddress, let sp = spP.baseAddress else { return }
                        DispatchQueue.concurrentPerform(iterations: bands) { (band: Int) in
                            let y0 = max(2, h * band / bands)
                            let y1 = min(h - 2, h * (band + 1) / bands)
                            if y0 >= y1 { return }
                            for y in y0..<y1 {
                                for x in 2..<(w - 2) {
                                    let c = ip[y * w + x]
                                    if c <= 0 { continue }
                                    var sum: Float = 0
                                    var wsum: Float = 0
                                    for dy in -2...2 {
                                        for dx in -2...2 {
                                            let v = ip[(y + dy) * w + (x + dx)]
                                            if v <= 0 { continue }
                                            let r = (v - c) / sigma
                                            if r > 3 || r < -3 { continue }
                                            let wgt = sp[(dy + 2) * 5 + (dx + 2)] / (1 + r * r)
                                            sum += wgt * v
                                            wsum += wgt
                                        }
                                    }
                                    if wsum > 0 { op[y * w + x] = sum / wsum }
                                }
                            }
                        }
                    }
                }
            }
            out = sm
        }

        let s = 5
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let d = out[y * w + x]
                if d <= 0 { continue }
                var cosT: Float = 1.0
                if x >= s && x < w - s && y >= s && y < h - s {
                    let dl = out[y * w + x - s], dr = out[y * w + x + s]
                    let dUp = out[(y - s) * w + x], dDown = out[(y + s) * w + x]
                    if dl > 0 && dr > 0 && dUp > 0 && dDown > 0 {
                        // camera-space points (ARKit camera looks down -Z, +Y up, image v points down)
                        let pL = SIMD3<Float>((Float(x - s) - cx) * dl / fx, -(Float(y) - cy) * dl / fy, -dl)
                        let pR = SIMD3<Float>((Float(x + s) - cx) * dr / fx, -(Float(y) - cy) * dr / fy, -dr)
                        let pU = SIMD3<Float>((Float(x) - cx) * dUp / fx, -(Float(y - s) - cy) * dUp / fy, -dUp)
                        let pD = SIMD3<Float>((Float(x) - cx) * dDown / fx, -(Float(y + s) - cy) * dDown / fy, -dDown)
                        let nrm = simd_cross(pR - pL, pD - pU)
                        let nl = simd_length(nrm)
                        if nl > 1e-12 {
                            let ray = SIMD3<Float>((Float(x) - cx) * d / fx, -(Float(y) - cy) * d / fy, -d)
                            cosT = abs(simd_dot(nrm / nl, ray / simd_length(ray)))
                        }
                    }
                }
                let ratio = refZ / d
                let ratio2 = ratio * ratio
                wt[y * w + x] = min(4.0, ratio2 * ratio2) * max(minAngleWeight, cosT)
            }
        }
        return (out, wt)
    }

    func extractMesh(mirror: Bool = false) -> SCNGeometry? {
        guard initialised else { return nil }
        stateLock.lock()
        defer { stateLock.unlock() }
        let tm0 = CFAbsoluteTimeGetCurrent()
        var verts      = [SIMD3<Float>]()
        var normals    = [SIMD3<Float>]()
        var vertColors = [SIMD3<Float>]()
        var indices    = [UInt32]()
        var filtered = tsdf
        var weightDropped = 0
        for i in 0..<filtered.count {
            if weights[i] < minWeight && filtered[i] < 1.0 { filtered[i] = 1.0; weightDropped += 1 }
        }
        let tm1 = CFAbsoluteTimeGetCurrent()
        MeshBuilder.marchingCubesFaithful(
            tsdf: filtered, colors: colors, nx: nx, ny: ny, nz: nz,
            origin: volOrigin, voxelSize: voxelSize,
            verts: &verts, normals: &normals, vertColors: &vertColors, indices: &indices)
        let tm2 = CFAbsoluteTimeGetCurrent()
        let trisBefore = indices.count / 3
        MeshBuilder.keepMainPieces(verts: &verts, normals: &normals, vertColors: &vertColors,
                                   indices: &indices, minFraction: minPieceFraction)
        print("[CLEAN] weightDropped=\(weightDropped) trisBefore=\(trisBefore) trisAfter=\(indices.count / 3)")
        let tm3 = CFAbsoluteTimeGetCurrent()
        var obs = 0, neg = 0
        for i in 0..<weights.count where weights[i] > 0 { obs += 1; if tsdf[i] < 0 { neg += 1 } }
        print("[MESH] verts=\(verts.count) tris=\(indices.count / 3) observedVoxels=\(obs) negativeVoxels=\(neg)")
        if mirror {
            // Mirror left-to-right (x -> -x), reverse each triangle's corner order so the surface still faces outward.
            for i in 0..<verts.count { verts[i].x = -verts[i].x }
            for i in 0..<normals.count { normals[i].x = -normals[i].x }
            var t = 0
            while t + 2 < indices.count {
                let tmp = indices[t + 1]
                indices[t + 1] = indices[t + 2]
                indices[t + 2] = tmp
                t += 3
            }
        }
        guard verts.count > 10, indices.count > 0 else { return nil }
        let geo = MeshBuilder.buildSCNGeometryColored(
            vertices: verts, normals: normals, vertColors: vertColors, indices: indices)
        lastGeometry = geo
        let tm4 = CFAbsoluteTimeGetCurrent()
        func ms(_ a: Double, _ b: Double) -> Int { return Int((b - a) * 1000) }
        print("[TIME] mesh total=\(ms(tm0, tm4)) weightCopy=\(ms(tm0, tm1)) marching=\(ms(tm1, tm2)) clean=\(ms(tm2, tm3)) build=\(ms(tm3, tm4)) (ms)")
        return geo
    }

    func reset() {
        stateLock.lock()
        defer { stateLock.unlock() }
        tsdf = []; weights = []; colors = []
        nx = 0; ny = 0; nz = 0; volOrigin = .zero; initialised = false; lastGeometry = nil
        dbgCount = 0
    }
}

struct MeshBuilder {

    static func marchingCubesColored(
        tsdf: [Float], weights: [Float], voxelColors: [SIMD3<Float>],
        nx: Int, ny: Int, nz: Int,
        minPt: SIMD3<Float>, voxelSize: Float,
        verts: inout [SIMD3<Float>], vertColors: inout [SIMD3<Float>],
        indices: inout [UInt32])
    {
        let isoVal: Float = 0.0
        func idx(_ x:Int,_ y:Int,_ z:Int)->Int { x + y*nx + z*nx*ny }
        func voxColor(_ x:Int,_ y:Int,_ z:Int)->SIMD3<Float> {
            let i=idx(x,y,z); return voxelColors.indices.contains(i) ? voxelColors[i] : .zero
        }
        var edgeTable = [Int](repeating:0, count:256)
        var triTable  = [[Int]](repeating:[], count:256)
        buildMarchingCubesTables(edgeTable: &edgeTable, triTable: &triTable)
        var edgeVerts = [String: UInt32]()
        func getOrAdd(_ p0: SIMD3<Float>,_ p1: SIMD3<Float>,_ c0: SIMD3<Float>,_ c1: SIMD3<Float>,_ v0: Float,_ v1: Float) -> UInt32 {
            let key = "\(p0.x),\(p0.y),\(p0.z)-\(p1.x),\(p1.y),\(p1.z)"
            if let existing = edgeVerts[key] { return existing }
            let denom = v1 - v0
            let t: Float = abs(denom) > 1e-9 ? (isoVal - v0) / denom : 0.5
            let pt = p0 + t * (p1 - p0)
            let cl = c0 + t * (c1 - c0)
            let idx32 = UInt32(verts.count)
            verts.append(pt); vertColors.append(cl)
            edgeVerts[key] = idx32
            return idx32
        }
        for iz in 0..<(nz-1) {
            for iy in 0..<(ny-1) {
                for ix in 0..<(nx-1) {
                    let corners: [(Int,Int,Int)] = [
                        (ix,iy,iz),(ix+1,iy,iz),(ix+1,iy+1,iz),(ix,iy+1,iz),
                        (ix,iy,iz+1),(ix+1,iy,iz+1),(ix+1,iy+1,iz+1),(ix,iy+1,iz+1)]
                    // Only triangulate where at least one corner is observed AND has negative TSDF
                    // Require at least one corner with weight>=2 and negative TSDF
                    // AND at least one corner with positive TSDF (real zero crossing)
                    var hasNeg = false; var hasPos = false; var hasUnobs = false
                    for (_,(cx,cy,cz)) in corners.enumerated() {
                        let ii = idx(cx,cy,cz)
                        if weights[ii] == 0 { hasUnobs = true }
                        if weights[ii] >= 1 && tsdf[ii] < -0.0005 { hasNeg = true }
                        if weights[ii] >= 1 && tsdf[ii] > 0.0005 { hasPos = true }
                    }
                    guard hasNeg && hasPos && !hasUnobs else { continue }
                    var cubeIdx = 0
                    for (i,(cx,cy,cz)) in corners.enumerated() {
                        let ii = idx(cx,cy,cz)
                        if weights[ii] >= 2 && tsdf[ii] < isoVal { cubeIdx |= (1<<i) }
                    }
                    if edgeTable[cubeIdx] == 0 { continue }
                    let pts = corners.map { (cx,cy,cz) -> SIMD3<Float> in
                        minPt + SIMD3<Float>(Float(cx)*voxelSize, Float(cy)*voxelSize, Float(cz)*voxelSize)
                    }
                    let vals = corners.map { (cx,cy,cz) -> Float in tsdf[idx(cx,cy,cz)] }
                    let cols = corners.map { (cx,cy,cz) -> SIMD3<Float> in voxColor(cx,cy,cz) }
                    let edgePairs = [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]
                    var ev = [UInt32](repeating: 0, count: 12)
                    for (e,(a,b)) in edgePairs.enumerated() {
                        if edgeTable[cubeIdx] & (1<<e) != 0 {
                            ev[e] = getOrAdd(pts[a],pts[b],cols[a],cols[b],vals[a],vals[b])
                        }
                    }
                    let tris = triTable[cubeIdx]
                    var t = 0
                    while t < tris.count {
                        indices.append(ev[tris[t]]); indices.append(ev[tris[t+1]]); indices.append(ev[tris[t+2]])
                        t += 3
                    }
                }
            }
        }
    }

    // Keeps connected mesh pieces with at least minFraction of the largest piece's triangles
    // (never fewer than 100 unless the whole mesh is smaller) and compacts the vertex arrays.
    static func keepMainPieces(
        verts: inout [SIMD3<Float>], normals: inout [SIMD3<Float>],
        vertColors: inout [SIMD3<Float>], indices: inout [UInt32], minFraction: Float)
    {
        let triCount = indices.count / 3
        if triCount == 0 || verts.isEmpty { return }
        var parent = [Int](repeating: 0, count: verts.count)
        for i in 0..<verts.count { parent[i] = i }
        func find(_ a: Int) -> Int {
            var x = a
            while true {
                let p = parent[x]
                if p == x { return x }
                let g = parent[p]
                parent[x] = g
                x = g
            }
        }
        for t in 0..<triCount {
            let ra = find(Int(indices[t * 3]))
            let rb = find(Int(indices[t * 3 + 1]))
            if ra == rb { } else { parent[rb] = ra }
            let rc = find(Int(indices[t * 3 + 2]))
            if rc == ra { } else { parent[rc] = ra }
        }
        var triPerRoot = [Int](repeating: 0, count: verts.count)
        for t in 0..<triCount { triPerRoot[find(Int(indices[t * 3]))] += 1 }
        let largest = triPerRoot.max() ?? 0
        let threshold = min(largest, max(100, Int(Float(largest) * minFraction)))

        var remap = [Int32](repeating: -1, count: verts.count)
        var nv = [SIMD3<Float>](), nn = [SIMD3<Float>](), nc = [SIMD3<Float>]()
        var ni = [UInt32]()
        ni.reserveCapacity(indices.count)
        func emit(_ i: Int) {
            if remap[i] < 0 {
                remap[i] = Int32(nv.count)
                nv.append(verts[i]); nn.append(normals[i]); nc.append(vertColors[i])
            }
            ni.append(UInt32(remap[i]))
        }
        for t in 0..<triCount {
            let i0 = Int(indices[t * 3]), i1 = Int(indices[t * 3 + 1]), i2 = Int(indices[t * 3 + 2])
            if triPerRoot[find(i0)] < threshold { continue }
            emit(i0); emit(i1); emit(i2)
        }
        verts = nv; normals = nn; vertColors = nc; indices = ni
    }

    // Plain marching cubes at level 0 over the WHOLE volume (skimage.measure.marching_cubes, as in andyzeng's get_mesh)
    static func marchingCubesFaithful(
        tsdf: [Float], colors: [SIMD3<Float>],
        nx: Int, ny: Int, nz: Int,
        origin: SIMD3<Float>, voxelSize: Float,
        verts: inout [SIMD3<Float>], normals: inout [SIMD3<Float>],
        vertColors: inout [SIMD3<Float>], indices: inout [UInt32])
    {
        var edgeTable = [Int](repeating: 0, count: 256)
        var triTable  = [[Int]](repeating: [], count: 256)
        buildMarchingCubesTables(edgeTable: &edgeTable, triTable: &triTable)

        let cox: [Int] = [0, 1, 1, 0, 0, 1, 1, 0]
        let coy: [Int] = [0, 0, 1, 1, 0, 0, 1, 1]
        let coz: [Int] = [0, 0, 0, 0, 1, 1, 1, 1]
        let ea:  [Int] = [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3]
        let eb:  [Int] = [1, 2, 3, 0, 5, 6, 7, 4, 4, 5, 6, 7]
        let slab = nx * ny
        func vi(_ x: Int, _ y: Int, _ z: Int) -> Int { return x + y * nx + z * slab }
        func grad(_ x: Int, _ y: Int, _ z: Int) -> SIMD3<Float> {
            let x0 = max(x - 1, 0), x1 = min(x + 1, nx - 1)
            let y0 = max(y - 1, 0), y1 = min(y + 1, ny - 1)
            let z0 = max(z - 1, 0), z1 = min(z + 1, nz - 1)
            return SIMD3<Float>(tsdf[vi(x1, y, z)] - tsdf[vi(x0, y, z)],
                                tsdf[vi(x, y1, z)] - tsdf[vi(x, y0, z)],
                                tsdf[vi(x, y, z1)] - tsdf[vi(x, y, z0)])
        }

        // Only cubes touching at least one inside (negative) voxel can contain surface. Flag those cubes first so the
        // main loop skips empty space with one byte read. The triangles produced are exactly the same as before.
        var cubeFlag = [Bool](repeating: false, count: nx * ny * nz)
        for z in 0..<nz {
            for y in 0..<ny {
                for x in 0..<nx {
                    if tsdf[vi(x, y, z)] < 0 {
                        for qz in max(0, z - 1)...min(z, nz - 2) {
                            for qy in max(0, y - 1)...min(y, ny - 2) {
                                for qx in max(0, x - 1)...min(x, nx - 2) {
                                    cubeFlag[vi(qx, qy, qz)] = true
                                }
                            }
                        }
                    }
                }
            }
        }
        var edgeVert = [Int: UInt32]()
        edgeVert.reserveCapacity(150_000)
        var ev = [UInt32](repeating: 0, count: 12)
        var val = [Float](repeating: 0, count: 8)

        for z in 0..<(nz - 1) {
            for y in 0..<(ny - 1) {
                for x in 0..<(nx - 1) {
                    if cubeFlag[vi(x, y, z)] == false { continue }
                    var cubeIdx = 0
                    for c in 0..<8 {
                        let v = tsdf[vi(x + cox[c], y + coy[c], z + coz[c])]
                        val[c] = v
                        if v < 0 { cubeIdx |= (1 << c) }
                    }
                    let edges = edgeTable[cubeIdx]
                    if edges == 0 { continue }

                    for e in 0..<12 where (edges & (1 << e)) != 0 {
                        let a = ea[e], b = eb[e]
                        let ax = x + cox[a], ay = y + coy[a], az = z + coz[a]
                        let bx = x + cox[b], by = y + coy[b], bz = z + coz[b]
                        let lx = min(ax, bx), ly = min(ay, by), lz = min(az, bz)
                        let axis = (ax != bx) ? 0 : ((ay != by) ? 1 : 2)
                        let key = vi(lx, ly, lz) * 3 + axis
                        if let existing = edgeVert[key] { ev[e] = existing; continue }

                        let v0 = val[a], v1 = val[b]
                        let denom = v1 - v0
                        let t: Float = abs(denom) > 1e-9 ? (0 - v0) / denom : 0.5
                        let pa = SIMD3<Float>(Float(ax), Float(ay), Float(az))
                        let pb = SIMD3<Float>(Float(bx), Float(by), Float(bz))
                        let pos = origin + voxelSize * (pa + t * (pb - pa))
                        let ga = grad(ax, ay, az), gb = grad(bx, by, bz)
                        var n = ga + t * (gb - ga)
                        let nl = simd_length(n)
                        n = nl > 1e-9 ? n / nl : SIMD3<Float>(0, 1, 0)
                        let nearest = t < 0.5 ? vi(ax, ay, az) : vi(bx, by, bz)

                        let id = UInt32(verts.count)
                        verts.append(pos); normals.append(n); vertColors.append(colors[nearest])
                        edgeVert[key] = id
                        ev[e] = id
                    }

                    let tri = triTable[cubeIdx]
                    var k = 0
                    while k + 2 < tri.count {
                        let i0 = ev[tri[k]], i1 = ev[tri[k + 1]], i2 = ev[tri[k + 2]]
                        k += 3
                        if i0 == i1 || i1 == i2 || i0 == i2 { continue }
                        let p0 = verts[Int(i0)], p1 = verts[Int(i1)], p2 = verts[Int(i2)]
                        let gn = simd_cross(p1 - p0, p2 - p0)
                        let vn = normals[Int(i0)] + normals[Int(i1)] + normals[Int(i2)]
                        if simd_dot(gn, vn) >= 0 {
                            indices.append(i0); indices.append(i1); indices.append(i2)
                        } else {
                            indices.append(i0); indices.append(i2); indices.append(i1)
                        }
                    }
                }
            }
        }
    }

    static func capOpenBoundaryPublic(vertices: inout [SIMD3<Float>], indices: inout [UInt32]) {
        var edgeCount = [String: Int]()
        var edgeVerts  = [String: (UInt32,UInt32)]()
        for t in 0..<(indices.count/3) {
            let a=indices[t*3],b=indices[t*3+1],c=indices[t*3+2]
            for (e0,e1) in [(a,b),(b,c),(c,a)] {
                let k = e0<e1 ? "\(e0)-\(e1)" : "\(e1)-\(e0)"
                edgeCount[k, default:0] += 1
                edgeVerts[k] = (e0,e1)
            }
        }
        var boundaryAdj = [UInt32:[UInt32]]()
        for (k,cnt) in edgeCount where cnt==1 {
            let (a,b) = edgeVerts[k]!
            boundaryAdj[a, default:[]].append(b)
            boundaryAdj[b, default:[]].append(a)
        }
        guard !boundaryAdj.isEmpty else { return }
        var visited = Set<UInt32>()
        var loops = [[UInt32]]()
        for start in boundaryAdj.keys {
            guard !visited.contains(start) else { continue }
            var loop=[UInt32](); var cur=start; var prev: UInt32? = nil
            while true {
                loop.append(cur); visited.insert(cur)
                guard let neighbors=boundaryAdj[cur] else { break }
                let nxt = neighbors.first(where:{$0 != prev && !visited.contains($0)})
                if let n=nxt { prev=cur; cur=n } else { break }
            }
            if loop.count > 2 { loops.append(loop) }
        }
        guard let bigLoop = loops.max(by:{$0.count < $1.count}) else { return }
        var centroid = SIMD3<Float>.zero
        for i in bigLoop { centroid += vertices[Int(i)] }
        centroid /= Float(bigLoop.count)
        let cIdx = UInt32(vertices.count)
        vertices.append(centroid)
        for i in 0..<bigLoop.count {
            let a=bigLoop[i], b=bigLoop[(i+1)%bigLoop.count]
            indices.append(a); indices.append(cIdx); indices.append(b)
        }
    }

    static func triNormalPublic(_ a: SIMD3<Float>,_ b: SIMD3<Float>,_ c: SIMD3<Float>) -> SIMD3<Float> {
        simd_normalize(simd_cross(b-a, c-a))
    }

    static func buildSCNGeometryColored(
        vertices: [SIMD3<Float>], normals: [SIMD3<Float>],
        vertColors: [SIMD3<Float>], indices: [UInt32]) -> SCNGeometry
    {
        // SIMD3<Float> is 16 bytes in memory (x,y,z + padding) but SceneKit is told 12 bytes per vertex,
        // so pack tightly as x,y,z floats.
        func pack(_ a: [SIMD3<Float>]) -> Data {
            var f = [Float]()
            f.reserveCapacity(a.count * 3)
            for v in a { f.append(v.x); f.append(v.y); f.append(v.z) }
            return f.withUnsafeBytes { Data($0) }
        }
        let vData = pack(vertices)
        let nData = pack(normals)
        let cData = pack(vertColors)
        let iData = indices.withUnsafeBytes   { Data($0) }
        let vSrc  = SCNGeometrySource(data:vData, semantic:.vertex,   vectorCount:vertices.count,  usesFloatComponents:true, componentsPerVector:3, bytesPerComponent:4, dataOffset:0, dataStride:12)
        let nSrc  = SCNGeometrySource(data:nData, semantic:.normal,   vectorCount:normals.count,   usesFloatComponents:true, componentsPerVector:3, bytesPerComponent:4, dataOffset:0, dataStride:12)
        let cSrc  = SCNGeometrySource(data:cData, semantic:.color,    vectorCount:vertColors.count,usesFloatComponents:true, componentsPerVector:3, bytesPerComponent:4, dataOffset:0, dataStride:12)
        let elem  = SCNGeometryElement(data:iData, primitiveType:.triangles, primitiveCount:indices.count/3, bytesPerIndex:4)
        let geo   = SCNGeometry(sources:[vSrc,nSrc,cSrc], elements:[elem])
        let mat   = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents  = UIColor.white
        mat.roughness.contents = 0.6
        mat.metalness.contents = 0.0
        geo.materials = [mat]
        return geo
    }

    static func exportSTL(from geometry: SCNGeometry, footSide: String) -> URL? {
        guard let vSrc = geometry.sources(for:.vertex).first,
              let elem  = geometry.elements.first else { return nil }
        var verts = [SIMD3<Float>]()
        let vData  = vSrc.data
        let stride = vSrc.dataStride, offset = vSrc.dataOffset
        for i in 0..<vSrc.vectorCount {
            let base = i*stride+offset
            var v = SIMD3<Float>.zero
            vData.withUnsafeBytes { ptr in
                v.x = ptr.load(fromByteOffset:base,   as:Float.self)
                v.y = ptr.load(fromByteOffset:base+4, as:Float.self)
                v.z = ptr.load(fromByteOffset:base+8, as:Float.self)
            }
            verts.append(v)
        }
        var tris = [SIMD3<UInt32>]()
        let iData = elem.data; let bpi = elem.bytesPerIndex
        for t in 0..<elem.primitiveCount {
            var tri = SIMD3<UInt32>.zero
            iData.withUnsafeBytes { ptr in
                if bpi==4 {
                    tri.x = ptr.load(fromByteOffset:(t*3+0)*4, as:UInt32.self)
                    tri.y = ptr.load(fromByteOffset:(t*3+1)*4, as:UInt32.self)
                    tri.z = ptr.load(fromByteOffset:(t*3+2)*4, as:UInt32.self)
                } else {
                    tri.x = UInt32(ptr.load(fromByteOffset:(t*3+0)*2, as:UInt16.self))
                    tri.y = UInt32(ptr.load(fromByteOffset:(t*3+1)*2, as:UInt16.self))
                    tri.z = UInt32(ptr.load(fromByteOffset:(t*3+2)*2, as:UInt16.self))
                }
            }
            tris.append(tri)
        }
        // ARKit works in metres; write the STL in millimetres (x1000). In Fusion pick Millimeter in the Insert Mesh dialog.
        verts = verts.map { $0 * 1000.0 }
        var stl = "solid foot\n"
        for tri in tris {
            let a=verts[Int(tri.x)],b=verts[Int(tri.y)],c=verts[Int(tri.z)]
            let n=simd_normalize(simd_cross(b-a,c-a))
            stl += "  facet normal \(n.x) \(n.y) \(n.z)\n    outer loop\n"
            stl += "      vertex \(a.x) \(a.y) \(a.z)\n"
            stl += "      vertex \(b.x) \(b.y) \(b.z)\n"
            stl += "      vertex \(c.x) \(c.y) \(c.z)\n"
            stl += "    endloop\n  endfacet\n"
        }
        stl += "endsolid foot\n"
        let dir = FileManager.default.urls(for:.documentDirectory, in:.userDomainMask)[0]
        let url = dir.appendingPathComponent("scan_\(footSide).stl")
        try? stl.write(to:url, atomically:true, encoding:.utf8)
        return url
    }

    private static func buildMarchingCubesTables(edgeTable: inout [Int], triTable: inout [[Int]]) {
        edgeTable[0]=0x000;edgeTable[1]=0x109;edgeTable[2]=0x203;edgeTable[3]=0x30a
        edgeTable[4]=0x406;edgeTable[5]=0x50f;edgeTable[6]=0x605;edgeTable[7]=0x70c
        edgeTable[8]=0x80c;edgeTable[9]=0x905;edgeTable[10]=0xa0f;edgeTable[11]=0xb06
        edgeTable[12]=0xc0a;edgeTable[13]=0xd03;edgeTable[14]=0xe09;edgeTable[15]=0xf00
        edgeTable[16]=0x190;edgeTable[17]=0x099;edgeTable[18]=0x393;edgeTable[19]=0x29a
        edgeTable[20]=0x596;edgeTable[21]=0x49f;edgeTable[22]=0x795;edgeTable[23]=0x69c
        edgeTable[24]=0x99c;edgeTable[25]=0x895;edgeTable[26]=0xb9f;edgeTable[27]=0xa96
        edgeTable[28]=0xd9a;edgeTable[29]=0xc93;edgeTable[30]=0xf99;edgeTable[31]=0xe90
        edgeTable[32]=0x230;edgeTable[33]=0x339;edgeTable[34]=0x033;edgeTable[35]=0x13a
        edgeTable[36]=0x636;edgeTable[37]=0x73f;edgeTable[38]=0x435;edgeTable[39]=0x53c
        edgeTable[40]=0xa3c;edgeTable[41]=0xb35;edgeTable[42]=0x83f;edgeTable[43]=0x936
        edgeTable[44]=0xe3a;edgeTable[45]=0xf33;edgeTable[46]=0xc39;edgeTable[47]=0xd30
        edgeTable[48]=0x3a0;edgeTable[49]=0x2a9;edgeTable[50]=0x1a3;edgeTable[51]=0x0aa
        edgeTable[52]=0x7a6;edgeTable[53]=0x6af;edgeTable[54]=0x5a5;edgeTable[55]=0x4ac
        edgeTable[56]=0xbac;edgeTable[57]=0xaa5;edgeTable[58]=0x9af;edgeTable[59]=0x8a6
        edgeTable[60]=0xfaa;edgeTable[61]=0xea3;edgeTable[62]=0xda9;edgeTable[63]=0xca0
        edgeTable[64]=0x460;edgeTable[65]=0x569;edgeTable[66]=0x663;edgeTable[67]=0x76a
        edgeTable[68]=0x066;edgeTable[69]=0x16f;edgeTable[70]=0x265;edgeTable[71]=0x36c
        edgeTable[72]=0xc6c;edgeTable[73]=0xd65;edgeTable[74]=0xe6f;edgeTable[75]=0xf66
        edgeTable[76]=0x86a;edgeTable[77]=0x963;edgeTable[78]=0xa69;edgeTable[79]=0xb60
        edgeTable[80]=0x5f0;edgeTable[81]=0x4f9;edgeTable[82]=0x7f3;edgeTable[83]=0x6fa
        edgeTable[84]=0x1f6;edgeTable[85]=0x0ff;edgeTable[86]=0x3f5;edgeTable[87]=0x2fc
        edgeTable[88]=0xdfc;edgeTable[89]=0xcf5;edgeTable[90]=0xfff;edgeTable[91]=0xef6
        edgeTable[92]=0x9fa;edgeTable[93]=0x8f3;edgeTable[94]=0xbf9;edgeTable[95]=0xaf0
        edgeTable[96]=0x650;edgeTable[97]=0x759;edgeTable[98]=0x453;edgeTable[99]=0x55a
        edgeTable[100]=0x256;edgeTable[101]=0x35f;edgeTable[102]=0x055;edgeTable[103]=0x15c
        edgeTable[104]=0xe5c;edgeTable[105]=0xf55;edgeTable[106]=0xc5f;edgeTable[107]=0xd56
        edgeTable[108]=0xa5a;edgeTable[109]=0xb53;edgeTable[110]=0x859;edgeTable[111]=0x950
        edgeTable[112]=0x7c0;edgeTable[113]=0x6c9;edgeTable[114]=0x5c3;edgeTable[115]=0x4ca
        edgeTable[116]=0x3c6;edgeTable[117]=0x2cf;edgeTable[118]=0x1c5;edgeTable[119]=0x0cc
        edgeTable[120]=0xfcc;edgeTable[121]=0xec5;edgeTable[122]=0xdcf;edgeTable[123]=0xcc6
        edgeTable[124]=0xbca;edgeTable[125]=0xac3;edgeTable[126]=0x9c9;edgeTable[127]=0x8c0
        edgeTable[128]=0x8c0;edgeTable[129]=0x9c9;edgeTable[130]=0xac3;edgeTable[131]=0xbca
        edgeTable[132]=0xcc6;edgeTable[133]=0xdcf;edgeTable[134]=0xec5;edgeTable[135]=0xfcc
        edgeTable[136]=0x0cc;edgeTable[137]=0x1c5;edgeTable[138]=0x2cf;edgeTable[139]=0x3c6
        edgeTable[140]=0x4ca;edgeTable[141]=0x5c3;edgeTable[142]=0x6c9;edgeTable[143]=0x7c0
        edgeTable[144]=0x950;edgeTable[145]=0x859;edgeTable[146]=0xb53;edgeTable[147]=0xa5a
        edgeTable[148]=0xd56;edgeTable[149]=0xc5f;edgeTable[150]=0xf55;edgeTable[151]=0xe5c
        edgeTable[152]=0x15c;edgeTable[153]=0x055;edgeTable[154]=0x35f;edgeTable[155]=0x256
        edgeTable[156]=0x55a;edgeTable[157]=0x453;edgeTable[158]=0x759;edgeTable[159]=0x650
        edgeTable[160]=0xaf0;edgeTable[161]=0xbf9;edgeTable[162]=0x8f3;edgeTable[163]=0x9fa
        edgeTable[164]=0xef6;edgeTable[165]=0xfff;edgeTable[166]=0xcf5;edgeTable[167]=0xdfc
        edgeTable[168]=0x2fc;edgeTable[169]=0x3f5;edgeTable[170]=0x0ff;edgeTable[171]=0x1f6
        edgeTable[172]=0x6fa;edgeTable[173]=0x7f3;edgeTable[174]=0x4f9;edgeTable[175]=0x5f0
        edgeTable[176]=0xb60;edgeTable[177]=0xa69;edgeTable[178]=0x963;edgeTable[179]=0x86a
        edgeTable[180]=0xf66;edgeTable[181]=0xe6f;edgeTable[182]=0xd65;edgeTable[183]=0xc6c
        edgeTable[184]=0x36c;edgeTable[185]=0x265;edgeTable[186]=0x16f;edgeTable[187]=0x066
        edgeTable[188]=0x76a;edgeTable[189]=0x663;edgeTable[190]=0x569;edgeTable[191]=0x460
        edgeTable[192]=0xca0;edgeTable[193]=0xda9;edgeTable[194]=0xea3;edgeTable[195]=0xfaa
        edgeTable[196]=0x8a6;edgeTable[197]=0x9af;edgeTable[198]=0xaa5;edgeTable[199]=0xbac
        edgeTable[200]=0x4ac;edgeTable[201]=0x5a5;edgeTable[202]=0x6af;edgeTable[203]=0x7a6
        edgeTable[204]=0x0aa;edgeTable[205]=0x1a3;edgeTable[206]=0x2a9;edgeTable[207]=0x3a0
        edgeTable[208]=0xd30;edgeTable[209]=0xc39;edgeTable[210]=0xf33;edgeTable[211]=0xe3a
        edgeTable[212]=0x936;edgeTable[213]=0x83f;edgeTable[214]=0xb35;edgeTable[215]=0xa3c
        edgeTable[216]=0x53c;edgeTable[217]=0x435;edgeTable[218]=0x73f;edgeTable[219]=0x636
        edgeTable[220]=0x13a;edgeTable[221]=0x033;edgeTable[222]=0x339;edgeTable[223]=0x230
        edgeTable[224]=0xe90;edgeTable[225]=0xf99;edgeTable[226]=0xc93;edgeTable[227]=0xd9a
        edgeTable[228]=0xa96;edgeTable[229]=0xb9f;edgeTable[230]=0x895;edgeTable[231]=0x99c
        edgeTable[232]=0x69c;edgeTable[233]=0x795;edgeTable[234]=0x49f;edgeTable[235]=0x596
        edgeTable[236]=0x29a;edgeTable[237]=0x393;edgeTable[238]=0x099;edgeTable[239]=0x190
        edgeTable[240]=0xf00;edgeTable[241]=0xe09;edgeTable[242]=0xd03;edgeTable[243]=0xc0a
        edgeTable[244]=0xb06;edgeTable[245]=0xa0f;edgeTable[246]=0x905;edgeTable[247]=0x80c
        edgeTable[248]=0x70c;edgeTable[249]=0x605;edgeTable[250]=0x50f;edgeTable[251]=0x406
        edgeTable[252]=0x30a;edgeTable[253]=0x203;edgeTable[254]=0x109;edgeTable[255]=0x000
        let rawTri: [[Int]] = [
            [],[0,8,3],[0,1,9],[1,8,3,9,8,1],
            [1,2,10],[0,8,3,1,2,10],[9,2,10,0,2,9],[2,8,3,2,10,8,10,9,8],
            [3,11,2],[0,11,2,8,11,0],[1,9,0,2,3,11],[1,11,2,1,9,11,9,8,11],
            [3,10,1,11,10,3],[0,10,1,0,8,10,8,11,10],[3,9,0,3,11,9,11,10,9],[9,8,10,10,8,11],
            [4,7,8],[4,3,0,7,3,4],[0,1,9,8,4,7],[4,1,9,4,7,1,7,3,1],
            [1,2,10,8,4,7],[3,4,7,3,0,4,1,2,10],[9,2,10,9,0,2,8,4,7],[2,10,9,2,9,7,2,7,3,7,9,4],
            [8,4,7,3,11,2],[11,4,7,11,2,4,2,0,4],[9,0,1,8,4,7,2,3,11],[4,7,11,9,4,11,9,11,2,9,2,1],
            [3,10,1,3,11,10,7,8,4],[1,11,10,1,4,11,1,0,4,7,11,4],[4,7,8,9,0,11,9,11,10,11,0,3],[4,7,11,4,11,9,9,11,10],
            [9,5,4],[9,5,4,0,8,3],[0,5,4,1,5,0],[8,5,4,8,3,5,3,1,5],
            [1,2,10,9,5,4],[3,0,8,1,2,10,4,9,5],[5,2,10,5,4,2,4,0,2],[2,10,5,3,2,5,3,5,4,3,4,8],
            [9,5,4,2,3,11],[0,11,2,0,8,11,4,9,5],[0,5,4,0,1,5,2,3,11],[2,1,5,2,5,8,2,8,11,4,8,5],
            [10,3,11,10,1,3,9,5,4],[4,9,5,0,8,1,8,10,1,8,11,10],[5,4,0,5,0,11,5,11,10,11,0,3],[5,4,8,5,8,10,10,8,11],
            [9,7,8,5,7,9],[9,3,0,9,5,3,5,7,3],[0,7,8,0,1,7,1,5,7],[1,5,3,3,5,7],
            [9,7,8,9,5,7,10,1,2],[10,1,2,9,5,0,5,3,0,5,7,3],[8,0,2,8,2,5,8,5,7,10,5,2],[2,10,5,2,5,3,3,5,7],
            [7,9,5,7,8,9,3,11,2],[9,5,7,9,7,2,9,2,0,2,7,11],[2,3,11,0,1,8,1,7,8,1,5,7],[11,2,1,11,1,7,7,1,5],
            [9,5,8,8,5,7,10,1,3,10,3,11],[5,7,0,5,0,9,7,11,0,1,0,10,11,10,0],[11,10,0,11,0,3,10,5,0,8,0,7,5,7,0],[11,10,5,7,11,5],
            [10,6,5],[0,8,3,5,10,6],[9,0,1,5,10,6],[1,8,3,1,9,8,5,10,6],
            [1,6,5,2,6,1],[1,6,5,1,2,6,3,0,8],[9,6,5,9,0,6,0,2,6],[5,9,8,5,8,2,5,2,6,3,2,8],
            [2,3,11,10,6,5],[11,0,8,11,2,0,10,6,5],[0,1,9,2,3,11,5,10,6],[5,10,6,1,9,2,9,11,2,9,8,11],
            [6,3,11,6,5,3,5,1,3],[0,8,11,0,11,5,0,5,1,5,11,6],[3,11,6,0,3,6,0,6,5,0,5,9],[6,5,9,6,9,11,11,9,8],
            [5,10,6,4,7,8],[4,3,0,4,7,3,6,5,10],[1,9,0,5,10,6,8,4,7],[10,6,5,1,9,7,1,7,3,7,9,4],
            [6,1,2,6,5,1,4,7,8],[1,2,5,5,2,6,3,0,4,3,4,7],[8,4,7,9,0,5,0,6,5,0,2,6],[7,3,9,7,9,4,3,2,9,5,9,6,2,6,9],
            [3,11,2,7,8,4,10,6,5],[5,10,6,4,7,2,4,2,0,2,7,11],[0,1,9,4,7,8,2,3,11,5,10,6],[9,2,1,9,11,2,9,4,11,7,11,4,5,10,6],
            [8,4,7,3,11,5,3,5,1,5,11,6],[5,1,11,5,11,6,1,0,11,7,11,4,0,4,11],[0,5,9,0,6,5,0,3,6,11,6,3,8,4,7],[6,5,9,6,9,11,4,7,9,7,11,9],
            [10,4,9,6,4,10],[4,10,6,4,9,10,0,8,3],[10,0,1,10,6,0,6,4,0],[8,3,1,8,1,6,8,6,4,6,1,10],
            [1,4,9,1,2,4,2,6,4],[3,0,8,1,2,9,2,4,9,2,6,4],[0,2,4,4,2,6],[8,3,2,8,2,4,4,2,6],
            [10,4,9,10,6,4,11,2,3],[0,8,2,2,8,11,4,9,10,4,10,6],[3,11,2,0,1,6,0,6,4,6,1,10],[6,4,1,6,1,10,4,8,1,2,1,11,8,11,1],
            [9,6,4,9,3,6,9,1,3,11,6,3],[8,11,1,8,1,0,11,6,1,9,1,4,6,4,1],[3,11,6,3,6,0,0,6,4],[6,4,8,11,6,8],
            [7,10,6,7,8,10,8,9,10],[0,7,3,0,10,7,0,9,10,6,7,10],[10,6,7,1,10,7,1,7,8,1,8,0],[10,6,7,10,7,1,1,7,3],
            [1,2,6,1,6,8,1,8,9,8,6,7],[2,6,9,2,9,1,6,7,9,0,9,3,7,3,9],[7,8,0,7,0,6,6,0,2],[7,3,2,6,7,2],
            [2,3,11,10,6,8,10,8,9,8,6,7],[2,0,7,2,7,11,0,9,7,6,7,10,9,10,7],[1,8,0,1,7,8,1,10,7,6,7,10,2,3,11],[11,2,1,11,1,7,10,6,1,6,7,1],
            [8,9,6,8,6,7,9,1,6,11,6,3,1,3,6],[0,9,1,11,6,7],[7,8,0,7,0,6,3,11,0,11,6,0],[7,11,6],
            [7,6,11],[3,0,8,11,7,6],[0,1,9,11,7,6],[8,1,9,8,3,1,11,7,6],
            [10,1,2,6,11,7],[1,2,10,3,0,8,6,11,7],[2,9,0,2,10,9,6,11,7],[6,11,7,2,10,3,10,8,3,10,9,8],
            [7,2,3,6,2,7],[7,0,8,7,6,0,6,2,0],[2,7,6,2,3,7,0,1,9],[1,6,2,1,8,6,1,9,8,8,7,6],
            [10,7,6,10,1,7,1,3,7],[10,7,6,1,7,10,1,8,7,1,0,8],[0,3,7,0,7,10,0,10,9,6,10,7],[7,6,10,7,10,8,8,10,9],
            [6,8,4,11,8,6],[3,6,11,3,0,6,0,4,6],[8,6,11,8,4,6,9,0,1],[9,4,6,9,6,3,9,3,1,11,3,6],
            [6,8,4,6,11,8,2,10,1],[1,2,10,3,0,11,0,6,11,0,4,6],[4,11,8,4,6,11,0,2,9,2,10,9],[10,9,3,10,3,2,9,4,3,11,3,6,4,6,3],
            [8,2,3,8,4,2,4,6,2],[0,4,2,4,6,2],[1,9,0,2,3,4,2,4,6,4,3,8],[1,9,4,1,4,2,2,4,6],
            [8,1,3,8,6,1,8,4,6,6,10,1],[10,1,0,10,0,6,6,0,4],[4,6,3,4,3,8,6,10,3,0,3,9,10,9,3],[10,9,4,6,10,4],
            [4,9,5,7,6,11],[0,8,3,4,9,5,11,7,6],[5,0,1,5,4,0,7,6,11],[11,7,6,8,3,4,3,5,4,3,1,5],
            [9,5,4,10,1,2,7,6,11],[6,11,7,1,2,10,0,8,3,4,9,5],[7,6,11,5,4,10,4,2,10,4,0,2],[3,4,8,3,5,4,3,2,5,10,5,2,11,7,6],
            [7,2,3,7,6,2,5,4,9],[9,5,4,0,8,6,0,6,2,6,8,7],[3,6,2,3,7,6,1,5,0,5,4,0],[6,2,8,6,8,7,2,1,8,4,8,5,1,5,8],
            [9,5,4,10,1,6,1,7,6,1,3,7],[1,6,10,1,7,6,1,0,7,8,7,0,9,5,4],[4,0,10,4,10,5,0,3,10,6,10,7,3,7,10],[7,6,10,7,10,8,5,4,10,4,8,10],
            [6,9,5,6,11,9,11,8,9],[3,6,11,0,6,3,0,5,6,0,9,5],[0,11,8,0,5,11,0,1,5,5,6,11],[6,11,3,6,3,5,5,3,1],
            [1,2,10,9,5,11,9,11,8,11,5,6],[0,11,3,0,6,11,0,9,6,5,6,9,1,2,10],[11,8,5,11,5,6,8,0,5,10,5,2,0,2,5],[6,11,3,6,3,5,2,10,3,10,5,3],
            [5,8,9,5,2,8,5,6,2,3,8,2],[9,5,6,9,6,0,0,6,2],[1,5,8,1,8,0,5,6,8,3,8,2,6,2,8],[1,5,6,2,1,6],
            [1,3,6,1,6,10,3,8,6,5,6,9,8,9,6],[10,1,0,10,0,6,9,5,0,5,6,0],[0,3,8,5,6,10],[10,5,6],
            [11,5,10,7,5,11],[11,5,10,11,7,5,8,3,0],[5,11,7,5,10,11,1,9,0],[10,7,5,10,11,7,9,8,1,8,3,1],
            [11,1,2,11,7,1,7,5,1],[0,8,3,1,2,7,1,7,5,7,2,11],[9,7,5,9,2,7,9,0,2,2,11,7],[7,5,2,7,2,11,5,9,2,3,2,8,9,8,2],
            [2,5,10,2,3,5,3,7,5],[8,2,0,8,5,2,8,7,5,10,2,5],[9,0,1,5,10,3,5,3,7,3,10,2],[9,8,2,9,2,1,8,7,2,10,2,5,7,5,2],
            [1,3,5,3,7,5],[0,8,7,0,7,1,1,7,5],[9,0,3,9,3,5,5,3,7],[9,8,7,5,9,7],
            [5,8,4,5,10,8,10,11,8],[5,0,4,5,11,0,5,10,11,11,3,0],[0,1,9,8,4,10,8,10,11,10,4,5],[10,11,4,10,4,5,11,3,4,9,4,1,3,1,4],
            [2,5,1,2,8,5,2,11,8,4,5,8],[0,4,11,0,11,3,4,5,11,2,11,1,5,1,11],[0,2,5,0,5,9,2,11,5,4,5,8,11,8,5],[9,4,5,2,11,3],
            [2,5,10,3,5,2,3,4,5,3,8,4],[5,10,2,5,2,4,4,2,0],[3,10,2,3,5,10,3,8,5,4,5,8,0,1,9],[5,10,2,5,2,4,1,9,2,9,4,2],
            [8,4,5,8,5,3,3,5,1],[0,4,5,1,0,5],[8,4,5,8,5,3,9,0,5,0,3,5],[9,4,5],
            [4,11,7,4,9,11,9,10,11],[0,8,3,4,9,7,9,11,7,9,10,11],[1,10,11,1,11,4,1,4,0,7,4,11],[3,1,4,3,4,8,1,10,4,7,4,11,10,11,4],
            [4,11,7,9,11,4,9,2,11,9,1,2],[9,7,4,9,11,7,9,1,11,2,11,1,0,8,3],[11,7,4,11,4,2,2,4,0],[11,7,4,11,4,2,8,3,4,3,2,4],
            [2,9,10,2,7,9,2,3,7,7,4,9],[9,10,7,9,7,4,10,2,7,8,7,0,2,0,7],[3,7,10,3,10,2,7,4,10,1,10,0,4,0,10],[1,10,2,8,7,4],
            [4,9,1,4,1,7,7,1,3],[4,9,1,4,1,7,0,8,1,8,7,1],[4,0,3,7,4,3],[4,8,7],
            [9,10,8,10,11,8],[3,0,9,3,9,11,11,9,10],[0,1,10,0,10,8,8,10,11],[3,1,10,11,3,10],
            [1,2,11,1,11,9,9,11,8],[3,0,9,3,9,11,1,2,9,2,11,9],[0,2,11,8,0,11],[3,2,11],
            [2,3,8,2,8,10,10,8,9],[9,10,2,0,9,2],[2,3,8,2,8,10,0,1,8,1,10,8],[1,10,2],
            [1,3,8,9,1,8],[0,9,1],[0,3,8],[],
        ]
        for (i,t) in rawTri.enumerated() { triTable[i] = t }
    }
}
