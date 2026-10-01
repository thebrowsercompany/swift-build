import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
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


def write_results(output, results):
    (output / "results.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    lines = ["# CAS storage benchmark", "", f"Status: **{results['status']}**", ""]
    if "error" in results:
        lines.extend([f"Error: {results['error']}", ""])
    if "logical_bytes" in results:
        lines.extend([
            f"CAS files: {len(results['files']):,}; logical file bytes: {results['logical_bytes']:,}.",
            "",
        ])
    if "dense_tar_bytes" in results:
        lines.extend([
            f"Normal tar: **{results['dense_tar_bytes']:,} bytes**.",
            "Measured with GNU tar `--totals` writing to `/dev/null`; this avoids storing the expanded sparse files.",
            f"Counting took {results['dense_count_seconds']:.3f}s; this is not a disk archive creation benchmark.",
            "",
        ])
    if results.get("archives"):
        lines.extend([
            "| Format | Bytes | Saved vs normal tar | Archive (s) | Compress (s) | Upload (s) | Upload MiB/s | Total save (s) |",
            "|---|---:|---:|---:|---:|---:|---:|---:|",
        ])
        for archive in results["archives"]:
            saved = results["dense_tar_bytes"] - archive["bytes"]
            percent = 100 * saved / results["dense_tar_bytes"]
            upload = archive.get("upload_seconds")
            upload_text = f"{upload:.3f}" if upload is not None else "—"
            rate = f"{archive['upload_mib_per_second']:.2f}" if upload is not None else "—"
            total = archive["archive_seconds"] + archive["compression_seconds"]
            total_text = f"{total + upload:.3f}" if upload is not None else "—"
            lines.append(
                f"| {archive['file']} | {archive['bytes']:,} | {saved:,} ({percent:.2f}%) | "
                f"{archive['archive_seconds']:.3f} | {archive['compression_seconds']:.3f} | "
                f"{upload_text} | {rate} | {total_text} |"
            )
        lines.extend([
            "",
            "Total save = sparse archive creation + compression, if any + upload. "
            "It excludes authentication, validation, hashing, and benchmark setup.",
            "",
        ])
    if "compression_saved_bytes" in results:
        lines.extend([
            f"Zstandard additionally saved **{results['compression_saved_bytes']:,} bytes "
            f"({results['compression_saved_percent']:.2f}%)** relative to the sparse tar, using `-1 -T0`.",
            "",
        ])
    if "s3_prefix" in results:
        lines.extend([
            f"S3 results and archives: `{results['s3_prefix']}`.",
            "Uploads use the AWS CLI classic client, 10 concurrent requests, and 8 MiB multipart chunks.",
            "",
        ])
    lines.extend([
        "Each variant is measured once, sequentially, on the same data. Filesystem caching can affect timings.",
        "Exact byte counts, checksums, source revisions, tool versions, and validation timings are in `results.json`.",
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


def upload_archives(args, results):
    if results["status"] != "ready_to_upload":
        raise ValueError("Archive creation and compression validation must succeed before uploading")
    prefix = args.prefix.strip("/")
    if not prefix.startswith("cas-benchmark/"):
        raise ValueError("Use a run-specific prefix under cas-benchmark/")
    results["status"] = "uploading"
    results["s3_prefix"] = f"s3://{args.bucket}/{prefix}"
    results["aws_s3_config"] = {
        "preferred_transfer_client": "classic",
        "max_concurrent_requests": 10,
        "multipart_threshold": "8MB",
        "multipart_chunksize": "8MB",
    }
    with tempfile.TemporaryDirectory(prefix="cas-aws-") as directory:
        config = Path(directory) / "config"
        settings = "".join(f"    {key} = {value}\n" for key, value in results["aws_s3_config"].items())
        config.write_text("[default]\ns3 =\n" + settings, encoding="utf-8")
        env = dict(os.environ, AWS_CONFIG_FILE=str(config), AWS_PROFILE="default", AWS_DEFAULT_PROFILE="default")
        version, _ = run([args.aws, "--version"], env)
        results["aws_version"] = version.stdout.strip()
        for archive in results["archives"]:
            file = args.output / archive["file"]
            if file.stat().st_size != archive["bytes"] or sha256(file) != archive["sha256"]:
                raise ValueError(f"Archive changed after measurement: {file}")
            uri = f"{results['s3_prefix']}/{file.name}"
            _, seconds = run([
                args.aws, "s3", "cp", str(file), uri, "--region", args.region,
                "--no-progress", "--only-show-errors",
            ], env)
            archive.update(
                s3_uri=uri,
                upload_seconds=seconds,
                upload_mib_per_second=archive["bytes"] / (1024 * 1024 * seconds),
            )
            write_results(args.output, results)
        results["status"] = "complete"
        write_results(args.output, results)
        for name in ["results.json", "results.md"]:
            run([
                args.aws, "s3", "cp", str(args.output / name), f"{results['s3_prefix']}/{name}",
                "--region", args.region, "--no-progress", "--only-show-errors",
            ], env)


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    archive = commands.add_parser("archive")
    archive.add_argument("--cas-path", type=Path, required=True)
    archive.add_argument("--output", type=Path, required=True)
    archive.add_argument("--tar", required=True)
    archive.add_argument("--zstd", required=True)
    upload = commands.add_parser("upload")
    upload.add_argument("--output", type=Path, required=True)
    upload.add_argument("--bucket", required=True)
    upload.add_argument("--prefix", required=True)
    upload.add_argument("--region", required=True)
    upload.add_argument("--aws", default="aws")
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    results = {"status": "archiving", "schema_version": 1}
    if args.command == "upload":
        results = json.loads((args.output / "results.json").read_text(encoding="utf-8"))
    try:
        if args.command == "archive":
            archive_cas(args, results)
        else:
            upload_archives(args, results)
    except Exception as error:
        results.update(status="failed", error=str(error))
        raise
    finally:
        write_results(args.output, results)


if __name__ == "__main__":
    main()
