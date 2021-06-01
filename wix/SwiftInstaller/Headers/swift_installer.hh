// Copyright © 2021 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef SWIFT_INSTALLER_HEADERS_SWIFT_INSTALLER_HH
#define SWIFT_INSTALLER_HEADERS_SWIFT_INSTALLER_HH

#define WIN32_LEAN_AND_MEAN
#define VC_EXTRA_LEAN
#define NOMINMAX
#include <Windows.h>
#include <msi.h>

#if defined(_WINDLL)
# if defined(SwiftInstaller_EXPORTS)
#   define SWIFT_INSTALLER_API __declspec(dllexport)
# else
#   define SWIFT_INSTALLER_API __declspec(dllimport)
# endif
#else
# define SWIFT_INSTALLER_API
#endif

#if defined(__cplusplus)
extern "C" {
#endif

UINT SWIFT_INSTALLER_API
SwiftInstaller_InstallAuxiliaryFiles(MSIHANDLE hInstall);

#if defined(__cplusplus)
}
#endif

#endif
