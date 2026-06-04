cmake_minimum_required(VERSION 3.5.0)
project(rustdesk_bridge)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

message(STATUS "=== STATIC LINK MODE ===")
message(STATUS "Bridge links Rust core staticlib directly, single .so output")

find_library(log-lib hilog_ndk.z)
find_library(napi-lib ace_napi.z)
find_library(cpp_shared-lib c++_shared)
find_library(time-lib NAMES time_service_ndk.z time_service_ndk)

if(NOT time-lib AND DEFINED OHOS_SDK_NATIVE)
  set(TIME_FALLBACK "${OHOS_SDK_NATIVE}/sysroot/usr/lib/aarch64-linux-ohos/libtime_service_ndk.so")
  if(EXISTS ${TIME_FALLBACK})
    set(time-lib ${TIME_FALLBACK})
    message(STATUS "time_service_ndk found via fallback: ${time-lib}")
  endif()
endif()

if(NOT time-lib)
  message(WARNING "time_service_ndk not found, OH_TimeService_GetTimeZone may be undefined")
endif()

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
  ohos_stubs.cpp
)

target_include_directories(rustdesk_bridge PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${NATIVERENDER_ROOT_PATH}
)

set(RUST_CORE_A ${CMAKE_CURRENT_SOURCE_DIR}/../libs/arm64/librustdesk_core.a)

if(EXISTS ${RUST_CORE_A})
  file(SIZE ${RUST_CORE_A} RUST_CORE_A_SIZE)
  math(EXPR RUST_CORE_A_SIZE_MB "${RUST_CORE_A_SIZE} / 1024 / 1024")
  message(STATUS "Rust core staticlib: ${RUST_CORE_A_SIZE_MB} MB")

  if(time-lib)
    target_link_libraries(rustdesk_bridge PUBLIC
      ${log-lib}
      ${napi-lib}
      ${cpp_shared-lib}
      ${time-lib}
      ${RUST_CORE_A}
      m
    )
  else()
    target_link_libraries(rustdesk_bridge PUBLIC
      ${log-lib}
      ${napi-lib}
      ${cpp_shared-lib}
      ${RUST_CORE_A}
      m
    )
  endif()

  target_link_options(rustdesk_bridge PRIVATE
    "-Wl,--unresolved-symbols=ignore-all"
  )
else()
  message(WARNING "Rust core staticlib not found at ${RUST_CORE_A}")
  message(STATUS "To include: copy librustdesk_core.a to entry/src/main/libs/arm64/")
  target_link_libraries(rustdesk_bridge PUBLIC
    ${log-lib}
    ${napi-lib}
    ${cpp_shared-lib}
  )
endif()

set_target_properties(rustdesk_bridge PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
)

message(STATUS "Bridge configured with static link to Rust core.")
