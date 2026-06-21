#include <multimedia/player_framework/native_avcodec_videodecoder.h>
#include <multimedia/player_framework/native_avbuffer_info.h>
#include <multimedia/player_framework/native_avformat.h>
#include <multimedia/player_framework/native_avmemory.h>

#include <hilog/log.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <deque>
#include <mutex>
#include <string>
#include <vector>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x3200
#define LOG_TAG "RustDeskVideoDecoder"

namespace {

constexpr int32_t kPixelFormatI420 = 1;
constexpr auto kInputWait = std::chrono::milliseconds(50);
constexpr auto kOutputWait = std::chrono::milliseconds(100);

const char *CodecMime(int32_t codec) {
  switch (codec) {
    case 3:
      return "video/av01";
    case 4:
      return "video/avc";
    case 5:
      return "video/hevc";
    default:
      return nullptr;
  }
}

struct InputBuffer {
  uint32_t index = 0;
  OH_AVMemory *memory = nullptr;
};

struct DecodedFrame {
  std::vector<uint8_t> bytes;
  int32_t width = 0;
  int32_t height = 0;
  int32_t stride = 0;
  int32_t sliceHeight = 0;
  int32_t pixelFormat = kPixelFormatI420;
};

struct VideoDecoder {
  OH_AVCodec *codec = nullptr;
  std::mutex mutex;
  std::condition_variable inputReady;
  std::condition_variable outputReady;
  std::deque<InputBuffer> inputs;
  std::deque<DecodedFrame> outputs;
  int32_t width = 0;
  int32_t height = 0;
  int32_t stride = 0;
  int32_t sliceHeight = 0;
  int32_t pixelFormat = kPixelFormatI420;
  int32_t errorCode = 0;
  bool stopping = false;
};

void ReadOutputFormat(VideoDecoder *decoder, OH_AVFormat *format) {
  if (decoder == nullptr || format == nullptr) {
    return;
  }
  int32_t width = 0;
  int32_t height = 0;
  int32_t stride = 0;
  int32_t sliceHeight = 0;
  int32_t pixelFormat = kPixelFormatI420;
  OH_AVFormat_GetIntValue(format, OH_MD_KEY_WIDTH, &width);
  OH_AVFormat_GetIntValue(format, OH_MD_KEY_HEIGHT, &height);
  OH_AVFormat_GetIntValue(format, OH_MD_KEY_VIDEO_STRIDE, &stride);
  OH_AVFormat_GetIntValue(format, OH_MD_KEY_VIDEO_SLICE_HEIGHT, &sliceHeight);
  OH_AVFormat_GetIntValue(format, OH_MD_KEY_PIXEL_FORMAT, &pixelFormat);

  std::lock_guard<std::mutex> lock(decoder->mutex);
  if (width > 0) decoder->width = width;
  if (height > 0) decoder->height = height;
  decoder->stride = stride > 0 ? stride : decoder->width;
  decoder->sliceHeight = sliceHeight > 0 ? sliceHeight : decoder->height;
  decoder->pixelFormat = pixelFormat;
}

void OnDecoderError(OH_AVCodec *, int32_t errorCode, void *userData) {
  auto *decoder = static_cast<VideoDecoder *>(userData);
  if (decoder == nullptr) return;
  {
    std::lock_guard<std::mutex> lock(decoder->mutex);
    decoder->errorCode = errorCode == 0 ? -1 : errorCode;
  }
  decoder->inputReady.notify_all();
  decoder->outputReady.notify_all();
  OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
               "native video decoder error: %{public}d", errorCode);
}

void OnStreamChanged(OH_AVCodec *, OH_AVFormat *format, void *userData) {
  ReadOutputFormat(static_cast<VideoDecoder *>(userData), format);
}

void OnNeedInputData(OH_AVCodec *, uint32_t index, OH_AVMemory *memory,
                     void *userData) {
  auto *decoder = static_cast<VideoDecoder *>(userData);
  if (decoder == nullptr || memory == nullptr) return;
  {
    std::lock_guard<std::mutex> lock(decoder->mutex);
    if (decoder->stopping) return;
    decoder->inputs.push_back({index, memory});
  }
  decoder->inputReady.notify_one();
}

void OnNewOutputData(OH_AVCodec *codec, uint32_t index, OH_AVMemory *memory,
                     OH_AVCodecBufferAttr *attr, void *userData) {
  auto *decoder = static_cast<VideoDecoder *>(userData);
  if (decoder == nullptr || memory == nullptr || attr == nullptr) return;

  DecodedFrame frame;
  {
    std::lock_guard<std::mutex> lock(decoder->mutex);
    frame.width = decoder->width;
    frame.height = decoder->height;
    frame.stride = decoder->stride > 0 ? decoder->stride : decoder->width;
    frame.sliceHeight = decoder->sliceHeight > 0 ? decoder->sliceHeight : decoder->height;
    frame.pixelFormat = decoder->pixelFormat;
  }

  const int32_t capacity = OH_AVMemory_GetSize(memory);
  const int32_t offset = attr->offset < 0 ? 0 : attr->offset;
  int32_t size = attr->size;
  if (size <= 0 || offset + size > capacity) {
    size = capacity - offset;
  }
  uint8_t *address = OH_AVMemory_GetAddr(memory);
  if (address != nullptr && size > 0 && frame.width > 0 && frame.height > 0) {
    frame.bytes.assign(address + offset, address + offset + size);
    {
      std::lock_guard<std::mutex> lock(decoder->mutex);
      if (decoder->outputs.size() >= 2) decoder->outputs.pop_front();
      decoder->outputs.push_back(std::move(frame));
    }
    decoder->outputReady.notify_one();
  }
  OH_VideoDecoder_FreeOutputData(codec, index);
}

VideoDecoder *CreateDecoder(int32_t codecId) {
  const char *mime = CodecMime(codecId);
  if (mime == nullptr) return nullptr;

  auto *decoder = new VideoDecoder();
  decoder->codec = OH_VideoDecoder_CreateByMime(mime);
  if (decoder->codec == nullptr) {
    delete decoder;
    return nullptr;
  }

  OH_AVCodecAsyncCallback callback = {};
  callback.onError = OnDecoderError;
  callback.onStreamChanged = OnStreamChanged;
  callback.onNeedInputData = OnNeedInputData;
  callback.onNeedOutputData = OnNewOutputData;
  OH_AVErrCode result = OH_VideoDecoder_SetCallback(decoder->codec, callback, decoder);

  OH_AVFormat *format = OH_AVFormat_CreateVideoFormat(mime, 0, 0);
  if (format != nullptr) {
    OH_AVFormat_SetIntValue(format, OH_MD_KEY_PIXEL_FORMAT, kPixelFormatI420);
  }
  if (result == AV_ERR_OK && format != nullptr) {
    result = OH_VideoDecoder_Configure(decoder->codec, format);
  }
  if (format != nullptr) OH_AVFormat_Destroy(format);
  if (result == AV_ERR_OK) result = OH_VideoDecoder_Prepare(decoder->codec);
  if (result == AV_ERR_OK) result = OH_VideoDecoder_Start(decoder->codec);
  if (result != AV_ERR_OK) {
    OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG,
                 "failed to start %{public}s decoder: %{public}d", mime, result);
    OH_VideoDecoder_Destroy(decoder->codec);
    delete decoder;
    return nullptr;
  }
  OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG,
               "started native %{public}s decoder", mime);
  return decoder;
}

}  // namespace

extern "C" {

bool rustdesk_ohos_video_decoder_is_supported(int32_t codec) {
  static std::atomic<int32_t> av1{-1};
  static std::atomic<int32_t> h264{-1};
  static std::atomic<int32_t> h265{-1};
  std::atomic<int32_t> *cached = codec == 3 ? &av1 : (codec == 4 ? &h264 : (codec == 5 ? &h265 : nullptr));
  if (cached == nullptr) return false;
  int32_t value = cached->load();
  if (value >= 0) return value == 1;
  VideoDecoder *decoder = CreateDecoder(codec);
  const bool supported = decoder != nullptr;
  if (decoder != nullptr) {
    {
      std::lock_guard<std::mutex> lock(decoder->mutex);
      decoder->stopping = true;
    }
    OH_VideoDecoder_Stop(decoder->codec);
    OH_VideoDecoder_Destroy(decoder->codec);
    delete decoder;
  }
  cached->store(supported ? 1 : 0);
  return supported;
}

void *rustdesk_ohos_video_decoder_create(int32_t codec) {
  return CreateDecoder(codec);
}

void rustdesk_ohos_video_decoder_destroy(void *handle) {
  auto *decoder = static_cast<VideoDecoder *>(handle);
  if (decoder == nullptr) return;
  {
    std::lock_guard<std::mutex> lock(decoder->mutex);
    decoder->stopping = true;
  }
  decoder->inputReady.notify_all();
  decoder->outputReady.notify_all();
  OH_VideoDecoder_Stop(decoder->codec);
  OH_VideoDecoder_Destroy(decoder->codec);
  delete decoder;
}

int32_t rustdesk_ohos_video_decoder_submit(void *handle, const uint8_t *data,
                                           size_t size, bool key,
                                           int64_t presentationTimeUs) {
  auto *decoder = static_cast<VideoDecoder *>(handle);
  if (decoder == nullptr || data == nullptr || size == 0) return -1;

  InputBuffer input;
  {
    std::unique_lock<std::mutex> lock(decoder->mutex);
    decoder->inputReady.wait_for(lock, kInputWait, [&] {
      return !decoder->inputs.empty() || decoder->errorCode != 0 || decoder->stopping;
    });
    if (decoder->errorCode != 0) return -decoder->errorCode;
    if (decoder->stopping) return -1;
    if (decoder->inputs.empty()) return 0;
    input = decoder->inputs.front();
    decoder->inputs.pop_front();
  }

  const int32_t capacity = OH_AVMemory_GetSize(input.memory);
  uint8_t *address = OH_AVMemory_GetAddr(input.memory);
  if (address == nullptr || size > static_cast<size_t>(capacity)) return -2;
  std::memcpy(address, data, size);
  OH_AVCodecBufferAttr attr = {};
  attr.pts = presentationTimeUs;
  attr.size = static_cast<int32_t>(size);
  attr.offset = 0;
  attr.flags = key ? AVCODEC_BUFFER_FLAGS_SYNC_FRAME : AVCODEC_BUFFER_FLAGS_NONE;
  const OH_AVErrCode result = OH_VideoDecoder_PushInputData(decoder->codec, input.index, attr);
  if (result != AV_ERR_OK) return -static_cast<int32_t>(result);

  std::unique_lock<std::mutex> lock(decoder->mutex);
  decoder->outputReady.wait_for(lock, kOutputWait, [&] {
    return !decoder->outputs.empty() || decoder->errorCode != 0 || decoder->stopping;
  });
  if (decoder->errorCode != 0) return -decoder->errorCode;
  return decoder->outputs.empty() ? 0 : 1;
}

int64_t rustdesk_ohos_video_decoder_frame_info(void *handle, int32_t *width,
                                                int32_t *height, int32_t *stride,
                                                int32_t *sliceHeight,
                                                int32_t *pixelFormat) {
  auto *decoder = static_cast<VideoDecoder *>(handle);
  if (decoder == nullptr) return -1;
  std::lock_guard<std::mutex> lock(decoder->mutex);
  if (decoder->outputs.empty()) return 0;
  const DecodedFrame &frame = decoder->outputs.front();
  if (width != nullptr) *width = frame.width;
  if (height != nullptr) *height = frame.height;
  if (stride != nullptr) *stride = frame.stride;
  if (sliceHeight != nullptr) *sliceHeight = frame.sliceHeight;
  if (pixelFormat != nullptr) *pixelFormat = frame.pixelFormat;
  return static_cast<int64_t>(frame.bytes.size());
}

int64_t rustdesk_ohos_video_decoder_copy_frame(void *handle, uint8_t *output,
                                                size_t capacity) {
  auto *decoder = static_cast<VideoDecoder *>(handle);
  if (decoder == nullptr || output == nullptr) return -1;
  std::lock_guard<std::mutex> lock(decoder->mutex);
  if (decoder->outputs.empty()) return 0;
  DecodedFrame &frame = decoder->outputs.front();
  if (capacity < frame.bytes.size()) return static_cast<int64_t>(frame.bytes.size());
  std::memcpy(output, frame.bytes.data(), frame.bytes.size());
  const int64_t copied = static_cast<int64_t>(frame.bytes.size());
  decoder->outputs.pop_front();
  return copied;
}

}  // extern "C"
