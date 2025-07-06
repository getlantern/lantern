# XXX <14-10-21, soltzen> We're using gomobile, but we need to ensure
# libc++_shared.so is included in the binary
cmake_minimum_required(VERSION 3.10.2)
set(CMAKE_VERBOSE_MAKEFILE ON)
include(ndk-stl-config.cmake)