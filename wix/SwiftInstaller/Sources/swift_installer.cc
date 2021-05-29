// Copyright © 2021 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#include "swift_installer.hh"
#include "logging.hh"
#include "scoped_raii.hh"

#include <comip.h>
#include <comdef.h>

#include <algorithm>
#include <cassert>
#include <ciso646>
#include <filesystem>
#include <fstream>
#include <functional>
#include <sstream>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <vector>

// NOTE(compnerd) `Unknwn.h` must be included before `Setup.Configuration.h` as
// the header is not fully self-contained.
#include <Unknwn.h>
#include <Setup.Configuration.h>

_COM_SMARTPTR_TYPEDEF(IEnumSetupInstances, __uuidof(IEnumSetupInstances));
_COM_SMARTPTR_TYPEDEF(ISetupConfiguration, __uuidof(ISetupConfiguration));
_COM_SMARTPTR_TYPEDEF(ISetupConfiguration2, __uuidof(ISetupConfiguration2));
_COM_SMARTPTR_TYPEDEF(ISetupHelper, __uuidof(ISetupHelper));
_COM_SMARTPTR_TYPEDEF(ISetupInstance, __uuidof(ISetupInstance));
_COM_SMARTPTR_TYPEDEF(ISetupInstance2, __uuidof(ISetupInstance2));
_COM_SMARTPTR_TYPEDEF(ISetupPackageReference, __uuidof(ISetupPackageReference));

namespace {
std::string contents(const std::filesystem::path &path) noexcept {
  std::ostringstream buffer;
  std::ifstream stream(path);
  if (!stream)
    return {};
  buffer << stream.rdbuf();
  return buffer.str();
}

template <typename CharType_>
void trim(std::basic_string<CharType_> &string) noexcept {
  string.erase(std::remove_if(std::begin(string), std::end(string),
                              [](CharType_ ch) { return !std::isprint(ch); }),
               std::end(string));
}
}

// This is technically a misnomer.  We are not looking for the Windows SDK but
// rather the Universal CRT SDK.
//
// The Windows SDK installation is found by querying:
//  HKLM\SOFTWARE\[Wow6432Node]\Microsoft\Microsoft SDKs\Windows\v10.0\InstallationFolder
// We can identify the SDK version using:
//  HKLM\SOFTWARE\[Wow6432Node]\Microsoft\Microsoft SDKs\Windows\v10.0\ProductVersion
//
// We currently only query:
//  HKLM\SOFTWARE\Microsoft\Windows Kits\Installed Roots\KitsRoot10
// which gives us the Universal CRT installation root.
//
// FIXME(compnerd) we should support additional installation configurations by
// also querying the HKCU hive.
namespace winsdk {
static const wchar_t kits_root_key[] = L"KitsRoot10";
static const wchar_t kits_installed_roots_keypath[] =
    L"SOFTWARE\\Microsoft\\Windows Kits\\Installed Roots";

std::filesystem::path install_root() noexcept {
  std::vector<wchar_t> buffer;
  DWORD cbData = 0;

  if (FAILED(RegGetValueW(HKEY_LOCAL_MACHINE, kits_installed_roots_keypath,
                          kits_root_key, RRF_RT_REG_SZ, nullptr, nullptr,
                          &cbData)))
    return {};

  buffer.resize(cbData);
  if (FAILED(RegGetValueW(HKEY_LOCAL_MACHINE, kits_installed_roots_keypath,
                          kits_root_key, RRF_RT_REG_SZ, nullptr, buffer.data(),
                          &cbData)))
    return {};

  return std::filesystem::path(buffer.data());
}

std::vector<std::wstring> available_versions() noexcept {
  HKEY hKey;

  if (FAILED(RegOpenKeyExW(HKEY_LOCAL_MACHINE, kits_installed_roots_keypath,
                           0, KEY_READ, &hKey)))
    return {};

  windows::raii::hkey key{hKey};

  DWORD cSubKeys;
  DWORD cbMaxSubKeyLen;
  if (FAILED(RegQueryInfoKeyW(hKey, nullptr, nullptr, nullptr, &cSubKeys,
                              &cbMaxSubKeyLen, nullptr, nullptr, nullptr,
                              nullptr, nullptr, nullptr)))
    return {};

  std::vector<wchar_t> buffer;
  buffer.resize(static_cast<size_t>(cbMaxSubKeyLen) + 1);

  std::vector<std::wstring> versions;
  for (DWORD dwIndex = 0; dwIndex < cSubKeys; ++dwIndex) {
    DWORD cchName = cbMaxSubKeyLen + 1;

    // TODO(compnerd) handle error
    (void)RegEnumKeyExW(hKey, dwIndex, buffer.data(), &cchName, nullptr,
                        nullptr, nullptr, nullptr);

    versions.emplace_back(buffer.data());
  }
  return versions;
}
}

namespace msvc {
// VS2019 v142 Build Tools
static const wchar_t toolset_v142_x86_x64[] =
    L"Microsoft.VisualStudio.Component.VC.Tools.x86.x64";
static const wchar_t toolset_v142_arm[] =
    L"Microsoft.VisualStudio.Component.VC.Tools.ARM";
static const wchar_t toolset_v142_arm64[] =
    L"Microsoft.VisualStudio.Component.VC.Tools.ARM64";
static const wchar_t toolset_v142_arm64ec[] =
    L"Microsoft.VisualStudio.Component.VC.Tools.ARM64EC";

// VS2017 v141 Build Tools
static const wchar_t toolset_v141_x86_x64[] =
    L"Microsoft.VisualStudio.Component.VC.v141.x86.x64";
static const wchar_t toolset_v141_arm[] =
    L"Microsoft.VisualStudio.Component.VC.v141.ARM";
static const wchar_t toolset_v141_arm64[] =
    L"Microsoft.VisualStudio.Component.VC.v141.ARM64";

static const wchar_t *known_toolsets[] = {
  toolset_v142_x86_x64,
  toolset_v142_arm64ec,
  toolset_v142_arm64,
  toolset_v142_arm,

  toolset_v141_x86_x64,
  toolset_v141_arm64,
  toolset_v141_arm,
};

// The name is misleading.  This currently returns the default toolset in all
// VS2015+ installations.
std::vector<std::filesystem::path> available_toolsets() noexcept {
  windows::raii::com_initializer com;

  std::vector<std::filesystem::path> toolsets;

  ISetupConfigurationPtr configuration;
  if (FAILED(configuration.CreateInstance(__uuidof(SetupConfiguration))))
    return toolsets;

  ISetupConfiguration2Ptr configuration2;
  if (FAILED(configuration->QueryInterface(&configuration2)))
    return toolsets;

  IEnumSetupInstancesPtr instances;
  if (FAILED(configuration2->EnumAllInstances(&instances)))
    return toolsets;

  ULONG fetched;
  ISetupInstancePtr instance;
  while (SUCCEEDED(instances->Next(1, &instance, &fetched)) && fetched) {
    ISetupInstance2Ptr instance2;
    if (FAILED(instance->QueryInterface(&instance2)))
      continue;

    InstanceState state;
    if (FAILED(instance2->GetState(&state)))
      continue;

    // Ensure that the instance state matches
    //  eLocal: The instance installation path exists.
    //  eRegistered: A product is registered to the instance.
    if (~state & eLocal or ~state & eRegistered)
      continue;

    LPSAFEARRAY packages;
    if (FAILED(instance2->GetPackages(&packages)))
      continue;

    LONG lower, upper;
    if (FAILED(SafeArrayGetLBound(packages, 1, &lower)) ||
        FAILED(SafeArrayGetUBound(packages, 1, &upper)))
      continue;

    for (LONG index = 0, count = upper - lower + 1; index < count; ++index) {
      IUnknownPtr element;
      if (FAILED(SafeArrayGetElement(packages, &index, &element)))
        continue;

      ISetupPackageReferencePtr package;
      if (FAILED(element->QueryInterface(&package)))
        continue;

      _bstr_t package_id;
      if (FAILED(package->GetId(package_id.GetAddress())))
        continue;

      // Ensure that we are dealing with a (known) MSVC ToolSet
      if (std::none_of(std::begin(known_toolsets), std::end(known_toolsets),
                      [package_id = package_id.GetBSTR()](const wchar_t *id) {
                        return wcscmp(package_id, id) == 0;
                      }))
        continue;

      _bstr_t VSInstallDir;
      if (FAILED(instance2->GetInstallationPath(VSInstallDir.GetAddress())))
        continue;

      std::filesystem::path VCInstallDir{static_cast<wchar_t *>(VSInstallDir)};
      VCInstallDir.append("VC");

      std::string VCToolsVersion;
      // VSInstallDir\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt
      // contains the default version of the v141 MSVC toolset.  Prefer to use
      // VSInstallDir\VC\Auxiliary\Build\Microsoft.VCToolsVersion.v142.default.txt
      // which contains the default v142 version of the toolset.
      for (const auto &file : {"Microsoft.VCToolsVersion.v142.default.txt",
                               "Microsoft.VCToolsVersion.default.txt"}) {
        std::filesystem::path path{VCInstallDir};
        path.append("Auxiliary");
        path.append("Build");
        path.append(file);

        VCToolsVersion = contents(path);
        // Strip any line ending characters from the contents of the file.
        trim(VCToolsVersion);
        if (!VCToolsVersion.empty())
          break;
      }

      if (VCToolsVersion.empty())
        continue;

      std::filesystem::path VCToolsInstallDir{VCInstallDir};
      VCToolsInstallDir.append("Tools");
      VCToolsInstallDir.append("MSVC");
      VCToolsInstallDir.append(VCToolsVersion);

      // FIXME(compnerd) should we actually just walk the directory structure
      // instead and populate all the toolsets?  That would match roughly what
      // we do with the UCRT currently.

      toolsets.push_back(VCToolsInstallDir);
    }
  }

  return toolsets;
}
}

namespace msi {
std::wstring get_property(MSIHANDLE hInstall, std::wstring_view key) noexcept {
  DWORD size = 0;
  UINT status;

  status = MsiGetPropertyW(hInstall, key.data(), L"", &size);
  assert(status == ERROR_MORE_DATA);

  std::vector<wchar_t> buffer;
  buffer.resize(size + 1);

  size = buffer.capacity();
  status = MsiGetPropertyW(hInstall, key.data(), buffer.data(), &size);
  // TODO(compnerd) handle error

  return {buffer.data(), buffer.capacity()};
}

void record_auxiliary_file(MSIHANDLE hInstall, MSIHANDLE database,
                           const std::filesystem::path &path) noexcept {
#if WORKING_MSI_RECORDING
  // See https://docs.microsoft.com/en-us/windows/win32/msi/removefile-table
  // for details about the schema details about the `RemoveFile` table.
  static const wchar_t query[] = LR"(
INSERT INTO `RemoveFile` (`FileKey`, `Component_`, `FileName`, `DirProperty`, `InstallMode`)
VALUES ([1], [2], [3], [4], [5])
  )";

  PMSIHANDLE view;
  if (!MsiDatabaseOpenViewW(database, query, &view)) {
    LOG(hInstall, warning)
        << "unable to create database view: " << MsiGetLastErrorRecord();
    return;
  }

  PMSIHANDLE record = MsiCreateRecord(5);
  if (!record) {
    LOG(hInstall, warning)
        << "unable to create AuxiliaryFile record: " << MsiGetLastErrorRecord();
    return;
  }

  UINT status;
  std::hash<std::wstring> hasher;
  std::wostringstream component;

  component << "cmp" << hasher(path.wstring());
  status = MsiRecordSetStringW(record, 1, component.str().c_str());
  // TODO(compnerd) handle error

  // NOTE(compnerd) this maps the AuxiliaryFiles component created in the WiX
  // definition for the MSI.
  status = MsiRecordSetStringW(record, 2, L"AuxiliaryFiles");
  // TODO(compnerd) handle error

  status = MsiRecordSetStringW(record, 3, path.stem().wstring().c_str());
  // TODO(compnerd) handle error

  // TODO(compnerd) this needs to be a dynamically constructed property
  status = MsiRecordSetStringW(record, 4, path.parent_path().wstring().c_str());
  // TODO(compnerd) handle error

  // https://docs.microsoft.com/en-us/windows/win32/msi/removefile-table
  // msidbRemoveFileInstallModeOnInstall  0x001   Remove During Installation
  // msidbRemoveFileInstallModeOnRemove   0x002   Remove During Removal
  // msidbRemoveFileInstallModeOnBoth     0x003   Remove Always
  status = MsiRecordSetInteger(record, 5, 0x002);
  // TODO(compnerd) handle error

  status = MsiViewExecute(view, record);
  if (status)
    LOG(hInstall, warning)
        << "unable to insert AuxiliaryFile " << path << ": " << status;
#endif
}
}

UINT SwiftInstaller_RecordAuxiliaryFiles(MSIHANDLE hInstall) {
  std::vector<std::filesystem::path> additional_content;

  // SDK Module Maps
  std::filesystem::path UniversalCRTSdkDir = winsdk::install_root();
  if (UniversalCRTSdkDir.empty()) {
    LOG(hInstall, warning) << "UniversalCRTSdkDir is unset";
  } else {
    // FIXME(compnerd) Technically we are using the UniversalCRTSdkDir here
    // instead of the WindowsSdkDir which would contain `um`.

    // FIXME(compnerd) we may end up in a state where the ucrt and Windows SDKs
    // do not match.  Users have reported cases where they somehow managed to
    // setup such a configuration.  We should split this up to explicitly
    // handle the UCRT and WinSDK paths separately.
    for (const auto &version : winsdk::available_versions()) {
      additional_content.emplace_back(UniversalCRTSdkDir / "Include" / version / "ucrt" / "module.modulemap");
      additional_content.emplace_back(UniversalCRTSdkDir / "Include" / version / "um" / "module.modulemap");
    }
  }

  // MSVC Tools Module Maps
  for (const auto &VCToolsInstallDir : msvc::available_toolsets()) {
    additional_content.emplace_back(VCToolsInstallDir / "include" / "module.modulemap");
    additional_content.emplace_back(VCToolsInstallDir / "include" / "visualc.apinotes");
  }

  std::wstring product_code = msi::get_property(hInstall, L"ProductCode");
  LOG(hInstall, info) << "Product Code: " << product_code;

  LOG(hInstall, info) << "Additional Content:";
  for (const auto &content : additional_content)
    LOG(hInstall, info) << "  - " << content.string();

  if (PMSIHANDLE database = MsiGetActiveDatabase(hInstall))
    for (const auto &content : additional_content)
      msi::record_auxiliary_file(hInstall, database, content);
  else
    LOG(hInstall, warning)
        << "unable to access active database: " << MsiGetLastErrorRecord();

  return ERROR_SUCCESS;
}

UINT SwiftInstaller_InstallAuxiliaryFiles(MSIHANDLE hInstall) {
  std::vector<std::filesystem::path> additional_content;

  std::wstring data = msi::get_property(hInstall, L"CustomActionData");
  trim(data);

  std::filesystem::path SDKROOT{data};
  LOG(hInstall, info) << "SDKROOT: " << SDKROOT.string();

  // Copy SDK Module Maps
  std::filesystem::path UniversalCRTSdkDir = winsdk::install_root();
  if (UniversalCRTSdkDir.empty()) {
    LOG(hInstall, warning) << "UniversalCRTSdkDir is unset";
  } else {
    // FIXME(compnerd) Technically we are using the UniversalCRTSdkDir here
    // instead of the WindowsSdkDir which would contain `um`.

    // FIXME(compnerd) we may end up in a state where the ucrt and Windows SDKs
    // do not match.  Users have reported cases where they somehow managed to
    // setup such a configuration.  We should split this up to explicitly
    // handle the UCRT and WinSDK paths separately.
    for (const auto &version : winsdk::available_versions()) {
      const struct {
        std::filesystem::path src;
        std::filesystem::path dst;
      } items[] = {
        { SDKROOT / "usr" / "share" / "ucrt.modulemap",
          UniversalCRTSdkDir / "Include" / version / "ucrt" / "module.modulemap" },
        { SDKROOT / "usr" / "share" / "winsdk.modulemap",
          UniversalCRTSdkDir / "Include" / version / "um" / "module.modulemap" },
      };

      for (const auto &item : items) {
        static const constexpr std::filesystem::copy_options options =
            std::filesystem::copy_options::overwrite_existing;

        std::error_code ec;
        if (!std::filesystem::copy_file(item.src, item.dst, options, ec)) {
          LOG(hInstall, error)
              << "unable to copy " << item.src << " to " << item.dst << ": "
              << ec.message();
          continue;
        }
        LOG(hInstall, info) << "Deployed " << item.dst;
      }
    }
  }

  // Copy MSVC Tools Module Maps
  for (const auto &VCToolsInstallDir : msvc::available_toolsets()) {
    const struct {
      std::filesystem::path src;
      std::filesystem::path dst;
    } items[] = {
      { SDKROOT / "usr" / "share" / "visualc.modulemap",
        VCToolsInstallDir / "include" / "module.modulemap" },
      { SDKROOT / "usr" / "share" / "visualc.apinotes",
        VCToolsInstallDir / "include" / "visualc.apinotes" },
    };

    for (const auto &item : items) {
      static const constexpr std::filesystem::copy_options options =
          std::filesystem::copy_options::overwrite_existing;

      std::error_code ec;
      if (!std::filesystem::copy_file(item.src, item.dst, options, ec)) {
        LOG(hInstall, error)
            << "unable to copy " << item.src << " to " << item.dst << ": "
            << ec.message();
        continue;
      }
      LOG(hInstall, info) << "Deployed " << item.dst;
    }
  }

  return ERROR_SUCCESS;
}
