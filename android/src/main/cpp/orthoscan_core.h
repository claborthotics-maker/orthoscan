#pragma once

#include "point_cloud.h"
#include "mesh_exporter.h"
#include <string>

extern "C" {
    void orthoscan_start_session();
    void orthoscan_stop_session();
    void orthoscan_reset();

    void orthoscan_add_point(float x, float y, float z);
    void orthoscan_add_point_colored(float x, float y, float z,
                                     uint8_t r, uint8_t g, uint8_t b);

    int orthoscan_get_point_count();
    int orthoscan_is_scanning();

    int orthoscan_export_stl(const char* filePath);
    int orthoscan_export_obj(const char* filePath);
    int orthoscan_export_ply(const char* filePath);
}