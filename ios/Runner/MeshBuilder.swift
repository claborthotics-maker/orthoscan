import SceneKit
import ModelIO
import simd

struct MeshBuilder {

    static func buildMesh(from points: [SIMD3<Float>]) -> SCNGeometry? {
        guard points.count > 100 else { return nil }
        let downsampled = voxelDownsample(points: points, voxelSize: 0.001)
        guard downsampled.count > 100 else { return nil }
        let normals = estimateNormals(points: downsampled, k: 12)
        let (vertices, indices) = triangulateCloud(points: downsampled, normals: normals, maxEdge: 0.004)
        guard !vertices.isEmpty, !indices.isEmpty else { return nil }
        return buildSCNGeometry(vertices: vertices, normals: normals, indices: indices)
    }

    private static func voxelDownsample(points: [SIMD3<Float>], voxelSize: Float) -> [SIMD3<Float>] {
        var buckets = [SIMD3<Int32>: (sum: SIMD3<Float>, count: Int)]()
        for p in points {
            let key = SIMD3<Int32>(Int32(p.x / voxelSize), Int32(p.y / voxelSize), Int32(p.z / voxelSize))
            if var b = buckets[key] { b.sum += p; b.count += 1; buckets[key] = b }
            else { buckets[key] = (sum: p, count: 1) }
        }
        return buckets.values.map { $0.sum / Float($0.count) }
    }

    private static func estimateNormals(points: [SIMD3<Float>], k: Int) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: SIMD3(0, 0, 1), count: points.count)
        let effectiveK = min(k, points.count - 1)
        guard effectiveK >= 3 else { return normals }
        for i in 0..<points.count {
            let pi = points[i]
            var dists = points.enumerated().map { (j, p) in (j: j, d: simd_distance_squared(pi, p)) }
            dists.sort { $0.d < $1.d }
            let neighbours = dists[1...effectiveK].map { points[$0.j] }
            if neighbours.count >= 2 {
                let v1 = simd_normalize(neighbours[0] - pi)
                let v2 = simd_normalize(neighbours[1] - pi)
                let n  = simd_cross(v1, v2)
                if simd_length(n) > 0.001 {
                    normals[i] = n.z < 0 ? -simd_normalize(n) : simd_normalize(n)
                }
            }
        }
        return normals
    }

    private static func triangulateCloud(points: [SIMD3<Float>], normals: [SIMD3<Float>], maxEdge: Float)
        -> (vertices: [SIMD3<Float>], indices: [UInt32]) {
        let xs = points.map { $0.x }, ys = points.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else { return ([], []) }
        let cellSize: Float = maxEdge * 0.8
        let cols = Int((maxX - minX) / cellSize) + 1
        let rows = Int((maxY - minY) / cellSize) + 1
        var grid = [Int: [Int]]()
        for (i, p) in points.enumerated() {
            let col = Int((p.x - minX) / cellSize)
            let row = Int((p.y - minY) / cellSize)
            grid[row * cols + col, default: []].append(i)
        }
        var cellRep = [Int: Int]()
        for (cell, idxs) in grid {
            let sorted = idxs.sorted { points[$0].z < points[$1].z }
            cellRep[cell] = sorted[sorted.count / 2]
        }
        var outVerts = [SIMD3<Float>](), outIdx = [UInt32](), vertMap = [Int: UInt32]()
        func addVert(_ pi: Int) -> UInt32 {
            if let e = vertMap[pi] { return e }
            let idx = UInt32(outVerts.count); outVerts.append(points[pi]); vertMap[pi] = idx; return idx
        }
        for row in 0..<(rows - 1) {
            for col in 0..<(cols - 1) {
                let tl = row * cols + col, tr = tl + 1, bl = (row+1)*cols+col, br = bl + 1
                guard let piTL = cellRep[tl], let piTR = cellRep[tr],
                      let piBL = cellRep[bl], let piBR = cellRep[br] else { continue }
                let a = points[piTL], b = points[piTR], c = points[piBL], d = points[piBR]
                if simd_distance(a,b) < maxEdge, simd_distance(a,c) < maxEdge, simd_distance(b,c) < maxEdge {
                    outIdx.append(contentsOf: [addVert(piTL), addVert(piTR), addVert(piBL)])
                }
                if simd_distance(b,d) < maxEdge, simd_distance(d,c) < maxEdge, simd_distance(b,c) < maxEdge {
                    outIdx.append(contentsOf: [addVert(piTR), addVert(piBR), addVert(piBL)])
                }
            }
        }
        return (outVerts, outIdx)
    }

    private static func buildSCNGeometry(vertices: [SIMD3<Float>], normals: [SIMD3<Float>], indices: [UInt32]) -> SCNGeometry {
        let vertData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SIMD3<Float>>.stride)
        let vertSource = SCNGeometrySource(data: vertData, semantic: .vertex, vectorCount: vertices.count,
                                           usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4,
                                           dataOffset: 0, dataStride: MemoryLayout<SIMD3<Float>>.stride)
        let normData = Data(bytes: vertices.map { _ in SIMD3<Float>(0,0,1) },
                            count: vertices.count * MemoryLayout<SIMD3<Float>>.stride)
        let normSource = SCNGeometrySource(data: normData, semantic: .normal, vectorCount: vertices.count,
                                           usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4,
                                           dataOffset: 0, dataStride: MemoryLayout<SIMD3<Float>>.stride)
        let idxData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)
        let element  = SCNGeometryElement(data: idxData, primitiveType: .triangles,
                                          primitiveCount: indices.count / 3, bytesPerIndex: MemoryLayout<UInt32>.size)
        let geometry = SCNGeometry(sources: [vertSource, normSource], elements: [element])
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
            } else if element.bytesPerIndex == 2 {
                let indices = ptr.bindMemory(to: UInt16.self)
                for t in 0..<element.primitiveCount {
                    let a = Int(indices[t*3]), b = Int(indices[t*3+1]), c = Int(indices[t*3+2])
                    if a < verts.count && b < verts.count && c < verts.count { triangles.append((verts[a], verts[b], verts[c])) }
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
