#include "orthoscan_core.h"
#include <android/log.h>
#include <jni.h>
#include <vector>

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
    LOGI("Scan session stopped - %zu points captured", g_pointCloud.size());
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
        LOGE("Export failed - no points captured");
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
        LOGE("Export failed - no points captured");
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
        LOGE("Export failed - no points captured");
        return 0;
    }
    bool success = MeshExporter::exportPLY(g_pointCloud, std::string(filePath));
    if (success) LOGI("PLY exported to %s", filePath);
    else LOGE("PLY export failed to %s", filePath);
    return success ? 1 : 0;
}

// ─── JNI Entry Points ─────────────────────────────────────────────────────────

extern "C" JNIEXPORT void JNICALL
Java_com_orthotics_orthoscan_MainActivity_addPointToCore(
        JNIEnv* env,
        jobject /* this */,
        jfloat x,
        jfloat y,
        jfloat z) {
    orthoscan_add_point(x, y, z);
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_orthotics_orthoscan_MainActivity_getPointsFromCore(
        JNIEnv* env,
        jobject /* this */) {
    const auto& points = g_pointCloud.points;
    int count = (int)points.size();

    jfloatArray result = env->NewFloatArray(count * 3);
    if (result == nullptr) return nullptr;

    std::vector<float> flat;
    flat.reserve(count * 3);
    for (const auto& p : points) {
        flat.push_back(p.x);
        flat.push_back(p.y);
        flat.push_back(p.z);
    }

    env->SetFloatArrayRegion(result, 0, count * 3, flat.data());
    return result;
}

extern "C" JNIEXPORT void JNICALL
Java_com_orthotics_orthoscan_MainActivity_orthoscanStartSession(
        JNIEnv* env, jobject /* this */) {
    orthoscan_start_session();
}

extern "C" JNIEXPORT void JNICALL
Java_com_orthotics_orthoscan_MainActivity_orthoscanStopSession(
        JNIEnv* env, jobject /* this */) {
    orthoscan_stop_session();
}

extern "C" JNIEXPORT void JNICALL
Java_com_orthotics_orthoscan_MainActivity_orthoscanReset(
        JNIEnv* env, jobject /* this */) {
    orthoscan_reset();
}

extern "C" JNIEXPORT jint JNICALL
Java_com_orthotics_orthoscan_MainActivity_orthoscanGetPointCount(
        JNIEnv* env, jobject /* this */) {
    return orthoscan_get_point_count();
}