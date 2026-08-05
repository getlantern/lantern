if(NOT ${ANDROID_STL} MATCHES "_shared")
    return()
endif()

if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    set(NDK_PREBUILT_HOST "darwin-x86_64")
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    set(NDK_PREBUILT_HOST "linux-x86_64")
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(NDK_PREBUILT_HOST "windows-x86_64")
else()
    message(FATAL_ERROR "Unsupported host system: ${CMAKE_HOST_SYSTEM_NAME}")
endif()

set(NDK_SYSROOT "${ANDROID_NDK}/toolchains/llvm/prebuilt/${NDK_PREBUILT_HOST}/sysroot")

function(configure_shared_stl lib_path so_base)
    message("Configuring STL ${so_base} for ${ANDROID_ABI}")

    if(${ANDROID_ABI} STREQUAL "arm64-v8a")
        set(LIBCXX_PATH "${NDK_SYSROOT}/usr/lib/aarch64-linux-android/lib${so_base}.so")
    elseif(${ANDROID_ABI} STREQUAL "armeabi-v7a")
        set(LIBCXX_PATH "${NDK_SYSROOT}/usr/lib/arm-linux-androideabi/lib${so_base}.so")
    elseif(${ANDROID_ABI} STREQUAL "x86")
        set(LIBCXX_PATH "${NDK_SYSROOT}/usr/lib/i686-linux-android/lib${so_base}.so")
    elseif(${ANDROID_ABI} STREQUAL "x86_64")
        set(LIBCXX_PATH "${NDK_SYSROOT}/usr/lib/x86_64-linux-android/lib${so_base}.so")
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
    configure_shared_stl("stlport" "stlport_shared")
elseif("${ANDROID_STL}" STREQUAL "gnustl_shared")
    # The GNU STL (shared).
    configure_shared_stl("gnu-libstdc++/4.9" "gnustl_shared")
elseif("${ANDROID_STL}" STREQUAL "c++_shared")
    # The LLVM libc++ runtime (static).
    configure_shared_stl("llvm-libc++" "c++_shared")
else()
    message(FATAL_ERROR "STL configuration ANDROID_STL=${ANDROID_STL} is not supported")
endif()
