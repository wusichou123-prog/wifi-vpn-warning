#include "native_monitor.h"

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <winhttp.h>
#include <wlanapi.h>

#include <algorithm>
#include <cctype>
#include <memory>
#include <sstream>
#include <vector>

namespace wifi_warning {
namespace {

std::string ToLower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](unsigned char character) {
                   return static_cast<char>(std::tolower(character));
                 });
  return value;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) return {};
  std::string output(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), output.data(), size,
                      nullptr, nullptr);
  return output;
}

bool ContainsIgnoreCase(const std::string& text,
                        const std::string& pattern) {
  if (pattern.empty()) return false;
  return ToLower(text).find(ToLower(pattern)) != std::string::npos;
}

std::string GetWifiSsid(std::string* error) {
  DWORD negotiated_version = 0;
  HANDLE client = nullptr;
  const DWORD open_result = WlanOpenHandle(2, nullptr, &negotiated_version,
                                            &client);
  if (open_result != ERROR_SUCCESS) {
    if (error) *error = "WLAN service is unavailable";
    return {};
  }

  PWLAN_INTERFACE_INFO_LIST interfaces = nullptr;
  const DWORD enum_result =
      WlanEnumInterfaces(client, nullptr, &interfaces);
  if (enum_result != ERROR_SUCCESS || interfaces == nullptr) {
    WlanCloseHandle(client, nullptr);
    if (error) *error = "Unable to enumerate WLAN interfaces";
    return {};
  }

  std::string ssid;
  for (DWORD index = 0; index < interfaces->dwNumberOfItems; ++index) {
    const WLAN_INTERFACE_INFO& item = interfaces->InterfaceInfo[index];
    if (item.isState != wlan_interface_state_connected) continue;

    DWORD data_size = 0;
    PWLAN_CONNECTION_ATTRIBUTES attributes = nullptr;
    const DWORD query_result = WlanQueryInterface(
        client, &item.InterfaceGuid, wlan_intf_opcode_current_connection,
        nullptr, &data_size, reinterpret_cast<PVOID*>(&attributes), nullptr);
    if (query_result == ERROR_SUCCESS && attributes != nullptr) {
      const DOT11_SSID& raw_ssid =
          attributes->wlanAssociationAttributes.dot11Ssid;
      ssid.assign(reinterpret_cast<const char*>(raw_ssid.ucSSID),
                  raw_ssid.uSSIDLength);
      WlanFreeMemory(attributes);
      if (!ssid.empty()) break;
    }
  }

  WlanFreeMemory(interfaces);
  WlanCloseHandle(client, nullptr);
  return ssid;
}

bool HasUsableAddress(const IP_ADAPTER_ADDRESSES* adapter) {
  for (const IP_ADAPTER_UNICAST_ADDRESS* unicast =
           adapter->FirstUnicastAddress;
       unicast != nullptr; unicast = unicast->Next) {
    if (unicast->Address.lpSockaddr == nullptr) continue;
    const int family = unicast->Address.lpSockaddr->sa_family;
    if (family == AF_INET) {
      const auto* address = reinterpret_cast<const sockaddr_in*>(
          unicast->Address.lpSockaddr);
      const unsigned long host = ntohl(address->sin_addr.S_un.S_addr);
      const bool unspecified = host == 0;
      const bool loopback = (host & 0xff000000UL) == 0x7f000000UL;
      const bool link_local = (host & 0xffff0000UL) == 0xa9fe0000UL;
      if (!unspecified && !loopback && !link_local) return true;
    } else if (family == AF_INET6) {
      const auto* address = reinterpret_cast<const sockaddr_in6*>(
          unicast->Address.lpSockaddr);
      const unsigned char* bytes = address->sin6_addr.s6_addr;
      const bool unspecified = std::all_of(bytes, bytes + 16,
                                           [](unsigned char value) {
                                             return value == 0;
                                           });
      const bool loopback = std::all_of(bytes, bytes + 15,
                                        [](unsigned char value) {
                                          return value == 0;
                                        }) && bytes[15] == 1;
      const bool link_local = bytes[0] == 0xfe &&
                              (bytes[1] & 0xc0) == 0x80;
      if (!unspecified && !loopback && !link_local) return true;
    }
  }
  return false;
}

void DetectVpn(DetectionSnapshot* snapshot) {
  ULONG buffer_size = 0;
  GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr, nullptr,
                       &buffer_size);
  if (buffer_size == 0) return;

  std::vector<unsigned char> buffer(buffer_size);
  auto* addresses = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
  if (GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_PREFIX, nullptr,
                           addresses, &buffer_size) != NO_ERROR) {
    return;
  }

  for (auto* adapter = addresses; adapter != nullptr;
       adapter = adapter->Next) {
    if (adapter->OperStatus != IfOperStatusUp ||
        !HasUsableAddress(adapter)) {
      continue;
    }
    const std::string description_utf8 =
        WideToUtf8(std::wstring(adapter->Description));
    const std::string friendly_utf8 =
        WideToUtf8(std::wstring(adapter->FriendlyName));
    const bool known_name =
        ContainsIgnoreCase(description_utf8, "wireguard") ||
        ContainsIgnoreCase(description_utf8, "tailscale") ||
        ContainsIgnoreCase(description_utf8, "zerotier") ||
        ContainsIgnoreCase(description_utf8, "openvpn tunnel") ||
        ContainsIgnoreCase(description_utf8, "vpn tunnel") ||
        ContainsIgnoreCase(friendly_utf8, "vpn tunnel");
    const bool vpn_type = adapter->IfType == IF_TYPE_PPP ||
                          adapter->IfType == IF_TYPE_TUNNEL;
    if (!known_name && !vpn_type) continue;
    snapshot->vpn_active = true;
    const std::string source =
        description_utf8.empty() ? friendly_utf8 : description_utf8;
    if (!source.empty()) {
      const std::string label = "VPN/Tunnel adapter: " + source;
      if (std::find(snapshot->vpn_sources.begin(),
                    snapshot->vpn_sources.end(),
                    label) == snapshot->vpn_sources.end()) {
        snapshot->vpn_sources.push_back(label);
      }
    }
  }
}
void DetectSystemProxy(DetectionSnapshot* snapshot) {
  WINHTTP_CURRENT_USER_IE_PROXY_CONFIG config{};
  if (!WinHttpGetIEProxyConfigForCurrentUser(&config)) return;
  if (config.lpszProxy != nullptr && *config.lpszProxy != L'\0') {
    snapshot->proxy_active = true;
    snapshot->proxy_sources.push_back("System HTTP proxy");
  }
  if (config.lpszAutoConfigUrl != nullptr &&
      *config.lpszAutoConfigUrl != L'\0') {
    snapshot->proxy_active = true;
    snapshot->proxy_sources.push_back("PAC proxy");
  }

  if (config.lpszProxy) GlobalFree(config.lpszProxy);
  if (config.lpszProxyBypass) GlobalFree(config.lpszProxyBypass);
  if (config.lpszAutoConfigUrl) GlobalFree(config.lpszAutoConfigUrl);
}

}  // namespace

DetectionSnapshot NativeMonitor::Detect(
    const std::vector<std::string>& process_patterns) {
  DetectionSnapshot snapshot;
  snapshot.wifi_ssid = GetWifiSsid(&snapshot.wifi_error);
  snapshot.wifi_available = !snapshot.wifi_ssid.empty();
  DetectVpn(&snapshot);
  DetectSystemProxy(&snapshot);
  return snapshot;
}

}  // namespace wifi_warning




