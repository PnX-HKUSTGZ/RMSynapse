cmake_minimum_required(VERSION 3.16)
project(rm_video_decoder LANGUAGES CXX)

option(RM_VIDEO_DECODER_BUILD_TESTS "Build the OpenCV preview test program" OFF)
set(FFMPEG_ROOT "" CACHE PATH "FFmpeg installation root, such as a vcpkg triplet directory")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_subdirectory(../rm_common rm_common_build)

function(rm_find_ffmpeg)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(FFMPEG QUIET IMPORTED_TARGET libavcodec libavutil libswscale)
    endif()

    if(TARGET PkgConfig::FFMPEG)
        add_library(rm_ffmpeg INTERFACE)
        target_link_libraries(rm_ffmpeg INTERFACE PkgConfig::FFMPEG)
        return()
    endif()

    if(DEFINED ENV{VCPKG_DEFAULT_TRIPLET})
        set(_vcpkg_triplet "$ENV{VCPKG_DEFAULT_TRIPLET}")
    elseif(WIN32)
        if(MINGW)
            set(_vcpkg_triplet "x64-mingw-dynamic")
        else()
            set(_vcpkg_triplet "x64-windows")
        endif()
    elseif(APPLE)
        if(CMAKE_OSX_ARCHITECTURES MATCHES "(^|;)arm64($|;)" OR CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
            set(_vcpkg_triplet "arm64-osx")
        else()
            set(_vcpkg_triplet "x64-osx")
        endif()
    else()
        set(_vcpkg_triplet "x64-linux")
    endif()

    set(_ffmpeg_roots "")
    foreach(_root IN ITEMS "${FFMPEG_ROOT}" "$ENV{FFMPEG_ROOT}" "$ENV{VCPKG_INSTALLED_DIR}")
        if(_root)
            list(APPEND _ffmpeg_roots "${_root}")
            if(EXISTS "${_root}/${_vcpkg_triplet}")
                list(APPEND _ffmpeg_roots "${_root}/${_vcpkg_triplet}")
            endif()
            if(EXISTS "${_root}/installed/${_vcpkg_triplet}")
                list(APPEND _ffmpeg_roots "${_root}/installed/${_vcpkg_triplet}")
            endif()
        endif()
    endforeach()

    if(DEFINED ENV{VCPKG_ROOT})
        list(APPEND _ffmpeg_roots "$ENV{VCPKG_ROOT}/installed/${_vcpkg_triplet}")
    endif()

    set(_saved_find_library_suffixes "${CMAKE_FIND_LIBRARY_SUFFIXES}")
    if(WIN32)
        if(MINGW)
            set(CMAKE_FIND_LIBRARY_SUFFIXES ".dll.a" ".a" ".lib")
        else()
            set(CMAKE_FIND_LIBRARY_SUFFIXES ".lib" ".dll.a" ".a")
        endif()
    elseif(APPLE)
        set(CMAKE_FIND_LIBRARY_SUFFIXES ".dylib" ".a")
    else()
        set(CMAKE_FIND_LIBRARY_SUFFIXES ".so" ".a")
    endif()

    find_path(FFMPEG_INCLUDE_DIR
        NAMES libavcodec/avcodec.h
        HINTS ${_ffmpeg_roots}
        PATH_SUFFIXES include
    )
    find_library(FFMPEG_AVCODEC_LIBRARY
        NAMES avcodec libavcodec
        HINTS ${_ffmpeg_roots}
        PATH_SUFFIXES lib lib64 bin
    )
    find_library(FFMPEG_AVUTIL_LIBRARY
        NAMES avutil libavutil
        HINTS ${_ffmpeg_roots}
        PATH_SUFFIXES lib lib64 bin
    )
    find_library(FFMPEG_SWSCALE_LIBRARY
        NAMES swscale libswscale
        HINTS ${_ffmpeg_roots}
        PATH_SUFFIXES lib lib64 bin
    )
    set(CMAKE_FIND_LIBRARY_SUFFIXES "${_saved_find_library_suffixes}")

    include(FindPackageHandleStandardArgs)
    find_package_handle_standard_args(FFMPEG
        REQUIRED_VARS
            FFMPEG_INCLUDE_DIR
            FFMPEG_AVCODEC_LIBRARY
            FFMPEG_AVUTIL_LIBRARY
            FFMPEG_SWSCALE_LIBRARY
    )
    if(NOT FFMPEG_FOUND)
        message(FATAL_ERROR "FFmpeg development files were not found. Install libavcodec/libavutil/libswscale dev packages, use pkg-config, or pass -DFFMPEG_ROOT=<path>.")
    endif()

    add_library(rm_ffmpeg INTERFACE)
    target_include_directories(rm_ffmpeg INTERFACE "${FFMPEG_INCLUDE_DIR}")
    target_link_libraries(rm_ffmpeg INTERFACE
        "${FFMPEG_AVCODEC_LIBRARY}"
        "${FFMPEG_AVUTIL_LIBRARY}"
        "${FFMPEG_SWSCALE_LIBRARY}"
    )
endfunction()

rm_find_ffmpeg()

add_library(video_core STATIC
    src/video_core.cpp
)

target_include_directories(video_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)
target_link_libraries(video_core
    PUBLIC
        rm_common
        rm_ffmpeg
)

if(WIN32)
    target_link_libraries(video_core PUBLIC ws2_32)
endif()

install(TARGETS video_core
    ARCHIVE DESTINATION lib
)

if(RM_VIDEO_DECODER_BUILD_TESTS)
    find_package(OpenCV REQUIRED)

    add_executable(test_video_show src/test/test_video_show.cpp)
    target_link_libraries(test_video_show
        PRIVATE
            video_core
            rm_common
            rm_ffmpeg
            ${OpenCV_LIBS}
    )
    target_include_directories(test_video_show
        PRIVATE
            ${OpenCV_INCLUDE_DIRS}
    )
    if(APPLE)
        set_target_properties(test_video_show PROPERTIES
            BUILD_RPATH "@loader_path"
            INSTALL_RPATH "@loader_path"
        )
    endif()
endif()
