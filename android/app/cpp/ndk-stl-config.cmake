if(NOT ${ANDROID_STL} MATCHES "_shared")
    return()
endif()

set(NDK_PREBUILT_DIR "${ANDROID_NDK}/toolchains/llvm/prebuilt")

if(DEFINED ANDROID_HOST_TAG AND EXISTS "${NDK_PREBUILT_DIR}/${ANDROID_HOST_TAG}")
    set(NDK_PREBUILT_ROOT "${NDK_PREBUILT_DIR}/${ANDROID_HOST_TAG}")
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux" AND EXISTS "${NDK_PREBUILT_DIR}/linux-x86_64")
    set(NDK_PREBUILT_ROOT "${NDK_PREBUILT_DIR}/linux-x86_64")
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$" AND EXISTS "${NDK_PREBUILT_DIR}/darwin-arm64")
        set(NDK_PREBUILT_ROOT "${NDK_PREBUILT_DIR}/darwin-arm64")
    elseif(EXISTS "${NDK_PREBUILT_DIR}/darwin-x86_64")
        set(NDK_PREBUILT_ROOT "${NDK_PREBUILT_DIR}/darwin-x86_64")
    elseif(EXISTS "${NDK_PREBUILT_DIR}/darwin-arm64")
        set(NDK_PREBUILT_ROOT "${NDK_PREBUILT_DIR}/darwin-arm64")
    endif()
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows" AND EXISTS "${NDK_PREBUILT_DIR}/windows-x86_64")
    set(NDK_PREBUILT_ROOT "${NDK_PREBUILT_DIR}/windows-x86_64")
endif()

if(NOT NDK_PREBUILT_ROOT)
    message(FATAL_ERROR "No Android NDK prebuilt toolchain found for ${CMAKE_HOST_SYSTEM_NAME}/${CMAKE_HOST_SYSTEM_PROCESSOR} under ${NDK_PREBUILT_DIR}; set ANDROID_HOST_TAG if needed")
endif()

if(NOT EXISTS "${NDK_PREBUILT_ROOT}")
    message(FATAL_ERROR "Android NDK prebuilt toolchain does not exist: ${NDK_PREBUILT_ROOT}")
endif()

function(configure_shared_stl so_base)
    message("Configuring STL ${so_base} for ${ANDROID_ABI}")

    if(${ANDROID_ABI} STREQUAL "arm64-v8a")
        set(LIBCXX_PATH "${NDK_PREBUILT_ROOT}/sysroot/usr/lib/aarch64-linux-android/lib${so_base}.so")
    elseif(${ANDROID_ABI} STREQUAL "armeabi-v7a")
        set(LIBCXX_PATH "${NDK_PREBUILT_ROOT}/sysroot/usr/lib/arm-linux-androideabi/lib${so_base}.so")
    elseif(${ANDROID_ABI} STREQUAL "x86")
        set(LIBCXX_PATH "${NDK_PREBUILT_ROOT}/sysroot/usr/lib/i686-linux-android/lib${so_base}.so")
    elseif(${ANDROID_ABI} STREQUAL "x86_64")
        set(LIBCXX_PATH "${NDK_PREBUILT_ROOT}/sysroot/usr/lib/x86_64-linux-android/lib${so_base}.so")
    else()
        message(FATAL_ERROR "Unsupported ABI: ${ANDROID_ABI}")
    endif()

    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/../src/main/jniLibs/${ANDROID_ABI}")
    configure_file(
            "${LIBCXX_PATH}"
            "${CMAKE_SOURCE_DIR}/../src/main/jniLibs/${ANDROID_ABI}/lib${so_base}.so"
            COPYONLY
    )

endfunction()

if("${ANDROID_STL}" STREQUAL "libstdc++")
    # The default minimal system C++ runtime library.
elseif("${ANDROID_STL}" STREQUAL "gabi++_shared")
    # The GAbi++ runtime (shared).
    message(FATAL_ERROR "gabi++_shared was not configured by ndk-stl package")
elseif("${ANDROID_STL}" STREQUAL "stlport_shared")
    # The STLport runtime (shared).
    configure_shared_stl("stlport_shared")
elseif("${ANDROID_STL}" STREQUAL "gnustl_shared")
    # The GNU STL (shared).
    configure_shared_stl("gnustl_shared")
elseif("${ANDROID_STL}" STREQUAL "c++_shared")
    # The LLVM libc++ runtime (static).
    configure_shared_stl("c++_shared")
else()
    message(FATAL_ERROR "STL configuration ANDROID_STL=${ANDROID_STL} is not supported")
endif()
