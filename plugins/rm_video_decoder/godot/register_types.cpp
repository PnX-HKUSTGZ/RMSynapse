#include "register_types.h"
#include "rm_video_canvas.hpp"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <rm_common/godot_log_sink.hpp>

using namespace godot;

void initialize_rm_video_decoder_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    // Route rm_common logger output into Godot's console immediately at load time.
    rm::common::log::godot::install_global_sink();
    GDREGISTER_RUNTIME_CLASS(rm_video_gd::RMVideoCanvas);
}

void uninitialize_rm_video_decoder_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT rm_video_decoder_gdextension_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization* r_initialization) {
    GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
    init_obj.register_initializer(initialize_rm_video_decoder_module);
    init_obj.register_terminator(uninitialize_rm_video_decoder_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_obj.init();
}
}
