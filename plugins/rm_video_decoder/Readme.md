# rm_video_decoder

RoboMaster UDP video receiver and Godot GDExtension.

## Dependencies

- Godot 4.5 compatible `godot-cpp` submodule.
- SCons for the Godot extension build.
- FFmpeg development files: `libavcodec`, `libavutil`, `libswscale`.
- OpenCV is optional and only needed for `with_test=yes`.

## Build GDExtension

Ubuntu:

```bash
sudo apt install build-essential scons pkg-config libavcodec-dev libavutil-dev libswscale-dev
cd plugins/rm_video_decoder
scons platform=linux target=template_release arch=x86_64
```

macOS:

```bash
brew install scons pkg-config ffmpeg
cd plugins/rm_video_decoder
scons platform=macos target=template_release arch=arm64
```

Windows MSVC with vcpkg:

```powershell
cd plugins\rm_video_decoder
scons platform=windows target=template_release arch=x86_64 ffmpeg_root=$env:VCPKG_ROOT\installed\x64-windows
```

Windows MinGW with vcpkg:

```powershell
cd plugins\rm_video_decoder
scons platform=windows target=template_release arch=x86_64 use_mingw=yes ffmpeg_root=$env:VCPKG_ROOT\installed\x64-mingw-dynamic
```

Outputs are copied to `rm_synapse/bin`:

- Linux: `librm_video_decoder.so`
- Windows: `rm_video_decoder.dll`
- macOS: `librm_video_decoder.dylib`
- `rm_video_decoder.gdextension`
- `video_yuv.gdshader`

## SCons Options

- `ffmpeg_root=<path>`: FFmpeg install root, such as a vcpkg triplet directory.
- `ffmpeg_include=<path>`: directory containing `libavcodec/avcodec.h`.
- `ffmpeg_libpath=<path>`: library search path. Multiple paths use the host path separator.
- `ffmpeg_runtime_dir=<path>`: directory containing FFmpeg runtime libraries to copy into `rm_synapse/bin`.
- `use_pkg_config=auto|yes|no`: default is `auto`; Linux/macOS prefer pkg-config, Windows prefers manual/vcpkg paths.
- `copy_ffmpeg_runtime=auto|yes|no`: default is `auto`; copies from `ffmpeg_runtime_dir` or `ffmpeg_root/bin` when present.
- `with_test=yes`: also builds the OpenCV preview program.
- `opencv_root=<path>`: optional OpenCV root for `with_test=yes` when `opencv4.pc` is unavailable.

On macOS, copied FFmpeg `.dylib` files are loaded relative to the plugin with `@loader_path`.

## CMake Core/Test Build

CMake builds `video_core` by default and does not require OpenCV unless tests are enabled:

```bash
cmake -S plugins/rm_video_decoder -B build/rm_video_decoder -DRM_VIDEO_DECODER_BUILD_TESTS=OFF
cmake --build build/rm_video_decoder
```

Optional preview test:

```bash
cmake -S plugins/rm_video_decoder -B build/rm_video_decoder-test -DRM_VIDEO_DECODER_BUILD_TESTS=ON -DOpenCV_DIR=<opencv-config-dir>
cmake --build build/rm_video_decoder-test
```

Set `FFMPEG_ROOT` or pass `-DFFMPEG_ROOT=<path>` if FFmpeg is not discoverable through pkg-config or the active vcpkg toolchain.
