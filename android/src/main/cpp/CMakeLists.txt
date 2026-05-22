cmake_minimum_required(VERSION 3.18.1)
project(orthoscan_core)

add_library(
    orthoscan_core
    SHARED
    orthoscan_core.cpp
    point_cloud.cpp
    mesh_exporter.cpp
)

target_include_directories(orthoscan_core PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

find_library(log-lib log)

target_link_libraries(
    orthoscan_core
    ${log-lib}
)

target_compile_features(orthoscan_core PRIVATE cxx_std_17)