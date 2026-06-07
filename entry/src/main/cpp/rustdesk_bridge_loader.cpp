#include <node_api.h>
#include <hilog/log.h>
#include <cstring>
#include <string>
#include <vector>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>

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
  size_t argc = 5;
  napi_value args[5] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string values[5];
  for (size_t i = 0; i < argc && i < 5; ++i) ReadUtf8String(env, args[i], &values[i]);
  rustdesk_bridge_connect_to_peer(values[0].c_str(), values[1].c_str(), values[2].c_str(), values[3].c_str(), values[4].c_str());
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
  rustdesk_bridge_account_auth(op.c_str(), remember_me ? 1 : 0, server.c_str(), relay_server.c_str(), api_server.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value AccountAuthCancel(napi_env env, napi_callback_info info) {
  (void)info;
  rustdesk_bridge_account_auth_cancel();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value AccountAuthResult(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeString(env, CopyOwnedText(rustdesk_bridge_account_auth_result()));
}

napi_value GetLocalOption(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_local_option(key.c_str())));
}

napi_value SetLocalOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string key, value;
  if (argc > 0) ReadUtf8String(env, args[0], &key);
  if (argc > 1) ReadUtf8String(env, args[1], &value);
  rustdesk_bridge_set_local_option(key.c_str(), value.c_str());
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value CloseSession(napi_env env, napi_callback_info info) {
  (void)info;
  rustdesk_bridge_close_session();
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
  return MakeBool(env, rustdesk_bridge_reconnect_session(force_relay ? 1 : 0) != 0);
}

napi_value SubmitSessionPassword(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string password;
  bool remember = false;
  if (argc > 0) ReadUtf8String(env, args[0], &password);
  if (argc > 1) napi_get_value_bool(env, args[1], &remember);
  return MakeBool(env, rustdesk_bridge_submit_session_password(password.c_str(), remember ? 1 : 0) != 0);
}

napi_value SetIncomingServiceEnabled(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  bool enabled = false;
  if (argc > 0) napi_get_value_bool(env, args[0], &enabled);
  std::string values[3];
  for (size_t i = 1; i < argc && i < 4; ++i) ReadUtf8String(env, args[i], &values[i - 1]);
  const char *snapshot = rustdesk_bridge_set_incoming_service_enabled(enabled ? 1 : 0, values[0].c_str(), values[1].c_str(), values[2].c_str());
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
  return MakeBool(env, rustdesk_bridge_send_mouse_input(mask, x, y) != 0);
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
  return MakeBool(env, rustdesk_bridge_send_keyboard_input(key_code, is_pressed ? 1 : 0, modifiers) != 0);
}

napi_value SendCtrlAltDel(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeBool(env, rustdesk_bridge_send_ctrl_alt_del() != 0);
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

napi_value SendChatMessage(napi_env env, napi_callback_info info) {
  size_t argc = 4;
  napi_value args[4] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id, message_type, content;
  int64_t timestamp = 0;
  std::string *targets[3] = {&peer_id, &message_type, &content};
  for (size_t i = 0; i < argc && i < 3; ++i) ReadUtf8String(env, args[i], targets[i]);
  if (argc > 3) napi_get_value_int64(env, args[3], &timestamp);
  return MakeBool(env, rustdesk_bridge_send_chat_message(peer_id.c_str(), message_type.c_str(), content.c_str(), timestamp) != 0);
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
  return MakeBool(env, rustdesk_bridge_open_terminal(terminal_id, rows, cols) != 0);
}

napi_value SendTerminalInput(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0;
  std::string data;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  if (argc > 1) ReadUtf8String(env, args[1], &data);
  return MakeBool(env, rustdesk_bridge_send_terminal_input(terminal_id, data.c_str()) != 0);
}

napi_value ResizeTerminal(napi_env env, napi_callback_info info) {
  size_t argc = 3;
  napi_value args[3] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0, rows = 24, cols = 80;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  if (argc > 1) napi_get_value_int32(env, args[1], &rows);
  if (argc > 2) napi_get_value_int32(env, args[2], &cols);
  return MakeBool(env, rustdesk_bridge_resize_terminal(terminal_id, rows, cols) != 0);
}

napi_value CloseTerminal(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  int32_t terminal_id = 0;
  if (argc > 0) napi_get_value_int32(env, args[0], &terminal_id);
  return MakeBool(env, rustdesk_bridge_close_terminal(terminal_id) != 0);
}

napi_value ReadRemoteDirectory(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  bool include_hidden = false;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  if (argc > 1) napi_get_value_bool(env, args[1], &include_hidden);
  return MakeBool(env, rustdesk_bridge_read_remote_directory(path.c_str(), include_hidden ? 1 : 0) != 0);
}

napi_value CreateRemoteDirectory(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string path;
  if (argc > 0) ReadUtf8String(env, args[0], &path);
  return MakeBool(env, rustdesk_bridge_create_remote_directory(path.c_str()) != 0);
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
  return MakeBool(env, rustdesk_bridge_start_file_transfer(path.c_str(), to.c_str(), is_remote ? 1 : 0) != 0);
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
  rustdesk_bridge_discover_lan_peers();
  napi_value undefined = nullptr;
  napi_get_undefined(env, &undefined);
  return undefined;
}

napi_value LoadLanPeers(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeString(env, CopyOwnedText(rustdesk_bridge_load_lan_peers()));
}

napi_value RemoveDiscoveredPeer(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value args[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  return MakeBool(env, rustdesk_bridge_remove_discovered_peer(peer_id.c_str()) != 0);
}

napi_value GetPeerOption(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value args[2] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
  std::string peer_id, key;
  if (argc > 0) ReadUtf8String(env, args[0], &peer_id);
  if (argc > 1) ReadUtf8String(env, args[1], &key);
  return MakeString(env, CopyOwnedText(rustdesk_bridge_get_peer_option(peer_id.c_str(), key.c_str())));
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
  return MakeBool(env, rustdesk_bridge_get_session_toggle_option(key.c_str()) != 0);
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
  return MakeBool(env, rustdesk_bridge_restart_remote_device() != 0);
}

napi_value LockRemoteScreen(napi_env env, napi_callback_info info) {
  (void)info;
  return MakeBool(env, rustdesk_bridge_lock_remote_screen() != 0);
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
