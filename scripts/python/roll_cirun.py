#!/usr/bin/python3

"""Rolls Azure VM images used by cirun.

These base images have a reduced set of preinstalled software compared to the
GitHub hosted runners.
"""

import argparse
import glob
import os
import re
import subprocess
import sys


def rewrite(filepath, regexpairs):
    with open(filepath) as f:
        old_data = f.read()
    data = old_data
    for pattern, repl in regexpairs:
        data = re.sub(pattern, repl, data)
    if old_data != data:
        print(f"Updated {filepath}")
        with open(filepath, "w") as f:
            f.write(data)


def main():
    os.chdir(subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).rstrip())
    parser = argparse.ArgumentParser(description=sys.modules[__name__].__doc__)
    parser.add_argument(
        "--version", required=True, help="New version to roll to in form YYYY-MM-DD"
    )
    args = parser.parse_args()
    if not re.match(r"^\d\d\d\d-\d\d-\d\d$", args.version):
        parser.error("--version must be in form YYYY-MM-DD")
    regexpairs = [
        (
            r"cirun-win(\d+)-(\w+)-pro-(\w+)-(\d+)-(\d+)-(\d+)-(\d+)",
            r"cirun-win\1-\2-pro-\3-\4-" + args.version,
        ),
    ]

    for filepath in glob.glob(".github/workflows/*.y*"):
        rewrite(filepath, regexpairs)

    regexpairs.append(
        (
            r"\/win(\d+)-(\w+)-(\w+)-(\w+)\/versions\/\d+\.\d+\.\d+",
            r"/win\1-\2-\3-\4/versions/" + args.version.replace("-", "."),
        ),
    )
    rewrite(".cirun.yml", regexpairs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
