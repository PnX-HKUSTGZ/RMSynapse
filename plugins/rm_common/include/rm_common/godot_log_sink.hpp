#pragma once

#include <rm_common/logger.hpp>

// This header is meant to be included only in builds that have godot-cpp headers available.
#include <cstdint>
#include <deque>
#include <mutex>
#include <string>
#include <vector>

// Optional adapter: include this header only in your Godot (godot-cpp) build.
// It installs a global sink that forwards rm::common::log to Godot's UtilityFunctions.
//
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace rm::common::log::godot {

namespace detail {
struct QueuedLogLine {
    Level level = Level::Info;
    std::string line;
};

inline const char* level_name(Level level) noexcept {
    switch (level) {
        case Level::Debug: return "DEBUG";
        case Level::Info: return "INFO";
        case Level::Warn: return "WARN";
        case Level::Error: return "ERROR";
    }
    return "UNKNOWN";
}

inline std::mutex& queue_mutex() noexcept {
    static std::mutex mutex;
    return mutex;
}

inline std::deque<QueuedLogLine>& queue() noexcept {
    static std::deque<QueuedLogLine> lines;
    return lines;
}
} // namespace detail

inline void sink(void*, Level level, std::string_view tag, std::string_view message) noexcept {
    try {
        std::string line = "[";
        line += detail::level_name(level);
        line += "] ";
        line.append(tag.data(), tag.size());
        line += ": ";
        line.append(message.data(), message.size());

        std::lock_guard<std::mutex> lock(detail::queue_mutex());
        auto& lines = detail::queue();
        if (lines.size() >= 512) {
            lines.pop_front();
        }
        lines.push_back({level, std::move(line)});
    } catch (...) {
        // Logging must never throw.
    }
}

inline void flush_pending() noexcept {
    std::vector<detail::QueuedLogLine> lines;
    {
        std::lock_guard<std::mutex> lock(detail::queue_mutex());
        auto& queued = detail::queue();
        lines.assign(queued.begin(), queued.end());
        queued.clear();
    }

    for (const auto& item : lines) {
        const ::godot::String line = ::godot::String::utf8(item.line.c_str(), static_cast<int64_t>(item.line.size()));

        switch (item.level) {
            case Level::Debug:
            case Level::Info:
            case Level::Warn:
                ::godot::UtilityFunctions::print(line);
                break;
            case Level::Error:
                ::godot::UtilityFunctions::printerr(line);
                break;
        }
    }
}

inline void install_global_sink() noexcept {
    rm::common::log::set_sink(&sink, nullptr);
}

} // namespace rm::common::log::godot
