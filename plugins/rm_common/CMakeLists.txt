add_library(rm_common INTERFACE)
target_compile_features(rm_common INTERFACE cxx_std_17)
target_include_directories(rm_common INTERFACE ${CMAKE_CURRENT_LIST_DIR}/include)

