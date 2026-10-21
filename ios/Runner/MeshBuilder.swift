import SceneKit
import ModelIO
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

struct MeshBuilder {

    static func buildMesh(from frames: [DepthFrame],
                          step: Int = 2,
                          footSide: String = "left") -> SCNGeometry? {
        guard !frames.isEmpty else { return nil }

        var allVerts   = [SIMD3<Float>]()
        var allNormals = [SIMD3<Float>]()
        var allIndices = [UInt32]()

        let mergeRadius: Float = 0.003
        var vertexHash = [SIMD3<Int32>: UInt32]()

        func hashKey(_ p: SIMD3<Float>) -> SIMD3<Int32> {
            SIMD3<Int32>(Int32(floor(p.x / mergeRadius)),
                         Int32(floor(p.y / mergeRadius)),
                         Int32(floor(p.z / mergeRadius)))
        }

        func addVertex(_ p: SIMD3<Float>, _ n: SIMD3<Float>) -> UInt32 {
            let key = hashKey(p)
            if let existing = vertexHash[key] { return existing }
            let idx = UInt32(allVerts.count)
            allVerts.append(p)
            allNormals.append(n)
            vertexHash[key] = idx
            return idx
        }

        let maxEdge: Float = 0.010

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
            while r + step < h {
                var c = 0
                while c + step < w {
                    guard let p00 = unproject(col: c,        row: r),
                          let p10 = unproject(col: c + step, row: r),
                          let p01 = unproject(col: c,        row: r + step),
                          let p11 = unproject(col: c + step, row: r + step)
                    else { c += step; continue }

                    let e1a = simd_distance(p00, p10)
                    let e1b = simd_distance(p00, p01)
                    let e1c = simd_distance(p10, p01)
                    if e1a < maxEdge && e1b < maxEdge && e1c < maxEdge {
                        let n1 = triNormal(p00, p10, p01)
                        let i0 = addVertex(p00, n1)
                        let i1 = addVertex(p10, n1)
                        let i2 = addVertex(p01, n1)
                        allIndices.append(contentsOf: [i0, i1, i2])
                        allIndices.append(contentsOf: [i2, i1, i0])
                    }

                    let e2a = simd_distance(p10, p11)
                    let e2b = simd_distance(p11, p01)
                    let e2c = simd_distance(p10, p01)
                    if e2a < maxEdge && e2b < maxEdge && e2c < maxEdge {
                        let n2 = triNormal(p10, p11, p01)
                        let i0 = addVertex(p10, n2)
                        let i1 = addVertex(p11, n2)
                        let i2 = addVertex(p01, n2)
                        allIndices.append(contentsOf: [i0, i1, i2])
                        allIndices.append(contentsOf: [i2, i1, i0])
                    }

                    c += step
                }
                r += step
            }
        }

        guard allVerts.count > 10, allIndices.count > 0 else { return nil }
        return buildSCNGeometry(vertices: allVerts, normals: allNormals, indices: allIndices)
    }

    private static func triNormal(_ a: SIMD3<Float>,
                                   _ b: SIMD3<Float>,
                                   _ c: SIMD3<Float>) -> SIMD3<Float> {
        let n = simd_cross(b - a, c - a)
        let l = simd_length(n)
        return l > 1e-9 ? n / l : SIMD3<Float>(0, 1, 0)
    }

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
