#include "point_cloud.h"
#include <limits>

void PointCloud::addPoint(float x, float y, float z) {
    points.push_back({x, y, z, 128, 128, 128});
}

void PointCloud::addPoint(float x, float y, float z, uint8_t r, uint8_t g, uint8_t b) {
    points.push_back({x, y, z, r, g, b});
}

size_t PointCloud::size() const {
    return points.size();
}

void PointCloud::clear() {
    points.clear();
}

bool PointCloud::isEmpty() const {
    return points.empty();
}

void PointCloud::getBounds(float& minX, float& maxX,
                           float& minY, float& maxY,
                           float& minZ, float& maxZ) const {
    minX = minY = minZ = std::numeric_limits<float>::max();
    maxX = maxY = maxZ = std::numeric_limits<float>::lowest();

    for (const auto& p : points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
        if (p.z < minZ) minZ = p.z;
        if (p.z > maxZ) maxZ = p.z;
    }
}