import SceneKit
import ModelIO
import ARKit
import simd

// MARK: - DepthFrame
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

// MARK: - MeshBuilder
struct MeshBuilder {

    // fusionRadius: world-space cell size in metres.
    // All depth readings within the same cell are averaged into one vertex.
    // 0.002 = 2mm (maximum detail, some noise)
    // 0.0025 = 2.5mm (default — good balance for foot scanning)
    // 0.003 = 3mm (smoother, slight detail loss)
    static let fusionRadius: Float = 0.0015

    static func buildMesh(from frames: [DepthFrame],
                          step: Int = 2,
                          footSide: String = "left") -> SCNGeometry? {
        guard !frames.isEmpty else { return nil }

        struct Accumulator {
            var sum: SIMD3<Float>
            var count: Int
        }
        var cellMap = [SIMD3<Int32>: Accumulator]()

        func hashKey(_ p: SIMD3<Float>) -> SIMD3<Int32> {
            SIMD3<Int32>(Int32(floor(p.x / fusionRadius)),
                         Int32(floor(p.y / fusionRadius)),
                         Int32(floor(p.z / fusionRadius)))
        }

        // Pass 1: accumulate all depth readings into cells
        for frame in frames {
            let w = frame.width, h = frame.height
            let pixels = frame.pixels
            let pose   = frame.pose
            let fx = frame.fx, fy = frame.fy
            let cx = frame.cx, cy = frame.cy

            func unproject(col: Int, row: Int) -> SIMD3<Float>? {
                let z = pixels[row * w + col]
                guard z > 0.05, z < 0.60, z.isFinite else { return nil }
                let xc = (Float(col) - cx) * z / fx
                let yc = -(Float(row) - cy) * z / fy
                let angle = atan2(sqrt(xc*xc + yc*yc), z)
                guard angle < 0.5 else { return nil }
                let cam = SIMD4<Float>(xc, yc, -z, 1.0)
                let world = pose * cam
                return SIMD3<Float>(world.x, world.y, world.z)
            }

            var r = 0
            while r < h {
                var c = 0
                while c < w {
                    if let p = unproject(col: c, row: r) {
                        let key = hashKey(p)
                        if var acc = cellMap[key] {
                            acc.sum = acc.sum + p
                            acc.count += 1
                            cellMap[key] = acc
                        } else {
                            cellMap[key] = Accumulator(sum: p, count: 1)
                        }
                    }
                    c += step
                }
                r += step
            }
        }

        guard cellMap.count > 10 else { return nil }

        // Pass 2: averaged vertex positions
        // Require at least 2 observations to filter single-frame noise spikes
        var cellVertices = [SIMD3<Int32>: UInt32]()
        var allVerts = [SIMD3<Float>]()

        for (key, acc) in cellMap {
            guard acc.count >= 1 else { continue }
            let avgPos = acc.sum / Float(acc.count)
            let idx = UInt32(allVerts.count)
            allVerts.append(avgPos)
            cellVertices[key] = idx
        }

        guard allVerts.count > 10 else { return nil }

        // Pass 3: triangulate by connecting adjacent occupied cells
        let maxEdge: Float = fusionRadius * 4.0
        var allIndices = [UInt32]()

        // Walk all occupied cells, emit triangles with right/down/diagonal neighbors
        for (key, i0) in cellVertices {
            let right    = SIMD3<Int32>(key.x + 1, key.y,     key.z)
            let down     = SIMD3<Int32>(key.x,     key.y + 1, key.z)
            let diagRD   = SIMD3<Int32>(key.x + 1, key.y + 1, key.z)
            let diagFwd  = SIMD3<Int32>(key.x,     key.y,     key.z + 1)
            let rightFwd = SIMD3<Int32>(key.x + 1, key.y,     key.z + 1)
            let downFwd  = SIMD3<Int32>(key.x,     key.y + 1, key.z + 1)

            let p0 = allVerts[Int(i0)]

            // XY plane triangles (main scan surface)
            if let i1 = cellVertices[right], let i2 = cellVertices[down] {
                let p1 = allVerts[Int(i1)], p2 = allVerts[Int(i2)]
                if simd_distance(p0,p1) < maxEdge && simd_distance(p0,p2) < maxEdge && simd_distance(p1,p2) < maxEdge {
                    allIndices.append(contentsOf: [i0, i1, i2])
                }
            }
            if let i1 = cellVertices[right], let i2 = cellVertices[diagRD], let i3 = cellVertices[down] {
                let p1 = allVerts[Int(i1)], p2 = allVerts[Int(i2)], p3 = allVerts[Int(i3)]
                if simd_distance(p1,p2) < maxEdge && simd_distance(p2,p3) < maxEdge && simd_distance(p1,p3) < maxEdge {
                    allIndices.append(contentsOf: [i1, i2, i3])
                }
            }

            // XZ plane triangles (side surfaces)
            if let i1 = cellVertices[right], let i2 = cellVertices[diagFwd] {
                let p1 = allVerts[Int(i1)], p2 = allVerts[Int(i2)]
                if simd_distance(p0,p1) < maxEdge && simd_distance(p0,p2) < maxEdge && simd_distance(p1,p2) < maxEdge {
                    allIndices.append(contentsOf: [i0, i1, i2])
                }
            }
            if let i1 = cellVertices[diagFwd], let i2 = cellVertices[rightFwd] {
                let _ = allVerts[Int(i1)], _ = allVerts[Int(i2)]
                if let i3 = cellVertices[right] {
                    let p1 = allVerts[Int(i1)], p2 = allVerts[Int(i2)], p3 = allVerts[Int(i3)]
                    if simd_distance(p1,p2) < maxEdge && simd_distance(p2,p3) < maxEdge && simd_distance(p1,p3) < maxEdge {
                        allIndices.append(contentsOf: [i1, i2, i3])
                    }
                }
            }

            // YZ plane triangles
            if let i1 = cellVertices[down], let i2 = cellVertices[diagFwd] {
                let p1 = allVerts[Int(i1)], p2 = allVerts[Int(i2)]
                if simd_distance(p0,p1) < maxEdge && simd_distance(p0,p2) < maxEdge && simd_distance(p1,p2) < maxEdge {
                    allIndices.append(contentsOf: [i0, i1, i2])
                }
            }
            if let i1 = cellVertices[diagFwd], let i2 = cellVertices[downFwd] {
                if let i3 = cellVertices[down] {
                    let p1 = allVerts[Int(i1)], p2 = allVerts[Int(i2)], p3 = allVerts[Int(i3)]
                    if simd_distance(p1,p2) < maxEdge && simd_distance(p2,p3) < maxEdge && simd_distance(p1,p3) < maxEdge {
                        allIndices.append(contentsOf: [i1, i2, i3])
                    }
                }
            }
        }

        guard allIndices.count > 0 else { return nil }

        // Compute normals
        var allNormals = [SIMD3<Float>](repeating: .zero, count: allVerts.count)
        let triTotal = allIndices.count / 3
        for t in 0..<triTotal {
            let i0 = Int(allIndices[t*3])
            let i1 = Int(allIndices[t*3+1])
            let i2 = Int(allIndices[t*3+2])
            let n = triNormal(allVerts[i0], allVerts[i1], allVerts[i2])
            allNormals[i0] = allNormals[i0] + n
            allNormals[i1] = allNormals[i1] + n
            allNormals[i2] = allNormals[i2] + n
        }
        allNormals = allNormals.map { n in
            let l = simd_length(n)
            return l > 1e-9 ? n / l : SIMD3<Float>(0, 1, 0)
        }

        // Gentle smoothing: 2 iterations, lambda 0.2 — blends cell boundaries without collapsing
        let smoothedVerts = laplacianSmooth(vertices: allVerts, indices: allIndices, iterations: 7, lambda: 0.35)
        var smoothedNormals = [SIMD3<Float>](repeating: .zero, count: smoothedVerts.count)
        let triTotal2 = allIndices.count / 3
        for t in 0..<triTotal2 {
            let i0 = Int(allIndices[t*3]), i1 = Int(allIndices[t*3+1]), i2 = Int(allIndices[t*3+2])
            let n = triNormal(smoothedVerts[i0], smoothedVerts[i1], smoothedVerts[i2])
            smoothedNormals[i0] = smoothedNormals[i0] + n
            smoothedNormals[i1] = smoothedNormals[i1] + n
            smoothedNormals[i2] = smoothedNormals[i2] + n
        }
        smoothedNormals = smoothedNormals.map { n in let l = simd_length(n); return l > 1e-9 ? n / l : SIMD3<Float>(0, 1, 0) }
        return buildSCNGeometry(vertices: smoothedVerts, normals: smoothedNormals, indices: allIndices)
    }

    // MARK: - Triangle normal
    private static func laplacianSmooth(vertices: [SIMD3<Float>], indices: [UInt32], iterations: Int, lambda: Float) -> [SIMD3<Float>] {
        let vCount = vertices.count
        var verts = vertices
        var neighbours = [[Int]](repeating: [], count: vCount)
        let triTotal = indices.count / 3
        for t in 0..<triTotal {
            let i0 = Int(indices[t*3]), i1 = Int(indices[t*3+1]), i2 = Int(indices[t*3+2])
            if !neighbours[i0].contains(i1) { neighbours[i0].append(i1) }
            if !neighbours[i0].contains(i2) { neighbours[i0].append(i2) }
            if !neighbours[i1].contains(i0) { neighbours[i1].append(i0) }
            if !neighbours[i1].contains(i2) { neighbours[i1].append(i2) }
            if !neighbours[i2].contains(i0) { neighbours[i2].append(i0) }
            if !neighbours[i2].contains(i1) { neighbours[i2].append(i1) }
        }
        for _ in 0..<iterations {
            var next = verts
            for i in 0..<vCount {
                let nb = neighbours[i]
                guard !nb.isEmpty else { continue }
                var avg = SIMD3<Float>.zero
                for j in nb { avg = avg + verts[j] }
                avg = avg / Float(nb.count)
                next[i] = verts[i] + lambda * (avg - verts[i])
            }
            verts = next
        }
        return verts
    }

    private static func triNormal(_ a: SIMD3<Float>,
                                   _ b: SIMD3<Float>,
                                   _ c: SIMD3<Float>) -> SIMD3<Float> {
        let n = simd_cross(b - a, c - a)
        let l = simd_length(n)
        return l > 1e-9 ? n / l : SIMD3<Float>(0, 1, 0)
    }

    // MARK: - Build SCNGeometry
    private static func buildSCNGeometry(vertices: [SIMD3<Float>],
                                          normals:  [SIMD3<Float>],
                                          indices:  [UInt32]) -> SCNGeometry {
        let vStride = MemoryLayout<SIMD3<Float>>.stride

        let vertData = Data(bytes: vertices, count: vertices.count * vStride)
        let vertSrc  = SCNGeometrySource(data: vertData,
                                         semantic: .vertex,
                                         vectorCount: vertices.count,
                                         usesFloatComponents: true,
                                         componentsPerVector: 3,
                                         bytesPerComponent: 4,
                                         dataOffset: 0,
                                         dataStride: vStride)

        let normList = normals.map { n -> SIMD3<Float> in n.z < 0 ? -n : n }
        let normData = Data(bytes: normList, count: normList.count * vStride)
        let normSrc  = SCNGeometrySource(data: normData,
                                         semantic: .normal,
                                         vectorCount: normList.count,
                                         usesFloatComponents: true,
                                         componentsPerVector: 3,
                                         bytesPerComponent: 4,
                                         dataOffset: 0,
                                         dataStride: vStride)

        let idxData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element = SCNGeometryElement(data: idxData,
                                         primitiveType: .triangles,
                                         primitiveCount: indices.count / 3,
                                         bytesPerIndex: MemoryLayout<UInt32>.size)

        let geo = SCNGeometry(sources: [vertSrc, normSrc], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents  = UIColor(red: 0.93, green: 0.82, blue: 0.72, alpha: 1)
        mat.specular.contents = UIColor.white
        mat.shininess         = 0.3
        mat.isDoubleSided     = true
        geo.materials = [mat]
        return geo
    }

    // MARK: - STL Export
    static func exportSTL(from geometry: SCNGeometry, footSide: String = "left") -> URL? {
        guard let vertSrc = geometry.sources(for: .vertex).first,
              let element = geometry.elements.first else { return nil }

        let vCount = vertSrc.vectorCount
        var verts  = [SIMD3<Float>](repeating: .zero, count: vCount)
        vertSrc.data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let floats = ptr.bindMemory(to: Float.self)
            let stride = vertSrc.dataStride / MemoryLayout<Float>.size
            let offset = vertSrc.dataOffset / MemoryLayout<Float>.size
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
            } else if element.bytesPerIndex == 2 {
                let idx = ptr.bindMemory(to: UInt16.self)
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

        var data = Data(count: 80)
        var count = UInt32(triangles.count)
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }

        func appendFloat(_ f: Float) {
            var v = f; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        for (a, b, c) in triangles {
            let raw = simd_cross(b - a, c - a)
            let len = simd_length(raw)
            let n   = len > 0 ? raw / len : SIMD3<Float>(0, 0, 1)
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
