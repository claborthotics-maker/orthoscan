import SceneKit
import simd

// MeshBuilder — triangulates directly from the depth map grid.
// Each depth pixel becomes a vertex; adjacent pixels are connected into quads.
// This preserves the natural connectivity of the TrueDepth sensor output.

struct MeshBuilder {

    static func buildMesh(from points: [SIMD3<Float>]) -> SCNGeometry? { return nil }

    // Main entry: build directly from the fused depth map + calibration
    static func buildMeshFromDepth(depth: [[Float]],
                                   fx: Float, fy: Float,
                                   cx: Float, cy: Float,
                                   minD: Float, maxD: Float,
                                   floorMargin: Float) -> SCNGeometry? {
        let h = depth.count
        guard h > 0 else { return nil }
        let w = depth[0].count

        let colStart = Int(Float(w) * 0.10), colEnd = Int(Float(w) * 0.90)
        let rowStart = Int(Float(h) * 0.10), rowEnd = Int(Float(h) * 0.90)

        // Build vertex grid: index ? 3D point (nil if invalid)
        var grid = [[SIMD3<Float>?]](repeating: [SIMD3<Float>?](repeating: nil, count: w), count: h)
        var allY = [Float]()

        for row in rowStart..<rowEnd {
            for col in colStart..<colEnd {
                let z = depth[row][col]
                guard z >= minD, z <= maxD else { continue }
                let x = (Float(col) - cx) * z / fx
                let y = (Float(row) - cy) * z / fy
                grid[row][col] = SIMD3(x, y, z)
                allY.append(y)
            }
        }

        guard !allY.isEmpty else { return nil }

        // 3x3 median smooth to reduce depth noise while preserving edges
        var smoothed = depth
        for r in 1..<(depth.count-1) {
            for c in 1..<(depth[0].count-1) {
                var neighbors: [Float] = []
                for dr in -1...1 {
                    for dc in -1...1 {
                        let v = depth[r+dr][c+dc]
                        if v > 0 { neighbors.append(v) }
                    }
                }
                if neighbors.count >= 5 {
                    neighbors.sort()
                    smoothed[r][c] = neighbors[neighbors.count/2]
                }
            }
        }
        let depth = smoothed

        // Floor exclusion
        let maxY = allY.max()!
        let yThreshold = maxY - floorMargin
        for row in rowStart..<rowEnd {
            for col in colStart..<colEnd {
                if let p = grid[row][col], p.y >= yThreshold {
                    grid[row][col] = nil
                }
            }
        }

        // Build vertex buffer and index map
        var vertices = [SIMD3<Float>]()
        var indexMap = [[Int]](repeating: [Int](repeating: -1, count: w), count: h)

        for row in rowStart..<rowEnd {
            for col in colStart..<colEnd {
                if let p = grid[row][col] {
                    indexMap[row][col] = vertices.count
                    vertices.append(p)
                }
            }
        }

        guard vertices.count > 100 else { return nil }

        // Connect adjacent pixels into triangles
        // Max allowed depth jump between neighbours (metres) — skips holes/edges
        let maxDepthJump: Float = 0.015

        var indices = [UInt32]()
        indices.reserveCapacity(vertices.count * 6)

        for row in rowStart..<(rowEnd - 1) {
            for col in colStart..<(colEnd - 1) {
                let iTL = indexMap[row][col]
                let iTR = indexMap[row][col+1]
                let iBL = indexMap[row+1][col]
                let iBR = indexMap[row+1][col+1]
                guard iTL >= 0, iTR >= 0, iBL >= 0, iBR >= 0 else { continue }
                let pTL = vertices[iTL], pTR = vertices[iTR]
                let pBL = vertices[iBL], pBR = vertices[iBR]

                // Skip if depth discontinuity (edge of object)
                let maxZ = Swift.max(Swift.max(pTL.z, pTR.z), Swift.max(pBL.z, pBR.z))
                let minZ = Swift.min(Swift.min(pTL.z, pTR.z), Swift.min(pBL.z, pBR.z))
                guard maxZ - minZ < maxDepthJump else { continue }

                // Two triangles per quad
                indices.append(contentsOf: [UInt32(iTL), UInt32(iTR), UInt32(iBL)])
                indices.append(contentsOf: [UInt32(iTR), UInt32(iBR), UInt32(iBL)])
            }
        }

        guard !indices.isEmpty else { return nil }
        return buildSCNGeometry(vertices: vertices, indices: indices)
    }

    private static func buildSCNGeometry(vertices: [SIMD3<Float>], indices: [UInt32]) -> SCNGeometry {
        let vertData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SIMD3<Float>>.stride)
        let vertSource = SCNGeometrySource(data: vertData, semantic: .vertex,
                                           vectorCount: vertices.count,
                                           usesFloatComponents: true, componentsPerVector: 3,
                                           bytesPerComponent: 4, dataOffset: 0,
                                           dataStride: MemoryLayout<SIMD3<Float>>.stride)
        let idxData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element = SCNGeometryElement(data: idxData, primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)
        let geometry = SCNGeometry(sources: [vertSource], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents  = UIColor(red: 0.93, green: 0.82, blue: 0.72, alpha: 1)
        mat.specular.contents = UIColor.white
        mat.shininess = 0.3
        mat.isDoubleSided = true
        geometry.materials = [mat]
        return geometry
    }

    static func exportSTL(from geometry: SCNGeometry) -> URL? {
        guard let vertSource = geometry.sources(for: .vertex).first,
              let element = geometry.elements.first else { return nil }
        let vCount = vertSource.vectorCount
        var verts = [SIMD3<Float>](repeating: .zero, count: vCount)
        vertSource.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let floats = ptr.bindMemory(to: Float.self)
            let stride = vertSource.dataStride / MemoryLayout<Float>.size
            let offset = vertSource.dataOffset / MemoryLayout<Float>.size
            for i in 0..<vCount { let base = offset + i * stride; verts[i] = SIMD3(floats[base], floats[base+1], floats[base+2]) }
        }
        var triangles = [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]()
        element.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            if element.bytesPerIndex == 4 {
                let indices = ptr.bindMemory(to: UInt32.self)
                for t in 0..<element.primitiveCount {
                    let a = Int(indices[t*3]), b = Int(indices[t*3+1]), c = Int(indices[t*3+2])
                    if a < verts.count && b < verts.count && c < verts.count { triangles.append((verts[a], verts[b], verts[c])) }
                }
            }
        }
        guard !triangles.isEmpty else { return nil }
        let ts = Int(Date().timeIntervalSince1970)
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("scan_\(ts).stl")
        var data = Data(count: 80)
        var count = UInt32(triangles.count)
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        func appendFloat(_ f: Float) { var v = f; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        for (a, b, c) in triangles {
            let edge1 = b - a, edge2 = c - a, raw = simd_cross(edge1, edge2)
            let len = simd_length(raw), n = len > 0 ? raw / len : SIMD3<Float>(0,0,1)
            for v in [n, a, b, c] { appendFloat(v.x); appendFloat(v.y); appendFloat(v.z) }
            var attr: UInt16 = 0; withUnsafeBytes(of: &attr) { data.append(contentsOf: $0) }
        }
        do { try data.write(to: url); return url } catch { print("STL write error: \(error)"); return nil }
    }
}

