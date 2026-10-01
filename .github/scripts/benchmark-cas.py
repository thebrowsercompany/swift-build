import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import tempfile
import time


def run(command, env=None):
    print(subprocess.list2cmdline([str(arg) for arg in command]), flush=True)
    start = time.perf_counter()
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    seconds = time.perf_counter() - start
    if result.stdout:
        print(result.stdout, end="", flush=True)
    if result.stderr:
        print(result.stderr, end="", flush=True)
    result.check_returncode()
    return result, seconds


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def median_text(samples, key):
    values = [sample[key] for sample in samples if key in sample]
    if not values:
        return "—"
    return f"{statistics.median(values):.3f} [{min(values):.3f}–{max(values):.3f}]"


def write_results(output, results):
    (output / "results.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    lines = ["# CAS storage benchmark", "", f"Status: **{results['status']}**", ""]
    if "error" in results:
        lines.extend([f"Error: {results['error']}", ""])
    if "logical_bytes" in results:
        lines.extend([
            f"CAS files: {len(results['files']):,}; logical file bytes: {results['logical_bytes']:,}.", "",
        ])
    if "dense_tar_bytes" in results:
        lines.extend([
            f"Normal tar: **{results['dense_tar_bytes']:,} bytes**.",
            "Counted with GNU tar `--totals` writing to `/dev/null`, without expanding sparse holes.",
            f"Counting took {results['dense_count_seconds']:.3f}s; this is not a disk archive creation benchmark.", "",
        ])
    if results.get("archives"):
        lines.extend([
            "| Format | Bytes | Saved vs normal tar | Archive (s) | Compress (s) |",
            "|---|---:|---:|---:|---:|",
        ])
        for archive in results["archives"]:
            saved = results["dense_tar_bytes"] - archive["bytes"]
            percent = 100 * saved / results["dense_tar_bytes"]
            lines.append(
                f"| {archive['file']} | {archive['bytes']:,} | {saved:,} ({percent:.2f}%) | "
                f"{archive['archive_seconds']:.3f} | {archive['compression_seconds']:.3f} |"
            )
        lines.append("")
    if "compression_saved_bytes" in results:
        lines.extend([
            f"Zstandard additionally saved **{results['compression_saved_bytes']:,} bytes "
            f"({results['compression_saved_percent']:.2f}%)** relative to the sparse tar, using `-1 -T0`.", "",
        ])
    if results.get("transfers"):
        lines.extend([
            "Transfer times are medians [min–max] in seconds. Trials include client startup.", "",
            "| Method | Format | Verified trials | Upload (s) | Download (s) |",
            "|---|---|---:|---:|---:|",
        ])
        for method in results["methods"]:
            for archive in results["archives"]:
                samples = [t for t in results["transfers"]
                           if t["method"] == method and t["file"] == archive["file"] and t["status"] == "complete"]
                lines.append(
                    f"| {method} | {archive['file']} | {len(samples)}/{results['repeats']} | "
                    f"{median_text(samples, 'upload_seconds')} | {median_text(samples, 'download_seconds')} |"
                )
        lines.append("")
    if results.get("restores"):
        lines.extend([
            "Restore operations are measured separately on verified downloads, in fresh directories.", "",
            "| Format | Decompress (s) | Extract (s) | Allocated bytes after extraction |",
            "|---|---:|---:|---:|",
        ])
        for archive in results["archives"]:
            samples = [r for r in results["restores"] if r["file"] == archive["file"] and r["status"] == "complete"]
            allocated = f"{samples[-1]['allocated_bytes']:,}" if samples else "—"
            lines.append(
                f"| {archive['file']} | {median_text(samples, 'decompression_seconds')} | "
                f"{median_text(samples, 'extraction_seconds')} | {allocated} |"
            )
        lines.extend([
            "", "| Method | Format | Estimated save (s) | Estimated restore (s) | Save + restore (s) |",
            "|---|---|---:|---:|---:|",
        ])
        for method in results["methods"]:
            for archive in results["archives"]:
                transfers = [t for t in results["transfers"]
                             if t["method"] == method and t["file"] == archive["file"] and t["status"] == "complete"]
                restores = [r for r in results["restores"] if r["file"] == archive["file"] and r["status"] == "complete"]
                if len(transfers) != results["repeats"] or len(restores) != results["repeats"]:
                    continue
                save = archive["archive_seconds"] + archive["compression_seconds"] + statistics.median(t["upload_seconds"] for t in transfers)
                restore = statistics.median(t["download_seconds"] for t in transfers) + statistics.median(
                    r["decompression_seconds"] + r["extraction_seconds"] for r in restores)
                lines.append(f"| {method} | {archive['file']} | {save:.3f} | {restore:.3f} | {save + restore:.3f} |")
        lines.extend([
            "", "Totals require all trials to succeed and combine the separately measured phases. They exclude setup, authentication, hashing, "
            "validation, and cleanup. Extraction checks file names and logical sizes, not a full CAS content comparison.", "",
        ])
    if results.get("errors"):
        lines.extend(["Failures (excluded from timing summaries):", ""])
        lines.extend(f"- {error}" for error in results["errors"])
        lines.append("")
    if "s3_prefix" in results:
        lines.extend([
            f"S3 results and archives: `{results['s3_prefix']}`.",
            "AWS classic uses 10 or 32 concurrent requests and 8 MiB parts. "
            "CRT is explicitly requested with a 10 Gbit/s target and 8 MiB parts; "
            "an untimed probe verifies the selected AWS client. s5cmd uses 32 concurrent parts of 8 MiB.", "",
        ])
    lines.extend([
        "Trials run sequentially, rotating method and archive order between rounds. "
        "Filesystem and remote caches are not flushed; these are not cold-cache guarantees.",
        "Raw trials, throughput, checksums, source revisions, and tool versions are in `results.json`.",
    ])
    (output / "results.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def archive_cas(args, results):
    cas = args.cas_path.resolve(strict=True)
    if args.output == cas or cas in args.output.parents:
        raise ValueError("Archive output must be outside the CAS directory")
    env = dict(os.environ, LC_ALL="C")
    tar_version, _ = run([args.tar, "--version"], env)
    if "GNU tar" not in tar_version.stdout:
        raise ValueError("GNU tar is required to measure --sparse; Windows bsdtar is not supported")
    zstd_version, _ = run([args.zstd, "--version"], env)
    results.update({
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "platform": platform.platform(),
        "cpu_count": os.cpu_count(),
        "tar_version": tar_version.stdout.strip(),
        "zstd_version": zstd_version.stdout.strip(),
    })
    build_file = args.output / "build.json"
    if build_file.exists():
        results["build"] = json.loads(build_file.read_text(encoding="utf-8-sig"))
    files = []
    for path in sorted(cas.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"Unexpected symlink in CAS: {path}")
        if path.is_file():
            files.append({"path": path.relative_to(cas).as_posix(), "logical_bytes": path.stat().st_size})
    results["files"] = files
    results["logical_bytes"] = sum(file["logical_bytes"] for file in files)
    if not results["logical_bytes"]:
        raise ValueError("CAS is empty; no useful benchmark data was produced")
    write_results(args.output, results)

    common = [args.tar, "--force-local", "--format=gnu", "--sort=name", "--create", "--directory", str(cas)]
    # GNU tar can count a normal archive at /dev/null without materializing its holes.
    dense, seconds = run([*common, "--totals", "--file=/dev/null", "."], env)
    match = re.search(r"Total bytes written: (\d+)", dense.stderr)
    if not match:
        raise ValueError("GNU tar did not report an exact normal archive byte count")
    results.update(dense_tar_bytes=int(match[1]), dense_count_seconds=seconds)
    write_results(args.output, results)

    sparse = args.output / "cas.tar"
    compressed = args.output / "cas.tar.zst"
    if sparse.exists() or compressed.exists():
        raise ValueError("Archive output files already exist; use a fresh output directory")
    _, seconds = run([*common, "--sparse", "--file", str(sparse), "."], env)
    sparse_bytes = sparse.stat().st_size
    results["sparse_saved_bytes"] = results["dense_tar_bytes"] - sparse_bytes
    results["sparse_saved_percent"] = 100 * results["sparse_saved_bytes"] / results["dense_tar_bytes"]
    results["archives"] = [{
        "file": sparse.name,
        "bytes": sparse_bytes,
        "sha256": sha256(sparse),
        "archive_seconds": seconds,
        "compression_seconds": 0,
    }]
    write_results(args.output, results)
    _, seconds = run([args.zstd, "-1", "-T0", "--no-progress", str(sparse), "-o", str(compressed)], env)
    compressed_bytes = compressed.stat().st_size
    results["archives"].append({
        "file": compressed.name,
        "bytes": compressed_bytes,
        "sha256": sha256(compressed),
        "archive_seconds": results["archives"][0]["archive_seconds"],
        "compression_seconds": seconds,
    })
    results["compression_saved_bytes"] = sparse_bytes - compressed_bytes
    results["compression_saved_percent"] = 100 * results["compression_saved_bytes"] / sparse_bytes
    write_results(args.output, results)
    _, seconds = run([args.zstd, "--test", str(compressed)], env)
    results["compression_validation_seconds"] = seconds
    results["status"] = "ready_to_upload"


def copy_command(args, method, source, destination):
    if method == "s5cmd-32":
        return [args.s5cmd, "--numworkers", "1", "cp", "--concurrency", "32", "--part-size", "8", str(source), str(destination)]
    return [args.aws, "s3", "cp", str(source), str(destination), "--region", args.region,
            "--no-progress", "--only-show-errors"]


def verify_download(path, archive):
    if path.stat().st_size != archive["bytes"] or sha256(path) != archive["sha256"]:
        raise ValueError(f"Downloaded archive does not match its source: {path.name}")


def allocated_bytes(paths):
    if os.name != "nt":
        return sum(path.stat().st_blocks * 512 for path in paths)
    import ctypes
    from ctypes import wintypes
    size = ctypes.WinDLL("kernel32", use_last_error=True).GetCompressedFileSizeW
    size.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.DWORD)]
    size.restype = wintypes.DWORD
    total = 0
    for path in paths:
        high = wintypes.DWORD()
        ctypes.set_last_error(0)
        low = size(str(path), ctypes.byref(high))
        if low == 0xFFFFFFFF and ctypes.get_last_error():
            raise ctypes.WinError(ctypes.get_last_error())
        total += (high.value << 32) | low
    return total


def measure_restores(args, results, downloads):
    results["status"] = "restoring"
    expected = {file["path"]: file["logical_bytes"] for file in results["files"]}
    env = dict(os.environ, LC_ALL="C")
    for trial in range(1, args.repeats + 1):
        archives = results["archives"] if trial % 2 else list(reversed(results["archives"]))
        for archive in archives:
            downloaded = downloads / archive["file"]
            if not downloaded.exists():
                continue
            sample = {"file": archive["file"], "trial": trial, "status": "running"}
            results["restores"].append(sample)
            try:
                with tempfile.TemporaryDirectory(prefix="restore-", dir=args.output) as directory:
                    directory = Path(directory)
                    source = downloaded
                    sample["decompression_seconds"] = 0
                    if archive["file"].endswith(".zst"):
                        source = directory / "cas.tar"
                        _, sample["decompression_seconds"] = run([
                            args.zstd, "--decompress", "--no-progress", str(downloaded), "-o", str(source)], env)
                        sparse = results["archives"][0]
                        verify_download(source, sparse)
                    destination = directory / "cas"
                    destination.mkdir()
                    _, sample["extraction_seconds"] = run([
                        args.tar, "--force-local", "--extract", "--file", str(source), "--directory", str(destination)], env)
                    files = [path for path in destination.rglob("*") if path.is_file()]
                    restored = {path.relative_to(destination).as_posix(): path.stat().st_size for path in files}
                    if restored != expected:
                        raise ValueError("Extracted file names or logical sizes differ from the original CAS")
                    sample["allocated_bytes"] = allocated_bytes(files)
                    sample["status"] = "complete"
            except (OSError, ValueError, subprocess.CalledProcessError) as error:
                sample.update(status="failed", error=str(error))
                results["errors"].append(f"Restore {archive['file']} trial {trial}: {error}")
            write_results(args.output, results)


def transfer_archives(args, results):
    if results["status"] != "ready_to_upload":
        raise ValueError("Archive creation and compression validation must succeed before transferring")
    if args.repeats < 1:
        raise ValueError("At least one trial is required")
    prefix = args.prefix.strip("/")
    if not prefix.startswith("cas-benchmark/"):
        raise ValueError("Use a run-specific prefix under cas-benchmark/")
    results.update(status="transferring", repeats=args.repeats, transfers=[], restores=[], errors=[])
    results["s3_prefix"] = f"s3://{args.bucket}/{prefix}"
    classic = {"preferred_transfer_client": "classic", "max_concurrent_requests": 10,
               "multipart_threshold": "8MB", "multipart_chunksize": "8MB"}
    results["methods"] = {
        "aws-classic-10": classic,
        "aws-classic-32": dict(classic, max_concurrent_requests=32),
        "aws-crt": {"preferred_transfer_client": "crt", "multipart_chunksize": "8MB", "target_bandwidth": "1250000000"},
        "s5cmd-32": {"concurrency": 32, "part_size_mib": 8, "numworkers": 1},
    }
    version, _ = run([args.aws, "--version"])
    results["aws_version"] = version.stdout.strip()
    version, _ = run([args.s5cmd, "version"])
    results["s5cmd_version"] = version.stdout.strip()
    for archive in results["archives"]:
        verify_download(args.output / archive["file"], archive)
    with tempfile.TemporaryDirectory(prefix="transfer-", dir=args.output) as directory:
        directory = Path(directory)
        downloads = directory / "downloads"
        downloads.mkdir()
        environments = {}
        results["client_probes"] = {}
        probe = directory / "probe.txt"
        probe.write_text("CAS transfer client probe\n", encoding="utf-8")
        for method, settings in results["methods"].items():
            config = directory / f"{method}.config"
            s3_settings = classic if method == "s5cmd-32" else settings
            values = "".join(f"    {key} = {value}\n" for key, value in s3_settings.items())
            config.write_text(f"[default]\nregion = {args.region}\ns3 =\n" + values, encoding="utf-8")
            env = dict(os.environ, AWS_CONFIG_FILE=str(config), AWS_PROFILE="default", AWS_DEFAULT_PROFILE="default",
                       AWS_REGION=args.region, AWS_DEFAULT_REGION=args.region)
            if method != "s5cmd-32":
                command = copy_command(args, method, probe, f"{results['s3_prefix']}/{method}/probe.txt")
                # Debug output can contain credentials. Inspect it in memory and never publish it.
                result = subprocess.run([*command, "--debug"], capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
                actual = "unknown"
                if "Using a multipart threshold of" in result.stderr:
                    actual = "classic"
                elif "Using CRT throughput target in gbps:" in result.stderr:
                    actual = "crt"
                results["client_probes"][method] = {"requested": settings["preferred_transfer_client"], "actual": actual,
                                                   "returncode": result.returncode}
                if result.returncode or actual != settings["preferred_transfer_client"]:
                    results["errors"].append(f"{method}: client probe failed (exit {result.returncode}, selected {actual}); excluded")
                    continue
            environments[method] = env
        write_results(args.output, results)
        cases = [(method, archive) for method in environments for archive in results["archives"]]
        for trial in range(1, args.repeats + 1):
            offset = ((trial - 1) * 3) % len(cases)
            for method, archive in cases[offset:] + cases[:offset]:
                uri = f"{results['s3_prefix']}/{method}/{archive['file']}"
                sample = {"method": method, "file": archive["file"], "trial": trial, "s3_uri": uri, "status": "running"}
                results["transfers"].append(sample)
                destination = downloads / f"candidate-{archive['file']}"
                destination.unlink(missing_ok=True)
                try:
                    _, sample["upload_seconds"] = run(copy_command(args, method, args.output / archive["file"], uri), environments[method])
                    _, sample["download_seconds"] = run(copy_command(args, method, uri, destination), environments[method])
                    verify_download(destination, archive)
                    destination.replace(downloads / archive["file"])
                    for direction in ("upload", "download"):
                        sample[f"{direction}_mib_per_second"] = archive["bytes"] / (1024 * 1024 * sample[f"{direction}_seconds"])
                    sample["status"] = "complete"
                except (OSError, ValueError, subprocess.CalledProcessError) as error:
                    destination.unlink(missing_ok=True)
                    sample.update(status="failed", error=str(error))
                    results["errors"].append(f"{method} {archive['file']} trial {trial}: {error}")
                write_results(args.output, results)
        measure_restores(args, results, downloads)
        results["status"] = "complete_with_errors" if results["errors"] else "complete"
        write_results(args.output, results)
        for name in ("results.json", "results.md"):
            run([args.aws, "s3", "cp", str(args.output / name), f"{results['s3_prefix']}/{name}",
                 "--region", args.region, "--no-progress", "--only-show-errors"],
                dict(os.environ, AWS_CONFIG_FILE=str(directory / "aws-classic-10.config"), AWS_PROFILE="default"))


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    archive = commands.add_parser("archive")
    archive.add_argument("--cas-path", type=Path, required=True)
    archive.add_argument("--output", type=Path, required=True)
    archive.add_argument("--tar", required=True)
    archive.add_argument("--zstd", required=True)
    transfer = commands.add_parser("transfer")
    transfer.add_argument("--output", type=Path, required=True)
    transfer.add_argument("--bucket", required=True)
    transfer.add_argument("--prefix", required=True)
    transfer.add_argument("--region", required=True)
    transfer.add_argument("--aws", default="aws")
    transfer.add_argument("--s5cmd", required=True)
    transfer.add_argument("--tar", required=True)
    transfer.add_argument("--zstd", required=True)
    transfer.add_argument("--repeats", type=int, default=3)
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    results = {"status": "archiving", "schema_version": 2}
    if args.command == "transfer":
        results = json.loads((args.output / "results.json").read_text(encoding="utf-8"))
    try:
        if args.command == "archive":
            archive_cas(args, results)
        else:
            transfer_archives(args, results)
    except Exception as error:
        results.update(status="failed", error=str(error))
        raise
    finally:
        write_results(args.output, results)
    if results.get("errors"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
