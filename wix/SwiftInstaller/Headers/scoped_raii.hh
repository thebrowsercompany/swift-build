// Copyright © 2021 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef SWIFT_INSTALLER_HEADERS_SCOPED_RAII_HH
#define SWIFT_INSTALLER_HEADERS_SCOPED_RAII_HH

#define WIN32_LEAN_AND_MEAN
#define VC_EXTRA_LEAN
#define NOMINMAX
#include <Windows.h>
#include <objbase.h>

namespace windows {
namespace raii {
class hkey {
  HKEY hKey_;

 public:
  explicit hkey(HKEY hKey) noexcept : hKey_(hKey) {}

  // TODO(compnerd) log failure
  ~hkey() noexcept { (void)RegCloseKey(hKey_); }
};

class com_initializer {
  HRESULT hr_;

 public:
   enum threading_model { multithreaded };

   explicit com_initializer() {
     hr_ = ::CoInitializeEx(nullptr,
                            COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
   }

   explicit com_initializer(threading_model) {
     hr_ = ::CoInitializeEx(nullptr,
                            COINIT_MULTITHREADED | COINIT_DISABLE_OLE1DDE);
   }

   ~com_initializer() {
     if (SUCCEEDED(hr_))
       ::CoUninitialize();
   }

   bool succeeded() const { return SUCCEEDED(hr_); }
};
}
}

#endif
