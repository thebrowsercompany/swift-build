# escape=`

# use the latest Winows nanoserver image
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
RUN C:\TEMP\vs_buildtools.exe --quiet --wait --norestart --nocache  `
    --installPath "C:\MSVC"                                         `
    --add Microsoft.VisualStudio.Component.Windows10SDK             `
    --add Microsoft.VisualStudio.Component.Windows10SDK.17763       `
    --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64         `
  || IF "%EXITCODE%"=="3010" EXIT 0

# Install Swift toolchain.
COPY InstallSwiftToolchain.ps1 C:\TEMP\InstallSwiftToolchain.ps1
RUN powershell -nologo -ExecutionPolicy Bypass "& 'C:\TEMP\InstallSwiftToolchain.ps1'"

# Clean up.
RUN del C:\TEMP\*

# Use developer command prompt with any command specified
ENTRYPOINT "C:\MSVC\Common7\Tools\VsDevCmd.bat" &&

# Default to powershell otherwise
CMD ["powershell.exe", "-nologo", "-ExecutionPolicy", "Bypass"]

