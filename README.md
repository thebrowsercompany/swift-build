# **//swift/build**

`//swift/build` homes the CI configuration for GitHub Actions based builds as
well as a repo manifest to provide the ability to sync the full repository set.

 ## Symbols

This table outlines high-level information about debugging symbol availability and coverage. If you are unfamiliar with how to configure a symbol server, please check out [SYMBOLS.md](SYMBOLS.md) for more information.


| | |
| --- | --- |
| Symbol Server URL | https://swift-toolchain.thebrowserco.com/symbols |
| Authentication | None required |
| Protocol | Standard Microsoft symsrv (HTTPS) |
| Architectures | x64, ARM64 |
| Symbol format | PDB (Program Database) |
| Compatible tools | WinDBG, Visual Studio, WPA, LLDB (coming soon), cdb, symchk |
| Coverage | Swift runtime, standard library, compiler infrastructure |

