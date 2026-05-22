#include "orthoscan_core.h"
#include <android/log.h>
#include <jni.h>

#define LOG_TAG "OrthoScan"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static PointCloud g_pointCloud;
static bool g_isScanning = false;

void orthoscan_start_session() {
    g_pointCloud.clear();
    g_isScanning = true;
    LOGI("Scan session started");
}

void orthoscan_stop_session() {
    g_isScanning = false;
    LOGI("Scan session stopped — %zu points captured", g_pointCloud.size());
}

void orthoscan_reset() {
    g_pointCloud.clear();
    g_isScanning = false;
    LOGI("Scan reset");
}

void orthoscan_add_point(float x, float y, float z) {
    if (!g_isScanning) return;
    g_pointCloud.addPoint(x, y, z);
}

void orthoscan_add_point_colored(float x, float y, float z,
                                  uint8_t r, uint8_t g, uint8_t b) {
    if (!g_isScanning) return;
    g_pointCloud.addPoint(x, y, z, r, g, b);
}

int orthoscan_get_point_count() {
    return (int)g_pointCloud.size();
}

int orthoscan_is_scanning() {
    return g_isScanning ? 1 : 0;
}

int orthoscan_export_stl(const char* filePath) {
    if (g_pointCloud.isEmpty()) {
        LOGE("Export failed — no points captured");
        return 0;
    }
    Mesh mesh;
    mesh.vertices = g_pointCloud.points;
    bool success = MeshExporter::exportSTL(mesh, std::string(filePath));
    if (success) LOGI("STL exported to %s", filePath);
    else LOGE("STL export failed to %s", filePath);
    return success ? 1 : 0;
}

int orthoscan_export_obj(const char* filePath) {
    if (g_pointCloud.isEmpty()) {
        LOGE("Export failed — no points captured");
        return 0;
    }
    Mesh mesh;
    mesh.vertices = g_pointCloud.points;
    bool success = MeshExporter::exportOBJ(mesh, std::string(filePath));
    if (success) LOGI("OBJ exported to %s", filePath);
    else LOGE("OBJ export failed to %s", filePath);
    return success ? 1 : 0;
}

int orthoscan_export_ply(const char* filePath) {
    if (g_pointCloud.isEmpty()) {
        LOGE("Export failed — no points captured");
        return 0;
    }
    bool success = MeshExporter::exportPLY(g_pointCloud, std::string(filePath));
    if (success) LOGI("PLY exported to %s", filePath);
    else LOGE("PLY export failed to %s", filePath);
    return success ? 1 : 0;
}
// ─── JNI Entry Point ──────────────────────────────────────────────────────────
// This is called directly from Kotlin via System.loadLibrary("orthoscan_core")
extern "C" JNIEXPORT void JNICALL
Java_com_orthotics_orthoscan_MainActivity_addPointToCore(
        JNIEnv* env,
        jobject /* this */,
        jfloat x,
        jfloat y,
        jfloat z) {
    orthoscan_add_point(x, y, z);
}