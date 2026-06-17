#include <node_api.h>
#include <hilog/log.h>
#include <cstring>
#include <string>
#include <vector>
#include <atomic>
#include <algorithm>
#include <chrono>
#include <mutex>
#include <thread>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <multimedia/player_framework/native_avscreen_capture.h>
#include <native_buffer/native_buffer.h>

extern "C" void qsort_r(void *base, size_t nmemb, size_t size,
                         int (*compar)(const void *, const void *, void *),
                         void *arg) {
  if (!base || !compar || nmemb == 0 || size == 0) return;
  std::vector<char> tmp(size);
  for (size_t i = 0; i < nmemb - 1; i++) {
    for (size_t j = i + 1; j < nmemb; j++) {
      void *a = (char *)base + i * size;
      void *b = (char *)base + j * size;
      if (compar(a, b, arg) > 0) {
        memcpy(tmp.data(), a, size);
        memcpy(a, b, size);
        memcpy(b, tmp.data(), size);
      }
    }
  }
}

#include "rustdesk_bridge_abi.h"

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x3200
#define LOG_TAG "RustDeskLoader"

static const char *kDefaultSnapshot = R"JSON({
  "adapter":"loader-stub",
  "coreReady":false,
  "incomingReady":false,
  "displayId":"",
  "fingerprint":"Core not loaded",
  "directAddress":"Core not loaded",
  "statusSummary":"NAPI bridge ready, core .so not loaded yet",
  "detailMessage":"Use loadCoreLibrary(path) to load the RustDesk core .so at runtime.",
  "server":"",
  "sessionStage":"idle",
  "activePeerId":"",
  "lastError":""
})JSON";

namespace {

napi_value MakeString(napi_env env, const std::string &value) {
  napi_value result = nullptr;
  napi_create_string_utf8(env, value.c_str(), value.size(), &result);
  return result;
}

napi_value MakeNull(napi_env env) {
  napi_value result = nullptr;
  napi_get_null(env, &result);
  return result;
}

napi_value MakeBool(napi_env env, bool value) {
  napi_value result = nullptr;
  napi_get_boolean(env, value, &result);
  return result;
}

void ReadUtf8String(napi_env env, napi_value value, std::string *result) {
  if (result == nullptr) return;
  size_t size = 0;
  napi_get_value_string_utf8(env, value, nullptr, 0, &size);
  result->resize(size + 1);
  napi_get_value_string_utf8(env, value, result->empty() ? nullptr : &(*result)[0], result->size(), &size);
  result->resize(size);
}

std::string CopyOwnedString(const char *value) {
  if (value == nullptr) return kDefaultSnapshot;
  std::string copied(value);
  rustdesk_bridge_string_free(value);
  return copied;
}

std::string CopyOwnedText(const char *value) {
  if (value == nullptr) return "";
  std::string copied(value);
  rustdesk_bridge_string_free(value);
  return copied;
}

bool IsCoreLoaded() {
  return true;
}

struct NativeScreenCaptureState {
  std::mutex mutex;
  OH_AVScreenCapture *capture = nullptr;
  std::thread worker;
  std::atomic_bool running{false};
  std::atomic_bool video_buffer_ready{false};
  bool active = false;
  int width = 0;
  int height = 0;
  int frame_rate = 0;
  int32_t last_error_code = 0;
  int32_t last_buffer_format = 0;
  int32_t last_buffer_stride = 0;
  int64_t last_timestamp = 0;
  uint64_t frame_count = 0;
  uint64_t core_frame_count = 0;
  uint64_t last_payload_bytes = 0;
  bool last_core_push_ok = false;
  std::string last_error;
};

NativeScreenCaptureState g_native_screen_capture;

std::string EscapeJsonString(const std::string &value) {
  std::string escaped;
  escaped.reserve(value.size() + 8);
  for (char ch : value) {
    switch (ch) {
      case '\\': escaped += "\\\\"; break;
      case '"': escaped += "\\\""; break;
      case '\n': escaped += "\\n"; break;
      case '\r': escaped += "\\r"; break;
      case '\t': escaped += "\\t"; break;
      default: escaped += ch; break;
    }
  }
  return escaped;
}

void NativeScreenCaptureSetError(const std::string &message, int32_t code = 0) {
  std::lock_guard<std::mutex> lock(g_native_screen_capture.mutex);
  g_native_screen_capture.last_error = message;
  g_native_screen_capture.last_error_code = code;
  OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
               "Native screen capture error code=%{public}d message=%{public}s",
               code, message.c_str());
}

void NativeScreenCaptureOnError(OH_AVScreenCapture *capture, int32_t errorCode) {
  (void)capture;
  NativeScreenCaptureSetError("OH_AVScreenCapture runtime error", errorCode);
}

void NativeScreenCaptureOnAudioBuffer(OH_AVScreenCapture *capture, bool isReady,
                                      OH_AudioCaptureSourceType type) {
  (void)capture;
  (void)isReady;
  (void)type;
}

void NativeScreenCaptureOnVideoBuffer(OH_AVScreenCapture *capture, bool isReady) {
  (void)capture;
  if (isReady) {
    g_native_screen_capture.video_buffer_ready.store(true);
  } else {
    NativeScreenCaptureSetError("OH_AVScreenCapture video buffer is not ready", 0);
  }
}

int32_t NativeScreenCaptureOk(OH_AVSCREEN_CAPTURE_ErrCode code, const char *step) {
  if (code == AV_SCREEN_CAPTURE_ERR_OK) {
    return 1;
  }
  NativeScreenCaptureSetError(std::string(step) + " failed", static_cast<int32_t>(code));
  return 0;
}

const char *NativeScreenCaptureFormatName(int32_t format) {
  switch (format) {
    case NATIVEBUFFER_PIXEL_FMT_RGBA_8888:
      return "RGBA";
    case NATIVEBUFFER_PIXEL_FMT_BGRA_8888:
      return "BGRA";
    case NATIVEBUFFER_PIXEL_FMT_RGBX_8888:
      return "RGBX";
    case NATIVEBUFFER_PIXEL_FMT_BGRX_8888:
      return "BGRX";
    case NATIVEBUFFER_PIXEL_FMT_RGB_565:
      return "RGB565";
    default:
      return "RGBA";
  }
}

void NativeScreenCaptureDrainLoop(OH_AVScreenCapture *capture, int frame_rate) {
  const int sleep_ms = frame_rate > 0 ? std::max(16, 1000 / frame_rate) : 100;
  while (g_native_screen_capture.running.load() && !g_native_screen_capture.video_buffer_ready.load()) {
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }
  while (g_native_screen_capture.running.load()) {
    int32_t fence = 0;
    int64_t timestamp = 0;
    OH_Rect region = {};
    OH_NativeBuffer *buffer = OH_AVScreenCapture_AcquireVideoBuffer(capture, &fence, &timestamp, &region);
    if (buffer != nullptr) {
      OH_NativeBuffer_Config buffer_config = {};
      OH_NativeBuffer_GetConfig(buffer, &buffer_config);
      void *mapped = nullptr;
      bool core_push_ok = false;
      uint64_t payload_bytes = 0;
      if (OH_NativeBuffer_Map(buffer, &mapped) == 0 && mapped != nullptr) {
        const int32_t width = buffer_config.width > 0 ? buffer_config.width : 0;
        const int32_t height = buffer_config.height > 0 ? buffer_config.height : 0;
        const int32_t stride = buffer_config.stride > 0 ? buffer_config.stride : width * 4;
        if (width > 0 && height > 0 && stride > 0) {
          payload_bytes = static_cast<uint64_t>(stride) * static_cast<uint64_t>(height);
          core_push_ok = rustdesk_bridge_update_incoming_screen_frame(
            width,
            height,
            stride,
            static_cast<long long>(timestamp),
            NativeScreenCaptureFormatName(buffer_config.format),
            static_cast<const unsigned char *>(mapped),
            static_cast<unsigned long long>(payload_bytes)) != 0;
        }
        OH_NativeBuffer_Unmap(buffer);
      }
      {
        std::lock_guard<std::mutex> lock(g_native_screen_capture.mutex);
        g_native_screen_capture.frame_count += 1;
        if (core_push_ok) {
          g_native_screen_capture.core_frame_count += 1;
        }
        g_native_screen_capture.last_core_push_ok = core_push_ok;
        g_native_screen_capture.last_payload_bytes = payload_bytes;
        g_native_screen_capture.last_timestamp = timestamp;
        g_native_screen_capture.last_buffer_format = buffer_config.format;
        g_native_screen_capture.last_buffer_stride = buffer_config.stride;
        if (buffer_config.width > 0) g_native_screen_capture.width = buffer_config.width;
        if (buffer_config.height > 0) g_native_screen_capture.height = buffer_config.height;
      }
      OH_AVScreenCapture_ReleaseVideoBuffer(capture);
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(sleep_ms));
  }
}

bool NativeScreenCaptureStopInternal() {
  OH_AVScreenCapture *capture = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_native_screen_capture.mutex);
    capture = g_native_screen_capture.capture;
    g_native_screen_capture.running.store(false);
  }
  if (g_native_screen_capture.worker.joinable()) {
    g_native_screen_capture.worker.join();
  }
  if (capture != nullptr) {
    OH_AVScreenCapture_StopScreenCapture(capture);
    OH_AVScreenCapture_Release(capture);
  }
  rustdesk_bridge_clear_incoming_screen_frame();
  {
    std::lock_guard<std::mutex> lock(g_native_screen_capture.mutex);
    g_native_screen_capture.capture = nullptr;
    g_native_screen_capture.active = false;
  }
  return true;
}

bool NativeScreenCaptureStart(int width, int height, int frame_rate) {
  {
    std::lock_guard<std::mutex> lock(g_native_screen_capture.mutex);
    if (g_native_screen_capture.active && g_native_screen_capture.capture != nullptr) {
      return true;
    }
  }
  NativeScreenCaptureStopInternal();

  const int capture_width = width > 0 ? width : 1280;
  const int capture_height = height > 0 ? height : 720;
  const int capture_fps = frame_rate > 0 ? frame_rate : 10;
  OH_AVScreenCapture *capture = OH_AVScreenCapture_Create();
  if (capture == nullptr) {
    NativeScreenCaptureSetError("OH_AVScreenCapture_Create failed");
    return false;
  }

  OH_AVScreenCaptureCallback callback = {};
  callback.onError = NativeScreenCaptureOnError;
  callback.onAudioBufferAvailable = NativeScreenCaptureOnAudioBuffer;
  callback.onVideoBufferAvailable = NativeScreenCaptureOnVideoBuffer;
  OH_AVScreenCapture_SetCallback(capture, callback);
  OH_AVScreenCapture_SetMicrophoneEnabled(capture, false);

  OH_AVScreenCaptureConfig config = {};
  config.captureMode = OH_CAPTURE_HOME_SCREEN;
  config.dataType = OH_ORIGINAL_STREAM;
  config.audioInfo.micCapInfo.audioSource = OH_SOURCE_INVALID;
  config.audioInfo.innerCapInfo.audioSource = OH_SOURCE_INVALID;
  config.videoInfo.videoCapInfo.videoFrameWidth = capture_width;
  config.videoInfo.videoCapInfo.videoFrameHeight = capture_height;
  config.videoInfo.videoCapInfo.videoSource = OH_VIDEO_SOURCE_SURFACE_RGBA;
  config.videoInfo.videoEncInfo.videoCodec = OH_VIDEO_DEFAULT;
  config.videoInfo.videoEncInfo.videoFrameRate = capture_fps;
  config.videoInfo.videoEncInfo.videoBitrate = capture_width * capture_height * capture_fps;

  if (!NativeScreenCaptureOk(OH_AVScreenCapture_Init(capture, config), "OH_AVScreenCapture_Init")) {
    OH_AVScreenCapture_Release(capture);
    return false;
  }
  OH_AVScreenCapture_SetMaxVideoFrameRate(capture, capture_fps);
  if (!NativeScreenCaptureOk(OH_AVScreenCapture_StartScreenCapture(capture), "OH_AVScreenCapture_StartScreenCapture")) {
    OH_AVScreenCapture_Release(capture);
    return false;
  }

  {
    std::lock_guard<std::mutex> lock(g_native_screen_capture.mutex);
    g_native_screen_capture.capture = capture;
    g_native_screen_capture.active = true;
    g_native_screen_capture.width = capture_width;
    g_native_screen_capture.height = capture_height;
    g_native_screen_capture.frame_rate = capture_fps;
    g_native_screen_capture.frame_count = 0;
    g_native_screen_capture.core_frame_count = 0;
    g_native_screen_capture.last_payload_bytes = 0;
    g_native_screen_capture.last_core_push_ok = false;
    g_native_screen_capture.last_error.clear();
    g_native_screen_capture.last_error_code = 0;
    g_native_screen_capture.running.store(true);
    g_native_screen_capture.video_buffer_ready.store(false);
  }
  g_native_screen_capture.worker = std::thread(NativeScreenCaptureDrainLoop, capture, capture_fps);
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "Native screen capture started width=%{public}d height=%{public}d fps=%{public}d",
               capture_width, capture_height, capture_fps);
  return true;
}

std::string NativeScreenCaptureStatsJson() {
  std::lock_guard<std::mutex> lock(g_native_screen_capture.mutex);
  std::string error = EscapeJsonString(g_native_screen_capture.last_error);
  return std::string("{") +
    "\"active\":" + (g_native_screen_capture.active ? "true" : "false") +
    ",\"width\":" + std::to_string(g_native_screen_capture.width) +
    ",\"height\":" + std::to_string(g_native_screen_capture.height) +
    ",\"frameRate\":" + std::to_string(g_native_screen_capture.frame_rate) +
    ",\"frameCount\":" + std::to_string(g_native_screen_capture.frame_count) +
    ",\"coreFrameCount\":" + std::to_string(g_native_screen_capture.core_frame_count) +
    ",\"payloadBytes\":" + std::to_string(g_native_screen_capture.last_payload_bytes) +
    ",\"corePushOk\":" + (g_native_screen_capture.last_core_push_ok ? "true" : "false") +
    ",\"timestamp\":" + std::to_string(g_native_screen_capture.last_timestamp) +
    ",\"format\":" + std::to_string(g_native_screen_capture.last_buffer_format) +
    ",\"stride\":" + std::to_string(g_native_screen_capture.last_buffer_stride) +
    ",\"lastErrorCode\":" + std::to_string(g_native_screen_capture.last_error_code) +
    ",\"lastError\":\"" + error + "\"}";
}

struct CoreFileInfo {
  bool exists;
  bool valid_elf;
  off_t file_size;
  long long modified_time;
  std::string error;
};

static const uint8_t ELF_MAGIC[] = {0x7f, 'E', 'L', 'F'};

CoreFileInfo ValidateCoreFile(const char *path) {
  CoreFileInfo info = {false, false, 0, 0, ""};

  if (path == nullptr || path[0] == '\0') {
    info.error = "empty path";
    return info;
  }

  struct stat st;
  if (stat(path, &st) != 0) {
    info.error = "file not found";
    return info;
  }

  info.exists = true;
  info.file_size = st.st_size;
  info.modified_time = static_cast<long long>(st.st_mtime);

  if (st.st_size < 16) {
    info.error = "file too small (< 16 bytes)";
    return info;
  }

  int fd = open(path, O_RDONLY);
  if (fd < 0) {
    info.error = "cannot open file";
    return info;
  }

  uint8_t header[16] = {0};
  ssize_t n = read(fd, header, 16);
  close(fd);

  if (n < 4) {
    info.error = "cannot read file header";
    return info;
  }

  if (std::memcmp(header, ELF_MAGIC, 4) != 0) {
    info.error = "not an ELF file (bad magic)";
    return info;
  }

  if (header[4] != 2) {
    info.error = "not 64-bit ELF (e_ident[EI_CLASS] != 2)";
    return info;
  }

  if (header[5] != 1) {
    info.error = "not little-endian ELF";
    return info;
  }

  info.valid_elf = true;
  return info;
}

std::string ComputeFileMD5Hex(const char *path, size_t max_bytes) {
  if (path == nullptr || path[0] == '\0') return "";

  int fd = open(path, O_RDONLY);
  if (fd < 0) return "";

  uint32_t hash = 0x811c9dc5;
  uint8_t buf[8192];
  size_t total = 0;
  while (total < max_bytes) {
    size_t to_read = sizeof(buf);
    if (max_bytes - total < to_read) to_read = max_bytes - total;
    ssize_t n = read(fd, buf, to_read);
    if (n <= 0) break;
    for (ssize_t i = 0; i < n; i++) {
      hash ^= buf[i];
      hash *= 0x01000193;
    }
    total += n;
  }
  close(fd);

  char hex[9];
  std::snprintf(hex, sizeof(hex), "%08x", hash);
  return std::string(hex);
}

bool LoadCoreFromPath(const char *path) {
  OH_LOG_INFO(LOG_APP, "LoadCoreFromPath: static-link mode, core is linked at compile time (path=%{public}s)",
              path ? path : "(null)");
  return true;
}

} // namespace

namespace {

napi_value NapiLoadCoreLibrary(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  bool ok = LoadCoreFromPath(path.c_str());
  return MakeBool(env, ok);
}

napi_value NapiIsCoreLoaded(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeBool(env, IsCoreLoaded());
}

napi_value NapiGetCoreLoadInfo(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeString(env, R"JSON({"loaded":true,"source":"static-link"})JSON");
}

napi_value NapiVerifyCoreFile(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);

  CoreFileInfo fi = ValidateCoreFile(path.c_str());
  std::string json = std::string(R"JSON({"exists":)JSON") +
    (fi.exists ? "true" : "false") + "," +
    R"JSON("validElf":)JSON" +
    (fi.valid_elf ? "true" : "false") + "," +
    R"JSON("fileSize":)JSON" + std::to_string(fi.file_size) + "," +
    R"JSON("modifiedTime":)JSON" + std::to_string(fi.modified_time) + "," +
    R"JSON("error":")JSON" + fi.error + R"JSON("})JSON";

  OH_LOG_INFO(LOG_APP, "verifyCoreFile: %{public}s", json.c_str());
  return MakeString(env, json);
}

napi_value NapiGetCoreFileInfo(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);

  CoreFileInfo fi = ValidateCoreFile(path.c_str());
  std::string fhash = ComputeFileMD5Hex(path.c_str(), 1024 * 1024);

  std::string json = std::string(R"JSON({"path":")JSON") + path + R"JSON(",)JSON" +
    R"JSON("exists":)JSON" + (fi.exists ? "true" : "false") + "," +
    R"JSON("validElf":)JSON" + (fi.valid_elf ? "true" : "false") + "," +
    R"JSON("fileSize":)JSON" + std::to_string(fi.file_size) + "," +
    R"JSON("fileSizeMB":)JSON" + std::to_string(fi.file_size / 1024 / 1024) + "," +
    R"JSON("modifiedTime":)JSON" + std::to_string(fi.modified_time) + "," +
    R"JSON("hash":")JSON" + fhash + R"JSON(",)JSON" +
    R"JSON("error":")JSON" + fi.error + R"JSON("})JSON";

  OH_LOG_INFO(LOG_APP, "getCoreFileInfo: %{public}s", json.c_str());
  return MakeString(env, json);
}

napi_value GetCoreSnapshot(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string server;
  if (argc > 0) ReadUtf8String(env, args[0], &server);
  const char *snapshot = rustdesk_bridge_get_core_snapshot(server.c_str());
  return MakeString(env, CopyOwnedString(snapshot));
}

napi_value InitializeRuntime(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string values[2];
  for (size_t i = 0; i < argc && i < 2; ++i) ReadUtf8String(env, args[i], &values[i]);
  const char *snapshot = rustdesk_bridge_initialize_runtime(values[0].c_str(), values[1].c_str());
  return MakeString(env, CopyOwnedString(snapshot));
}

napi_value PullSessionEvents(napi_env env, napi_callback_info info) {
  (void)info;
  const char *events = rustdesk_bridge_pull_session_events();
  return MakeString(env, CopyOwnedString(events));
}

napi_value GetLatestVideoFrameMetadata(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t since_frame_id = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &since_frame_id);
  const char *metadata = rustdesk_bridge_get_latest_video_frame_metadata(static_cast<unsigned long long>(since_frame_id));
  if (metadata == nullptr) return MakeNull(env);
  const std::string copied(metadata);
  rustdesk_bridge_string_free(metadata);
  if (copied.empty() || copied == "null") return MakeNull(env);
  return MakeString(env, copied);
}

napi_value CopyLatestVideoFrame(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t frame_id = 0, expected_bytes = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &frame_id);
  if (argc > 1) napi_get_value_int64(env, args[1], &expected_bytes);
  if (expected_bytes <= 0) return MakeNull(env);
  void *data = nullptr;
  napi_value array_buffer = nullptr;
  napi_create_arraybuffer(env, static_cast<size_t>(expected_bytes), &data, &array_buffer);
  const int copied = rustdesk_bridge_copy_latest_video_frame(static_cast<unsigned long long>(frame_id), static_cast<unsigned char *>(data), static_cast<unsigned long long>(expected_bytes));
  if (copied <= 0 || copied != expected_bytes) return MakeNull(env);
  return array_buffer;
}

napi_value GetIncomingScreenFrameMetadata(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t since_frame_id = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &since_frame_id);
  const char *metadata = rustdesk_bridge_get_incoming_screen_frame_metadata(static_cast<unsigned long long>(since_frame_id));
  if (metadata == nullptr) return MakeNull(env);
  const std::string copied(metadata);
  rustdesk_bridge_string_free(metadata);
  if (copied.empty() || copied == "null") return MakeNull(env);
  return MakeString(env, copied);
}

napi_value CopyIncomingScreenFrame(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t frame_id = 0, expected_bytes = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &frame_id);
  if (argc > 1) napi_get_value_int64(env, args[1], &expected_bytes);
  if (expected_bytes <= 0) return MakeNull(env);
  void *data = nullptr;
  napi_value array_buffer = nullptr;
  napi_create_arraybuffer(env, static_cast<size_t>(expected_bytes), &data, &array_buffer);
  const int copied = rustdesk_bridge_copy_incoming_screen_frame(static_cast<unsigned long long>(frame_id), static_cast<unsigned char *>(data), static_cast<unsigned long long>(expected_bytes));
  if (copied <= 0 || copied != expected_bytes) return MakeNull(env);
  return array_buffer;
}

napi_value UpdateIncomingScreenFrame(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value args[6] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t width = 0, height = 0, stride = 0;
  int64_t timestamp = 0;
  std::string format;
  if (argc > 0) napi_get_value_int32(env, args[0], &width);
  if (argc > 1) napi_get_value_int32(env, args[1], &height);
  if (argc > 2) napi_get_value_int32(env, args[2], &stride);
  if (argc > 3) napi_get_value_int64(env, args[3], &timestamp);
  if (argc > 4) ReadUtf8String(env, args[4], &format);
  void *data = nullptr;
  size_t data_len = 0;
  if (argc > 5 && args[5] != nullptr) {
    bool is_array_buffer = false;
    napi_is_arraybuffer(env, args[5], &is_array_buffer);
    if (is_array_buffer) {
      napi_get_arraybuffer_info(env, args[5], &data, &data_len);
    } else {
      bool is_typed_array = false;
      napi_is_typedarray(env, args[5], &is_typed_array);
      if (is_typed_array) {
        napi_typedarray_type type;
        size_t length = 0;
        napi_value array_buffer = nullptr;
        size_t byte_offset = 0;
        napi_get_typedarray_info(env, args[5], &type, &length, &data, &array_buffer, &byte_offset);
        (void)array_buffer;
        (void)byte_offset;
        data_len = length;
        if (type != napi_uint8_array && type != napi_uint8_clamped_array) {
          data = nullptr;
          data_len = 0;
        }
      }
    }
  }
  if (data == nullptr || data_len == 0) return MakeBool(env, false);
  return MakeBool(env, rustdesk_bridge_update_incoming_screen_frame(
    width,
    height,
    stride,
    timestamp,
    format.c_str(),
    static_cast<const unsigned char *>(data),
    static_cast<unsigned long long>(data_len)) != 0);
}

napi_value ClearIncomingScreenFrame(napi_env env, napi_callback_info info) {
  (void)info;
  rustdesk_bridge_clear_incoming_screen_frame();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value RefreshSessionVideo(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  return MakeBool(env, rustdesk_bridge_refresh_session_video(display) != 0);
}

napi_value HarmonyNextRgba(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  rustdesk_bridge_harmony_next_rgba(display);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value ConnectToPeer(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value args[6] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string values[6];
  for (size_t i = 0; i < argc && i < 6; ++i) ReadUtf8String(env, args[i], &values[i]);
  rustdesk_bridge_session_start(values[0].c_str(), values[1].c_str(), values[2].c_str(), values[3].c_str(), values[4].c_str(), values[5].c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value AccountAuth(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string op, server, relay_server, api_server;
  bool remember_me = false;
  if (argc > 0) ReadUtf8String(env, args[0], &op);
  if (argc > 1) napi_get_value_bool(env, args[1], &remember_me);
  if (argc > 2) ReadUtf8String(env, args[2], &server);
  if (argc > 3) ReadUtf8String(env, args[3], &relay_server);
  if (argc > 4) ReadUtf8String(env, args[4], &api_server);
  rustdesk_bridge_main_account_auth(op.c_str(), remember_me ? 1 : 0, server.c_str(), relay_server.c_str(), api_server.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value AccountAuthCancel(napi_env env, napi_callback_info info) {
  (void)info;
  rustdesk_bridge_main_account_auth_cancel();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value AccountAuthResult(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_account_auth_result()));
}

napi_value GetLocalOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_local_option(key.c_str())));
}

napi_value SetLocalOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key, value;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  rustdesk_bridge_main_set_local_option(key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CloseSession(napi_env env, napi_callback_info info) {
  (void)info;
  rustdesk_bridge_session_close();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value ReconnectSession(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool force_relay = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &force_relay);
  return MakeBool(env, rustdesk_bridge_session_reconnect(force_relay ? 1 : 0) != 0);
}

napi_value SubmitSessionPassword(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string password;
  bool remember = false;
  if (argc > 0) ReadUtf8String(env, args[0], &password);
  if (argc > 1) napi_get_value_bool(env, args[1], &remember);
  return MakeBool(env, rustdesk_bridge_session_login(password.c_str(), remember ? 1 : 0) != 0);
}

napi_value SetIncomingServiceEnabled(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool enabled = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &enabled);
  std::string values[4];
  for (size_t i = 1; i < argc && i < 5; ++i) ReadUtf8String(env, args[i], &values[i - 1]);
  const char *snapshot = rustdesk_bridge_main_start_service(enabled ? 1 : 0, values[0].c_str(), values[1].c_str(), values[2].c_str(), values[3].c_str());
  return MakeString(env, CopyOwnedString(snapshot));
}

napi_value BootstrapCoreSnapshot(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string values[4];
  for (size_t i = 0; i < argc && i < 4; ++i) ReadUtf8String(env, args[i], &values[i]);
  const char *snapshot = rustdesk_bridge_bootstrap_core_snapshot(values[0].c_str(), values[1].c_str(), values[2].c_str(), values[3].c_str());
  return MakeString(env, CopyOwnedString(snapshot));
}

napi_value SendMouseInput(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t mask = 0, x = 0, y = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &mask);
  if (argc > 1) napi_get_value_int32(env, args[1], &x);
  if (argc > 2) napi_get_value_int32(env, args[2], &y);
  return MakeBool(env, rustdesk_bridge_session_send_mouse(mask, x, y) != 0);
}

napi_value SendKeyboardInput(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t key_code = 0, modifiers = 0;
  bool is_pressed = false;
  if (argc > 0) napi_get_value_int32(env, args[0], &key_code);
  if (argc > 1) napi_get_value_bool(env, args[1], &is_pressed);
  if (argc > 2) napi_get_value_int32(env, args[2], &modifiers);
  return MakeBool(env, rustdesk_bridge_session_input_key(key_code, is_pressed ? 1 : 0, modifiers) != 0);
}

napi_value SendCtrlAltDel(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeBool(env, rustdesk_bridge_session_ctrl_alt_del() != 0);
}

napi_value SendClipboardData(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string content;
  int64_t timestamp = 0;
  if (argc > 0) ReadUtf8String(env, args[0], &content);
  if (argc > 1) napi_get_value_int64(env, args[1], &timestamp);
  return MakeBool(env, rustdesk_bridge_send_clipboard_data(content.c_str(), timestamp) != 0);
}

napi_value SendVideoFrameMetadata(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value args[6] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t codec = 0, width = 0, height = 0, data_length = 0;
  int64_t timestamp = 0;
  bool key_frame = false;
  if (argc > 0) napi_get_value_int32(env, args[0], &codec);
  if (argc > 1) napi_get_value_int32(env, args[1], &width);
  if (argc > 2) napi_get_value_int32(env, args[2], &height);
  if (argc > 3) napi_get_value_int64(env, args[3], &timestamp);
  if (argc > 4) napi_get_value_bool(env, args[4], &key_frame);
  if (argc > 5) napi_get_value_int32(env, args[5], &data_length);
  return MakeBool(env, rustdesk_bridge_send_video_frame_metadata(codec, width, height, timestamp, key_frame ? 1 : 0, data_length) != 0);
}

napi_value SendAudioFrameMetadata(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t codec = 0, sample_rate = 0, channels = 0, data_length = 0;
  int64_t timestamp = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &codec);
  if (argc > 1) napi_get_value_int32(env, args[1], &sample_rate);
  if (argc > 2) napi_get_value_int32(env, args[2], &channels);
  if (argc > 3) napi_get_value_int64(env, args[3], &timestamp);
  if (argc > 4) napi_get_value_int32(env, args[4], &data_length);
  return MakeBool(env, rustdesk_bridge_send_audio_frame_metadata(codec, sample_rate, channels, timestamp, data_length) != 0);
}

napi_value StartNativeScreenCapture(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t width = 0;
  int32_t height = 0;
  int32_t frame_rate = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &width);
  if (argc > 1) napi_get_value_int32(env, args[1], &height);
  if (argc > 2) napi_get_value_int32(env, args[2], &frame_rate);
  return MakeBool(env, NativeScreenCaptureStart(width, height, frame_rate));
}

napi_value StopNativeScreenCapture(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeBool(env, NativeScreenCaptureStopInternal());
}

napi_value IsNativeScreenCaptureActive(napi_env env, napi_callback_info info) {
  (void)info;
  std::lock_guard<std::mutex> lock(g_native_screen_capture.mutex);
  return MakeBool(env, g_native_screen_capture.active && g_native_screen_capture.capture != nullptr);
}

napi_value GetNativeScreenCaptureStats(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeString(env, NativeScreenCaptureStatsJson());
}

napi_value SendChatMessage(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id, message_type, content;
  int64_t timestamp = 0;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  if (argc > 1) ReadUtf8String(env, args[1], &message_type);
  if (argc > 2) ReadUtf8String(env, args[2], &content);
  else if (argc > 0 && content.empty()) ReadUtf8String(env, args[0], &content);
  if (argc > 3) napi_get_value_int64(env, args[3], &timestamp);
  OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "SendChatMessage: argc=%{public}zu contentLen=%{public}zu content=[%{public}s]", argc, content.size(), content.c_str());
  int ret = rustdesk_bridge_session_send_chat(peer_id.c_str(), message_type.c_str(), content.c_str(), timestamp);
  OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "SendChatMessage: ret=%{public}d", ret);
  return MakeBool(env, ret != 0);
}

napi_value SendFileTransferRequest(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string task_id, peer_id, file_name, direction;
  int64_t total_bytes = 0;
  std::string *targets[4] = {&task_id, &peer_id, &file_name, &direction};
  size_t arg_indexes[4] = {0, 1, 2, 4};
  for (size_t i = 0; i < 4; ++i) if (argc > arg_indexes[i]) ReadUtf8String(env, args[arg_indexes[i]], targets[i]);
  if (argc > 3) napi_get_value_int64(env, args[3], &total_bytes);
  return MakeBool(env, rustdesk_bridge_send_file_transfer_request(task_id.c_str(), peer_id.c_str(), file_name.c_str(), total_bytes, direction.c_str()) != 0);
}

napi_value DebugMarkSessionConnected(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  rustdesk_bridge_mark_session_connected(peer_id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value DebugMarkSessionError(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string message;
  if (argc > 0) ReadUtf8String(env, args[0], &message);
  rustdesk_bridge_mark_session_error(message.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value OpenTerminal(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0, rows = 24, cols = 80;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  if (argc > 1) napi_get_value_int32(env, args[1], &rows);
  if (argc > 2) napi_get_value_int32(env, args[2], &cols);
  return MakeBool(env, rustdesk_bridge_session_open_terminal(terminal_id, rows, cols) != 0);
}

napi_value SendTerminalInput(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0;
  std::string data;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  if (argc > 1) ReadUtf8String(env, args[1], &data);
  return MakeBool(env, rustdesk_bridge_session_send_terminal_input(terminal_id, data.c_str()) != 0);
}

napi_value ResizeTerminal(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0, rows = 24, cols = 80;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  if (argc > 1) napi_get_value_int32(env, args[1], &rows);
  if (argc > 2) napi_get_value_int32(env, args[2], &cols);
  return MakeBool(env, rustdesk_bridge_session_resize_terminal(terminal_id, rows, cols) != 0);
}

napi_value CloseTerminal(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  return MakeBool(env, rustdesk_bridge_session_close_terminal(terminal_id) != 0);
}

napi_value ReadRemoteDirectory(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  bool include_hidden = false;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  if (argc > 1) napi_get_value_bool(env, args[1], &include_hidden);
  return MakeBool(env, rustdesk_bridge_session_read_remote_dir(path.c_str(), include_hidden ? 1 : 0) != 0);
}

napi_value CreateRemoteDirectory(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  return MakeBool(env, rustdesk_bridge_session_create_dir(path.c_str()) != 0);
}

napi_value DeleteRemotePath(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  bool is_directory = false;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  if (argc > 1) napi_get_value_bool(env, args[1], &is_directory);
  return MakeBool(env, rustdesk_bridge_delete_remote_path(path.c_str(), is_directory ? 1 : 0) != 0);
}

napi_value StartFileTransfer(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path, to;
  bool is_remote = false;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  if (argc > 1) ReadUtf8String(env, args[1], &to);
  if (argc > 2) napi_get_value_bool(env, args[2], &is_remote);
  return MakeBool(env, rustdesk_bridge_session_send_files(path.c_str(), to.c_str(), is_remote ? 1 : 0) != 0);
}

napi_value QueryOnlines(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string ids_json;
  if (argc > 0) ReadUtf8String(env, args[0], &ids_json);
  return MakeBool(env, rustdesk_bridge_query_onlines(ids_json.c_str()) != 0);
}

napi_value DiscoverLanPeers(napi_env env, napi_callback_info info) {
  (void)info;
  rustdesk_bridge_main_discover();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value LoadLanPeers(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_load_lan_peers()));
}

napi_value RemoveDiscoveredPeer(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  return MakeBool(env, rustdesk_bridge_main_remove_discovered(peer_id.c_str()) != 0);
}

napi_value GetPeerOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id, key;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  if (argc > 1) ReadUtf8String(env, args[1], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_peer_option(peer_id.c_str(), key.c_str())));
}

napi_value GetPeerInfo(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_peer_info(peer_id.c_str())));
}

napi_value GetSessionToggleOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeBool(env, rustdesk_bridge_session_get_toggle_option(key.c_str()) != 0);
}

napi_value ApplySessionOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key, value;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  return MakeBool(env, rustdesk_bridge_apply_session_option(key.c_str(), value.c_str()) != 0);
}

napi_value RestartRemoteDevice(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeBool(env, rustdesk_bridge_session_restart_remote_device() != 0);
}

napi_value LockRemoteScreen(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeBool(env, rustdesk_bridge_session_lock_screen() != 0);
}

napi_value PullAudioFrames(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeString(env, CopyOwnedText(rustdesk_bridge_pull_audio_frames()));
}

napi_value MarkSessionConnected(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  rustdesk_bridge_mark_session_connected(peer_id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MarkSessionError(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string message;
  if (argc > 0) ReadUtf8String(env, args[0], &message);
  rustdesk_bridge_mark_session_error(message.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}


napi_value GetSessionStage(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_session_stage()));
}

napi_value GetActivePeerId(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_active_peer_id()));
}

napi_value GetConnectStatusSummary(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_connect_status_summary()));
}

napi_value GetConnectDetailMessage(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_connect_detail_message()));
}

napi_value GetConnectLastError(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_connect_last_error()));
}

napi_value DrainConnectEventsJson(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_drain_connect_events_json()));
}

napi_value GetCoreSnapshotJson(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string server;
  if (argc > 0) ReadUtf8String(env, args[0], &server);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_core_snapshot_json(server.c_str())));
}

napi_value PullSessionEventsJson(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_pull_session_events_json()));
}

napi_value PullAudioFramesJson(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_pull_audio_frames_json()));
}

napi_value GetLatestVideoFrameMetadataJson(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t since_frame_id = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &since_frame_id);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_latest_video_frame_metadata_json(static_cast<unsigned long long>(since_frame_id))));
}

napi_value GetIncomingScreenFrameMetadataJson(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t since_frame_id = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &since_frame_id);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_incoming_screen_frame_metadata_json(static_cast<unsigned long long>(since_frame_id))));
}

napi_value MainStartService(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool enabled = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &enabled);
  std::string server;
  if (argc > 1) ReadUtf8String(env, args[1], &server);
  std::string relay_server;
  if (argc > 2) ReadUtf8String(env, args[2], &relay_server);
  std::string api_server;
  if (argc > 3) ReadUtf8String(env, args[3], &api_server);
  std::string key;
  if (argc > 4) ReadUtf8String(env, args[4], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_start_service(enabled ? 1 : 0, server.c_str(), relay_server.c_str(), api_server.c_str(), key.c_str())));
}

napi_value SessionSendMouse(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t mask = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &mask);
  int32_t x = 0;
  if (argc > 1) napi_get_value_int32(env, args[1], &x);
  int32_t y = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &y);
  return MakeBool(env, rustdesk_bridge_session_send_mouse(mask, x, y) != 0);
}

napi_value SessionInputKey(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t key_code = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &key_code);
  bool is_pressed = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &is_pressed);
  int32_t modifiers = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &modifiers);
  return MakeBool(env, rustdesk_bridge_session_input_key(key_code, is_pressed ? 1 : 0, modifiers) != 0);
}

napi_value SessionCtrlAltDel(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_ctrl_alt_del() != 0);
}

napi_value SessionSendChat(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id, message_type, content;
  int64_t timestamp = 0;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  if (argc > 1) ReadUtf8String(env, args[1], &message_type);
  if (argc > 2) ReadUtf8String(env, args[2], &content);
  else if (argc > 0 && content.empty()) ReadUtf8String(env, args[0], &content);
  if (argc > 3) napi_get_value_int64(env, args[3], &timestamp);
  OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "SessionSendChat: argc=%{public}zu contentLen=%{public}zu content=[%{public}s]", argc, content.size(), content.c_str());
  int ret = rustdesk_bridge_session_send_chat(peer_id.c_str(), message_type.c_str(), content.c_str(), timestamp);
  OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "SessionSendChat: ret=%{public}d", ret);
  return MakeBool(env, ret != 0);
}

napi_value SessionStart(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value args[6] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  std::string password;
  if (argc > 1) ReadUtf8String(env, args[1], &password);
  std::string server;
  if (argc > 2) ReadUtf8String(env, args[2], &server);
  std::string relay_server;
  if (argc > 3) ReadUtf8String(env, args[3], &relay_server);
  std::string api_server;
  if (argc > 4) ReadUtf8String(env, args[4], &api_server);
  std::string key;
  if (argc > 5) ReadUtf8String(env, args[5], &key);
  rustdesk_bridge_session_start(peer_id.c_str(), password.c_str(), server.c_str(), relay_server.c_str(), api_server.c_str(), key.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainAccountAuth(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string op;
  if (argc > 0) ReadUtf8String(env, args[0], &op);
  bool remember_me = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &remember_me);
  std::string server;
  if (argc > 2) ReadUtf8String(env, args[2], &server);
  std::string relay_server;
  if (argc > 3) ReadUtf8String(env, args[3], &relay_server);
  std::string api_server;
  if (argc > 4) ReadUtf8String(env, args[4], &api_server);
  rustdesk_bridge_main_account_auth(op.c_str(), remember_me ? 1 : 0, server.c_str(), relay_server.c_str(), api_server.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainAccountAuthCancel(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_account_auth_cancel();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainAccountAuthResult(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_account_auth_result()));
}

napi_value MainGetLocalOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_local_option(key.c_str())));
}

napi_value MainGetPeerOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  std::string key;
  if (argc > 1) ReadUtf8String(env, args[1], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_peer_option(peer_id.c_str(), key.c_str())));
}

napi_value SessionGetToggleOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeBool(env, rustdesk_bridge_session_get_toggle_option(key.c_str()) != 0);
}

napi_value MainSetLocalOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  std::string value;
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  rustdesk_bridge_main_set_local_option(key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionReconnect(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool force_relay = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &force_relay);
  return MakeBool(env, rustdesk_bridge_session_reconnect(force_relay ? 1 : 0) != 0);
}

napi_value SessionClose(napi_env env, napi_callback_info info) {
  rustdesk_bridge_session_close();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionLogin(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string password;
  if (argc > 0) ReadUtf8String(env, args[0], &password);
  bool remember = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &remember);
  return MakeBool(env, rustdesk_bridge_session_login(password.c_str(), remember ? 1 : 0) != 0);
}

napi_value SessionRestartRemoteDevice(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_restart_remote_device() != 0);
}

napi_value SessionLockScreen(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_lock_screen() != 0);
}

napi_value SessionOpenTerminal(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  int32_t rows = 0;
  if (argc > 1) napi_get_value_int32(env, args[1], &rows);
  int32_t cols = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &cols);
  return MakeBool(env, rustdesk_bridge_session_open_terminal(terminal_id, rows, cols) != 0);
}

napi_value SessionSendTerminalInput(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  std::string data;
  if (argc > 1) ReadUtf8String(env, args[1], &data);
  return MakeBool(env, rustdesk_bridge_session_send_terminal_input(terminal_id, data.c_str()) != 0);
}

napi_value SessionResizeTerminal(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  int32_t rows = 0;
  if (argc > 1) napi_get_value_int32(env, args[1], &rows);
  int32_t cols = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &cols);
  return MakeBool(env, rustdesk_bridge_session_resize_terminal(terminal_id, rows, cols) != 0);
}

napi_value SessionCloseTerminal(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  return MakeBool(env, rustdesk_bridge_session_close_terminal(terminal_id) != 0);
}

napi_value SessionReadRemoteDir(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  bool include_hidden = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &include_hidden);
  return MakeBool(env, rustdesk_bridge_session_read_remote_dir(path.c_str(), include_hidden ? 1 : 0) != 0);
}

napi_value SessionCreateDir(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  return MakeBool(env, rustdesk_bridge_session_create_dir(path.c_str()) != 0);
}

napi_value SessionSendFiles(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  std::string to;
  if (argc > 1) ReadUtf8String(env, args[1], &to);
  bool is_remote = false;
  if (argc > 2) napi_get_value_bool(env, args[2], &is_remote);
  return MakeBool(env, rustdesk_bridge_session_send_files(path.c_str(), to.c_str(), is_remote ? 1 : 0) != 0);
}

napi_value MainDiscover(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_discover();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainLoadLanPeers(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_load_lan_peers()));
}

napi_value MainRemoveDiscovered(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  return MakeBool(env, rustdesk_bridge_main_remove_discovered(peer_id.c_str()) != 0);
}

napi_value SessionSend2fa(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string code;
  if (argc > 0) ReadUtf8String(env, args[0], &code);
  bool trust_this_device = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &trust_this_device);
  return MakeBool(env, rustdesk_bridge_session_send2fa(code.c_str(), trust_this_device ? 1 : 0) != 0);
}

napi_value SessionToggleOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string name;
  if (argc > 0) ReadUtf8String(env, args[0], &name);
  rustdesk_bridge_session_toggle_option(name.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionTogglePrivacyMode(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string impl_key;
  if (argc > 0) ReadUtf8String(env, args[0], &impl_key);
  bool on = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &on);
  return MakeBool(env, rustdesk_bridge_session_toggle_privacy_mode(impl_key.c_str(), on ? 1 : 0) != 0);
}

napi_value SessionSwitchDisplay(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  return MakeBool(env, rustdesk_bridge_session_switch_display(display) != 0);
}

napi_value SessionEnterOrLeave(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_enter_or_leave() != 0);
}

napi_value SessionLeave(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_leave() != 0);
}

napi_value SessionSetSize(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t display = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &display);
  int64_t width = 0;
  if (argc > 1) napi_get_value_int64(env, args[1], &width);
  int64_t height = 0;
  if (argc > 2) napi_get_value_int64(env, args[2], &height);
  rustdesk_bridge_session_set_size(static_cast<unsigned long long>(display), static_cast<unsigned long long>(width), static_cast<unsigned long long>(height));
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionChangeResolution(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  int32_t width = 0;
  if (argc > 1) napi_get_value_int32(env, args[1], &width);
  int32_t height = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &height);
  rustdesk_bridge_session_change_resolution(display, width, height);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionElevateDirect(napi_env env, napi_callback_info info) {
  rustdesk_bridge_session_elevate_direct();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionElevateWithLogon(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string username;
  if (argc > 0) ReadUtf8String(env, args[0], &username);
  std::string password;
  if (argc > 1) ReadUtf8String(env, args[1], &password);
  rustdesk_bridge_session_elevate_with_logon(username.c_str(), password.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSwitchSides(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_switch_sides() != 0);
}

napi_value SessionTakeScreenshot(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t display = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &display);
  return MakeBool(env, rustdesk_bridge_session_take_screenshot(static_cast<unsigned long long>(display)) != 0);
}

napi_value SessionRecordScreen(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool start = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &start);
  return MakeBool(env, rustdesk_bridge_session_record_screen(start ? 1 : 0) != 0);
}

napi_value SessionGetIsRecording(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_get_is_recording() != 0);
}

napi_value SessionRequestVoiceCall(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_request_voice_call() != 0);
}

napi_value SessionCloseVoiceCall(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_close_voice_call() != 0);
}

napi_value SessionAddPortForward(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t local_port = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &local_port);
  std::string remote_host;
  if (argc > 1) ReadUtf8String(env, args[1], &remote_host);
  int32_t remote_port = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &remote_port);
  rustdesk_bridge_session_add_port_forward(local_port, remote_host.c_str(), remote_port);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionRemovePortForward(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t local_port = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &local_port);
  rustdesk_bridge_session_remove_port_forward(local_port);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionNewRdp(napi_env env, napi_callback_info info) {
  rustdesk_bridge_session_new_rdp();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionRemoveFile(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t act_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &act_id);
  std::string path;
  if (argc > 1) ReadUtf8String(env, args[1], &path);
  int32_t file_num = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &file_num);
  bool is_remote = false;
  if (argc > 3) napi_get_value_bool(env, args[3], &is_remote);
  rustdesk_bridge_session_remove_file(act_id, path.c_str(), file_num, is_remote ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionRenameFile(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t act_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &act_id);
  std::string path;
  if (argc > 1) ReadUtf8String(env, args[1], &path);
  std::string new_name;
  if (argc > 2) ReadUtf8String(env, args[2], &new_name);
  bool is_remote = false;
  if (argc > 3) napi_get_value_bool(env, args[3], &is_remote);
  rustdesk_bridge_session_rename_file(act_id, path.c_str(), new_name.c_str(), is_remote ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionCancelJob(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t act_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &act_id);
  rustdesk_bridge_session_cancel_job(act_id);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionResumeJob(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t act_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &act_id);
  bool is_remote = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &is_remote);
  rustdesk_bridge_session_resume_job(act_id, is_remote ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSetConfirmOverrideFile(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t act_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &act_id);
  int32_t file_num = 0;
  if (argc > 1) napi_get_value_int32(env, args[1], &file_num);
  bool need_override = false;
  if (argc > 2) napi_get_value_bool(env, args[2], &need_override);
  bool remember = false;
  if (argc > 3) napi_get_value_bool(env, args[3], &remember);
  bool is_upload = false;
  if (argc > 4) napi_get_value_bool(env, args[4], &is_upload);
  rustdesk_bridge_session_set_confirm_override_file(act_id, file_num, need_override ? 1 : 0, remember ? 1 : 0, is_upload ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSendNote(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string note;
  if (argc > 0) ReadUtf8String(env, args[0], &note);
  rustdesk_bridge_session_send_note(note.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionInputString(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string value;
  if (argc > 0) ReadUtf8String(env, args[0], &value);
  rustdesk_bridge_session_input_string(value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionInputOsPassword(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string pass;
  if (argc > 0) ReadUtf8String(env, args[0], &pass);
  rustdesk_bridge_session_input_os_password(pass.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionLoadLastTransferJobs(napi_env env, napi_callback_info info) {
  rustdesk_bridge_session_load_last_transfer_jobs();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetViewStyle(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_view_style()));
}

napi_value SessionSetViewStyle(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string value;
  if (argc > 0) ReadUtf8String(env, args[0], &value);
  rustdesk_bridge_session_set_view_style(value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetScrollStyle(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_scroll_style()));
}

napi_value SessionSetScrollStyle(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string value;
  if (argc > 0) ReadUtf8String(env, args[0], &value);
  rustdesk_bridge_session_set_scroll_style(value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetImageQuality(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_image_quality()));
}

napi_value SessionSetImageQuality(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string value;
  if (argc > 0) ReadUtf8String(env, args[0], &value);
  rustdesk_bridge_session_set_image_quality(value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetKeyboardMode(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_keyboard_mode()));
}

napi_value SessionSetKeyboardMode(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string value;
  if (argc > 0) ReadUtf8String(env, args[0], &value);
  rustdesk_bridge_session_set_keyboard_mode(value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetCustomImageQuality(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_custom_image_quality()));
}

napi_value SessionSetCustomImageQuality(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t value = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &value);
  rustdesk_bridge_session_set_custom_image_quality(value);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSetCustomFps(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t fps = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &fps);
  rustdesk_bridge_session_set_custom_fps(fps);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetTrackpadSpeed(napi_env env, napi_callback_info info) {
  int32_t result_val = rustdesk_bridge_session_get_trackpad_speed();
  napi_value result = nullptr;
  napi_create_int32(env, result_val, &result);
  return result;
}

napi_value SessionSetTrackpadSpeed(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t value = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &value);
  rustdesk_bridge_session_set_trackpad_speed(value);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetFlutterOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string k;
  if (argc > 0) ReadUtf8String(env, args[0], &k);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_flutter_option(k.c_str())));
}

napi_value SessionSetFlutterOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string k;
  if (argc > 0) ReadUtf8String(env, args[0], &k);
  std::string v;
  if (argc > 1) ReadUtf8String(env, args[1], &v);
  rustdesk_bridge_session_set_flutter_option(k.c_str(), v.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetReverseMouseWheelSync(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_reverse_mouse_wheel_sync()));
}

napi_value SessionSetReverseMouseWheel(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string value;
  if (argc > 0) ReadUtf8String(env, args[0], &value);
  rustdesk_bridge_session_set_reverse_mouse_wheel(value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string k;
  if (argc > 0) ReadUtf8String(env, args[0], &k);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_option(k.c_str())));
}

napi_value SessionSetOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string k;
  if (argc > 0) ReadUtf8String(env, args[0], &k);
  std::string v;
  if (argc > 1) ReadUtf8String(env, args[1], &v);
  rustdesk_bridge_session_set_option(k.c_str(), v.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetPeerOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string name;
  if (argc > 0) ReadUtf8String(env, args[0], &name);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_peer_option(name.c_str())));
}

napi_value SessionPeerOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string name;
  if (argc > 0) ReadUtf8String(env, args[0], &name);
  std::string value;
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  rustdesk_bridge_session_peer_option(name.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionIsKeyboardModeSupported(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string mode;
  if (argc > 0) ReadUtf8String(env, args[0], &mode);
  return MakeBool(env, rustdesk_bridge_session_is_keyboard_mode_supported(mode.c_str()) != 0);
}

napi_value SessionGetPlatform(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool is_remote = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &is_remote);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_platform(is_remote ? 1 : 0)));
}

napi_value SessionGetRemember(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_get_remember() != 0);
}

napi_value SessionGetEnableTrustedDevices(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_get_enable_trusted_devices() != 0);
}

napi_value SessionGetAlternativeCodecs(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_alternative_codecs()));
}

napi_value SessionChangePreferCodec(napi_env env, napi_callback_info info) {
  rustdesk_bridge_session_change_prefer_codec();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_option(key.c_str())));
}

napi_value MainSetOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  std::string value;
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  rustdesk_bridge_main_set_option(key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetOptions(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_options()));
}

napi_value MainGetMyId(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_my_id()));
}

napi_value MainGetUuid(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_uuid()));
}

napi_value MainGetVersion(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_version()));
}

napi_value MainGetFingerprint(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_fingerprint()));
}

napi_value MainGetApiServer(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_api_server()));
}

napi_value MainGetTemporaryPassword(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_temporary_password()));
}

napi_value MainSetPermanentPasswordWithResult(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string password;
  if (argc > 0) ReadUtf8String(env, args[0], &password);
  return MakeBool(env, rustdesk_bridge_main_set_permanent_password_with_result(password.c_str()) != 0);
}

napi_value MainUpdateTemporaryPassword(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_update_temporary_password();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainTestIfValidServer(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string server;
  if (argc > 0) ReadUtf8String(env, args[0], &server);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_test_if_valid_server(server.c_str())));
}

napi_value MainGetConnectStatus(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_connect_status()));
}

napi_value MainIsUsingPublicServer(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_using_public_server() != 0);
}

napi_value MainForgetPassword(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  rustdesk_bridge_main_forget_password(id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainPeerHasPassword(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  return MakeBool(env, rustdesk_bridge_main_peer_has_password(id.c_str()) != 0);
}

napi_value MainPeerExists(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  return MakeBool(env, rustdesk_bridge_main_peer_exists(id.c_str()) != 0);
}

napi_value MainSetPeerAlias(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string alias;
  if (argc > 1) ReadUtf8String(env, args[1], &alias);
  rustdesk_bridge_main_set_peer_alias(id.c_str(), alias.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainSetPeerOption(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string key;
  if (argc > 1) ReadUtf8String(env, args[1], &key);
  std::string value;
  if (argc > 2) ReadUtf8String(env, args[2], &value);
  rustdesk_bridge_main_set_peer_option(id.c_str(), key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainRemovePeer(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  rustdesk_bridge_main_remove_peer(id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetNewStoredPeers(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_new_stored_peers()));
}

napi_value MainLoadRecentPeers(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_load_recent_peers();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetLangs(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_langs()));
}

napi_value MainGetError(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_error()));
}

napi_value MainGetBuildDate(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_build_date()));
}

napi_value MainGetLicense(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_license()));
}

napi_value MainGetAppName(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_app_name()));
}

napi_value MainHasHwcodec(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_has_hwcodec() != 0);
}

napi_value MainGenerate2fa(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_generate2fa()));
}

napi_value MainVerify2fa(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string code;
  if (argc > 0) ReadUtf8String(env, args[0], &code);
  return MakeBool(env, rustdesk_bridge_main_verify2fa(code.c_str()) != 0);
}

napi_value MainGetTrustedDevices(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_trusted_devices()));
}

napi_value MainClearTrustedDevices(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_clear_trusted_devices();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainSetUserDefaultOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  std::string value;
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  rustdesk_bridge_main_set_user_default_option(key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetUserDefaultOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_user_default_option(key.c_str())));
}

napi_value MainResolveAvatarUrl(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string avatar;
  if (argc > 0) ReadUtf8String(env, args[0], &avatar);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_resolve_avatar_url(avatar.c_str())));
}

napi_value MainGetLoginDeviceInfo(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_login_device_info()));
}

napi_value MainGetHardOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_hard_option(key.c_str())));
}

napi_value MainGetBuildinOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_buildin_option(key.c_str())));
}

napi_value MainGetCommon(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_common(key.c_str())));
}

napi_value MainSetCommon(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  std::string value;
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  rustdesk_bridge_main_set_common(key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainCheckConnectStatus(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_check_connect_status();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainStopService(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_stop_service();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainOnMainWindowClose(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_on_main_window_close();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainWol(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  rustdesk_bridge_main_wol(id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainHttpRequest(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string url;
  if (argc > 0) ReadUtf8String(env, args[0], &url);
  std::string method;
  if (argc > 1) ReadUtf8String(env, args[1], &method);
  std::string body;
  if (argc > 2) ReadUtf8String(env, args[2], &body);
  std::string header;
  if (argc > 3) ReadUtf8String(env, args[3], &header);
  rustdesk_bridge_main_http_request(url.c_str(), method.c_str(), body.c_str(), header.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionIsFileTransfer(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_is_file_transfer() != 0);
}

napi_value SessionIsTerminal(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_is_terminal() != 0);
}

napi_value SessionIsPortForward(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_is_port_forward() != 0);
}

napi_value SessionIsRdp(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_is_rdp() != 0);
}

napi_value SessionIsViewCamera(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_is_view_camera() != 0);
}

napi_value SessionToggleVirtualDisplay(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t index = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &index);
  bool on = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &on);
  rustdesk_bridge_session_toggle_virtual_display(index, on ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetAuditServer(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string typ;
  if (argc > 0) ReadUtf8String(env, args[0], &typ);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_audit_server(typ.c_str())));
}

napi_value SessionSendSelectedSessionId(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string sid;
  if (argc > 0) ReadUtf8String(env, args[0], &sid);
  rustdesk_bridge_session_send_selected_session_id(sid.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetConnToken(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_conn_token()));
}

napi_value SessionHandleFlutterKeyEvent(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string keyboard_mode;
  if (argc > 0) ReadUtf8String(env, args[0], &keyboard_mode);
  std::string character;
  if (argc > 1) ReadUtf8String(env, args[1], &character);
  int32_t usb_hid = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &usb_hid);
  int32_t lock_modes = 0;
  if (argc > 3) napi_get_value_int32(env, args[3], &lock_modes);
  bool down_or_up = false;
  if (argc > 4) napi_get_value_bool(env, args[4], &down_or_up);
  rustdesk_bridge_session_handle_flutter_key_event(keyboard_mode.c_str(), character.c_str(), usb_hid, lock_modes, down_or_up ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionHandleFlutterRawKeyEvent(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value args[6] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string keyboard_mode;
  if (argc > 0) ReadUtf8String(env, args[0], &keyboard_mode);
  std::string name;
  if (argc > 1) ReadUtf8String(env, args[1], &name);
  int32_t platform_code = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &platform_code);
  int32_t position_code = 0;
  if (argc > 3) napi_get_value_int32(env, args[3], &position_code);
  int32_t lock_modes = 0;
  if (argc > 4) napi_get_value_int32(env, args[4], &lock_modes);
  bool down_or_up = false;
  if (argc > 5) napi_get_value_bool(env, args[5], &down_or_up);
  rustdesk_bridge_session_handle_flutter_raw_key_event(keyboard_mode.c_str(), name.c_str(), platform_code, position_code, lock_modes, down_or_up ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSendTouchScale(napi_env env, napi_callback_info info) {
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t scale = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &scale);
  bool alt = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &alt);
  bool ctrl = false;
  if (argc > 2) napi_get_value_bool(env, args[2], &ctrl);
  bool shift = false;
  if (argc > 3) napi_get_value_bool(env, args[3], &shift);
  bool command = false;
  if (argc > 4) napi_get_value_bool(env, args[4], &command);
  rustdesk_bridge_session_send_touch_scale(scale, alt ? 1 : 0, ctrl ? 1 : 0, shift ? 1 : 0, command ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSendTouchPanEvent(napi_env env, napi_callback_info info) {
  size_t argc = 7;
  napi_value args[7] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string event;
  if (argc > 0) ReadUtf8String(env, args[0], &event);
  int32_t x = 0;
  if (argc > 1) napi_get_value_int32(env, args[1], &x);
  int32_t y = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &y);
  bool alt = false;
  if (argc > 3) napi_get_value_bool(env, args[3], &alt);
  bool ctrl = false;
  if (argc > 4) napi_get_value_bool(env, args[4], &ctrl);
  bool shift = false;
  if (argc > 5) napi_get_value_bool(env, args[5], &shift);
  bool command = false;
  if (argc > 6) napi_get_value_bool(env, args[6], &command);
  rustdesk_bridge_session_send_touch_pan_event(event.c_str(), x, y, alt ? 1 : 0, ctrl ? 1 : 0, shift ? 1 : 0, command ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionRefresh(napi_env env, napi_callback_info info) {
  rustdesk_bridge_session_refresh();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetPeerVersion(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_peer_version()));
}

napi_value SessionGetPathSep(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_path_sep()));
}

napi_value SessionIsRestartingRemoteDevice(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_is_restarting_remote_device() != 0);
}

napi_value CmInit(napi_env env, napi_callback_info info) {
  rustdesk_bridge_cm_init();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmGetClientsState(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_cm_get_clients_state()));
}

napi_value CmCheckClientsLength(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int64_t length = 0;
  if (argc > 0) napi_get_value_int64(env, args[0], &length);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_cm_check_clients_length(static_cast<unsigned long long>(length))));
}

napi_value CmGetClientsLength(napi_env env, napi_callback_info info) {
  rustdesk_bridge_cm_get_clients_length();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmSendChat(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t conn_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &conn_id);
  std::string msg;
  if (argc > 1) ReadUtf8String(env, args[1], &msg);
  rustdesk_bridge_cm_send_chat(conn_id, msg.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmLoginRes(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t conn_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &conn_id);
  bool res = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &res);
  rustdesk_bridge_cm_login_res(conn_id, res ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmCloseConnection(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t conn_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &conn_id);
  rustdesk_bridge_cm_close_connection(conn_id);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmRemoveDisconnectedConnection(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t conn_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &conn_id);
  rustdesk_bridge_cm_remove_disconnected_connection(conn_id);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmCheckClickTime(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t conn_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &conn_id);
  rustdesk_bridge_cm_check_click_time(conn_id);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmGetClickTime(napi_env env, napi_callback_info info) {
  rustdesk_bridge_cm_get_click_time();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmSwitchPermission(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t conn_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &conn_id);
  std::string name;
  if (argc > 1) ReadUtf8String(env, args[1], &name);
  bool enabled = false;
  if (argc > 2) napi_get_value_bool(env, args[2], &enabled);
  rustdesk_bridge_cm_switch_permission(conn_id, name.c_str(), enabled ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmCanElevate(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_cm_can_elevate() != 0);
}

napi_value CmElevatePortable(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t conn_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &conn_id);
  rustdesk_bridge_cm_elevate_portable(conn_id);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmSwitchBack(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t conn_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &conn_id);
  rustdesk_bridge_cm_switch_back(conn_id);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmGetConfig(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string name;
  if (argc > 0) ReadUtf8String(env, args[0], &name);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_cm_get_config(name.c_str())));
}

napi_value CmHandleIncomingVoiceCall(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &id);
  bool accept = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &accept);
  rustdesk_bridge_cm_handle_incoming_voice_call(id, accept ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CmCloseVoiceCall(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &id);
  rustdesk_bridge_cm_close_voice_call(id);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginEvent(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string peer;
  if (argc > 1) ReadUtf8String(env, args[1], &peer);
  std::string msg;
  if (argc > 2) ReadUtf8String(env, args[2], &msg);
  rustdesk_bridge_plugin_event(id.c_str(), peer.c_str(), msg.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginRegisterEventStream(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string peer;
  if (argc > 1) ReadUtf8String(env, args[1], &peer);
  rustdesk_bridge_plugin_register_event_stream(id.c_str(), peer.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginGetSessionOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string key;
  if (argc > 1) ReadUtf8String(env, args[1], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_plugin_get_session_option(id.c_str(), key.c_str())));
}

napi_value PluginSetSessionOption(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string key;
  if (argc > 1) ReadUtf8String(env, args[1], &key);
  std::string value;
  if (argc > 2) ReadUtf8String(env, args[2], &value);
  rustdesk_bridge_plugin_set_session_option(id.c_str(), key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginGetSharedOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string key;
  if (argc > 1) ReadUtf8String(env, args[1], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_plugin_get_shared_option(id.c_str(), key.c_str())));
}

napi_value PluginSetSharedOption(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string key;
  if (argc > 1) ReadUtf8String(env, args[1], &key);
  std::string value;
  if (argc > 2) ReadUtf8String(env, args[2], &value);
  rustdesk_bridge_plugin_set_shared_option(id.c_str(), key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginReload(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  rustdesk_bridge_plugin_reload(id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginEnable(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  bool enable = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &enable);
  rustdesk_bridge_plugin_enable(id.c_str(), enable ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginIsEnabled(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  return MakeBool(env, rustdesk_bridge_plugin_is_enabled(id.c_str()) != 0);
}

napi_value PluginFeatureIsEnabled(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  return MakeBool(env, rustdesk_bridge_plugin_feature_is_enabled(id.c_str()) != 0);
}

napi_value PluginSyncUi(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  rustdesk_bridge_plugin_sync_ui(id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginListReload(napi_env env, napi_callback_info info) {
  rustdesk_bridge_plugin_list_reload();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value PluginInstall(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  bool b = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &b);
  rustdesk_bridge_plugin_install(id.c_str(), b ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value InstallInstallMe(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  std::string options;
  if (argc > 1) ReadUtf8String(env, args[1], &options);
  std::string exe;
  if (argc > 2) ReadUtf8String(env, args[2], &exe);
  rustdesk_bridge_install_install_me(path.c_str(), options.c_str(), exe.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value InstallInstallOptions(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_install_install_options()));
}

napi_value InstallInstallPath(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_install_install_path()));
}

napi_value InstallRunWithoutInstall(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_install_run_without_install() != 0);
}

napi_value InstallShowRunWithoutInstall(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_install_show_run_without_install() != 0);
}

napi_value IsCustomClient(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_custom_client() != 0);
}

napi_value IsDisableAb(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_disable_ab() != 0);
}

napi_value IsDisableAccount(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_disable_account() != 0);
}

napi_value IsDisableGroupPanel(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_disable_group_panel() != 0);
}

napi_value IsDisableInstallation(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_disable_installation() != 0);
}

napi_value IsDisableSettings(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_disable_settings() != 0);
}

napi_value IsIncomingOnly(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_incoming_only() != 0);
}

napi_value IsOutgoingOnly(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_outgoing_only() != 0);
}

napi_value IsPresetPassword(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_preset_password() != 0);
}

napi_value IsPresetPasswordMobileOnly(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_preset_password_mobile_only() != 0);
}

napi_value IsSelinuxEnforcing(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_selinux_enforcing() != 0);
}

napi_value IsSupportMultiUiSession(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_is_support_multi_ui_session() != 0);
}

napi_value MainChangeId(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  rustdesk_bridge_main_change_id(id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainChangeLanguage(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string lang;
  if (argc > 0) ReadUtf8String(env, args[0], &lang);
  rustdesk_bridge_main_change_language(lang.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainChangeTheme(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string dark;
  if (argc > 0) ReadUtf8String(env, args[0], &dark);
  rustdesk_bridge_main_change_theme(dark.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetDisplays(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_displays()));
}

napi_value MainGetPrinterNames(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_printer_names()));
}

napi_value MainGetSocks(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_socks()));
}

napi_value MainSetSocks(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string proxy;
  if (argc > 0) ReadUtf8String(env, args[0], &proxy);
  std::string username;
  if (argc > 1) ReadUtf8String(env, args[1], &username);
  std::string password;
  if (argc > 2) ReadUtf8String(env, args[2], &password);
  rustdesk_bridge_main_set_socks(proxy.c_str(), username.c_str(), password.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetProxyStatus(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_get_proxy_status() != 0);
}

napi_value MainGetAppNameSync(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_app_name_sync()));
}

napi_value MainGetNewVersion(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_new_version()));
}

napi_value MainGetHomeDir(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_home_dir()));
}

napi_value MainInit(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string app_dir;
  std::string custom_client_config;
  if (argc > 0) ReadUtf8String(env, args[0], &app_dir);
  if (argc > 1) ReadUtf8String(env, args[1], &custom_client_config);
  rustdesk_bridge_main_init(app_dir.c_str(), custom_client_config.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainDeviceId(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_device_id()));
}

napi_value MainDeviceName(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_device_name()));
}

napi_value MainIsInstalled(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_installed() != 0);
}

napi_value MainIsInstalledDaemon(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_installed_daemon() != 0);
}

napi_value MainIsRoot(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_root() != 0);
}

napi_value MainIsProcessTrusted(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_process_trusted() != 0);
}

napi_value MainIsCanScreenRecording(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_can_screen_recording() != 0);
}

napi_value MainIsCanInputMonitoring(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_can_input_monitoring() != 0);
}

napi_value MainCurrentIsWayland(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_current_is_wayland() != 0);
}

napi_value MainIsLoginWayland(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_login_wayland() != 0);
}

napi_value MainHasVram(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_has_vram() != 0);
}

napi_value MainSupportedHwdecodings(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_supported_hwdecodings()));
}

napi_value MainCheckHwcodec(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_check_hwcodec();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainCreateShortcut(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_create_shortcut() != 0);
}

napi_value MainGetMouseTime(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_get_mouse_time();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainCheckMouseTime(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_check_mouse_time() != 0);
}

napi_value MainGetAsyncStatus(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_async_status()));
}

napi_value MainGetLanPeers(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_lan_peers()));
}

napi_value MainGetLastRemoteId(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_last_remote_id()));
}

napi_value MainGetFav(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_fav()));
}

napi_value MainStoreFav(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string fav;
  if (argc > 0) ReadUtf8String(env, args[0], &fav);
  rustdesk_bridge_main_store_fav(fav.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetPeerSync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_peer_sync(id.c_str())));
}

napi_value MainGetPeerFlutterOptionSync(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string k;
  if (argc > 1) ReadUtf8String(env, args[1], &k);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_peer_flutter_option_sync(id.c_str(), k.c_str())));
}

napi_value MainSetPeerFlutterOptionSync(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string k;
  if (argc > 1) ReadUtf8String(env, args[1], &k);
  std::string v;
  if (argc > 2) ReadUtf8String(env, args[2], &v);
  rustdesk_bridge_main_set_peer_flutter_option_sync(id.c_str(), k.c_str(), v.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetPeerOptionSync(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string k;
  if (argc > 1) ReadUtf8String(env, args[1], &k);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_peer_option_sync(id.c_str(), k.c_str())));
}

napi_value MainSetPeerOptionSync(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  std::string k;
  if (argc > 1) ReadUtf8String(env, args[1], &k);
  std::string v;
  if (argc > 2) ReadUtf8String(env, args[2], &v);
  rustdesk_bridge_main_set_peer_option_sync(id.c_str(), k.c_str(), v.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainRemoveTrustedDevices(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string json;
  if (argc > 0) ReadUtf8String(env, args[0], &json);
  rustdesk_bridge_main_remove_trusted_devices(json.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainHasValid2faSync(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_has_valid_2fa_sync() != 0);
}

napi_value MainHasValidBotSync(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_has_valid_bot_sync() != 0);
}

napi_value MainVerifyBot(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string token;
  if (argc > 0) ReadUtf8String(env, args[0], &token);
  return MakeBool(env, rustdesk_bridge_main_verify_bot(token.c_str()) != 0);
}

napi_value MainMaxEncryptLen(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_max_encrypt_len();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetUnlockPin(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_unlock_pin()));
}

napi_value MainSetUnlockPin(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string pin;
  if (argc > 0) ReadUtf8String(env, args[0], &pin);
  rustdesk_bridge_main_set_unlock_pin(pin.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainOptionSynced(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_option_synced() != 0);
}

napi_value MainSupportRemoveWallpaper(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_support_remove_wallpaper() != 0);
}

napi_value MainTestWallpaper(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_test_wallpaper() != 0);
}

napi_value MainSupportedPrivacyModeImpls(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_supported_privacy_mode_impls()));
}

napi_value MainDefaultPrivacyModeImpl(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_default_privacy_mode_impl()));
}

napi_value MainIsOptionFixed(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeBool(env, rustdesk_bridge_main_is_option_fixed(key.c_str()) != 0);
}

napi_value MainGetUseTextureRender(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_get_use_texture_render() != 0);
}

napi_value MainHasFileClipboard(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_has_file_clipboard() != 0);
}

napi_value MainHasGpuTextureRender(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_has_gpu_texture_render() != 0);
}

napi_value MainAudioSupportLoopback(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_audio_support_loopback() != 0);
}

napi_value MainIsShareRdp(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_share_rdp() != 0);
}

napi_value MainSetShareRdp(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool v = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &v);
  rustdesk_bridge_main_set_share_rdp(v ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainIsInstalledLowerVersion(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_is_installed_lower_version() != 0);
}

napi_value MainGetSoftwareUpdateUrl(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_software_update_url()));
}

napi_value MainHandleRelayId(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  rustdesk_bridge_main_handle_relay_id(id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainHideDock(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_hide_dock();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainSetCursorPosition(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t x = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &x);
  int32_t y = 0;
  if (argc > 1) napi_get_value_int32(env, args[1], &y);
  rustdesk_bridge_main_set_cursor_position(x, y);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainClipCursor(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_clip_cursor();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetEnv(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_env(key.c_str())));
}

napi_value MainSetEnv(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  std::string value;
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  rustdesk_bridge_main_set_env(key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainSetHomeDir(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string home;
  if (argc > 0) ReadUtf8String(env, args[0], &home);
  rustdesk_bridge_main_set_home_dir(home.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainStartDbusServer(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_start_dbus_server();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainStartIpcUrlServer(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_start_ipc_url_server();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainCheckSuperUserPermission(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_check_super_user_permission() != 0);
}

napi_value MainGotoInstall(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_goto_install()));
}

napi_value MainUpdateMe(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  rustdesk_bridge_main_update_me(path.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainDeployDevice(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_main_deploy_device() != 0);
}

napi_value MainGetMainDisplay(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_main_display()));
}

napi_value MainGetInputSource(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_input_source()));
}

napi_value MainSetInputSource(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string source;
  if (argc > 0) ReadUtf8String(env, args[0], &source);
  rustdesk_bridge_main_set_input_source(source.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainInitInputSource(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_init_input_source();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainSupportedInputSource(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_supported_input_source()));
}

napi_value MainVideoSaveDirectory(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_video_save_directory()));
}

napi_value MainGetDataDirIos(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_data_dir_ios()));
}

napi_value MainShowOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeBool(env, rustdesk_bridge_main_show_option(key.c_str()) != 0);
}

napi_value MainSetOptions(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string options;
  if (argc > 0) ReadUtf8String(env, args[0], &options);
  rustdesk_bridge_main_set_options(options.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainGetOptionsSync(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_options_sync()));
}

napi_value MainGetOptionSync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_option_sync(key.c_str())));
}

napi_value MainGetCommonSync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_common_sync(key.c_str())));
}

napi_value MainGetHttpStatus(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_get_http_status()));
}

napi_value MainUriPrefixSync(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_uri_prefix_sync()));
}

napi_value MainLoadAb(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_load_ab()));
}

napi_value MainSaveAb(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string ab;
  if (argc > 0) ReadUtf8String(env, args[0], &ab);
  rustdesk_bridge_main_save_ab(ab.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainClearAb(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_clear_ab();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainLoadGroup(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_load_group()));
}

napi_value MainSaveGroup(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string group;
  if (argc > 0) ReadUtf8String(env, args[0], &group);
  rustdesk_bridge_main_save_group(group.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainClearGroup(napi_env env, napi_callback_info info) {
  rustdesk_bridge_main_clear_group();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value MainLoadFavPeers(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_load_fav_peers()));
}

napi_value MainLoadRecentPeersForAb(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_main_load_recent_peers_for_ab()));
}

napi_value MainHandleWaylandScreencastRestoreToken(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string token;
  if (argc > 0) ReadUtf8String(env, args[0], &token);
  rustdesk_bridge_main_handle_wayland_screencast_restore_token(token.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value GetDoubleClickTime(napi_env env, napi_callback_info info) {
  rustdesk_bridge_get_double_click_time();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value GetLocalFlutterOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string k;
  if (argc > 0) ReadUtf8String(env, args[0], &k);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_local_flutter_option(k.c_str())));
}

napi_value SetLocalFlutterOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string k;
  if (argc > 0) ReadUtf8String(env, args[0], &k);
  std::string v;
  if (argc > 1) ReadUtf8String(env, args[1], &v);
  rustdesk_bridge_set_local_flutter_option(k.c_str(), v.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value GetLocalKbLayoutType(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_local_kb_layout_type()));
}

napi_value SetLocalKbLayoutType(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string v;
  if (argc > 0) ReadUtf8String(env, args[0], &v);
  rustdesk_bridge_set_local_kb_layout_type(v.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value GetVoiceCallInputDevice(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_voice_call_input_device()));
}

napi_value SetVoiceCallInputDevice(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string device;
  if (argc > 0) ReadUtf8String(env, args[0], &device);
  rustdesk_bridge_set_voice_call_input_device(device.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value HostStopSystemKeyPropagate(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool stop = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &stop);
  rustdesk_bridge_host_stop_system_key_propagate(stop ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value OptionSynced(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_option_synced() != 0);
}

napi_value PeerGetSessionsCount(napi_env env, napi_callback_info info) {
  rustdesk_bridge_peer_get_sessions_count();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SendUrlScheme(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string url;
  if (argc > 0) ReadUtf8String(env, args[0], &url);
  rustdesk_bridge_send_url_scheme(url.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SetCurSessionId(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string id;
  if (argc > 0) ReadUtf8String(env, args[0], &id);
  rustdesk_bridge_set_cur_session_id(id.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value StartGlobalEventStream(napi_env env, napi_callback_info info) {
  rustdesk_bridge_start_global_event_stream();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value StopGlobalEventStream(napi_env env, napi_callback_info info) {
  rustdesk_bridge_stop_global_event_stream();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value Translate(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string name;
  if (argc > 0) ReadUtf8String(env, args[0], &name);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_translate(name.c_str())));
}

napi_value VersionToNumber(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string v;
  if (argc > 0) ReadUtf8String(env, args[0], &v);
  rustdesk_bridge_version_to_number(v.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value WillSessionCloseCloseSession(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_will_session_close_close_session() != 0);
}

napi_value GetNextTextureKey(napi_env env, napi_callback_info info) {
  int32_t result_val = rustdesk_bridge_get_next_texture_key();
  napi_value result = nullptr;
  napi_create_int32(env, result_val, &result);
  return result;
}


napi_value SessionAddExistedSync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool is_sync = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &is_sync);
  return MakeBool(env, rustdesk_bridge_session_add_existed_sync(is_sync ? 1 : 0) != 0);
}

napi_value SessionAddJob(napi_env env, napi_callback_info info) {
  size_t argc = 6;
  napi_value args[6] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &id);
  std::string path_str;
  if (argc > 1) ReadUtf8String(env, args[1], &path_str);
  std::string to_str;
  if (argc > 2) ReadUtf8String(env, args[2], &to_str);
  int32_t file_num = 0;
  if (argc > 3) napi_get_value_int32(env, args[3], &file_num);
  bool include_hidden = false;
  if (argc > 4) napi_get_value_bool(env, args[4], &include_hidden);
  bool is_remote = false;
  if (argc > 5) napi_get_value_bool(env, args[5], &is_remote);
  rustdesk_bridge_session_add_job(id, path_str.c_str(), to_str.c_str(), file_num, include_hidden ? 1 : 0, is_remote ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionAddSync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool is_sync = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &is_sync);
  rustdesk_bridge_session_add_sync(is_sync ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionGetAuditGuid(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_audit_guid()));
}

napi_value SessionGetAuditServerSync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string typ;
  if (argc > 0) ReadUtf8String(env, args[0], &typ);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_audit_server_sync(typ.c_str())));
}

napi_value SessionGetCommon(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_common(key.c_str())));
}

napi_value SessionGetCommonSync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_common_sync(key.c_str())));
}

napi_value SessionGetConnSessionId(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_conn_session_id()));
}

napi_value SessionGetDisplaysAsIndividualWindows(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_displays_as_individual_windows()));
}

napi_value SessionGetEdgeScrollEdgeThickness(napi_env env, napi_callback_info info) {
  int32_t result_val = rustdesk_bridge_session_get_edge_scroll_edge_thickness();
  napi_value result = nullptr;
  napi_create_int32(env, result_val, &result);
  return result;
}

napi_value SessionGetLastAuditNote(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_last_audit_note()));
}

napi_value SessionGetRgbaSize(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  int32_t result_val = rustdesk_bridge_session_get_rgba_size(display);
  napi_value result = nullptr;
  napi_create_int32(env, result_val, &result);
  return result;
}

napi_value SessionGetToggleOptionSync(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string arg;
  if (argc > 0) ReadUtf8String(env, args[0], &arg);
  return MakeBool(env, rustdesk_bridge_session_get_toggle_option_sync(arg.c_str()) != 0);
}

napi_value SessionGetUseAllMyDisplaysForTheRemoteSession(napi_env env, napi_callback_info info) {
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_get_use_all_my_displays_for_the_remote_session()));
}

napi_value SessionHandleScreenshot(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string action;
  if (argc > 0) ReadUtf8String(env, args[0], &action);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_handle_screenshot(action.c_str())));
}

napi_value SessionIsMultiUiSession(napi_env env, napi_callback_info info) {
  return MakeBool(env, rustdesk_bridge_session_is_multi_ui_session() != 0);
}

napi_value SessionNextRgba(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  rustdesk_bridge_session_next_rgba(display);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionOnWaitingForImageDialogShow(napi_env env, napi_callback_info info) {
  rustdesk_bridge_session_on_waiting_for_image_dialog_show();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionPrinterResponse(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &id);
  std::string path_str;
  if (argc > 1) ReadUtf8String(env, args[1], &path_str);
  std::string printer_name;
  if (argc > 2) ReadUtf8String(env, args[2], &printer_name);
  rustdesk_bridge_session_printer_response(id, path_str.c_str(), printer_name.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionReadDirToRemoveRecursive(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &id);
  std::string path_str;
  if (argc > 1) ReadUtf8String(env, args[1], &path_str);
  bool include_hidden = false;
  if (argc > 2) napi_get_value_bool(env, args[2], &include_hidden);
  rustdesk_bridge_session_read_dir_to_remove_recursive(id, path_str.c_str(), include_hidden ? 1 : 0);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionReadLocalDirSync(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path_str;
  if (argc > 0) ReadUtf8String(env, args[0], &path_str);
  bool include_hidden = false;
  if (argc > 1) napi_get_value_bool(env, args[1], &include_hidden);
  int32_t id = 0;
  if (argc > 2) napi_get_value_int32(env, args[2], &id);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_read_local_dir_sync(path_str.c_str(), include_hidden ? 1 : 0, id)));
}

napi_value SessionReadLocalEmptyDirsRecursiveSync(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &id);
  std::string path_str;
  if (argc > 1) ReadUtf8String(env, args[1], &path_str);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_read_local_empty_dirs_recursive_sync(id, path_str.c_str())));
}

napi_value SessionReadRemoteEmptyDirsRecursiveSync(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &id);
  std::string path_str;
  if (argc > 1) ReadUtf8String(env, args[1], &path_str);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_session_read_remote_empty_dirs_recursive_sync(id, path_str.c_str())));
}

napi_value SessionRegisterGpuTexture(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  int32_t result_val = rustdesk_bridge_session_register_gpu_texture(display);
  napi_value result = nullptr;
  napi_create_int32(env, result_val, &result);
  return result;
}

napi_value SessionRegisterPixelbufferTexture(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  int32_t result_val = rustdesk_bridge_session_register_pixelbuffer_texture(display);
  napi_value result = nullptr;
  napi_create_int32(env, result_val, &result);
  return result;
}

napi_value SessionRemoveAllEmptyDirs(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &id);
  rustdesk_bridge_session_remove_all_empty_dirs(id);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionRequestNewDisplayInitMsgs(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t display = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &display);
  rustdesk_bridge_session_request_new_display_init_msgs(display);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSendPointer(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string msg;
  if (argc > 0) ReadUtf8String(env, args[0], &msg);
  rustdesk_bridge_session_send_pointer(msg.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSetAuditGuid(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string guid;
  if (argc > 0) ReadUtf8String(env, args[0], &guid);
  rustdesk_bridge_session_set_audit_guid(guid.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSetDisplaysAsIndividualWindows(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string value;
  if (argc > 0) ReadUtf8String(env, args[0], &value);
  rustdesk_bridge_session_set_displays_as_individual_windows(value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSetEdgeScrollEdgeThickness(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t value = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &value);
  rustdesk_bridge_session_set_edge_scroll_edge_thickness(value);
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionSetUseAllMyDisplaysForTheRemoteSession(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string value;
  if (argc > 0) ReadUtf8String(env, args[0], &value);
  rustdesk_bridge_session_set_use_all_my_displays_for_the_remote_session(value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value SessionStartWithDisplays(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string displays;
  if (argc > 0) ReadUtf8String(env, args[0], &displays);
  return MakeBool(env, rustdesk_bridge_session_start_with_displays(displays.c_str()) != 0);
}

} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
    {"loadCoreLibrary", nullptr, NapiLoadCoreLibrary, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isCoreLoaded", nullptr, NapiIsCoreLoaded, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getCoreLoadInfo", nullptr, NapiGetCoreLoadInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"verifyCoreFile", nullptr, NapiVerifyCoreFile, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getCoreFileInfo", nullptr, NapiGetCoreFileInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getCoreSnapshot", nullptr, GetCoreSnapshot, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"initializeRuntime", nullptr, InitializeRuntime, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pullSessionEvents", nullptr, PullSessionEvents, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getLatestVideoFrameMetadata", nullptr, GetLatestVideoFrameMetadata, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"copyLatestVideoFrame", nullptr, CopyLatestVideoFrame, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getIncomingScreenFrameMetadata", nullptr, GetIncomingScreenFrameMetadata, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"copyIncomingScreenFrame", nullptr, CopyIncomingScreenFrame, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"updateIncomingScreenFrame", nullptr, UpdateIncomingScreenFrame, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"clearIncomingScreenFrame", nullptr, ClearIncomingScreenFrame, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"refreshSessionVideo", nullptr, RefreshSessionVideo, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"harmonyNextRgba", nullptr, HarmonyNextRgba, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"connectToPeer", nullptr, ConnectToPeer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"accountAuth", nullptr, AccountAuth, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"accountAuthCancel", nullptr, AccountAuthCancel, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"accountAuthResult", nullptr, AccountAuthResult, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getLocalOption", nullptr, GetLocalOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setLocalOption", nullptr, SetLocalOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"closeSession", nullptr, CloseSession, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"reconnectSession", nullptr, ReconnectSession, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"submitSessionPassword", nullptr, SubmitSessionPassword, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setIncomingServiceEnabled", nullptr, SetIncomingServiceEnabled, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"bootstrapCoreSnapshot", nullptr, BootstrapCoreSnapshot, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendMouseInput", nullptr, SendMouseInput, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendKeyboardInput", nullptr, SendKeyboardInput, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendCtrlAltDel", nullptr, SendCtrlAltDel, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendClipboardData", nullptr, SendClipboardData, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendVideoFrameMetadata", nullptr, SendVideoFrameMetadata, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendAudioFrameMetadata", nullptr, SendAudioFrameMetadata, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"startNativeScreenCapture", nullptr, StartNativeScreenCapture, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"stopNativeScreenCapture", nullptr, StopNativeScreenCapture, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isNativeScreenCaptureActive", nullptr, IsNativeScreenCaptureActive, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getNativeScreenCaptureStats", nullptr, GetNativeScreenCaptureStats, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendChatMessage", nullptr, SendChatMessage, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendFileTransferRequest", nullptr, SendFileTransferRequest, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"openTerminal", nullptr, OpenTerminal, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendTerminalInput", nullptr, SendTerminalInput, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"resizeTerminal", nullptr, ResizeTerminal, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"closeTerminal", nullptr, CloseTerminal, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"readRemoteDirectory", nullptr, ReadRemoteDirectory, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"createRemoteDirectory", nullptr, CreateRemoteDirectory, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"deleteRemotePath", nullptr, DeleteRemotePath, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"startFileTransfer", nullptr, StartFileTransfer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"queryOnlines", nullptr, QueryOnlines, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"discoverLanPeers", nullptr, DiscoverLanPeers, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"loadLanPeers", nullptr, LoadLanPeers, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"removeDiscoveredPeer", nullptr, RemoveDiscoveredPeer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getPeerOption", nullptr, GetPeerOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getPeerInfo", nullptr, GetPeerInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getSessionToggleOption", nullptr, GetSessionToggleOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"applySessionOption", nullptr, ApplySessionOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"restartRemoteDevice", nullptr, RestartRemoteDevice, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"lockRemoteScreen", nullptr, LockRemoteScreen, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pullAudioFrames", nullptr, PullAudioFrames, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"markSessionConnected", nullptr, MarkSessionConnected, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"markSessionError", nullptr, MarkSessionError, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getSessionStage", nullptr, GetSessionStage, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getActivePeerId", nullptr, GetActivePeerId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getConnectStatusSummary", nullptr, GetConnectStatusSummary, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getConnectDetailMessage", nullptr, GetConnectDetailMessage, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getConnectLastError", nullptr, GetConnectLastError, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"drainConnectEventsJson", nullptr, DrainConnectEventsJson, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getCoreSnapshotJson", nullptr, GetCoreSnapshotJson, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pullSessionEventsJson", nullptr, PullSessionEventsJson, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pullAudioFramesJson", nullptr, PullAudioFramesJson, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getLatestVideoFrameMetadataJson", nullptr, GetLatestVideoFrameMetadataJson, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getIncomingScreenFrameMetadataJson", nullptr, GetIncomingScreenFrameMetadataJson, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainStartService", nullptr, MainStartService, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendMouse", nullptr, SessionSendMouse, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionInputKey", nullptr, SessionInputKey, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionCtrlAltDel", nullptr, SessionCtrlAltDel, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendChat", nullptr, SessionSendChat, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionStart", nullptr, SessionStart, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainAccountAuth", nullptr, MainAccountAuth, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainAccountAuthCancel", nullptr, MainAccountAuthCancel, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainAccountAuthResult", nullptr, MainAccountAuthResult, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetLocalOption", nullptr, MainGetLocalOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetPeerOption", nullptr, MainGetPeerOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetToggleOption", nullptr, SessionGetToggleOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetLocalOption", nullptr, MainSetLocalOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionReconnect", nullptr, SessionReconnect, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionClose", nullptr, SessionClose, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionLogin", nullptr, SessionLogin, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRestartRemoteDevice", nullptr, SessionRestartRemoteDevice, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionLockScreen", nullptr, SessionLockScreen, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionOpenTerminal", nullptr, SessionOpenTerminal, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendTerminalInput", nullptr, SessionSendTerminalInput, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionResizeTerminal", nullptr, SessionResizeTerminal, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionCloseTerminal", nullptr, SessionCloseTerminal, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionReadRemoteDir", nullptr, SessionReadRemoteDir, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionCreateDir", nullptr, SessionCreateDir, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendFiles", nullptr, SessionSendFiles, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainDiscover", nullptr, MainDiscover, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainLoadLanPeers", nullptr, MainLoadLanPeers, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainRemoveDiscovered", nullptr, MainRemoveDiscovered, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSend2fa", nullptr, SessionSend2fa, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionToggleOption", nullptr, SessionToggleOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionTogglePrivacyMode", nullptr, SessionTogglePrivacyMode, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSwitchDisplay", nullptr, SessionSwitchDisplay, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionEnterOrLeave", nullptr, SessionEnterOrLeave, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionLeave", nullptr, SessionLeave, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetSize", nullptr, SessionSetSize, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionChangeResolution", nullptr, SessionChangeResolution, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionElevateDirect", nullptr, SessionElevateDirect, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionElevateWithLogon", nullptr, SessionElevateWithLogon, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSwitchSides", nullptr, SessionSwitchSides, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionTakeScreenshot", nullptr, SessionTakeScreenshot, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRecordScreen", nullptr, SessionRecordScreen, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetIsRecording", nullptr, SessionGetIsRecording, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRequestVoiceCall", nullptr, SessionRequestVoiceCall, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionCloseVoiceCall", nullptr, SessionCloseVoiceCall, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionAddPortForward", nullptr, SessionAddPortForward, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRemovePortForward", nullptr, SessionRemovePortForward, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionNewRdp", nullptr, SessionNewRdp, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRemoveFile", nullptr, SessionRemoveFile, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRenameFile", nullptr, SessionRenameFile, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionCancelJob", nullptr, SessionCancelJob, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionResumeJob", nullptr, SessionResumeJob, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetConfirmOverrideFile", nullptr, SessionSetConfirmOverrideFile, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendNote", nullptr, SessionSendNote, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionInputString", nullptr, SessionInputString, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionInputOsPassword", nullptr, SessionInputOsPassword, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionLoadLastTransferJobs", nullptr, SessionLoadLastTransferJobs, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetViewStyle", nullptr, SessionGetViewStyle, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetViewStyle", nullptr, SessionSetViewStyle, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetScrollStyle", nullptr, SessionGetScrollStyle, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetScrollStyle", nullptr, SessionSetScrollStyle, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetImageQuality", nullptr, SessionGetImageQuality, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetImageQuality", nullptr, SessionSetImageQuality, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetKeyboardMode", nullptr, SessionGetKeyboardMode, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetKeyboardMode", nullptr, SessionSetKeyboardMode, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetCustomImageQuality", nullptr, SessionGetCustomImageQuality, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetCustomImageQuality", nullptr, SessionSetCustomImageQuality, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetCustomFps", nullptr, SessionSetCustomFps, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetTrackpadSpeed", nullptr, SessionGetTrackpadSpeed, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetTrackpadSpeed", nullptr, SessionSetTrackpadSpeed, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetFlutterOption", nullptr, SessionGetFlutterOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetFlutterOption", nullptr, SessionSetFlutterOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetReverseMouseWheelSync", nullptr, SessionGetReverseMouseWheelSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetReverseMouseWheel", nullptr, SessionSetReverseMouseWheel, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetOption", nullptr, SessionGetOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetOption", nullptr, SessionSetOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetPeerOption", nullptr, SessionGetPeerOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionPeerOption", nullptr, SessionPeerOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionIsKeyboardModeSupported", nullptr, SessionIsKeyboardModeSupported, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetPlatform", nullptr, SessionGetPlatform, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetRemember", nullptr, SessionGetRemember, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetEnableTrustedDevices", nullptr, SessionGetEnableTrustedDevices, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetAlternativeCodecs", nullptr, SessionGetAlternativeCodecs, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionChangePreferCodec", nullptr, SessionChangePreferCodec, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetOption", nullptr, MainGetOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetOption", nullptr, MainSetOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetOptions", nullptr, MainGetOptions, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetMyId", nullptr, MainGetMyId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetUuid", nullptr, MainGetUuid, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetVersion", nullptr, MainGetVersion, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetFingerprint", nullptr, MainGetFingerprint, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetApiServer", nullptr, MainGetApiServer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetTemporaryPassword", nullptr, MainGetTemporaryPassword, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetPermanentPasswordWithResult", nullptr, MainSetPermanentPasswordWithResult, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainUpdateTemporaryPassword", nullptr, MainUpdateTemporaryPassword, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainTestIfValidServer", nullptr, MainTestIfValidServer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetConnectStatus", nullptr, MainGetConnectStatus, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsUsingPublicServer", nullptr, MainIsUsingPublicServer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainForgetPassword", nullptr, MainForgetPassword, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainPeerHasPassword", nullptr, MainPeerHasPassword, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainPeerExists", nullptr, MainPeerExists, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetPeerAlias", nullptr, MainSetPeerAlias, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetPeerOption", nullptr, MainSetPeerOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainRemovePeer", nullptr, MainRemovePeer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetNewStoredPeers", nullptr, MainGetNewStoredPeers, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainLoadRecentPeers", nullptr, MainLoadRecentPeers, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetLangs", nullptr, MainGetLangs, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetError", nullptr, MainGetError, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetBuildDate", nullptr, MainGetBuildDate, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetLicense", nullptr, MainGetLicense, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetAppName", nullptr, MainGetAppName, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHasHwcodec", nullptr, MainHasHwcodec, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGenerate2fa", nullptr, MainGenerate2fa, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainVerify2fa", nullptr, MainVerify2fa, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetTrustedDevices", nullptr, MainGetTrustedDevices, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainClearTrustedDevices", nullptr, MainClearTrustedDevices, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetUserDefaultOption", nullptr, MainSetUserDefaultOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetUserDefaultOption", nullptr, MainGetUserDefaultOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainResolveAvatarUrl", nullptr, MainResolveAvatarUrl, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetLoginDeviceInfo", nullptr, MainGetLoginDeviceInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetHardOption", nullptr, MainGetHardOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetBuildinOption", nullptr, MainGetBuildinOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetCommon", nullptr, MainGetCommon, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetCommon", nullptr, MainSetCommon, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainCheckConnectStatus", nullptr, MainCheckConnectStatus, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainStopService", nullptr, MainStopService, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainOnMainWindowClose", nullptr, MainOnMainWindowClose, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainWol", nullptr, MainWol, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHttpRequest", nullptr, MainHttpRequest, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionIsFileTransfer", nullptr, SessionIsFileTransfer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionIsTerminal", nullptr, SessionIsTerminal, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionIsPortForward", nullptr, SessionIsPortForward, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionIsRdp", nullptr, SessionIsRdp, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionIsViewCamera", nullptr, SessionIsViewCamera, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionToggleVirtualDisplay", nullptr, SessionToggleVirtualDisplay, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetAuditServer", nullptr, SessionGetAuditServer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendSelectedSessionId", nullptr, SessionSendSelectedSessionId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetConnToken", nullptr, SessionGetConnToken, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionHandleFlutterKeyEvent", nullptr, SessionHandleFlutterKeyEvent, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionHandleFlutterRawKeyEvent", nullptr, SessionHandleFlutterRawKeyEvent, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendTouchScale", nullptr, SessionSendTouchScale, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendTouchPanEvent", nullptr, SessionSendTouchPanEvent, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRefresh", nullptr, SessionRefresh, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetPeerVersion", nullptr, SessionGetPeerVersion, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetPathSep", nullptr, SessionGetPathSep, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionIsRestartingRemoteDevice", nullptr, SessionIsRestartingRemoteDevice, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmInit", nullptr, CmInit, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmGetClientsState", nullptr, CmGetClientsState, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmCheckClientsLength", nullptr, CmCheckClientsLength, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmGetClientsLength", nullptr, CmGetClientsLength, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmSendChat", nullptr, CmSendChat, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmLoginRes", nullptr, CmLoginRes, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmCloseConnection", nullptr, CmCloseConnection, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmRemoveDisconnectedConnection", nullptr, CmRemoveDisconnectedConnection, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmCheckClickTime", nullptr, CmCheckClickTime, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmGetClickTime", nullptr, CmGetClickTime, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmSwitchPermission", nullptr, CmSwitchPermission, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmCanElevate", nullptr, CmCanElevate, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmElevatePortable", nullptr, CmElevatePortable, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmSwitchBack", nullptr, CmSwitchBack, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmGetConfig", nullptr, CmGetConfig, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmHandleIncomingVoiceCall", nullptr, CmHandleIncomingVoiceCall, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"cmCloseVoiceCall", nullptr, CmCloseVoiceCall, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginEvent", nullptr, PluginEvent, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginRegisterEventStream", nullptr, PluginRegisterEventStream, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginGetSessionOption", nullptr, PluginGetSessionOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginSetSessionOption", nullptr, PluginSetSessionOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginGetSharedOption", nullptr, PluginGetSharedOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginSetSharedOption", nullptr, PluginSetSharedOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginReload", nullptr, PluginReload, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginEnable", nullptr, PluginEnable, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginIsEnabled", nullptr, PluginIsEnabled, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginFeatureIsEnabled", nullptr, PluginFeatureIsEnabled, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginSyncUi", nullptr, PluginSyncUi, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginListReload", nullptr, PluginListReload, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"pluginInstall", nullptr, PluginInstall, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"installInstallMe", nullptr, InstallInstallMe, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"installInstallOptions", nullptr, InstallInstallOptions, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"installInstallPath", nullptr, InstallInstallPath, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"installRunWithoutInstall", nullptr, InstallRunWithoutInstall, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"installShowRunWithoutInstall", nullptr, InstallShowRunWithoutInstall, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isCustomClient", nullptr, IsCustomClient, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isDisableAb", nullptr, IsDisableAb, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isDisableAccount", nullptr, IsDisableAccount, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isDisableGroupPanel", nullptr, IsDisableGroupPanel, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isDisableInstallation", nullptr, IsDisableInstallation, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isDisableSettings", nullptr, IsDisableSettings, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isIncomingOnly", nullptr, IsIncomingOnly, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isOutgoingOnly", nullptr, IsOutgoingOnly, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isPresetPassword", nullptr, IsPresetPassword, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isPresetPasswordMobileOnly", nullptr, IsPresetPasswordMobileOnly, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isSelinuxEnforcing", nullptr, IsSelinuxEnforcing, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"isSupportMultiUiSession", nullptr, IsSupportMultiUiSession, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainChangeId", nullptr, MainChangeId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainChangeLanguage", nullptr, MainChangeLanguage, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainChangeTheme", nullptr, MainChangeTheme, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetDisplays", nullptr, MainGetDisplays, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetPrinterNames", nullptr, MainGetPrinterNames, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetSocks", nullptr, MainGetSocks, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetSocks", nullptr, MainSetSocks, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetProxyStatus", nullptr, MainGetProxyStatus, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetAppNameSync", nullptr, MainGetAppNameSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetNewVersion", nullptr, MainGetNewVersion, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainInit", nullptr, MainInit, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetHomeDir", nullptr, MainGetHomeDir, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainDeviceId", nullptr, MainDeviceId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainDeviceName", nullptr, MainDeviceName, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsInstalled", nullptr, MainIsInstalled, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsInstalledDaemon", nullptr, MainIsInstalledDaemon, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsRoot", nullptr, MainIsRoot, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsProcessTrusted", nullptr, MainIsProcessTrusted, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsCanScreenRecording", nullptr, MainIsCanScreenRecording, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsCanInputMonitoring", nullptr, MainIsCanInputMonitoring, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainCurrentIsWayland", nullptr, MainCurrentIsWayland, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsLoginWayland", nullptr, MainIsLoginWayland, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHasVram", nullptr, MainHasVram, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSupportedHwdecodings", nullptr, MainSupportedHwdecodings, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainCheckHwcodec", nullptr, MainCheckHwcodec, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainCreateShortcut", nullptr, MainCreateShortcut, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetMouseTime", nullptr, MainGetMouseTime, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainCheckMouseTime", nullptr, MainCheckMouseTime, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetAsyncStatus", nullptr, MainGetAsyncStatus, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetLanPeers", nullptr, MainGetLanPeers, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetLastRemoteId", nullptr, MainGetLastRemoteId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetFav", nullptr, MainGetFav, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainStoreFav", nullptr, MainStoreFav, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetPeerSync", nullptr, MainGetPeerSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetPeerFlutterOptionSync", nullptr, MainGetPeerFlutterOptionSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetPeerFlutterOptionSync", nullptr, MainSetPeerFlutterOptionSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetPeerOptionSync", nullptr, MainGetPeerOptionSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetPeerOptionSync", nullptr, MainSetPeerOptionSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainRemoveTrustedDevices", nullptr, MainRemoveTrustedDevices, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHasValid_2faSync", nullptr, MainHasValid2faSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHasValidBotSync", nullptr, MainHasValidBotSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainVerifyBot", nullptr, MainVerifyBot, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainMaxEncryptLen", nullptr, MainMaxEncryptLen, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetUnlockPin", nullptr, MainGetUnlockPin, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetUnlockPin", nullptr, MainSetUnlockPin, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainOptionSynced", nullptr, MainOptionSynced, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSupportRemoveWallpaper", nullptr, MainSupportRemoveWallpaper, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainTestWallpaper", nullptr, MainTestWallpaper, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSupportedPrivacyModeImpls", nullptr, MainSupportedPrivacyModeImpls, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainDefaultPrivacyModeImpl", nullptr, MainDefaultPrivacyModeImpl, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsOptionFixed", nullptr, MainIsOptionFixed, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetUseTextureRender", nullptr, MainGetUseTextureRender, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHasFileClipboard", nullptr, MainHasFileClipboard, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHasGpuTextureRender", nullptr, MainHasGpuTextureRender, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainAudioSupportLoopback", nullptr, MainAudioSupportLoopback, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsShareRdp", nullptr, MainIsShareRdp, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetShareRdp", nullptr, MainSetShareRdp, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainIsInstalledLowerVersion", nullptr, MainIsInstalledLowerVersion, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetSoftwareUpdateUrl", nullptr, MainGetSoftwareUpdateUrl, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHandleRelayId", nullptr, MainHandleRelayId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHideDock", nullptr, MainHideDock, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetCursorPosition", nullptr, MainSetCursorPosition, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainClipCursor", nullptr, MainClipCursor, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetEnv", nullptr, MainGetEnv, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetEnv", nullptr, MainSetEnv, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetHomeDir", nullptr, MainSetHomeDir, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainStartDbusServer", nullptr, MainStartDbusServer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainStartIpcUrlServer", nullptr, MainStartIpcUrlServer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainCheckSuperUserPermission", nullptr, MainCheckSuperUserPermission, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGotoInstall", nullptr, MainGotoInstall, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainUpdateMe", nullptr, MainUpdateMe, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainDeployDevice", nullptr, MainDeployDevice, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetMainDisplay", nullptr, MainGetMainDisplay, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetInputSource", nullptr, MainGetInputSource, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetInputSource", nullptr, MainSetInputSource, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainInitInputSource", nullptr, MainInitInputSource, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSupportedInputSource", nullptr, MainSupportedInputSource, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainVideoSaveDirectory", nullptr, MainVideoSaveDirectory, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetDataDirIos", nullptr, MainGetDataDirIos, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainShowOption", nullptr, MainShowOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSetOptions", nullptr, MainSetOptions, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetOptionsSync", nullptr, MainGetOptionsSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetOptionSync", nullptr, MainGetOptionSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetCommonSync", nullptr, MainGetCommonSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainGetHttpStatus", nullptr, MainGetHttpStatus, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainUriPrefixSync", nullptr, MainUriPrefixSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainLoadAb", nullptr, MainLoadAb, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSaveAb", nullptr, MainSaveAb, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainClearAb", nullptr, MainClearAb, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainLoadGroup", nullptr, MainLoadGroup, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainSaveGroup", nullptr, MainSaveGroup, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainClearGroup", nullptr, MainClearGroup, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainLoadFavPeers", nullptr, MainLoadFavPeers, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainLoadRecentPeersForAb", nullptr, MainLoadRecentPeersForAb, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"mainHandleWaylandScreencastRestoreToken", nullptr, MainHandleWaylandScreencastRestoreToken, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getDoubleClickTime", nullptr, GetDoubleClickTime, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getLocalFlutterOption", nullptr, GetLocalFlutterOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setLocalFlutterOption", nullptr, SetLocalFlutterOption, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getLocalKbLayoutType", nullptr, GetLocalKbLayoutType, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setLocalKbLayoutType", nullptr, SetLocalKbLayoutType, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getVoiceCallInputDevice", nullptr, GetVoiceCallInputDevice, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setVoiceCallInputDevice", nullptr, SetVoiceCallInputDevice, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"hostStopSystemKeyPropagate", nullptr, HostStopSystemKeyPropagate, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"optionSynced", nullptr, OptionSynced, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"peerGetSessionsCount", nullptr, PeerGetSessionsCount, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sendUrlScheme", nullptr, SendUrlScheme, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setCurSessionId", nullptr, SetCurSessionId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"startGlobalEventStream", nullptr, StartGlobalEventStream, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"stopGlobalEventStream", nullptr, StopGlobalEventStream, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"translate", nullptr, Translate, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"versionToNumber", nullptr, VersionToNumber, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"willSessionCloseCloseSession", nullptr, WillSessionCloseCloseSession, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"getNextTextureKey", nullptr, GetNextTextureKey, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionAddExistedSync", nullptr, SessionAddExistedSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionAddJob", nullptr, SessionAddJob, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionAddSync", nullptr, SessionAddSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetAuditGuid", nullptr, SessionGetAuditGuid, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetAuditServerSync", nullptr, SessionGetAuditServerSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetCommon", nullptr, SessionGetCommon, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetCommonSync", nullptr, SessionGetCommonSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetConnSessionId", nullptr, SessionGetConnSessionId, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetDisplaysAsIndividualWindows", nullptr, SessionGetDisplaysAsIndividualWindows, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetEdgeScrollEdgeThickness", nullptr, SessionGetEdgeScrollEdgeThickness, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetLastAuditNote", nullptr, SessionGetLastAuditNote, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetRgbaSize", nullptr, SessionGetRgbaSize, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetToggleOptionSync", nullptr, SessionGetToggleOptionSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionGetUseAllMyDisplaysForTheRemoteSession", nullptr, SessionGetUseAllMyDisplaysForTheRemoteSession, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionHandleScreenshot", nullptr, SessionHandleScreenshot, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionIsMultiUiSession", nullptr, SessionIsMultiUiSession, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionNextRgba", nullptr, SessionNextRgba, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionOnWaitingForImageDialogShow", nullptr, SessionOnWaitingForImageDialogShow, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionPrinterResponse", nullptr, SessionPrinterResponse, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionReadDirToRemoveRecursive", nullptr, SessionReadDirToRemoveRecursive, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionReadLocalDirSync", nullptr, SessionReadLocalDirSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionReadLocalEmptyDirsRecursiveSync", nullptr, SessionReadLocalEmptyDirsRecursiveSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionReadRemoteEmptyDirsRecursiveSync", nullptr, SessionReadRemoteEmptyDirsRecursiveSync, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRegisterGpuTexture", nullptr, SessionRegisterGpuTexture, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRegisterPixelbufferTexture", nullptr, SessionRegisterPixelbufferTexture, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRemoveAllEmptyDirs", nullptr, SessionRemoveAllEmptyDirs, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionRequestNewDisplayInitMsgs", nullptr, SessionRequestNewDisplayInitMsgs, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSendPointer", nullptr, SessionSendPointer, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetAuditGuid", nullptr, SessionSetAuditGuid, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetDisplaysAsIndividualWindows", nullptr, SessionSetDisplaysAsIndividualWindows, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetEdgeScrollEdgeThickness", nullptr, SessionSetEdgeScrollEdgeThickness, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionSetUseAllMyDisplaysForTheRemoteSession", nullptr, SessionSetUseAllMyDisplaysForTheRemoteSession, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"sessionStartWithDisplays", nullptr, SessionStartWithDisplays, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
  OH_LOG_INFO(LOG_APP, "RustDesk bridge loader module registered (%{public}zu functions)", sizeof(desc) / sizeof(desc[0]));
  return exports;
}
EXTERN_C_END

static napi_module rustdeskBridgeModule = {
  .nm_version = 1,
  .nm_flags = 0,
  .nm_filename = nullptr,
  .nm_register_func = Init,
  .nm_modname = "librustdesk_bridge.so",
  .nm_priv = nullptr,
  .reserved = {0},
};

static napi_module rustdeskBridgeAliasModule = {
  .nm_version = 1,
  .nm_flags = 0,
  .nm_filename = nullptr,
  .nm_register_func = Init,
  .nm_modname = "librustdesk_bridge",
  .nm_priv = nullptr,
  .reserved = {0},
};

static napi_module rustdeskBridgeCanonicalModule = {
  .nm_version = 1,
  .nm_flags = 0,
  .nm_filename = nullptr,
  .nm_register_func = Init,
  .nm_modname = "rustdesk_bridge",
  .nm_priv = nullptr,
  .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterRustdeskBridgeModule(void) {
  napi_module_register(&rustdeskBridgeModule);
  napi_module_register(&rustdeskBridgeAliasModule);
  napi_module_register(&rustdeskBridgeCanonicalModule);
  OH_LOG_INFO(LOG_APP, "RustDesk bridge NAPI modules registered: rustdesk_bridge aliases ready");
}

extern "C" __attribute__((visibility("default"))) napi_value napi_register_module_v1(
    napi_env env, napi_value exports) {
  return Init(env, exports);
}
