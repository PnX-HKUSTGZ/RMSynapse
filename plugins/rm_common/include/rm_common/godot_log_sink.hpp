#pragma once

#include <rm_common/logger.hpp>

// This header is meant to be included only in builds that have godot-cpp headers available.
#include <cstdint>

// Optional adapter: include this header only in your Godot (godot-cpp) build.
// It installs a global sink that forwards rm::common::log to Godot's UtilityFunctions.
//
// Note: If your Godot logging APIs must run on the main thread, wrap the sink with
// a thread-safe queue and flush it from _process().

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace rm::common::log::godot {

inline void sink(void*, Level level, std::string_view tag, std::string_view message) noexcept {
    // Note: this namespace is named `godot`, so use `::godot::` to refer to godot-cpp types.
    ::godot::String line = ::godot::String::utf8(tag.data(), static_cast<int64_t>(tag.size()));
    line += ": ";
    line += ::godot::String::utf8(message.data(), static_cast<int64_t>(message.size()));

    switch (level) {
        case Level::Debug:
        case Level::Info:
            ::godot::UtilityFunctions::print(line);
            return;
        case Level::Warn:
            ::godot::UtilityFunctions::push_warning(line);
            return;
        case Level::Error:
            ::godot::UtilityFunctions::push_error(line);
            return;
    }
}

inline void install_global_sink() noexcept {
    rm::common::log::set_sink(&sink, nullptr);
}

} // namespace rm::common::log::godot
