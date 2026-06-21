cmake_minimum_required(VERSION 3.5.0)
project(rustdesk_bridge)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

message(STATUS "=== STATIC LINK MODE ===")
message(STATUS "Bridge links Rust core staticlib directly, single .so output")

find_library(log-lib hilog_ndk.z)
find_library(napi-lib ace_napi.z)
find_library(cpp_shared-lib c++_shared)
find_library(native_avscreen_capture_lib native_avscreen_capture)
find_library(native_buffer_lib native_buffer)
find_library(native_media_vdec_lib native_media_vdec)
find_library(native_media_core_lib native_media_core)
find_library(native_media_codecbase_lib native_media_codecbase)

if(NOT cpp_shared-lib AND DEFINED OHOS_SDK_NATIVE AND DEFINED OHOS_TOOLCHAIN_NAME)
  set(CPP_SHARED_FALLBACK_CANDIDATES
    ${OHOS_SDK_NATIVE}/llvm/lib/${OHOS_TOOLCHAIN_NAME}/libc++_shared.so
    ${OHOS_SDK_NATIVE}/llvm/lib/${OHOS_TOOLCHAIN_NAME}/c++/libc++_shared.so
  )
  foreach(CPP_SHARED_CANDIDATE ${CPP_SHARED_FALLBACK_CANDIDATES})
    if(EXISTS ${CPP_SHARED_CANDIDATE})
      set(cpp_shared-lib ${CPP_SHARED_CANDIDATE})
      break()
    endif()
  endforeach()
endif()

add_library(rustdesk_bridge SHARED
  rustdesk_bridge_loader.cpp
  ohos_video_decoder.cpp
  ohos_stubs.cpp
)

target_include_directories(rustdesk_bridge PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${NATIVERENDER_ROOT_PATH}
)

set(RUST_CORE_A ${CMAKE_CURRENT_SOURCE_DIR}/../libs/arm64/librustdesk_core.a)
set(RUST_CORE_A_X86_64 ${CMAKE_CURRENT_SOURCE_DIR}/../libs/x86_64/librustdesk_core.a)
set(RUST_CORE_STUB ${CMAKE_CURRENT_SOURCE_DIR}/rustdesk_core_stub.cpp)

if(DEFINED ENV{RUSTDESK_CORE_ARM64_ARCHIVE} AND EXISTS "$ENV{RUSTDESK_CORE_ARM64_ARCHIVE}")
  set(RUST_CORE_A "$ENV{RUSTDESK_CORE_ARM64_ARCHIVE}")
endif()
if(DEFINED ENV{RUSTDESK_CORE_X86_64_ARCHIVE} AND EXISTS "$ENV{RUSTDESK_CORE_X86_64_ARCHIVE}")
  set(RUST_CORE_A_X86_64 "$ENV{RUSTDESK_CORE_X86_64_ARCHIVE}")
endif()

if(OHOS_ARCH STREQUAL "x86_64" AND EXISTS ${RUST_CORE_A_X86_64})
  file(SIZE ${RUST_CORE_A_X86_64} RUST_CORE_A_X86_64_SIZE)
  math(EXPR RUST_CORE_A_X86_64_SIZE_MB "${RUST_CORE_A_X86_64_SIZE} / 1024 / 1024")
  message(STATUS "=== x86_64 REAL CORE MODE ===")
  message(STATUS "Rust core staticlib (x86_64): ${RUST_CORE_A_X86_64_SIZE_MB} MB")
  target_link_libraries(rustdesk_bridge PUBLIC
    ${log-lib}
    ${napi-lib}
    ${cpp_shared-lib}
    ${native_avscreen_capture_lib}
    ${native_buffer_lib}
    ${native_media_vdec_lib}
    ${native_media_core_lib}
    ${native_media_codecbase_lib}
    ${RUST_CORE_A_X86_64}
    m
  )
  target_link_options(rustdesk_bridge PRIVATE
    "-Wl,--as-needed"
    "-Wl,--unresolved-symbols=ignore-all"
  )
elseif(OHOS_ARCH STREQUAL "x86_64")
  message(STATUS "=== x86_64 STUB MODE ===")
  message(STATUS "No real x86_64 core found; using stub for emulator UI debugging")
  target_sources(rustdesk_bridge PRIVATE ${RUST_CORE_STUB})
  target_link_libraries(rustdesk_bridge PUBLIC
    ${log-lib}
    ${napi-lib}
    ${cpp_shared-lib}
    ${native_avscreen_capture_lib}
    ${native_buffer_lib}
    ${native_media_vdec_lib}
    ${native_media_core_lib}
    ${native_media_codecbase_lib}
    m
  )
  target_link_options(rustdesk_bridge PRIVATE
    "-Wl,--as-needed"
    "-Wl,--unresolved-symbols=ignore-all"
  )
elseif(EXISTS ${RUST_CORE_A})
  file(SIZE ${RUST_CORE_A} RUST_CORE_A_SIZE)
  math(EXPR RUST_CORE_A_SIZE_MB "${RUST_CORE_A_SIZE} / 1024 / 1024")
  message(STATUS "Rust core staticlib: ${RUST_CORE_A_SIZE_MB} MB")

  target_link_libraries(rustdesk_bridge PUBLIC
    ${log-lib}
    ${napi-lib}
    ${cpp_shared-lib}
    ${native_avscreen_capture_lib}
    ${native_buffer_lib}
    ${native_media_vdec_lib}
    ${native_media_core_lib}
    ${native_media_codecbase_lib}
    ${RUST_CORE_A}
    m
  )

  target_link_options(rustdesk_bridge PRIVATE
    "-Wl,--as-needed"
    "-Wl,--unresolved-symbols=ignore-all"
  )
else()
  message(WARNING "Rust core staticlib not found at ${RUST_CORE_A}")
  message(STATUS "To include: copy librustdesk_core.a to entry/src/main/libs/arm64/")
  target_link_libraries(rustdesk_bridge PUBLIC
    ${log-lib}
    ${napi-lib}
    ${cpp_shared-lib}
    ${native_avscreen_capture_lib}
    ${native_buffer_lib}
    ${native_media_vdec_lib}
    ${native_media_core_lib}
    ${native_media_codecbase_lib}
  )
endif()

set_target_properties(rustdesk_bridge PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
)

message(STATUS "Bridge configured with static link to Rust core.")
