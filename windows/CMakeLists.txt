cmake_minimum_required(VERSION 3.14)
project(clipsync_nexus LANGUAGES CXX)

# ── C++ standard ────────────────────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ── Flutter toolchain ────────────────────────────────────────────────────────
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
include(${FLUTTER_MANAGED_DIR}/generated_plugins.cmake)
include(${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.h OPTIONAL)

# ── App target ──────────────────────────────────────────────────────────────
add_executable(${BINARY_NAME} WIN32
  "runner/main.cpp"
  "runner/flutter_window.cpp"
  "runner/run_loop.cpp"
  "runner/utils.cpp"
  "runner/win32_window.cpp"
  "clipboard_plugin.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# ── Include dirs ────────────────────────────────────────────────────────────
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/runner"
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/include"
  "${FLUTTER_EPHEMERAL_DIR}"
)

# ── Link libraries ──────────────────────────────────────────────────────────
target_link_libraries(${BINARY_NAME} PRIVATE
  flutter
  flutter_wrapper_app
  # Win32 APIs used by clipboard_plugin
  psapi          # Process info (active window detection)
  shell32        # SHGetKnownFolderPath, DragQueryFile
  ole32          # CoInitialize, clipboard
  user32         # OpenClipboard, GetClipboardData, AddClipboardFormatListener
  gdi32          # Bitmap operations
)

# ── Compile options ─────────────────────────────────────────────────────────
target_compile_options(${BINARY_NAME} PRIVATE
  /W4
  /WX-          # Warnings not errors in release
  /utf-8        # Source files are UTF-8
  /D_UNICODE
  /DUNICODE
)

# ── App manifest (DPI awareness, Windows 10+ targeting) ────────────────────
set(APP_MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/runner/Runner.rc")
if(EXISTS "${APP_MANIFEST}")
  target_sources(${BINARY_NAME} PRIVATE "${APP_MANIFEST}")
endif()

# ── Install ─────────────────────────────────────────────────────────────────
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")
install(
  FILES "${FLUTTER_EPHEMERAL_DIR}/flutter_windows.dll"
  DESTINATION "${CMAKE_INSTALL_PREFIX}"
)

# ── Flutter asset bundling ──────────────────────────────────────────────────
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${PROJECT_BUILD_DIR}/flutter_assets"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>/data/flutter_assets"
)
