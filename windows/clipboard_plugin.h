// windows/runner/clipboard_plugin.h
#ifndef CLIPBOARD_PLUGIN_H_
#define CLIPBOARD_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>

namespace clipsync {

class ClipboardPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  ClipboardPlugin() = default;
  virtual ~ClipboardPlugin() = default;

  // Disallow copy and assign
  ClipboardPlugin(const ClipboardPlugin&) = delete;
  ClipboardPlugin& operator=(const ClipboardPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace clipsync

#endif  // CLIPBOARD_PLUGIN_H_
