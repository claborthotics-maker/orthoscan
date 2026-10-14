import SceneKit
import ModelIO
import simd

struct MeshBuilder {

    static func buildMesh(from points: [SIMD3<Float>]) -> SCNGeometry? { return nil }

    static func buildMeshFromDepth(depth: [[Float]],
                                   fx: Float, fy: Float,
                                   cx: Float, cy: Float,
                                   minD: Float, maxD: Float,
                                   floorMargin: Float) -> SCNGeometry? {
        let rows = depth.count
        guard rows > 0 else { return nil }
        let cols = depth[0].count
        guard cols > 0 else { return nil }

        // 3x3 median smooth to reduce depth noise
        var smoothed = depth
        for r in 1..<(rows-1) {
            for c in 1..<(cols-1) {
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

        // Back-project depth pixels to 3D points
        var grid = [[SIMD3<Float>?]](repeating: [SIMD3<Float>?](repeating: nil, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                let d = smoothed[r][c]
                guard d >= minD && d <= maxD else { continue }
                let x = (Float(c) - cx) * d / fx
                let y = (Float(r) - cy) * d / fy
                grid[r][c] = SIMD3<Float>(x, y, d)
            }
        }

        // Floor exclusion: remove top floorMargin fraction of Y extent
        var allY = grid.flatMap { $0.compactMap { $0?.y } }
        if !allY.isEmpty {
            allY.sort()
            let yMin = allY.first!
            let yMax = allY.last!
            let yThreshold = yMin + (yMax - yMin) * floorMargin
            for r in 0..<rows {
                for c in 0..<cols {
                    if let p = grid[r][c], p.y < yThreshold {
                        grid[r][c] = nil
                    }
                }
            }
        }

        // Assign vertex indices
        var vertices = [SIMD3<Float>]()
        var indexMap = [[Int]](repeating: [Int](repeating: -1, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                if let p = grid[r][c] {
                    indexMap[r][c] = vertices.count
                    vertices.append(p)
                }
            }
        }
        guard vertices.count > 100 else { return nil }

        // Triangulate adjacent pixels
        var indices = [UInt32]()
        let maxDepthJump: Float = 0.015
        for r in 0..<(rows-1) {
            for c in 0..<(cols-1) {
                let i00 = indexMap[r][c]
                let i01 = indexMap[r][c+1]
                let i10 = indexMap[r+1][c]
                let i11 = indexMap[r+1][c+1]
                guard i00 >= 0, i01 >= 0, i10 >= 0, i11 >= 0 else { continue }
                let zs = [vertices[i00].z, vertices[i01].z, vertices[i10].z, vertices[i11].z]
                guard (zs.max()! - zs.min()!) < maxDepthJump else { continue }
                indices.append(contentsOf: [UInt32(i00), UInt32(i10), UInt32(i01)])
                indices.append(contentsOf: [UInt32(i01), UInt32(i10), UInt32(i11)])
            }
        }
        guard !indices.isEmpty else { return nil }

        return buildSCNGeometry(vertices: vertices, indices: indices)
    }

    private static func buildSCNGeometry(vertices: [SIMD3<Float>], indices: [UInt32]) -> SCNGeometry {
        let vertData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SIMD3<Float>>.stride)
        let vertSource = SCNGeometrySource(data: vertData, semantic: .vertex,
                                           vectorCount: vertices.count,
                                           usesFloatComponents: true,
                                           componentsPerVector: 3,
                                           bytesPerComponent: 4,
                                           dataOffset: 0,
                                           dataStride: MemoryLayout<SIMD3<Float>>.stride)
        let normData = Data(bytes: vertices.map { _ in SIMD3<Float>(0,0,-1) },
                            count: vertices.count * MemoryLayout<SIMD3<Float>>.stride)
        let normSource = SCNGeometrySource(data: normData, semantic: .normal,
                                           vectorCount: vertices.count,
                                           usesFloatComponents: true,
                                           componentsPerVector: 3,
                                           bytesPerComponent: 4,
                                           dataOffset: 0,
                                           dataStride: MemoryLayout<SIMD3<Float>>.stride)
        let idxData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element = SCNGeometryElement(data: idxData, primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)
        let geometry = SCNGeometry(sources: [vertSource, normSource], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.93, green: 0.82, blue: 0.72, alpha: 1)
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
        let url = dir.appendingPathComponent("scan_\(ts).stl")
        var data = Data(count: 80)
        var count = UInt32(triangles.count)
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        func appendFloat(_ f: Float) {
            var v = f; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        for (a, b, c) in triangles {
            let edge1 = b - a, edge2 = c - a
            let raw = simd_cross(edge1, edge2)
            let len = simd_length(raw)
            let n   = len > 0 ? raw / len : SIMD3<Float>(0,0,1)
            for v in [n, a, b, c] { appendFloat(v.x); appendFloat(v.y); appendFloat(v.z) }
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
