## A Public Symbol Server

The Browser Company now host a public symbol server for the Swift on Windows toolchain at:

**https://swift-toolchain.thebrowserco.com/symbols**

The server uses the standard Microsoft symbol server protocol, the same protocol used by Microsoft's own public symbol server at msdl.microsoft.com. This means it works with every tool in the Windows debugging ecosystem — WinDBG, Visual Studio, Windows Performance Analyzer, cdb, symchk — without any special client or plugin. Symbols are published automatically with each toolchain CI build and cover both x64 and ARM64 architectures. No authentication is required.

The PDB files cover the open-source components of the Swift toolchain: the Swift runtime, standard library, and compiler infrastructure. Application-specific symbols are not included — those come from your own builds.

## Configuration

### System-wide setup

The most straightforward approach is to set the `_NT_SYMBOL_PATH` environment variable, which is read by all symsrv-compatible tools. In PowerShell:

```powershell
[Environment]::SetEnvironmentVariable(
    "_NT_SYMBOL_PATH",
    "SRV*C:\SymCache*https://swift-toolchain.thebrowserco.com/symbols*https://msdl.microsoft.com/download/symbols",
    "User"
)
```

This configures the debugging tools to cache downloaded symbols locally in `C:\SymCache`, fetch Swift toolchain symbols from our server, and fall back to Microsoft's symbol server for Windows OS symbols. Restart any open debugger sessions for the change to take effect.

### Per-tool configuration

If you prefer not to set a system-wide environment variable, you can configure individual tools directly.

In **WinDBG**, add the symbol server to your current session:

```
.sympath+ SRV*C:\SymCache*https://swift-toolchain.thebrowserco.com/symbols
.symfix+
.reload /f
```

In **Visual Studio**, navigate to Tools → Options → Debugging → Symbols and add the URL as a new symbol server location with `C:\SymCache` as the cache directory.

**Windows Performance Analyzer** does not read `_NT_SYMBOL_PATH` by default. With a trace open, go to Trace → Configure Symbols and add `SRV*C:\SymCache*https://swift-toolchain.thebrowserco.com/symbols` in the Paths tab.

## Swift's Built-in Backtracing

Swift's runtime includes a built-in crash catcher and backtracer that can symbolicate stack frames using PDB files on Windows. The backtracer parses PDB files directly using CodeView debug information and does not require the DIA SDK or any external dependencies.

The backtracer does not fetch symbols from remote servers. It searches for PDB files on disk, looking in the directory containing the binary, and then in a configurable symbol path using the standard symstore directory layout. If symbols have been pre-cached locally by another tool — for example, WinDBG or `symchk.exe` will populate the local cache when they fetch from the symbol server — the backtracer will find and use them.

The search path is controlled by the `SWIFT_SYMBOL_PATH` environment variable, which defaults to `C:\Symbols` on Windows. Point this at your local symbol cache directory and the backtracer will resolve toolchain runtime frames in crash logs.

## Bringing Symbol Servers to LLDB

Alongside the symbol server, we are upstreaming a `SymbolLocatorSymStore` plugin for LLDB to the LLVM project. This adds native support for the Microsoft symbol server protocol directly into the debugger that ships with the Swift toolchain.

The work is being developed in the open on llvm.org. The implementation covers HTTP and HTTPS retrieval with security hardening — TLS certificate pinning to support self-signed certificates in isolated environments, and rejection of HTTPS-to-HTTP redirect downgrades — built on WinHTTP. Once landed upstream, it will be pulled into the Swift project's LLDB fork for inclusion in future toolchain releases.

LLDB reads the `_NT_SYMBOL_PATH` environment variable, so the system-wide configuration described above works for LLDB as well. Symbol server URLs can also be configured directly in LLDB via `settings set plugin.symbol-locator.symstore.urls`. Once this lands, debugging a Swift program in VS Code will transparently resolve toolchain symbols from the server.