import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def inventory(root):
    result = {}
    for path in sorted(root.rglob('*')):
        if path.is_file():
            digest = hashlib.sha256()
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
            result[path.relative_to(root).as_posix()] = digest.hexdigest()
    if not result:
        raise ValueError(f'No payload files in {root}')
    return result


def compare(baseline, candidate, variant):
    prefix = f'PFiles64/Swift/Toolchains/0.0.0+{variant}/usr/bin/'
    macros = [prefix + name for name in ('FoundationMacros.dll', 'TestingMacros.dll')]
    changed = sorted(path for path in baseline.keys() & candidate.keys() if baseline[path] != candidate[path])
    rebuilt = [path for path in changed if path == prefix + 'mimalloc.dll']
    result = {
        'baseline_file_count': len(baseline),
        'candidate_file_count': len(candidate),
        'added': sorted(candidate.keys() - baseline.keys()),
        'removed': sorted(baseline.keys() - candidate.keys()),
        'changed': [path for path in changed if path not in rebuilt],
        'rebuilt_mimalloc_changes': rebuilt,
        'missing_macros': [path for path in macros if path not in baseline or path not in candidate],
    }
    result['passed'] = bool(baseline) and bool(candidate) and not any(result[key] for key in ('added', 'removed', 'changed', 'missing_macros'))
    return result


def extract(directory, output, variant):
    package = directory / f'bld.{variant.lower()}.msi'
    cabinet = package.with_suffix('.cab')
    if not package.is_file() or not cabinet.is_file():
        raise FileNotFoundError(f'Expected MSI and CAB in {directory}')
    output.mkdir()
    with (directory / 'extraction.log').open('w') as log:
        subprocess.run(['msiextract', '-C', str(output), str(package.resolve())], stdout=log, stderr=subprocess.STDOUT, check=True)
    return inventory(output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--variant', choices=['Asserts', 'NoAsserts'], required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='build-tools-payloads-') as directory:
        root = Path(directory)
        baseline = extract(args.baseline, root / 'baseline', args.variant)
        candidate = extract(args.candidate, root / 'candidate', args.variant)
        result = compare(baseline, candidate, args.variant)
    args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as summary:
            summary.write(f"\nPayload comparison: {'passed' if result['passed'] else 'FAILED'}. "
                          f"Baseline: {result['baseline_file_count']} files; candidate: {result['candidate_file_count']} files.\n")
            if result['rebuilt_mimalloc_changes']:
                summary.write('\nThe rebuilt `mimalloc.dll` differs; its hash is excluded from the equality check. All other payload files must match exactly.\n')
    if not result['passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
