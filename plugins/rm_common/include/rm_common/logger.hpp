#pragma once

#include <atomic>
#include <cstdarg>
#include <cstdio>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>

namespace rm::common::log {

enum class Level : uint8_t {
    Debug = 0,
    Info = 1,
    Warn = 2,
    Error = 3,
};

using SinkFn = void (*)(void* ctx, Level level, std::string_view tag, std::string_view message) noexcept;

namespace detail {
inline constexpr std::string_view levelToString(Level level) noexcept {
    switch (level) {
        case Level::Debug: return "DEBUG";
        case Level::Info: return "INFO";
        case Level::Warn: return "WARN";
        case Level::Error: return "ERROR";
    }
    return "UNKNOWN";
}

inline void defaultSink(void*, Level level, std::string_view tag, std::string_view message) noexcept {
    // Keep this dependency-free and safe to call from any thread.
    // Format: [LEVEL][tag] message
    std::fprintf(stderr, "[%.*s][%.*s] %.*s\n",
                 static_cast<int>(levelToString(level).size()),
                 levelToString(level).data(),
                 static_cast<int>(tag.size()),
                 tag.data(),
                 static_cast<int>(message.size()),
                 message.data());
}

struct SinkState {
    std::atomic<SinkFn> fn{&defaultSink};
    std::atomic<void*> ctx{nullptr};
};

inline SinkState& sinkState() noexcept {
    static SinkState state{};
    return state;
}
} // namespace detail

inline void set_sink(SinkFn fn, void* ctx = nullptr) noexcept {
    if (!fn) fn = &detail::defaultSink;
    detail::sinkState().ctx.store(ctx, std::memory_order_release);
    detail::sinkState().fn.store(fn, std::memory_order_release);
}

inline SinkFn get_sink(void** out_ctx = nullptr) noexcept {
    if (out_ctx) *out_ctx = detail::sinkState().ctx.load(std::memory_order_acquire);
    return detail::sinkState().fn.load(std::memory_order_acquire);
}

inline void write(Level level, std::string_view tag, std::string_view message) noexcept {
    auto* ctx = detail::sinkState().ctx.load(std::memory_order_acquire);
    auto fn = detail::sinkState().fn.load(std::memory_order_acquire);
    fn(ctx, level, tag, message);
}

inline void debug(std::string_view tag, std::string_view message) noexcept { write(Level::Debug, tag, message); }
inline void info(std::string_view tag, std::string_view message) noexcept { write(Level::Info, tag, message); }
inline void warn(std::string_view tag, std::string_view message) noexcept { write(Level::Warn, tag, message); }
inline void error(std::string_view tag, std::string_view message) noexcept { write(Level::Error, tag, message); }

inline void vprintf(Level level, std::string_view tag, const char* fmt, va_list args) noexcept {
    if (!fmt) return;
    thread_local char buf[2048];
    va_list args_copy;
    va_copy(args_copy, args);
    const int n = std::vsnprintf(buf, sizeof(buf), fmt, args_copy);
    va_end(args_copy);
    if (n <= 0) return;
    const size_t len = static_cast<size_t>(n) < (sizeof(buf) - 1) ? static_cast<size_t>(n) : (sizeof(buf) - 1);
    write(level, tag, std::string_view(buf, len));
}

inline void printf(Level level, std::string_view tag, const char* fmt, ...) noexcept {
    va_list args;
    va_start(args, fmt);
    vprintf(level, tag, fmt, args);
    va_end(args);
}

// Stream-style logging:
// Usage: RM_LOGI_STREAM("tag", "value=" << x);
// Note: The sink must consume the provided string_views synchronously; if it needs to
// store them, it should copy into owned memory.
class Stream {
public:
    Stream(Level level, std::string_view tag) : level_(level), tag_(tag) {}
    Stream(const Stream&) = delete;
    Stream& operator=(const Stream&) = delete;
    Stream(Stream&&) = default;
    Stream& operator=(Stream&&) = default;

    ~Stream() noexcept {
        try {
            const std::string msg = oss_.str();
            write(level_, tag_, msg);
        } catch (...) {
            // Best-effort logging; never throw from destructor.
        }
    }

    template <class T>
    Stream& operator<<(T&& value) {
        oss_ << std::forward<T>(value);
        return *this;
    }

    Stream& operator<<(std::ostream& (*manip)(std::ostream&)) {
        oss_ << manip;
        return *this;
    }

private:
    Level level_;
    std::string_view tag_;
    std::ostringstream oss_{};
};

inline Stream stream(Level level, std::string_view tag) { return Stream(level, tag); }

} // namespace rm::common::log

#ifndef RM_COMMON_LOG_DISABLE_MACROS
#define RM_LOGD(tag, ...) ::rm::common::log::printf(::rm::common::log::Level::Debug, (tag), __VA_ARGS__)
#define RM_LOGI(tag, ...) ::rm::common::log::printf(::rm::common::log::Level::Info, (tag), __VA_ARGS__)
#define RM_LOGW(tag, ...) ::rm::common::log::printf(::rm::common::log::Level::Warn, (tag), __VA_ARGS__)
#define RM_LOGE(tag, ...) ::rm::common::log::printf(::rm::common::log::Level::Error, (tag), __VA_ARGS__)

#define RM_LOGD_STREAM(tag, ...) \
    do { auto _rm_log_stream = ::rm::common::log::stream(::rm::common::log::Level::Debug, (tag)); _rm_log_stream << __VA_ARGS__; } while (0)
#define RM_LOGI_STREAM(tag, ...) \
    do { auto _rm_log_stream = ::rm::common::log::stream(::rm::common::log::Level::Info, (tag)); _rm_log_stream << __VA_ARGS__; } while (0)
#define RM_LOGW_STREAM(tag, ...) \
    do { auto _rm_log_stream = ::rm::common::log::stream(::rm::common::log::Level::Warn, (tag)); _rm_log_stream << __VA_ARGS__; } while (0)
#define RM_LOGE_STREAM(tag, ...) \
    do { auto _rm_log_stream = ::rm::common::log::stream(::rm::common::log::Level::Error, (tag)); _rm_log_stream << __VA_ARGS__; } while (0)
#endif
