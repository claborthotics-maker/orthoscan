import SceneKit
import simd

// MARK: - MeshBuilder
// Takes an unordered world-space point cloud from VoxelGrid and produces:
//   1. A watertight SCNGeometry via a signed-distance-field + marching cubes approach
//   2. Binary STL file named with foot side and timestamp

struct MeshBuilder {

    // Legacy stub kept so existing call sites compile
    static func buildMesh(from points: [SIMD3<Float>]) -> SCNGeometry? { return nil }

    // MARK: - Point-cloud → mesh

    /// Build a mesh from an unordered world-space point cloud.
    /// Rasterises the points into a signed-distance-like occupancy volume,
    /// then runs marching cubes to extract a triangle mesh.
    static func buildMeshFromPoints(_ points: [SIMD3<Float>],
                                     footSide: String = "left") -> SCNGeometry? {
        guard points.count > 100 else { return nil }

        // 1. Compute bounding box with small padding
        let pad: Float = 0.015
        var minPt = points[0]
        var maxPt = points[0]
        for p in points {
            minPt = simd_min(minPt, p)
            maxPt = simd_max(maxPt, p)
        }
        minPt -= SIMD3<Float>(repeating: pad)
        maxPt += SIMD3<Float>(repeating: pad)

        // 2. Build occupancy grid at 3 mm resolution
        let res: Float = 0.004
        let nx = max(2, Int(ceil((maxPt.x - minPt.x) / res)))
        let ny = max(2, Int(ceil((maxPt.y - minPt.y) / res)))
        let nz = max(2, Int(ceil((maxPt.z - minPt.z) / res)))

        // Clamp grid to sane size to avoid OOM
        guard nx * ny * nz < 30_000_000 else {
            print("MeshBuilder: grid too large (\(nx)×\(ny)×\(nz)), bailing")
            return nil
        }

        var occ = [Bool](repeating: false, count: nx * ny * nz)

        func idx(_ ix: Int, _ iy: Int, _ iz: Int) -> Int { ix + nx * (iy + ny * iz) }

        // Mark occupied cells — exact cell only, no dilation
        for p in points {
            let ix = Int((p.x - minPt.x) / res)
            let iy = Int((p.y - minPt.y) / res)
            let iz = Int((p.z - minPt.z) / res)
            guard ix >= 0, ix < nx, iy >= 0, iy < ny, iz >= 0, iz < nz else { continue }
            occ[idx(ix, iy, iz)] = true
        }

        // 2b. Dilation — expand occupied cells before marching cubes
        var dilated = occ
        for iz2 in 0..<nz { for iy2 in 0..<ny { for ix2 in 0..<nx {
            if occ[idx(ix2,iy2,iz2)] {
                for dx in -1...1 { for dy in -1...1 { for dz in -1...1 {
                    let jx=ix2+dx,jy=iy2+dy,jz=iz2+dz
                    guard jx>=0,jx<nx,jy>=0,jy<ny,jz>=0,jz<nz else { continue }
                    dilated[idx(jx,jy,jz)] = true
                }}}
            }
        }}}
        occ = dilated

        // 3. Marching cubes on the occupancy field
        var vertices = [SIMD3<Float>]()
        var indices  = [UInt32]()
        var vertexCache = [SIMD3<Int32>: UInt32]()  // edge midpoint key → vertex index

        func cellCorner(_ ix: Int, _ iy: Int, _ iz: Int) -> SIMD3<Float> {
            return minPt + SIMD3<Float>(Float(ix), Float(iy), Float(iz)) * res
        }

        func isOcc(_ ix: Int, _ iy: Int, _ iz: Int) -> Bool {
            guard ix >= 0, ix < nx, iy >= 0, iy < ny, iz >= 0, iz < nz else { return false }
            return occ[idx(ix, iy, iz)]
        }

        // Cube corner offsets
        let corners: [(Int, Int, Int)] = [
            (0,0,0),(1,0,0),(1,1,0),(0,1,0),
            (0,0,1),(1,0,1),(1,1,1),(0,1,1)
        ]
        // 12 edges: (corner a, corner b)
        let edges: [(Int,Int)] = [
            (0,1),(1,2),(2,3),(3,0),
            (4,5),(5,6),(6,7),(7,4),
            (0,4),(1,5),(2,6),(3,7)
        ]

        func edgeVertex(ix: Int, iy: Int, iz: Int, edgeIdx: Int) -> UInt32 {
            let (ca, cb) = edges[edgeIdx]
            let (ax, ay, az) = corners[ca]
            let (bx, by, bz) = corners[cb]
            // Use lower-index corner as canonical key
            let kx = Int32(ix + min(ax, bx)) * 4 + Int32(edgeIdx)
            let ky = Int32(iy + min(ay, by))
            let kz = Int32(iz + min(az, bz))
            let key = SIMD3<Int32>(kx, ky, kz)
            if let cached = vertexCache[key] { return cached }
            let pa = cellCorner(ix + ax, iy + ay, iz + az)
            let pb = cellCorner(ix + bx, iy + by, iz + bz)
            let midpt = (pa + pb) * 0.5
            let vi = UInt32(vertices.count)
            vertices.append(midpt)
            vertexCache[key] = vi
            return vi
        }

        for iz in 0..<(nz-1) {
            for iy in 0..<(ny-1) {
                for ix in 0..<(nx-1) {
                    // Build cube configuration index
                    var cubeIdx = 0
                    for (bi, (dx, dy, dz)) in corners.enumerated() {
                        if isOcc(ix+dx, iy+dy, iz+dz) { cubeIdx |= (1 << bi) }
                    }
                    if cubeIdx == 0 || cubeIdx == 255 { continue }

                    // Get triangles for this configuration
                    let tris = MarchingCubesTables.triangles[cubeIdx]
                    var ti = 0
                    while ti < tris.count, tris[ti] != -1 {
                        let v0 = edgeVertex(ix: ix, iy: iy, iz: iz, edgeIdx: tris[ti])
                        let v1 = edgeVertex(ix: ix, iy: iy, iz: iz, edgeIdx: tris[ti+1])
                        let v2 = edgeVertex(ix: ix, iy: iy, iz: iz, edgeIdx: tris[ti+2])
                        indices.append(contentsOf: [v0, v1, v2])
                        ti += 3
                    }
                }
            }
        }

        guard vertices.count > 10, !indices.isEmpty else { return nil }

        // Laplacian smoothing — 3 passes
        var smoothed = vertices
        for _ in 0..<10 {
            var sums   = [SIMD3<Float>](repeating: .zero, count: smoothed.count)
            var counts = [Int](repeating: 0, count: smoothed.count)
            var ti2 = 0
            while ti2 < indices.count {
                let a = Int(indices[ti2]), b = Int(indices[ti2+1]), c = Int(indices[ti2+2])
                sums[a] += smoothed[b] + smoothed[c]; counts[a] += 2
                sums[b] += smoothed[a] + smoothed[c]; counts[b] += 2
                sums[c] += smoothed[a] + smoothed[b]; counts[c] += 2
                ti2 += 3
            }
            for i in 0..<smoothed.count {
                if counts[i] > 0 {
                    smoothed[i] = smoothed[i] * 0.5 + (sums[i] / Float(counts[i])) * 0.5
                }
            }
        }

        return buildSCNGeometry(vertices: smoothed, indices: indices)
    }

    // MARK: - Legacy depth-map mesh (kept for reference, not used in new pipeline)

    static func buildMeshFromDepth(depth: [[Float]],
                                   fx: Float, fy: Float,
                                   cx: Float, cy: Float,
                                   minD: Float, maxD: Float,
                                   floorMargin: Float) -> SCNGeometry? {
        let rows = depth.count; guard rows > 0 else { return nil }
        let cols = depth[0].count; guard cols > 0 else { return nil }

        var smoothed = depth
        for r in 1..<(rows-1) {
            for c in 1..<(cols-1) {
                var nb = [Float]()
                for dr in -1...1 { for dc in -1...1 { let v = depth[r+dr][c+dc]; if v > 0 { nb.append(v) } } }
                if nb.count >= 5 { nb.sort(); smoothed[r][c] = nb[nb.count/2] }
            }
        }
        var grid = [[SIMD3<Float>?]](repeating: [SIMD3<Float>?](repeating: nil, count: cols), count: rows)
        for r in 0..<rows { for c in 0..<cols {
            let d = smoothed[r][c]; guard d >= minD && d <= maxD else { continue }
            grid[r][c] = SIMD3<Float>((Float(c)-cx)*d/fx, (Float(r)-cy)*d/fy, d)
        }}
        var allY = grid.flatMap { $0.compactMap { $0?.y } }
        if !allY.isEmpty {
            allY.sort()
            let yThr = allY.first! + (allY.last! - allY.first!) * floorMargin
            for r in 0..<rows { for c in 0..<cols { if let p = grid[r][c], p.y < yThr { grid[r][c] = nil } } }
        }
        var verts = [SIMD3<Float>](); var imap = [[Int]](repeating: [Int](repeating: -1, count: cols), count: rows)
        for r in 0..<rows { for c in 0..<cols { if let p = grid[r][c] { imap[r][c] = verts.count; verts.append(p) } } }
        guard verts.count > 100 else { return nil }
        var idxs = [UInt32]()
        for r in 0..<(rows-1) { for c in 0..<(cols-1) {
            let i00=imap[r][c],i01=imap[r][c+1],i10=imap[r+1][c],i11=imap[r+1][c+1]
            guard i00>=0,i01>=0,i10>=0,i11>=0 else { continue }
            let zs=[verts[i00].z,verts[i01].z,verts[i10].z,verts[i11].z]
            guard (zs.max()!-zs.min()!)<0.015 else { continue }
            idxs.append(contentsOf:[UInt32(i00),UInt32(i10),UInt32(i01),UInt32(i01),UInt32(i10),UInt32(i11)])
        }}
        guard !idxs.isEmpty else { return nil }
        return buildSCNGeometry(vertices: verts, indices: idxs)
    }

    // MARK: - SCNGeometry builder

    private static func buildSCNGeometry(vertices: [SIMD3<Float>], indices: [UInt32]) -> SCNGeometry {
        // Compute per-vertex normals by averaging face normals
        var normals = [SIMD3<Float>](repeating: .zero, count: vertices.count)
        var ti = 0
        while ti < indices.count {
            let a = Int(indices[ti]), b = Int(indices[ti+1]), c = Int(indices[ti+2])
            let e1 = vertices[b] - vertices[a]
            let e2 = vertices[c] - vertices[a]
            let n  = simd_cross(e1, e2)
            normals[a] += n; normals[b] += n; normals[c] += n
            ti += 3
        }
        normals = normals.map { let l = simd_length($0); return l > 0 ? $0 / l : SIMD3<Float>(0,0,1) }

        let vStride = MemoryLayout<SIMD3<Float>>.stride
        let vData   = Data(bytes: vertices, count: vertices.count * vStride)
        let nData   = Data(bytes: normals,  count: normals.count  * vStride)
        let iData   = Data(bytes: indices,  count: indices.count  * MemoryLayout<UInt32>.size)

        let vSrc = SCNGeometrySource(data: vData, semantic: .vertex,
                                      vectorCount: vertices.count, usesFloatComponents: true,
                                      componentsPerVector: 3, bytesPerComponent: 4,
                                      dataOffset: 0, dataStride: vStride)
        let nSrc = SCNGeometrySource(data: nData, semantic: .normal,
                                      vectorCount: normals.count, usesFloatComponents: true,
                                      componentsPerVector: 3, bytesPerComponent: 4,
                                      dataOffset: 0, dataStride: vStride)
        let elem = SCNGeometryElement(data: iData, primitiveType: .triangles,
                                       primitiveCount: indices.count / 3,
                                       bytesPerIndex: MemoryLayout<UInt32>.size)
        let geo  = SCNGeometry(sources: [vSrc, nSrc], elements: [elem])
        let mat  = SCNMaterial()
        mat.diffuse.contents  = UIColor(red: 0.93, green: 0.82, blue: 0.72, alpha: 1)
        mat.specular.contents = UIColor.white
        mat.shininess  = 0.3
        mat.isDoubleSided = true
        geo.materials = [mat]
        return geo
    }

    // MARK: - STL Export

    /// Export geometry to binary STL.
    /// Filename: scan_<footSide>_<timestamp>.stl
    static func exportSTL(from geometry: SCNGeometry, footSide: String = "left") -> URL? {
        guard let vertSource = geometry.sources(for: .vertex).first,
              let element    = geometry.elements.first else { return nil }
        let vCount = vertSource.vectorCount
        var verts = [SIMD3<Float>](repeating: .zero, count: vCount)
        vertSource.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let floats = ptr.bindMemory(to: Float.self)
            let stride = vertSource.dataStride / MemoryLayout<Float>.size
            let offset = vertSource.dataOffset / MemoryLayout<Float>.size
            for i in 0..<vCount {
                let base = offset + i * stride
                verts[i] = SIMD3(floats[base], floats[base+1], floats[base+2])
            }
        }
        var triangles = [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]()
        element.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            if element.bytesPerIndex == 4 {
                let idx = ptr.bindMemory(to: UInt32.self)
                for t in 0..<element.primitiveCount {
                    let a = Int(idx[t*3]), b = Int(idx[t*3+1]), c = Int(idx[t*3+2])
                    if a < verts.count && b < verts.count && c < verts.count {
                        triangles.append((verts[a], verts[b], verts[c]))
                    }
                }
            }
        }
        guard !triangles.isEmpty else { return nil }

        let ts  = Int(Date().timeIntervalSince1970)
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("scan_\(footSide)_\(ts).stl")

        var data = Data(count: 80)   // 80-byte header
        var count32 = UInt32(triangles.count)
        withUnsafeBytes(of: &count32) { data.append(contentsOf: $0) }

        func af(_ f: Float) { var v = f; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }

        for (a, b, c) in triangles {
            let raw = simd_cross(b - a, c - a)
            let len = simd_length(raw)
            let n   = len > 0 ? raw / len : SIMD3<Float>(0, 0, 1)
            for v in [n, a, b, c] { af(v.x); af(v.y); af(v.z) }
            var attr: UInt16 = 0
            withUnsafeBytes(of: &attr) { data.append(contentsOf: $0) }
        }
        do {
            try data.write(to: url)
            return url
        } catch {
            print("STL write error: \(error)")
            return nil
        }
    }
}

// MARK: - Marching Cubes Tables
// Standard 256-entry triangle table (only non-trivial cases shown; all 256 entries present).

struct MarchingCubesTables {
    // Each row = up to 16 edge indices (terminated by -1) forming triangles for that cube config.
    static let triangles: [[Int]] = [
        [-1],
        [0,8,3,-1],
        [0,1,9,-1],
        [1,8,3,9,8,1,-1],
        [1,2,10,-1],
        [0,8,3,1,2,10,-1],
        [9,2,10,0,2,9,-1],
        [2,8,3,2,10,8,10,9,8,-1],
        [3,11,2,-1],
        [0,11,2,8,11,0,-1],
        [1,9,0,2,3,11,-1],
        [1,11,2,1,9,11,9,8,11,-1],
        [3,10,1,11,10,3,-1],
        [0,10,1,0,8,10,8,11,10,-1],
        [3,9,0,3,11,9,11,10,9,-1],
        [9,8,10,10,8,11,-1],
        [4,7,8,-1],
        [4,3,0,7,3,4,-1],
        [0,1,9,8,4,7,-1],
        [4,1,9,4,7,1,7,3,1,-1],
        [1,2,10,8,4,7,-1],
        [3,4,7,3,0,4,1,2,10,-1],
        [9,2,10,9,0,2,8,4,7,-1],
        [2,10,9,2,9,7,2,7,3,7,9,4,-1],
        [8,4,7,3,11,2,-1],
        [11,4,7,11,2,4,2,0,4,-1],
        [9,0,1,8,4,7,2,3,11,-1],
        [4,7,11,9,4,11,9,11,2,9,2,1,-1],
        [3,10,1,3,11,10,7,8,4,-1],
        [1,11,10,1,4,11,1,0,4,7,11,4,-1],
        [4,7,8,9,0,11,9,11,10,11,0,3,-1],
        [4,7,11,4,11,9,9,11,10,-1],
        [9,5,4,-1],
        [9,5,4,0,8,3,-1],
        [0,5,4,1,5,0,-1],
        [8,5,4,8,3,5,3,1,5,-1],
        [1,2,10,9,5,4,-1],
        [3,0,8,1,2,10,4,9,5,-1],
        [5,2,10,5,4,2,4,0,2,-1],
        [2,10,5,3,2,5,3,5,4,3,4,8,-1],
        [9,5,4,2,3,11,-1],
        [0,11,2,0,8,11,4,9,5,-1],
        [0,5,4,0,1,5,2,3,11,-1],
        [2,1,5,2,5,8,2,8,11,4,8,5,-1],
        [10,3,11,10,1,3,9,5,4,-1],
        [4,9,5,0,8,1,8,10,1,8,11,10,-1],
        [5,4,0,5,0,11,5,11,10,11,0,3,-1],
        [5,4,8,5,8,10,10,8,11,-1],
        [9,7,8,5,7,9,-1],
        [9,3,0,9,5,3,5,7,3,-1],
        [0,7,8,0,1,7,1,5,7,-1],
        [1,5,3,3,5,7,-1],
        [9,7,8,9,5,7,10,1,2,-1],
        [10,1,2,9,5,0,5,3,0,5,7,3,-1],
        [8,0,2,8,2,5,8,5,7,10,5,2,-1],
        [2,10,5,2,5,3,3,5,7,-1],
        [7,9,5,7,8,9,3,11,2,-1],
        [9,5,7,9,7,2,9,2,0,2,7,11,-1],
        [2,3,11,0,1,8,1,7,8,1,5,7,-1],
        [11,2,1,11,1,7,7,1,5,-1],
        [9,5,8,8,5,7,10,1,3,10,3,11,-1],
        [5,7,0,5,0,9,7,11,0,1,0,10,11,10,0,-1],
        [11,10,0,11,0,3,10,5,0,8,0,7,5,7,0,-1],
        [11,10,5,7,11,5,-1],
        [10,6,5,-1],
        [0,8,3,5,10,6,-1],
        [9,0,1,5,10,6,-1],
        [1,8,3,1,9,8,5,10,6,-1],
        [1,6,5,2,6,1,-1],
        [1,6,5,1,2,6,3,0,8,-1],
        [9,6,5,9,0,6,0,2,6,-1],
        [5,9,8,5,8,2,5,2,6,3,2,8,-1],
        [2,3,11,10,6,5,-1],
        [11,0,8,11,2,0,10,6,5,-1],
        [0,1,9,2,3,11,5,10,6,-1],
        [5,10,6,1,9,2,9,11,2,9,8,11,-1],
        [6,3,11,6,5,3,5,1,3,-1],
        [0,8,11,0,11,5,0,5,1,5,11,6,-1],
        [3,11,6,0,3,6,0,6,5,0,5,9,-1],
        [6,5,9,6,9,11,11,9,8,-1],
        [5,10,6,4,7,8,-1],
        [4,3,0,4,7,3,6,5,10,-1],
        [1,9,0,5,10,6,8,4,7,-1],
        [10,6,5,1,9,7,1,7,3,7,9,4,-1],
        [6,1,2,6,5,1,4,7,8,-1],
        [1,2,5,5,2,6,3,0,4,3,4,7,-1],
        [8,4,7,9,0,5,0,6,5,0,2,6,-1],
        [7,3,9,7,9,4,3,2,9,5,9,6,2,6,9,-1],
        [3,11,2,7,8,4,10,6,5,-1],
        [5,10,6,4,7,2,4,2,0,2,7,11,-1],
        [0,1,9,4,7,8,2,3,11,5,10,6,-1],
        [9,2,1,9,11,2,9,4,11,7,11,4,5,10,6,-1],
        [8,4,7,3,11,5,3,5,1,5,11,6,-1],
        [5,1,11,5,11,6,1,0,11,7,11,4,0,4,11,-1],
        [0,5,9,0,6,5,0,3,6,11,6,3,8,4,7,-1],
        [6,5,9,6,9,11,4,7,9,7,11,9,-1],
        [10,4,9,6,4,10,-1],
        [4,10,6,4,9,10,0,8,3,-1],
        [10,0,1,10,6,0,6,4,0,-1],
        [8,3,1,8,1,6,8,6,4,6,1,10,-1],
        [1,4,9,1,2,4,2,6,4,-1],
        [3,0,8,1,2,9,2,4,9,2,6,4,-1],
        [0,2,4,4,2,6,-1],
        [8,3,2,8,2,4,4,2,6,-1],
        [10,4,9,10,6,4,11,2,3,-1],
        [0,8,2,2,8,11,4,9,10,4,10,6,-1],
        [3,11,2,0,1,6,0,6,4,6,1,10,-1],
        [6,4,1,6,1,10,4,8,1,2,1,11,8,11,1,-1],
        [9,6,4,9,3,6,9,1,3,11,6,3,-1],
        [8,11,1,8,1,0,11,6,1,9,1,4,6,4,1,-1],
        [3,11,6,3,6,0,0,6,4,-1],
        [6,4,8,11,6,8,-1],
        [7,10,6,7,8,10,8,9,10,-1],
        [0,7,3,0,10,7,0,9,10,6,7,10,-1],
        [10,6,7,1,10,7,1,7,8,1,8,0,-1],
        [10,6,7,10,7,1,1,7,3,-1],
        [1,2,6,1,6,8,1,8,9,8,6,7,-1],
        [2,6,9,2,9,1,6,7,9,0,9,3,7,3,9,-1],
        [7,8,0,7,0,6,6,0,2,-1],
        [7,3,2,6,7,2,-1],
        [2,3,11,10,6,8,10,8,9,8,6,7,-1],
        [2,0,7,2,7,11,0,9,7,6,7,10,9,10,7,-1],
        [1,8,0,1,7,8,1,10,7,6,7,10,2,3,11,-1],
        [11,2,1,11,1,7,10,6,1,6,7,1,-1],
        [8,9,6,8,6,7,9,1,6,11,6,3,1,3,6,-1],
        [0,9,1,11,6,7,-1],
        [7,8,0,7,0,6,3,11,0,11,6,0,-1],
        [7,11,6,-1],
        [7,6,11,-1],
        [3,0,8,11,7,6,-1],
        [0,1,9,11,7,6,-1],
        [8,1,9,8,3,1,11,7,6,-1],
        [10,1,2,6,11,7,-1],
        [1,2,10,3,0,8,6,11,7,-1],
        [2,9,0,2,10,9,6,11,7,-1],
        [6,11,7,2,10,3,10,8,3,10,9,8,-1],
        [7,2,3,6,2,7,-1],
        [7,0,8,7,6,0,6,2,0,-1],
        [2,7,6,2,3,7,0,1,9,-1],
        [1,6,2,1,8,6,1,9,8,8,7,6,-1],
        [10,7,6,10,1,7,1,3,7,-1],
        [10,7,6,1,7,10,1,8,7,1,0,8,-1],
        [0,3,7,0,7,10,0,10,9,6,10,7,-1],
        [7,6,10,7,10,8,8,10,9,-1],
        [6,8,4,11,8,6,-1],
        [3,6,11,3,0,6,0,4,6,-1],
        [8,6,11,8,4,6,9,0,1,-1],
        [9,4,6,9,6,3,9,3,1,11,3,6,-1],
        [6,8,4,6,11,8,2,10,1,-1],
        [1,2,10,3,0,11,0,6,11,0,4,6,-1],
        [4,11,8,4,6,11,0,2,9,2,10,9,-1],
        [10,9,3,10,3,2,9,4,3,11,3,6,4,6,3,-1],
        [8,2,3,8,4,2,4,6,2,-1],
        [0,4,2,4,6,2,-1],
        [1,9,0,2,3,4,2,4,6,4,3,8,-1],
        [1,9,4,1,4,2,2,4,6,-1],
        [8,1,3,8,6,1,8,4,6,6,10,1,-1],
        [10,1,0,10,0,6,6,0,4,-1],
        [4,6,3,4,3,8,6,10,3,0,3,9,10,9,3,-1],
        [10,9,4,6,10,4,-1],
        [4,9,5,7,6,11,-1],
        [0,8,3,4,9,5,11,7,6,-1],
        [5,0,1,5,4,0,7,6,11,-1],
        [11,7,6,8,3,4,3,5,4,3,1,5,-1],
        [9,5,4,10,1,2,7,6,11,-1],
        [6,11,7,1,2,10,0,8,3,4,9,5,-1],
        [7,6,11,5,4,10,4,2,10,4,0,2,-1],
        [3,4,8,3,5,4,3,2,5,10,5,2,11,7,6,-1],
        [7,2,3,7,6,2,5,4,9,-1],
        [9,5,4,0,8,6,0,6,2,6,8,7,-1],
        [3,6,2,3,7,6,1,5,0,5,4,0,-1],
        [6,2,8,6,8,7,2,1,8,4,8,5,1,5,8,-1],
        [9,5,4,10,1,6,1,7,6,1,3,7,-1],
        [1,6,10,1,7,6,1,0,7,8,7,0,9,5,4,-1],
        [4,0,10,4,10,5,0,3,10,6,10,7,3,7,10,-1],
        [7,6,10,7,10,8,5,4,10,4,8,10,-1],
        [6,9,5,6,11,9,11,8,9,-1],
        [3,6,11,0,6,3,0,5,6,0,9,5,-1],
        [0,11,8,0,5,11,0,1,5,5,6,11,-1],
        [6,11,3,6,3,5,5,3,1,-1],
        [1,2,10,9,5,11,9,11,8,11,5,6,-1],
        [0,11,3,0,6,11,0,9,6,5,6,9,1,2,10,-1],
        [11,8,5,11,5,6,8,0,5,10,5,2,0,2,5,-1],
        [6,11,3,6,3,5,2,10,3,10,5,3,-1],
        [5,8,9,5,2,8,5,6,2,3,8,2,-1],
        [9,5,6,9,6,0,0,6,2,-1],
        [1,5,8,1,8,0,5,6,8,3,8,2,6,2,8,-1],
        [1,5,6,2,1,6,-1],
        [1,3,6,1,6,10,3,8,6,5,6,9,8,9,6,-1],
        [10,1,0,10,0,6,9,5,0,5,6,0,-1],
        [0,3,8,5,6,10,-1],
        [10,5,6,-1],
        [11,5,10,7,5,11,-1],
        [11,5,10,11,7,5,8,3,0,-1],
        [5,11,7,5,10,11,1,9,0,-1],
        [10,7,5,10,11,7,9,8,1,8,3,1,-1],
        [11,1,2,11,7,1,7,5,1,-1],
        [0,8,3,1,2,7,1,7,5,7,2,11,-1],
        [9,7,5,9,2,7,9,0,2,2,11,7,-1],
        [7,5,2,7,2,11,5,9,2,3,2,8,9,8,2,-1],
        [2,5,10,2,3,5,3,7,5,-1],
        [8,2,0,8,5,2,8,7,5,10,2,5,-1],
        [9,0,1,2,3,5,2,5,10,5,3,7,-1],
        [8,2,9,8,9,7,2,10,9,5,9,3,10,3,9,-1],
        [1,3,5,3,7,5,-1],
        [0,8,7,0,7,1,1,7,5,-1],
        [9,0,3,9,3,5,5,3,7,-1],
        [9,8,7,5,9,7,-1],
        [5,8,4,5,10,8,10,11,8,-1],
        [5,0,4,5,11,0,5,10,11,11,3,0,-1],
        [0,1,9,8,4,10,8,10,11,10,4,5,-1],
        [10,11,4,10,4,5,11,3,4,9,4,1,3,1,4,-1],
        [2,5,1,2,8,5,2,11,8,4,5,8,-1],
        [0,4,11,0,11,3,4,5,11,2,11,1,5,1,11,-1],
        [0,2,5,0,5,9,2,11,5,4,5,8,11,8,5,-1],
        [9,4,5,2,11,3,-1],
        [2,5,10,3,5,2,3,4,5,3,8,4,-1],
        [5,10,2,5,2,4,4,2,0,-1],
        [3,10,2,3,5,10,3,8,5,4,5,8,0,1,9,-1],
        [5,10,2,5,2,4,1,9,2,9,4,2,-1],
        [8,4,5,8,5,3,3,5,1,-1],
        [0,4,5,1,0,5,-1],
        [8,4,5,8,5,3,9,0,5,0,3,5,-1],
        [9,4,5,-1],
        [4,11,7,4,9,11,9,10,11,-1],
        [0,8,3,4,9,7,9,11,7,9,10,11,-1],
        [1,10,11,1,11,4,1,4,0,7,4,11,-1],
        [3,1,4,3,4,8,1,10,4,7,4,11,10,11,4,-1],
        [4,11,7,9,11,4,9,2,11,9,1,2,-1],
        [9,7,4,9,11,7,9,1,11,2,11,1,0,8,3,-1],
        [11,7,4,11,4,2,2,4,0,-1],
        [11,7,4,11,4,2,8,3,4,3,2,4,-1],
        [2,9,10,2,7,9,2,3,7,7,4,9,-1],
        [9,10,7,9,7,4,10,2,7,8,7,0,2,0,7,-1],
        [3,7,10,3,10,2,7,4,10,1,10,0,4,0,10,-1],
        [1,10,2,8,7,4,-1],
        [4,9,1,4,1,7,7,1,3,-1],
        [4,9,1,4,1,7,0,8,1,8,7,1,-1],
        [4,0,3,7,4,3,-1],
        [4,8,7,-1],
        [9,10,8,10,11,8,-1],
        [3,0,9,3,9,11,11,9,10,-1],
        [0,1,10,0,10,8,8,10,11,-1],
        [3,1,10,11,3,10,-1],
        [1,2,11,1,11,9,9,11,8,-1],
        [3,0,9,3,9,11,1,2,9,2,11,9,-1],
        [0,2,11,8,0,11,-1],
        [3,2,11,-1],
        [2,3,8,2,8,10,10,8,9,-1],
        [9,10,2,0,9,2,-1],
        [2,3,8,2,8,10,0,1,8,1,10,8,-1],
        [1,10,2,-1],
        [1,3,8,9,1,8,-1],
        [0,9,1,-1],
        [0,3,8,-1],
        [-1]
    ]
}







