cmake_minimum_required(VERSION 3.10)
project(rm_video_decoder)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ------------------- rm_common (shared headers) -------------------

add_subdirectory(../rm_common rm_common_build)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../godot-cpp ${CMAKE_BINARY_DIR}/godot-cpp-build)

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

add_library(rm_video_decoder_gd SHARED
    godot/register_types.cpp
    godot/rm_video_canvas.cpp
)

target_include_directories(rm_video_decoder_gd
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${OpenCV_INCLUDE_DIRS}
    ${FFMPEG_INCLUDE_DIRS}
    ${PROJECT_SOURCE_DIR}/../godot-cpp/include
    ${PROJECT_SOURCE_DIR}/../godot-cpp/gen/include
)

target_link_libraries(rm_video_decoder_gd
    PRIVATE
    video_core
    rm_common
    PkgConfig::FFMPEG
    godot-cpp
)

set_target_properties(rm_video_decoder_gd PROPERTIES
    OUTPUT_NAME "rm_video_decoder"
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../../rm_synapse/bin
)

add_custom_command(TARGET rm_video_decoder_gd POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${CMAKE_CURRENT_SOURCE_DIR}/godot/rm_video_decoder.gdextension
            ${CMAKE_CURRENT_SOURCE_DIR}/../../rm_synapse/bin/rm_video_decoder.gdextension
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${CMAKE_CURRENT_SOURCE_DIR}/godot/shaders/video_yuv.gdshader
            ${CMAKE_CURRENT_SOURCE_DIR}/../../rm_synapse/bin/video_yuv.gdshader
)

install(FILES godot/rm_video_decoder.gdextension
        DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/../../rm_synapse/bin)
