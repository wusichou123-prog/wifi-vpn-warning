#ifndef RUNNER_NATIVE_MONITOR_H_
#define RUNNER_NATIVE_MONITOR_H_

#include <string>
#include <vector>

namespace wifi_warning {

struct DetectionSnapshot {
  std::string wifi_ssid;
  bool wifi_available = false;
  std::string wifi_error;
  bool vpn_active = false;
  std::vector<std::string> vpn_sources;
  bool proxy_active = false;
  std::vector<std::string> proxy_sources;
  std::string error;
};

class NativeMonitor {
 public:
  DetectionSnapshot Detect(const std::vector<std::string>& process_patterns);
};

}  // namespace wifi_warning

#endif  // RUNNER_NATIVE_MONITOR_H_
