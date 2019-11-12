# escape=`

FROM microsoft/dotnet-framework:4.7.1 AS windows-swift

# MAINTAINER "compnerd@compnerd.org"
LABEL maintainer="compnerd@compnerd.org"

# restore the default Windows shell for correct batch processing
SHELL ["cmd", "/S", "/C"]

# download build tools bootstrapper
ADD https://aka.ms/vs/16/release/vs_buildtools.exe C:\TEMP\vs_buildtools.exe

# Microsoft.VisualStudio.Component.Windows10SDK: Universal C Runtime
# Microsoft.VisualStudio.Component.VC.Tools.x86.x64: MSVC v142 - VS 2019 C++ x64/x86 build tools (v14.20)
# Microsoft.VisualStudio.Component.Windows10SDK.17763: Windows 10 SDK (10.0.17763.0)
# Microsoft.VisualStudio.Component.Windows10SDK.18362: Windows 10 SDK (10.0.18362.0)
# Microsoft.VisualStudio.Component.VC.CMake.Project: C++ CMake tools for Windows
RUN C:\TEMP\vs_buildtools.exe --quiet --wait --norestart --nocache              `
    --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2019"         `
    --add Microsoft.VisualStudio.Component.Windows10SDK                         `
    --add Microsoft.VisualStudio.Component.Windows10SDK.18362                   `
  || IF "%EXITCODE%"=="3010" EXIT 0

# Install Swift toolchain.
COPY InstallSwiftToolchain.ps1 C:\TEMP\InstallSwiftToolchain.ps1
RUN powershell -nologo -ExecutionPolicy Bypass "& 'C:\TEMP\InstallSwiftToolchain.ps1'"

# Clean up.
RUN del /Q C:\TEMP

# Default to powershell otherwise
CMD ["powershell.exe", "-nologo", "-ExecutionPolicy", "Bypass"]

