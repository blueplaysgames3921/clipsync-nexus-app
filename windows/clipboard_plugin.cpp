// windows/runner/clipboard_plugin.cpp
// Provides rich clipboard access (HTML, images, file paths) and
// active window detection via Win32 API.

#include "clipboard_plugin.h"

#include <windows.h>
#include <psapi.h>
#include <shlobj.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>
#include <codecvt>

namespace clipsync {

// ── UTF-8 CONVERSION ──────────────────────────────────────────────────────

static std::string WstrToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return {};
    int size = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.size(),
                                   nullptr, 0, nullptr, nullptr);
    std::string result(size, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.size(),
                        result.data(), size, nullptr, nullptr);
    return result;
}

static std::wstring Utf8ToWstr(const std::string& str) {
    if (str.empty()) return {};
    int size = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.size(), nullptr, 0);
    std::wstring result(size, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), (int)str.size(), result.data(), size);
    return result;
}

// ── CLIPBOARD READER ──────────────────────────────────────────────────────

static std::string GetClipboardText() {
    if (!OpenClipboard(nullptr)) return {};
    std::string result;
    HANDLE hData = GetClipboardData(CF_UNICODETEXT);
    if (hData) {
        LPCWSTR pszText = static_cast<LPCWSTR>(GlobalLock(hData));
        if (pszText) {
            result = WstrToUtf8(std::wstring(pszText));
            GlobalUnlock(hData);
        }
    }
    CloseClipboard();
    return result;
}

static std::string GetClipboardHtml() {
    UINT htmlFormat = RegisterClipboardFormat(L"HTML Format");
    if (!OpenClipboard(nullptr)) return {};
    std::string result;
    HANDLE hData = GetClipboardData(htmlFormat);
    if (hData) {
        char* pData = static_cast<char*>(GlobalLock(hData));
        if (pData) {
            // HTML Format has a header — find the StartHTML / EndHTML markers
            std::string raw(pData, GlobalSize(hData));
            size_t start = raw.find("<!--StartFragment-->");
            size_t end   = raw.find("<!--EndFragment-->");
            if (start != std::string::npos && end != std::string::npos) {
                start += strlen("<!--StartFragment-->");
                result = raw.substr(start, end - start);
            } else {
                result = raw;
            }
            GlobalUnlock(hData);
        }
    }
    CloseClipboard();
    return result;
}

static std::vector<uint8_t> GetClipboardImage() {
    if (!OpenClipboard(nullptr)) return {};
    std::vector<uint8_t> result;

    // Try PNG first
    UINT pngFormat = RegisterClipboardFormat(L"PNG");
    HANDLE hPng = GetClipboardData(pngFormat);
    if (hPng) {
        size_t size = GlobalSize(hPng);
        uint8_t* data = static_cast<uint8_t*>(GlobalLock(hPng));
        if (data) {
            result.assign(data, data + size);
            GlobalUnlock(hPng);
        }
        CloseClipboard();
        return result;
    }

    // Fall back to DIB bitmap → convert to BMP bytes
    HANDLE hBitmap = GetClipboardData(CF_DIB);
    if (hBitmap) {
        size_t size = GlobalSize(hBitmap);
        uint8_t* data = static_cast<uint8_t*>(GlobalLock(hBitmap));
        if (data) {
            // Package as BMP with file header
            BITMAPINFOHEADER* bih = reinterpret_cast<BITMAPINFOHEADER*>(data);
            BITMAPFILEHEADER bfh = {};
            bfh.bfType = 0x4D42; // 'BM'
            bfh.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
            bfh.bfSize = (DWORD)(sizeof(BITMAPFILEHEADER) + size);
            result.resize(sizeof(BITMAPFILEHEADER) + size);
            memcpy(result.data(), &bfh, sizeof(BITMAPFILEHEADER));
            memcpy(result.data() + sizeof(BITMAPFILEHEADER), data, size);
            GlobalUnlock(hBitmap);
        }
    }
    CloseClipboard();
    return result;
}

static std::vector<std::string> GetClipboardFilePaths() {
    if (!OpenClipboard(nullptr)) return {};
    std::vector<std::string> paths;
    HANDLE hDrop = GetClipboardData(CF_HDROP);
    if (hDrop) {
        HDROP drop = static_cast<HDROP>(GlobalLock(hDrop));
        if (drop) {
            UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
            for (UINT i = 0; i < count; i++) {
                UINT len = DragQueryFileW(drop, i, nullptr, 0) + 1;
                std::wstring path(len, L'\0');
                DragQueryFileW(drop, i, path.data(), len);
                path.pop_back(); // remove null terminator
                paths.push_back(WstrToUtf8(path));
            }
            GlobalUnlock(hDrop);
        }
    }
    CloseClipboard();
    return paths;
}

// ── WRITE CLIPBOARD ────────────────────────────────────────────────────────

static void WriteClipboardText(const std::string& text) {
    std::wstring wtext = Utf8ToWstr(text);
    size_t bytes = (wtext.size() + 1) * sizeof(wchar_t);
    HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (!hMem) return;
    wchar_t* pMem = static_cast<wchar_t*>(GlobalLock(hMem));
    if (pMem) {
        memcpy(pMem, wtext.c_str(), bytes);
        GlobalUnlock(hMem);
    }
    if (OpenClipboard(nullptr)) {
        EmptyClipboard();
        SetClipboardData(CF_UNICODETEXT, hMem);
        CloseClipboard();
    }
}

// ── ACTIVE WINDOW ─────────────────────────────────────────────────────────

static std::string GetActiveWindowApp() {
    HWND hwnd = GetForegroundWindow();
    if (!hwnd) return "Unknown";
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProc) return "Unknown";
    wchar_t path[MAX_PATH] = {};
    DWORD size = MAX_PATH;
    QueryFullProcessImageNameW(hProc, 0, path, &size);
    CloseHandle(hProc);
    std::wstring fullPath(path);
    size_t slash = fullPath.rfind(L'\\');
    if (slash != std::wstring::npos) fullPath = fullPath.substr(slash + 1);
    // Strip .exe
    if (fullPath.size() > 4 && fullPath.substr(fullPath.size() - 4) == L".exe") {
        fullPath = fullPath.substr(0, fullPath.size() - 4);
    }
    return WstrToUtf8(fullPath);
}

// ── CLIPBOARD CHANGE WATCHER ──────────────────────────────────────────────

static HWND g_watcherHwnd = nullptr;
static flutter::MethodChannel<flutter::EncodableValue>* g_channel = nullptr;
static std::string g_lastText;

static LRESULT CALLBACK WatcherWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == WM_CLIPBOARDUPDATE) {
        std::string text = GetClipboardText();
        if (text != g_lastText && g_channel) {
            g_lastText = text;
            auto data = flutter::EncodableMap{
                {flutter::EncodableValue("text"),      flutter::EncodableValue(text)},
                {flutter::EncodableValue("html"),      flutter::EncodableValue(GetClipboardHtml())},
                {flutter::EncodableValue("sourceApp"), flutter::EncodableValue(GetActiveWindowApp())},
            };
            g_channel->InvokeMethod("onClipboardChange",
                std::make_unique<flutter::EncodableValue>(data));
        }
        return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

static void StartWatcher() {
    if (g_watcherHwnd) return;
    WNDCLASS wc = {};
    wc.lpfnWndProc   = WatcherWndProc;
    wc.hInstance     = GetModuleHandle(nullptr);
    wc.lpszClassName = L"ClipSyncWatcher";
    RegisterClass(&wc);
    g_watcherHwnd = CreateWindowEx(0, L"ClipSyncWatcher", L"", 0,
        0, 0, 0, 0, HWND_MESSAGE, nullptr, GetModuleHandle(nullptr), nullptr);
    AddClipboardFormatListener(g_watcherHwnd);
}

// ── PLUGIN ────────────────────────────────────────────────────────────────

void ClipboardPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
        registrar->messenger(),
        "com.clipsync.nexus/clipboard",
        &flutter::StandardMethodCodec::GetInstance()
    );
    g_channel = channel.get();

    auto plugin = std::make_unique<ClipboardPlugin>();
    channel->SetMethodCallHandler(
        [plugin_ptr = plugin.get()](const auto& call, auto result) {
            plugin_ptr->HandleMethodCall(call, std::move(result));
        });
    registrar->AddPlugin(std::move(plugin));
}

void ClipboardPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

    const auto& method = call.method_name();

    if (method == "startMonitoring") {
        StartWatcher();
        result->Success();

    } else if (method == "stopMonitoring") {
        if (g_watcherHwnd) {
            RemoveClipboardFormatListener(g_watcherHwnd);
            DestroyWindow(g_watcherHwnd);
            g_watcherHwnd = nullptr;
        }
        result->Success();

    } else if (method == "getRichText") {
        result->Success(flutter::EncodableValue(GetClipboardHtml()));

    } else if (method == "getImage") {
        auto bytes = GetClipboardImage();
        result->Success(flutter::EncodableValue(
            std::vector<uint8_t>(bytes.begin(), bytes.end())));

    } else if (method == "getFilePaths") {
        auto paths = GetClipboardFilePaths();
        flutter::EncodableList list;
        for (const auto& p : paths) {
            list.push_back(flutter::EncodableValue(p));
        }
        result->Success(flutter::EncodableValue(list));

    } else if (method == "writeText") {
        const auto* text = std::get_if<std::string>(call.arguments());
        if (text) {
            WriteClipboardText(*text);
            result->Success();
        } else {
            result->Error("INVALID_ARGS", "Expected string argument");
        }

    } else if (method == "getActiveWindow") {
        result->Success(flutter::EncodableValue(GetActiveWindowApp()));

    } else {
        result->NotImplemented();
    }
}

} // namespace clipsync
