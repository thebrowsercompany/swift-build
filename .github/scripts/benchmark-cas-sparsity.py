import argparse
import ctypes
from ctypes import wintypes
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import struct
import subprocess
import tarfile
import tempfile
import time


def run(command):
    print(subprocess.list2cmdline([str(value) for value in command]), flush=True)
    start = time.perf_counter()
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", env=dict(os.environ, LC_ALL="C"))
    seconds = time.perf_counter() - start
    print(result.stdout, end="", flush=True)
    print(result.stderr, end="", flush=True)
    result.check_returncode()
    return result.stdout, seconds


def diagnostic_command(command, archive, cwd=None, unset_locale=False):
    env = dict(os.environ, LC_ALL="C")
    if unset_locale:
        env.pop("LC_ALL", None)
    result = {"command": command, "cwd": str(cwd or Path.cwd()), "lc_all": env.get("LC_ALL")}
    print(f"Diagnostic: {subprocess.list2cmdline(command)}; cwd={result['cwd']}; LC_ALL={result['lc_all']!r}",
          flush=True)
    try:
        process = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True,
                                 encoding="utf-8", errors="replace", timeout=30)
        result.update(returncode=process.returncode, stdout=process.stdout, stderr=process.stderr)
    except (OSError, subprocess.TimeoutExpired) as error:
        result.update(returncode=None, error=str(error))
        for stream in ("stdout", "stderr"):
            value = getattr(error, stream, None) or ""
            result[stream] = value.decode("utf-8", errors="replace") if isinstance(value, bytes) else value
    result["archive_bytes"] = archive.stat().st_size if archive.exists() else None
    print(json.dumps(result, indent=2), flush=True)
    return result


def windows_creation_diagnostics(args, results, api):
    executable = Path(args.bsd_tar).resolve(strict=True)
    diagnostics = {"executable": str(executable), "sha256": hashlib.sha256(executable.read_bytes()).hexdigest(),
                   "fixtures": {}, "probes": []}
    results["windows_creation_diagnostics"] = diagnostics
    with tempfile.TemporaryDirectory(prefix="tar-diagnostics-", dir=args.output) as directory:
        root = Path(directory)
        for kind in ("ordinary", "sparse"):
            source = root / kind
            source.mkdir()
            fixture = source / "sample.bin"
            fixture.write_bytes(b"CAS tar diagnostic\n")
            try:
                if kind == "sparse":
                    import msvcrt
                    with fixture.open("r+b") as file:
                        returned = wintypes.DWORD()
                        # FSCTL_SET_SPARSE must precede extending the fixture.
                        if not api.api.DeviceIoControl(msvcrt.get_osfhandle(file.fileno()), 0x900C4,
                                                       None, 0, None, 0, ctypes.byref(returned), None):
                            raise ctypes.WinError(ctypes.get_last_error())
                        file.seek(1024 * 1024 - 1)
                        file.write(b"Z")
                diagnostics["fixtures"][kind] = api.inspect(fixture)
                if kind == "sparse" and not diagnostics["fixtures"][kind]["sparse"]:
                    raise ValueError("Fixture does not have the sparse attribute")
            except (OSError, ValueError) as error:
                diagnostics["fixtures"][kind] = {"error": str(error)}
                continue
            variants = ["baseline", "working-directory", "unset-locale"]
            if kind == "sparse":
                variants.append("no-read-sparse")
            for variant in variants:
                archive = root / f"{kind}-{variant}.tar"
                command = [str(executable), "-vv", "-cf", str(archive)]
                if variant == "no-read-sparse":
                    command.append("--no-read-sparse")
                if variant != "working-directory":
                    command.extend(["-C", str(source)])
                command.append(".")
                probe = diagnostic_command(command, archive,
                                           cwd=source if variant == "working-directory" else None,
                                           unset_locale=variant == "unset-locale")
                probe.update(fixture=kind, variant=variant)
                diagnostics["probes"].append(probe)
                write_report(args.output, results)


class FileStandardInfo(ctypes.Structure):
    _fields_ = [("allocation", ctypes.c_int64), ("length", ctypes.c_int64),
                ("links", wintypes.DWORD), ("delete_pending", ctypes.c_ubyte),
                ("directory", ctypes.c_ubyte)]


class WindowsFiles:
    def __init__(self):
        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        self.api.GetFileInformationByHandleEx.argtypes = [wintypes.HANDLE, ctypes.c_int,
                                                        wintypes.LPVOID, wintypes.DWORD]
        self.api.GetFileInformationByHandleEx.restype = wintypes.BOOL
        self.api.DeviceIoControl.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPVOID,
                                            wintypes.DWORD, wintypes.LPVOID, wintypes.DWORD,
                                            ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
        self.api.DeviceIoControl.restype = wintypes.BOOL
        self.api.GetCompressedFileSizeW.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.DWORD)]
        self.api.GetCompressedFileSizeW.restype = wintypes.DWORD
        self.api.GetVolumePathNameW.argtypes = [wintypes.LPCWSTR, wintypes.LPWSTR, wintypes.DWORD]
        self.api.GetVolumePathNameW.restype = wintypes.BOOL
        self.api.GetVolumeInformationW.argtypes = [wintypes.LPCWSTR, wintypes.LPWSTR, wintypes.DWORD,
                                                 ctypes.POINTER(wintypes.DWORD),
                                                 ctypes.POINTER(wintypes.DWORD),
                                                 ctypes.POINTER(wintypes.DWORD),
                                                 wintypes.LPWSTR, wintypes.DWORD]
        self.api.GetVolumeInformationW.restype = wintypes.BOOL

    def volume(self, path):
        root = ctypes.create_unicode_buffer(32768)
        if not self.api.GetVolumePathNameW(str(path), root, len(root)):
            raise ctypes.WinError(ctypes.get_last_error())
        filesystem = ctypes.create_unicode_buffer(256)
        flags = wintypes.DWORD()
        if not self.api.GetVolumeInformationW(root.value, None, 0, None, None,
                                              ctypes.byref(flags), filesystem, len(filesystem)):
            raise ctypes.WinError(ctypes.get_last_error())
        return {"root": root.value, "filesystem": filesystem.value,
                "supports_sparse_files": bool(flags.value & 0x40), "flags": flags.value}

    def inspect(self, path):
        import msvcrt
        stat = path.stat()
        ranges = []
        with path.open("rb") as file:
            handle = msvcrt.get_osfhandle(file.fileno())
            info = FileStandardInfo()
            if not self.api.GetFileInformationByHandleEx(handle, 1, ctypes.byref(info), ctypes.sizeof(info)):
                raise ctypes.WinError(ctypes.get_last_error())
            offset = 0
            while offset < stat.st_size:
                query = ctypes.create_string_buffer(struct.pack("<qq", offset, stat.st_size - offset))
                buffer = ctypes.create_string_buffer(65536)
                returned = wintypes.DWORD()
                ok = self.api.DeviceIoControl(handle, 0x940CF, query, 16, buffer, len(buffer),
                                             ctypes.byref(returned), None)
                error = ctypes.get_last_error() if not ok else 0
                if error not in (0, 234):  # ERROR_MORE_DATA means continue after the last returned range.
                    raise ctypes.WinError(error)
                if returned.value % 16:
                    raise ValueError("Invalid FSCTL_QUERY_ALLOCATED_RANGES response")
                batch = list(struct.iter_unpack("<qq", buffer.raw[:returned.value]))
                ranges.extend(batch)
                if ok:
                    break
                if not batch or batch[-1][0] + batch[-1][1] <= offset:
                    raise ValueError("Allocated-range query made no progress")
                offset = batch[-1][0] + batch[-1][1]
        high = wintypes.DWORD()
        ctypes.set_last_error(0)
        low = self.api.GetCompressedFileSizeW(str(path), ctypes.byref(high))
        if low == 0xFFFFFFFF and ctypes.get_last_error():
            raise ctypes.WinError(ctypes.get_last_error())
        return {"logical_bytes": stat.st_size, "allocation_bytes": info.allocation,
                "compressed_file_size_bytes": (high.value << 32) | low,
                "sparse": bool(stat.st_file_attributes & 0x200),
                "allocated_ranges": ranges, "range_bytes": sum(length for _, length in ranges)}


def snapshot(api, root):
    files = {}
    for path in sorted(root.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"Unexpected symlink: {path}")
        if path.is_file():
            files[path.relative_to(root).as_posix()] = api.inspect(path)
    return {"files": files, "file_count": len(files),
            "sparse_files": sum(file["sparse"] for file in files.values()),
            **{key: sum(file[key] for file in files.values()) for key in
               ("logical_bytes", "allocation_bytes", "compressed_file_size_bytes", "range_bytes")}}


def data_digest(path, ranges):
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for offset, length in ranges:
            digest.update(struct.pack("<qq", offset, length))
            file.seek(offset)
            while length:
                block = file.read(min(length, 1024 * 1024))
                if not block:
                    raise ValueError(f"Unexpected end of file: {path}")
                digest.update(block)
                length -= len(block)
    return digest.hexdigest()


def archive_manifest(archive, source, hash_data=True):
    entries = {}
    with tarfile.open(archive, "r:") as tar:
        for member in tar:
            if member.isdir():
                continue
            if not member.isfile():
                raise ValueError(f"Unexpected archive member type: {member.name}")
            name = Path(member.name).as_posix()
            if Path(name).is_absolute() or ".." in Path(name).parts or ":" in name or name in entries:
                raise ValueError(f"Unexpected archive path: {name}")
            ranges = [(offset, length) for offset, length in
                      (member.sparse if member.sparse is not None else [(0, member.size)]) if length]
            end = 0
            for offset, length in ranges:
                if offset < end or length < 0 or offset + length > member.size:
                    raise ValueError(f"Invalid sparse map: {name}")
                end = offset + length
            entries[name] = {"logical_bytes": member.size, "data_ranges": ranges}
            if hash_data:
                entries[name]["data_sha256"] = data_digest(source / name, ranges)
    return entries


def validate(root, manifest, measured):
    if {name: file["logical_bytes"] for name, file in measured["files"].items()} != {
            name: file["logical_bytes"] for name, file in manifest.items()}:
        raise ValueError("Restored file names or logical sizes differ")
    for name, entry in manifest.items():
        path = root / name
        if data_digest(path, entry["data_ranges"]) != entry["data_sha256"]:
            raise ValueError(f"Restored archive data ranges differ: {name}")
        # Sample each hole without reading tens of gigabytes of implicit zeros.
        end = 0
        with path.open("rb") as file:
            for offset, length in [*entry["data_ranges"], (entry["logical_bytes"], 0)]:
                if offset > end:
                    size = min(4096, offset - end)
                    for position in {end, offset - size, end + (offset - end - size) // 2}:
                        file.seek(position)
                        if file.read(size) != bytes(size):
                            raise ValueError(f"Nonzero or missing hole sample: {name} at {position}")
                end = offset + length


def header_candidates(source):
    candidates = []
    for path in sorted(source.rglob("*")):
        if path.name not in ("v9.index", "v9.data", "v4.actions") or not path.is_file():
            continue
        entry = {"path": path.relative_to(source).as_posix(), "logical_bytes": path.stat().st_size}
        with path.open("rb") as file:
            header = file.read(32)
        if len(header) == 32:
            magic, version, _, bump = struct.unpack("<QQQQ", header)
            entry.update(magic=hex(magic), version=version, bump_pointer=bump)
            if magic == 0x00FFDA7ABA53FF00 and version == 1 and 32 <= bump <= entry["logical_bytes"]:
                entry["potential_logical_trim_bytes"] = entry["logical_bytes"] - bump
        candidates.append(entry)
    return candidates


def write_report(output, results):
    (output / "sparsity.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    lines = ["# CAS sparsity experiment", "", f"Status: **{results['status']}**", ""]
    if "error" in results:
        lines.extend([f"Error: {results['error']}", ""])
    source = results.get("source")
    for name, binary in results.get("native_tar_binaries", {}).items():
        lines.extend([f"{name}: `{binary['path']}`", f"Version: `{binary['version'].strip()}`",
                      f"SHA-256: `{binary['sha256']}`", ""])
    if source:
        lines.extend([f"Source: {source['file_count']} files; {source['logical_bytes']:,} logical bytes; "
                      f"{source['allocation_bytes']:,} allocated bytes; {source['sparse_files']} sparse files.",
                      f"Prior GetCompressedFileSizeW metric: {source['compressed_file_size_bytes']:,} bytes.", ""])
    if results.get("round_trip"):
        lines.extend(["| Create → extract | Passed trials | Archive bytes (min–max) | Create (s) | Extract (s) | Combined (s) | Allocated bytes (min–max) | Sparse files (min–max) |",
                      "|---|---:|---:|---:|---:|---:|---:|---:|"])
    else:
        lines.extend(["| Extraction method | Passed trials | Median extraction (s) | Allocated bytes (min–max) | Sparse files (min–max) |",
                      "|---|---:|---:|---:|---:|"])
    for method in results.get("methods", []):
        trials = [trial for trial in results["trials"] if trial["method"] == method]
        good = [trial for trial in trials if trial["status"] == "complete"]
        duration = f"{statistics.median(trial['extraction_seconds'] for trial in good):.3f}" if good else "—"
        def bounds(key):
            values = [trial["restored"][key] for trial in good]
            return f"{min(values):,}–{max(values):,}" if values else "—"
        if results.get("round_trip"):
            sizes = [trial["archive_bytes"] for trial in good]
            archive_size = f"{min(sizes):,}–{max(sizes):,}" if sizes else "—"
            creation = f"{statistics.median(trial['archive_seconds'] for trial in good):.3f}" if good else "—"
            combined = f"{statistics.median(trial['archive_seconds'] + trial['extraction_seconds'] for trial in good):.3f}" if good else "—"
            lines.append(f"| {method} | {len(good)}/{results['repeats']} | {archive_size} | {creation} | "
                         f"{duration} | {combined} | {bounds('allocation_bytes')} | {bounds('sparse_files')} |")
        else:
            lines.append(f"| {method} | {len(good)}/{results['repeats']} | {duration} | "
                         f"{bounds('allocation_bytes')} | {bounds('sparse_files')} |")
    lines.extend(["", "Allocation uses GetFileInformationByHandleEx(FileStandardInfo). JSON also includes "
                  "GetCompressedFileSizeW, sparse attributes, and every FSCTL_QUERY_ALLOCATED_RANGES result.",
                  "Range lengths describe possibly populated regions, not exact physical allocation.", "",
                  ("Each method creates a fresh archive of the same source CAS and extracts it with the same tool. "
                   "GNU uses --format=gnu --sparse; native bsdtar uses its default format and sparse handling "
                   "unless the method explicitly specifies --read-sparse. "
                   "Restores are checked against the common source manifest from the GNU reference archive. "
                   if results.get("round_trip") else
                   "Each method extracts the same GNU sparse archive into a fresh directory. ") +
                  "Trial order rotates. "
                  "Timing excludes mount setup/cleanup, allocation inspection and validation; caches are not flushed.",
                  "Validation checks names, lengths, SHA-256 of every archived data range against the source, "
                  "and beginning/middle/end samples of each hole. It is not a full logical-file checksum.", ""])
    if diagnostics := results.get("windows_creation_diagnostics"):
        lines.extend(["## Windows tar creation diagnostics", "",
                      f"Executable: `{diagnostics['executable']}`",
                      f"SHA-256: `{diagnostics['sha256']}`", "",
                      "These probes run after the benchmark and are excluded from its timings. "
                      "The sparse fixture is only 1 MiB; --no-read-sparse is never used on the CAS. "
                      "Full commands, working directories, LC_ALL, stdout/stderr and fixture allocation are in sparsity.json.", "",
                      "| Fixture | Variant | Exit code | Archive bytes |",
                      "|---|---|---:|---:|"])
        for probe in diagnostics["probes"]:
            lines.append(f"| {probe['fixture']} | {probe['variant']} | {probe['returncode']} | {probe['archive_bytes']} |")
        lines.append("")
        for kind, fixture in diagnostics["fixtures"].items():
            if "error" in fixture:
                lines.append(f"- {kind} fixture setup failed: {fixture['error']}")
    if results.get("trim_candidates"):
        lines.extend(["## Read-only inspection of Hiroshi's trimming proposal", "",
                      "| File | Logical bytes | Bump pointer | Potential logical bytes removed |",
                      "|---|---:|---:|---:|"])
        for item in results["trim_candidates"]:
            lines.append(f"| {item['path']} | {item['logical_bytes']:,} | {item.get('bump_pointer', '—')} | "
                         f"{item.get('potential_logical_trim_bytes', 'unrecognized header')} |")
        lines.extend(["", "No CAS files were truncated. These header values do not establish that trimming is safe "
                      "for this toolchain or that it reduces physical allocation.", ""])
    for error in results.get("errors", []):
        lines.append(f"- {error}")
    (output / "sparsity.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def round_trips(args, results, api, source, manifest):
    methods = ["gnu-sparse → gnu", "windows-default → windows", "windows-read-sparse → windows"]
    if args.standalone_tar:
        methods[-1] = "standalone-default → standalone"
    results["methods"] = methods
    write_report(args.output, results)
    expected = {name: entry["logical_bytes"] for name, entry in manifest.items()}
    for trial in range(1, args.repeats + 1):
        offset = (trial - 1) % len(methods)
        for method in methods[offset:] + methods[:offset]:
            sample = {"trial": trial, "method": method, "status": "running"}
            results["trials"].append(sample)
            try:
                with tempfile.TemporaryDirectory(prefix="round-trip-", dir=args.output) as directory:
                    archive = Path(directory) / "cas.tar"
                    destination = Path(directory) / "restored"
                    destination.mkdir()
                    if method.startswith("gnu-"):
                        create = [args.gnu_tar, "--force-local", "--format=gnu", "--sort=name",
                                  "--sparse", "--create", "--file", str(archive), "--directory", str(source), "."]
                        extract = [args.gnu_tar, "--force-local", "--extract", "--file", str(archive),
                                   "--directory", destination.as_posix()]
                    else:
                        flags = ["--read-sparse"] if method.startswith("windows-read-sparse") else []
                        executable = args.standalone_tar if method.startswith("standalone-") else args.bsd_tar
                        create = [executable, *flags, "-cf", str(archive), "-C", str(source), "."]
                        extract = [executable, "-xf", str(archive), "-C", str(destination)]
                    sample.update(create_command=create, extract_command=extract)
                    try:
                        _, sample["archive_seconds"] = run(create)
                    except subprocess.CalledProcessError:
                        if not method.startswith("gnu-") and trial == 1:
                            failed_bytes = archive.stat().st_size if archive.exists() else None
                            diagnostic = diagnostic_command([create[0], "-vv", *create[1:]], archive)
                            diagnostic["failed_archive_bytes"] = failed_bytes
                            sample["creation_diagnostic"] = diagnostic
                        raise
                    sample["archive_bytes"] = archive.stat().st_size
                    _, sample["extraction_seconds"] = run(extract)
                    sample["archive_members"] = archive_manifest(archive, source, hash_data=False)
                    if {name: entry["logical_bytes"] for name, entry in sample["archive_members"].items()} != expected:
                        raise ValueError("Archive file names or logical sizes differ from source")
                    sample["restored"] = snapshot(api, destination)
                    validate(destination, manifest, sample["restored"])
                    sample["status"] = "complete"
            except (OSError, ValueError, tarfile.TarError, subprocess.CalledProcessError) as error:
                sample.update(status="failed", error=str(error))
                results["errors"].append(f"{method}, trial {trial}: {error}")
            write_report(args.output, results)
    results["status"] = "failed" if results["errors"] else "complete"


def experiment(args, results):
    if os.name != "nt":
        raise ValueError("This experiment requires Windows")
    api = WindowsFiles()
    source = args.cas_path.resolve(strict=True)
    archive = args.archive.resolve(strict=True)
    if args.output == source or source in args.output.parents:
        raise ValueError("Output must be outside the source CAS")
    bin_dir = Path(args.gnu_tar).parent
    results["volumes"] = {"source": api.volume(source), "output": api.volume(args.output)}
    results["versions"] = {"gnu_tar": run([args.gnu_tar, "--version"])[0],
                           "bsd_tar": run([args.bsd_tar, "--version"])[0],
                           "msys": run([str(bin_dir / "uname.exe"), "-a"])[0]}
    native_binaries = {"bsd_tar": args.bsd_tar}
    if args.standalone_tar:
        native_binaries["standalone_tar"] = args.standalone_tar
        results["versions"]["standalone_tar"] = run([args.standalone_tar, "--version"])[0]
    results["native_tar_binaries"] = {
        name: {"path": str(Path(path).resolve(strict=True)), "version": results["versions"][name],
               "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest()}
        for name, path in native_binaries.items()}
    results["mounts_before"] = run([str(bin_dir / "mount.exe")])[0]
    results["source"] = snapshot(api, source)
    results["trim_candidates"] = header_candidates(source)
    manifest = archive_manifest(archive, source)
    results["archive_members"] = manifest
    validate(source, manifest, results["source"])
    if args.round_trip:
        round_trips(args, results, api, source, manifest)
        windows_creation_diagnostics(args, results, api)
        return
    methods = ["gnu-current", "gnu-posix-path", "gnu-sparse-mount", "windows-bsdtar", "windows-bsdtar-S"]
    results["methods"] = methods
    write_report(args.output, results)
    for trial in range(1, args.repeats + 1):
        order = methods[trial - 1:] + methods[:trial - 1]
        for method in order:
            sample = {"trial": trial, "method": method, "status": "running"}
            results["trials"].append(sample)
            try:
                with tempfile.TemporaryDirectory(prefix="sparsity-", dir=args.output) as directory:
                    destination = Path(directory)
                    if method == "gnu-sparse-mount":
                        mountpoint = f"/cas-sparse-{os.getpid()}-{trial}"
                        script = '''set -euo pipefail
/usr/bin/mount -f -o binary,sparse,posix=0 "$1" "$2"
trap '/usr/bin/umount "$2"' EXIT
/usr/bin/mount
printf 'CAS_EXTRACT_START=%s\\n' "$EPOCHREALTIME"
/usr/bin/tar --force-local --extract --file "$3" --directory "$2"
printf 'CAS_EXTRACT_END=%s\\n' "$EPOCHREALTIME"
'''
                        stdout, sample["process_seconds"] = run([
                            str(bin_dir / "bash.exe"), "-c", script, "cas-sparsity",
                            destination.as_posix(), mountpoint, str(archive)])
                        sample["mount_output"] = stdout
                        start = re.search(r"^CAS_EXTRACT_START=(\d+\.\d+)$", stdout, re.M)
                        end = re.search(r"^CAS_EXTRACT_END=(\d+\.\d+)$", stdout, re.M)
                        if not start or not end:
                            raise ValueError("Missing sparse-mount extraction timing")
                        sample["extraction_seconds"] = float(end[1]) - float(start[1])
                    elif method.startswith("gnu-"):
                        target = destination.as_posix()
                        if method == "gnu-posix-path":
                            target = run([str(bin_dir / "cygpath.exe"), "-u", str(destination)])[0].strip()
                        _, sample["extraction_seconds"] = run([
                            args.gnu_tar, "--force-local", "--extract", "--file", str(archive), "--directory", target])
                    else:
                        flags = ["-S"] if method.endswith("-S") else []
                        _, sample["extraction_seconds"] = run([
                            args.bsd_tar, *flags, "-xf", str(archive), "-C", str(destination)])
                    sample["restored"] = snapshot(api, destination)
                    validate(destination, manifest, sample["restored"])
                    sample["status"] = "complete"
            except (OSError, ValueError, subprocess.CalledProcessError) as error:
                sample.update(status="failed", error=str(error))
                results["errors"].append(f"{method}, trial {trial}: {error}")
            write_report(args.output, results)
    results["status"] = "failed" if results["errors"] else "complete"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cas-path", type=Path, required=True)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--gnu-tar", required=True)
    parser.add_argument("--bsd-tar", required=True)
    parser.add_argument("--standalone-tar")
    parser.add_argument("--round-trip", action="store_true")
    parser.add_argument("--repeats", type=int, choices=range(1, 6), default=3)
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    results = {"status": "running", "schema_version": 2, "round_trip": args.round_trip,
               "repeats": args.repeats, "trials": [], "errors": []}
    try:
        experiment(args, results)
    except Exception as error:
        results.update(status="failed", error=str(error))
        raise
    finally:
        write_report(args.output, results)
    if results["errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
