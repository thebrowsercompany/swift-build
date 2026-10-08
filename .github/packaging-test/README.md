# Build-tools packaging replay

Temporary harness for `speednoisemovement/package_split`. It runs the production
build-tools matrix for AMD64/ARM64 and Asserts/NoAsserts, using artifacts from
[37306923447](https://github.com/thebrowsercompany/swift-build/actions/runs/37306923447).
Packaging inputs and source revisions are pinned to that run. Other build,
installer, release and snapshot jobs are disabled on this test branch.

After committing and pushing the harness, run:

```sh
gh workflow run build-toolchain.yml \
  --repo thebrowsercompany/swift-build \
  --ref speednoisemovement/package_split
```

The existing `Development Snapshot` workflow is the entry point. It accepts
manual dispatch only on this branch and forces signed packages, debug information,
version `0.0.0`, and x64 Windows runners. The matrix also packages ARM64 tools.
No toolchain rebuild or installation smoke test runs.

The preflight checks that the pinned source and comparison runs succeeded and
that all required artifacts remain available. Each Windows job checks the staged
toolchain against the original preparation rules, then verifies the MSI and CAB
signatures against the shared signing certificate.

Four Linux jobs extract the new MSIs and the corresponding packages from the
[previous successful replay](https://github.com/thebrowsercompany/swift-build/actions/runs/37470540240).
They require matching file paths and SHA-256 hashes, including FoundationMacros
and TestingMacros. The rebuilt `mimalloc.dll` may differ; that difference is
reported separately and is the only excluded content hash. Added or missing
files always fail, including a missing `mimalloc.dll`.

Results appear in job summaries, `build-tools-layout-*` inventories, and
`build-tools-comparison-*` reports. The normal four `Windows-*-bld-*-msi` artifacts
contain the new MSI/CAB pairs. Artifact expiry or a changed source run requires
updating the pinned context and baseline together.

Local checks:

```sh
python3 -m unittest discover -s .github/packaging-test -p 'test_*.py'
actionlint -shellcheck= -pyflakes= \
  -ignore '^unexpected key "description" for "workflow" section' \
  -ignore '^constant expression "false" in condition' \
  .github/workflows/build-toolchain.yml .github/workflows/swift-toolchain.yml
```

The first lint exclusion is pre-existing; the second covers the deliberately
disabled jobs in this temporary harness. Windows execution is still required to
validate packaging and signing.
