#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <chrono>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>
#include <thread>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::filesystem::path GetConfigPath() {
  wchar_t app_data[MAX_PATH] = {};
  const DWORD length =
      GetEnvironmentVariableW(L"APPDATA", app_data, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return {};
  return std::filesystem::path(app_data) / L"WifiWarning" / L"config.json";
}

std::string ReadConfig() {
  const std::filesystem::path path = GetConfigPath();
  if (path.empty() || !std::filesystem::exists(path)) return {};
  std::ifstream input(path, std::ios::binary);
  std::ostringstream stream;
  stream << input.rdbuf();
  return stream.str();
}

bool WriteConfig(const std::string& json) {
  const std::filesystem::path path = GetConfigPath();
  if (path.empty()) return false;
  std::error_code error;
  std::filesystem::create_directories(path.parent_path(), error);
  if (error) return false;
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output) return false;
  output.write(json.data(), static_cast<std::streamsize>(json.size()));
  return output.good();
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return {};
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0);
  if (size <= 0) return {};
  std::wstring output(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), output.data(), size);
  return output;
}

std::string StringValue(const flutter::EncodableValue* value) {
  if (value == nullptr) return {};
  if (const auto* text = std::get_if<std::string>(value)) return *text;
  return {};
}

std::vector<std::string> StringListValue(
    const flutter::EncodableValue* arguments,
    const char* key) {
  std::vector<std::string> values;
  const auto* map = arguments == nullptr
                        ? nullptr
                        : std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) return values;
  const auto iterator = map->find(flutter::EncodableValue(key));
  if (iterator == map->end()) return values;
  const auto* list = std::get_if<flutter::EncodableList>(&iterator->second);
  if (list == nullptr) return values;
  for (const auto& item : *list) {
    if (const auto* text = std::get_if<std::string>(&item)) {
      values.push_back(*text);
    }
  }
  return values;
}

flutter::EncodableValue StringList(const std::vector<std::string>& values) {
  flutter::EncodableList list;
  for (const auto& value : values) list.emplace_back(value);
  return flutter::EncodableValue(std::move(list));
}

void SetStartAtLogin(bool enabled) {
  constexpr wchar_t kRunKey[] =
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
  constexpr wchar_t kValueName[] = L"WifiWarning";
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) !=
      ERROR_SUCCESS) {
    return;
  }
  if (enabled) {
    wchar_t executable[MAX_PATH] = {};
    const DWORD length =
        GetModuleFileNameW(nullptr, executable, MAX_PATH);
    if (length > 0 && length < MAX_PATH) {
      const std::wstring command = L"\"" + std::wstring(executable) + L"\"";
      RegSetValueExW(
          key, kValueName, 0, REG_SZ,
          reinterpret_cast<const BYTE*>(command.c_str()),
          static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    }
  } else {
    RegDeleteValueW(key, kValueName);
  }
  RegCloseKey(key);
}

void ShowNativeAlert(const std::string& title, const std::string& message) {
  const std::wstring wide_title = Utf8ToWide(title);
  const std::wstring wide_message = Utf8ToWide(message);
  std::thread([wide_title, wide_message]() {
    MessageBoxW(nullptr, wide_message.c_str(), wide_title.c_str(),
                MB_OK | MB_ICONWARNING | MB_SETFOREGROUND | MB_TOPMOST |
                    MB_SYSTEMMODAL);
  }).detach();
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) return false;
  RECT frame = GetClientArea();
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterChannels();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  monitor_channel_.reset();
  if (flutter_controller_) flutter_controller_ = nullptr;
  Win32Window::OnDestroy();
}

void FlutterWindow::RegisterChannels() {
  monitor_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "wifi_warning/monitor",
          &flutter::StandardMethodCodec::GetInstance());
  monitor_channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<flutter::EncodableValue>& method_call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) { HandleMethodCall(method_call, std::move(result)); });
}

void FlutterWindow::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  const flutter::EncodableValue* arguments = method_call.arguments();
  const auto* argument_map =
      arguments == nullptr ? nullptr
                           : std::get_if<flutter::EncodableMap>(arguments);

  if (method == "loadConfig") {
    const std::string config = ReadConfig();
    if (config.empty()) {
      result->Success();
    } else {
      result->Success(flutter::EncodableValue(config));
    }
    return;
  }
  if (method == "saveConfig") {
    std::string json;
    if (argument_map != nullptr) {
      const auto iterator =
          argument_map->find(flutter::EncodableValue("json"));
      if (iterator != argument_map->end()) {
        json = StringValue(&iterator->second);
      }
    }
    result->Success(flutter::EncodableValue(WriteConfig(json)));
    return;
  }
  if (method == "getSnapshot") {
    const auto snapshot = native_monitor_.Detect(
        StringListValue(arguments, "processPatterns"));
    const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                         std::chrono::system_clock::now().time_since_epoch())
                         .count();
    flutter::EncodableMap map;
    map[flutter::EncodableValue("timestamp")] =
        flutter::EncodableValue(static_cast<int64_t>(now));
    map[flutter::EncodableValue("wifiSsid")] =
        snapshot.wifi_ssid.empty() ? flutter::EncodableValue()
                                   : flutter::EncodableValue(
                                         snapshot.wifi_ssid);
    map[flutter::EncodableValue("wifiAvailable")] =
        flutter::EncodableValue(snapshot.wifi_available);
    map[flutter::EncodableValue("wifiError")] =
        snapshot.wifi_error.empty() ? flutter::EncodableValue()
                                    : flutter::EncodableValue(
                                          snapshot.wifi_error);
    map[flutter::EncodableValue("vpnActive")] =
        flutter::EncodableValue(snapshot.vpn_active);
    map[flutter::EncodableValue("vpnSources")] =
        StringList(snapshot.vpn_sources);
    map[flutter::EncodableValue("proxyActive")] =
        flutter::EncodableValue(snapshot.proxy_active);
    map[flutter::EncodableValue("proxySources")] =
        StringList(snapshot.proxy_sources);
    map[flutter::EncodableValue("backgroundMonitoring")] =
        flutter::EncodableValue(false);
    if (!snapshot.error.empty()) {
      map[flutter::EncodableValue("error")] =
          flutter::EncodableValue(snapshot.error);
    }
    result->Success(flutter::EncodableValue(std::move(map)));
    return;
  }
  if (method == "setMonitoringEnabled") {
    result->Success();
    return;
  }
  if (method == "setStartAtLogin") {
    bool enabled = false;
    if (argument_map != nullptr) {
      const auto iterator =
          argument_map->find(flutter::EncodableValue("enabled"));
      if (iterator != argument_map->end()) {
        if (const auto* value = std::get_if<bool>(&iterator->second)) {
          enabled = *value;
        }
      }
    }
    SetStartAtLogin(enabled);
    result->Success();
    return;
  }
  if (method == "requestPermissions") {
    flutter::EncodableMap permissions;
    permissions[flutter::EncodableValue("locationGranted")] =
        flutter::EncodableValue(true);
    permissions[flutter::EncodableValue("notificationGranted")] =
        flutter::EncodableValue(true);
    permissions[flutter::EncodableValue("overlayGranted")] =
        flutter::EncodableValue(true);
    result->Success(flutter::EncodableValue(std::move(permissions)));
    return;
  }
  if (method == "openOverlaySettings") {
    result->Success();
    return;
  }
  if (method == "showAlert") {
    std::string title = "网络安全警告";
    std::string message;
    if (argument_map != nullptr) {
      const auto title_iterator =
          argument_map->find(flutter::EncodableValue("title"));
      if (title_iterator != argument_map->end()) {
        title = StringValue(&title_iterator->second);
      }
      const auto message_iterator =
          argument_map->find(flutter::EncodableValue("message"));
      if (message_iterator != argument_map->end()) {
        message = StringValue(&message_iterator->second);
      }
    }
    ShowNativeAlert(title, message);
    result->Success();
    return;
  }
  result->NotImplemented();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) return *result;
  }
  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }
  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
