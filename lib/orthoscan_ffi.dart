import 'dart:ffi';
import 'dart:io';

// Load the C++ library we compiled
final DynamicLibrary _lib = Platform.isAndroid
    ? DynamicLibrary.open('liborthoscan_core.so')
    : DynamicLibrary.process();

// ─── Bind C++ functions to Dart ───────────────────────────────────────────────

final void Function() orthoscanStartSession = _lib
    .lookup<NativeFunction<Void Function()>>('orthoscan_start_session')
    .asFunction();

final void Function() orthoscanStopSession = _lib
    .lookup<NativeFunction<Void Function()>>('orthoscan_stop_session')
    .asFunction();

final void Function() orthoscanReset = _lib
    .lookup<NativeFunction<Void Function()>>('orthoscan_reset')
    .asFunction();

final void Function(double, double, double) orthoscanAddPoint = _lib
    .lookup<NativeFunction<Void Function(Float, Float, Float)>>('orthoscan_add_point')
    .asFunction();

final int Function() orthoscanGetPointCount = _lib
    .lookup<NativeFunction<Int32 Function()>>('orthoscan_get_point_count')
    .asFunction();

final int Function() orthoscanIsScanning = _lib
    .lookup<NativeFunction<Int32 Function()>>('orthoscan_is_scanning')
    .asFunction();