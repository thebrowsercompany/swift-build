// Copyright © 2021 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef SWIFT_INSTALLER_HEADERS_LOGGING_HH
#define SWIFT_INSTALLER_HEADERS_LOGGING_HH

#define WIN32_LEAN_AND_MEAN
#define VC_EXTRA_LEAN
#define NOMINMAX
#include <Windows.h>
#include <MsiQuery.h>
#include <Msi.h>

#include <string>
#include <sstream>

namespace msi::logging {
enum class severity {
  info,     /// INSTALLMESSAGE_INFO
  warning,  /// INSTALLMESSAGE_WARNING
  error,    /// INSTALLMESSAGE_ERROR
  fatal,    /// INSTALLMESSAGE_FATALEXIT
};

class log_message {
  MSIHANDLE install_;
  const severity severity_;
  const char *file_;
  const unsigned line_;
  std::ostringstream stream_;

  template <typename Value_>
  friend log_message &operator<<(log_message &, const Value_ &) noexcept;

 public:
  log_message(MSIHANDLE install, severity severity,
              const char *file, unsigned line);
  ~log_message();

  log_message(const log_message &) = delete;
  log_message &operator=(const log_message &) = delete;

  std::string str() { return stream_.str(); }
  severity severity() const { return severity_; }
};

template <typename Value_>
log_message &operator<<(log_message &message, const Value_ &value) noexcept {
  message.stream_ << value;
  return message;
}

extern template
log_message &operator<<<std::wstring>(log_message &,
                                      const std::wstring &) noexcept;
}

#define LOG(Install,Severity)                                                   \
  msi::logging::log_message(Install, msi::logging::severity::##Severity,        \
                            __FILE__, __LINE__)

#endif
