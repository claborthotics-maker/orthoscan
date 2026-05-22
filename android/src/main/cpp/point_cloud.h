#pragma once

#include <vector>
#include <cstdint>

struct Point3D {
    float x, y, z;
    uint8_t r, g, b;
};

struct PointCloud {
    std::vector<Point3D> points;

    void addPoint(float x, float y, float z);
    void addPoint(float x, float y, float z, uint8_t r, uint8_t g, uint8_t b);

    size_t size() const;
    void clear();
    bool isEmpty() const;

    void getBounds(float& minX, float& maxX,
                   float& minY, float& maxY,
                   float& minZ, float& maxZ) const;
};