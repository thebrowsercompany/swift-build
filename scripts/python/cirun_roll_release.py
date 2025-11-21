#!/usr/bin/env python3
#
# Adds new CIRun runner definitions pinned for a new release:
# 1. Copies the main branch block.
# 2. Adds a new release block with the given version
# 3. Dates the runner names with the current date
# 4. Inserts the new release block after the main block
# 5. Updates the .cirun.yml file in-place

import sys
import datetime
import re
from pathlib import Path

def main():
    if len(sys.argv) != 2:
        print("Usage: python cirun_roll_release.py <release_version>  # e.g. 6.3")
        sys.exit(1)

    release_version = sys.argv[1]
    cirun_path = Path(__file__).parent.parent.parent / ".cirun.yml"

    if not cirun_path.exists():
        print("Error: .cirun.yml not found in root.")
        sys.exit(1)

    text = cirun_path.read_text(encoding="utf-8")

    main_header = "# Build definitions used in main branch"
    release_header = f"# Build definitions used by release/{release_version}"

    main_idx = text.find(main_header)
    if main_idx == -1:
        print(f"Error: Could not find '{main_header}' in .cirun.yml")
        sys.exit(1)

    # Find the end of the main-branch block: it runs from immediately after
    # its header until just before the next '# Build definitions used by release/'
    after_main_header_idx = main_idx + len(main_header)

    # Search for the next release header AFTER the main header
    # The release header comment is indented with 2 spaces: "  # Build definitions used by release/X.X"
    release_header_pattern = r"^  # Build definitions used by release/\d+\.\d+"
    next_release_match = re.search(release_header_pattern, text[after_main_header_idx:], re.MULTILINE)
    
    if next_release_match:
        # Match position is relative to after_main_header_idx, convert to absolute
        match_start_relative = next_release_match.start()
        match_start_absolute = after_main_header_idx + match_start_relative

        # Find the start of the line containing this match (go back to previous newline)
        # We want main_block_end_idx to point to the start of the release header line
        # Search from after_main_header_idx to avoid finding newlines before the main block
        line_start_before_match = text.rfind("\n", after_main_header_idx, match_start_absolute)
        if line_start_before_match == -1:
            # No newline found between main header and match, so match is on first line after main
            main_block_end_idx = after_main_header_idx
        else:
            main_block_end_idx = line_start_before_match + 1  # +1 to point after the newline
    else:
        # No release blocks exist yet, so main block goes to end of file
        main_block_end_idx = len(text)

    # Extract just the YAML content from the main block (everything after the header line)
    # Find the first newline after the main header
    first_newline_after_main = text.find("\n", main_idx)
    if first_newline_after_main == -1:
        print("Error: Malformed main branch block (no newline after header).")
        sys.exit(1)

    # Extract the body: from after the newline to the end of the main block
    # Strip any trailing whitespace/newlines from the main block body
    main_block_body = text[first_newline_after_main + 1:main_block_end_idx].rstrip()

    # Build new header for this release (indented with 2 spaces to match YAML structure)
    new_header = f"  # Build definitions used by release/{release_version}"

    # Build the new block content
    new_block = new_header + "\n" + main_block_body

    # Now adjust labels: each 'labels:' block has one or more lines with
    # '      - cirun-...' – we want to append '-YYYY-MM-DD' to each value.
    today_str = datetime.date.today().strftime("%Y-%m-%d")

    def append_date_to_label(match: re.Match) -> str:
        # Entire match is like:
        # '      - cirun-win11-pro-arm64-16'
        indent = match.group("indent")
        value = match.group("value")
        # Avoid double-appending if someone ran it twice on an already-dated label
        if re.search(r"-\d{4}-\d{2}-\d{2}$", value):
            new_value = value  # already dated; leave as-is
        else:
            new_value = f"{value}-{today_str}"
        return f"{indent}- {new_value}"

    label_pattern = re.compile(r"(?P<indent>\s*)-\s+(?P<value>cirun-[^\s#]+)")

    new_block_dated = label_pattern.sub(append_date_to_label, new_block)

    # Insert the new release block between main block and first release block
    insert_pos = main_block_end_idx
    # Strip trailing whitespace from main block
    prefix_text = text[:insert_pos].rstrip()
    suffix_text = text[insert_pos:]
    # Ensure blank lines: one between main block and new block, one between new block and next release
    # Strip trailing newlines from new_block_dated, then add proper spacing
    new_block_clean = new_block_dated.rstrip("\n")
    updated_text = prefix_text + "\n\n" + new_block_clean + "\n\n" + suffix_text.lstrip("\n")

    cirun_path.write_text(updated_text, encoding="utf-8")
    print(f"Updated .cirun.yml for release/{release_version} with new dated block from main branch.")

if __name__ == "__main__":
    main()
