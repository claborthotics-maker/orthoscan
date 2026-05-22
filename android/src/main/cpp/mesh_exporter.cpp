#include "mesh_exporter.h"
#include <fstream>
#include <cstring>

bool MeshExporter::exportSTL(const Mesh& mesh, const std::string& filePath) {
    std::ofstream file(filePath, std::ios::binary);
    if (!file.is_open()) return false;

    char header[80] = "OrthoScan STL Export";
    file.write(header, 80);

    uint32_t numTriangles = (uint32_t)mesh.triangles.size();
    file.write(reinterpret_cast<const char*>(&numTriangles), 4);

    for (const auto& tri : mesh.triangles) {
        const Point3D& a = mesh.vertices[tri.a];
        const Point3D& b = mesh.vertices[tri.b];
        const Point3D& c = mesh.vertices[tri.c];

        float ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
        float vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
        float nx = uy * vz - uz * vy;
        float ny = uz * vx - ux * vz;
        float nz = ux * vy - uy * vx;

        file.write(reinterpret_cast<const char*>(&nx), 4);
        file.write(reinterpret_cast<const char*>(&ny), 4);
        file.write(reinterpret_cast<const char*>(&nz), 4);

        file.write(reinterpret_cast<const char*>(&a.x), 4);
        file.write(reinterpret_cast<const char*>(&a.y), 4);
        file.write(reinterpret_cast<const char*>(&a.z), 4);

        file.write(reinterpret_cast<const char*>(&b.x), 4);
        file.write(reinterpret_cast<const char*>(&b.y), 4);
        file.write(reinterpret_cast<const char*>(&b.z), 4);

        file.write(reinterpret_cast<const char*>(&c.x), 4);
        file.write(reinterpret_cast<const char*>(&c.y), 4);
        file.write(reinterpret_cast<const char*>(&c.z), 4);

        uint16_t attrByteCount = 0;
        file.write(reinterpret_cast<const char*>(&attrByteCount), 2);
    }

    file.close();
    return true;
}

bool MeshExporter::exportOBJ(const Mesh& mesh, const std::string& filePath) {
    std::ofstream file(filePath);
    if (!file.is_open()) return false;

    file << "# OrthoScan OBJ Export\n";

    for (const auto& v : mesh.vertices) {
        file << "v " << v.x << " " << v.y << " " << v.z << "\n";
    }

    for (const auto& tri : mesh.triangles) {
        file << "f " << (tri.a + 1) << " "
                     << (tri.b + 1) << " "
                     << (tri.c + 1) << "\n";
    }

    file.close();
    return true;
}

bool MeshExporter::exportPLY(const PointCloud& cloud, const std::string& filePath) {
    std::ofstream file(filePath);
    if (!file.is_open()) return false;

    file << "ply\n";
    file << "format ascii 1.0\n";
    file << "element vertex " << cloud.size() << "\n";
    file << "property float x\n";
    file << "property float y\n";
    file << "property float z\n";
    file << "property uchar red\n";
    file << "property uchar green\n";
    file << "property uchar blue\n";
    file << "end_header\n";

    for (const auto& p : cloud.points) {
        file << p.x << " " << p.y << " " << p.z << " "
             << (int)p.r << " " << (int)p.g << " " << (int)p.b << "\n";
    }

    file.close();
    return true;
}