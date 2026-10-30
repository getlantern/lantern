# libgojni uses libc++ through its native dependencies. The NDK r28c prebuilt
# lacks stack protection, so package the matching runtime rebuilt from source.
# Running this at configure time also covers Android Studio/direct Gradle builds.
get_filename_component(LANTERN_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(HARDENED_LIBCXX_DIR "${LANTERN_ROOT}/bin/android/libcxx")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${LANTERN_ROOT}/scripts/android/build-hardened-libcxx.py"
    "${LANTERN_ROOT}/scripts/android/hardened-libcxx-sources.json"
)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${LANTERN_ROOT}/scripts/android/build-hardened-libcxx.py"
        --ndk "${ANDROID_NDK}"
        --abis "${ANDROID_ABI}"
        --output-dir "${HARDENED_LIBCXX_DIR}"
    RESULT_VARIABLE HARDENED_LIBCXX_RESULT
)
if(NOT HARDENED_LIBCXX_RESULT EQUAL 0)
    message(FATAL_ERROR "Unable to build the hardened Android C++ runtime. See build/android-hardened-libcxx/${ANDROID_ABI}.log.")
endif()
set(LIBCXX_PATH "${HARDENED_LIBCXX_DIR}/${ANDROID_ABI}/libc++_shared.so")
if(NOT EXISTS "${LIBCXX_PATH}")
    message(FATAL_ERROR "Hardened libc++ was not produced: ${LIBCXX_PATH}")
endif()
file(MAKE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/../src/main/jniLibs/${ANDROID_ABI}")
configure_file(
    "${LIBCXX_PATH}"
    "${CMAKE_CURRENT_LIST_DIR}/../src/main/jniLibs/${ANDROID_ABI}/libc++_shared.so"
    COPYONLY
)
