cmake_minimum_required(VERSION 3.10)
project(rm_video_decoder)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ------------------- rm_common (shared headers) -------------------

add_subdirectory(../rm_common rm_common_build)

# 寻找 OpenCV
find_package(OpenCV REQUIRED)

# 寻找 FFmpeg
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET libavcodec libavutil libswscale)

# ------------------- video_core -------------------

add_library(video_core STATIC
    src/video_core.cpp
)

target_include_directories(video_core
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
    ${OpenCV_INCLUDE_DIRS}
    ${FFMPEG_INCLUDE_DIRS}
)
target_link_libraries(video_core
    PUBLIC
    rm_common
    ${OpenCV_LIBS}
    PkgConfig::FFMPEG
)
install(TARGETS video_core
    ARCHIVE DESTINATION lib
)


# ------------------- test_video_show -------------------

add_executable(test_video_show src/test/test_video_show.cpp)

target_include_directories(test_video_show
    PRIVATE
    ${OpenCV_INCLUDE_DIRS}
    ${FFMPEG_INCLUDE_DIRS}
)
target_include_directories(test_video_show
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(test_video_show
    PRIVATE
    video_core
    rm_common
    ${OpenCV_LIBS}
    PkgConfig::FFMPEG
)

# ------------------- Godot GDExtension -------------------
# The Godot plugin is built with SCons. Keep CMake focused on non-Godot tests.
