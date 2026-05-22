#pragma once

#include "point_cloud.h"
#include <string>
#include <vector>

struct Triangle {
    uint32_t a, b, c;
};

struct Mesh {
    std::vector<Point3D> vertices;
    std::vector<Triangle> triangles;
};

class MeshExporter {
public:
    static bool exportSTL(const Mesh& mesh, const std::string& filePath);
    static bool exportOBJ(const Mesh& mesh, const std::string& filePath);
    static bool exportPLY(const PointCloud& cloud, const std::string& filePath);
};