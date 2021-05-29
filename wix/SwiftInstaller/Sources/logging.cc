// Copyright © 2021 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#include "logging.hh"

#include <cassert>
#include <codecvt>
#include <iomanip>
#include <string>
#include <vector>

namespace {
std::string to_string(const msi::logging::severity &severity) {
  switch (severity) {
  case msi::logging::severity::info: return "INFO";
  case msi::logging::severity::warning: return "WARN";
  case msi::logging::severity::error: return "ERROR";
  case msi::logging::severity::fatal: return "FATAL";
  }
  __assume(false);
}
}

namespace msi::logging {
log_message::log_message(MSIHANDLE install, msi::logging::severity severity,
                         const char *file, unsigned line)
    : install_(install), severity_(severity), file_(file), line_(line) {
  std::string_view filename(file);

  auto separator = filename.find_last_of("\\/");
  if (separator != std::string_view::npos)
    filename.remove_prefix(separator + 1);

  SYSTEMTIME time;
  GetLocalTime(&time);

  stream_ << "[\\[]"
          // TODO(compnerd) should we size the pid and tid?
          << GetCurrentProcessId() << ':' << GetCurrentThreadId() << ':'
          << std::setfill('0')
          << std::setw(2) << time.wMonth
          << std::setw(2) << time.wDay
          << '/'
          << std::setw(2) << time.wHour
          << std::setw(2) << time.wMinute
          << std::setw(2) << time.wSecond
          << '.'
          << std::setw(3) << time.wMilliseconds
          << ':'
          << to_string(severity_)
          << ':' << filename << '(' << line << ')'
          << "[\\]]" << ' ';
}

log_message::~log_message() {
  std::string message = stream_.str();

  PMSIHANDLE record;
  record = MsiCreateRecord(0);
  (void)MsiRecordSetStringA(record, 0, message.c_str());
  (void)MsiProcessMessage(install_, INSTALLMESSAGE_INFO, record);
}

template <>
log_message &operator<<<std::wstring>(log_message &message,
                                      const std::wstring &str) noexcept {
  std::wstring_convert<std::codecvt_utf8<std::wstring::traits_type::char_type>,
                       std::wstring::traits_type::char_type> utf8;
  message.stream_ << utf8.to_bytes(str.data(), str.data() + str.size());
  return message;
}

template <>
log_message &
operator<<<MSIHANDLE>(log_message &message, const MSIHANDLE &record) noexcept {
#if WORKING_MSI_ERROR_LOOKUP
  UINT status;
  DWORD size = 0;

  status = MsiFormatRecordW(message.install_, record, L"", &size);
  if (status == ERROR_MORE_DATA) {
    std::vector<wchar_t> buffer;
    buffer.resize(++size);

    status = MsiFormatRecordW(message.install_, record, buffer.data(), &size);
    if (status == ERROR_SUCCESS) {
      message << std::wstring{buffer.data(), buffer.size()};
      return message;
    }
  }
#endif
  message << "[\\{]record conversion failure - " << MsiRecordGetInteger(record, 1) << "[\\}]";
  return message;
}
}
