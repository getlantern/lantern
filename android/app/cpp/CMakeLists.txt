# gomobile's native dependencies need the matching hardened C++ runtime.
cmake_minimum_required(VERSION 3.10.2)
project(lantern_android_runtime LANGUAGES C CXX)
include(ndk-stl-config.cmake)
