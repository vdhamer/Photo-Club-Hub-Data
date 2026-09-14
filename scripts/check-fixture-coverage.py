#!/usr/bin/env python3
"""Check that the test fixtures still contain every field the production JSON files use.

The package tests read frozen copies of the JSON files (README.md, "Tests run against frozen data"), so
editing production data cannot turn the suite red. The price is that nothing in the suite notices when
production gains a field the fixtures lack: a new JSON feature then ships without any test having read it.

This compares structure, not content. Every key path used by any production file of a level, such as
`members[].optional.birthday`, must occur in at least one fixture of that level. Adding a member or an
expertise changes no key path, so everyday data edits pass; a new field, or a field put in the wrong
place, fails. New values (a new expertise id) go unnoticed. And a key path occurring in a fixture does not
mean a test asserts on it, so a failure means: add the field to a fixture, re-check the counts the tests
assert, and consider a test for the new field. Or, if the field is simply misplaced, fix the production file.

Usage:  check-fixture-coverage.py <fixture directory> <production JSON directory>...
The fixture directory holds Level0/, Level1/ and Level2/. Several production directories are merged,
because the iOS repo's JSON/ and this package's copy do not hold exactly the same set of files (Data#7).
Exits non-zero if production uses a key path no fixture has, if a production file does not parse, or if
a level has nothing to compare on either side.
"""
import glob
import json
import os
import sys

LEVELS = (0, 1, 2)


def key_paths(node, prefix=""):
    """Every key path in a JSON document. Array elements are written as [], so that members[3] and
    members[40] count as the same path."""
    paths = set()
    if isinstance(node, dict):
        for key, value in node.items():
            path = f"{prefix}.{key}" if prefix else key
            paths.add(path)
            paths |= key_paths(value, path)
    elif isinstance(node, list):
        for value in node:
            paths |= key_paths(value, prefix + "[]")
    return paths


def load(path):
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: check-fixture-coverage.py <fixture directory> <production JSON directory>...")

    fixture_dir, production_dirs = sys.argv[1], sys.argv[2:]
    failed = False

    for level in LEVELS:
        pattern = f"*.level{level}.json"

        # Which production files use each key path, so that a failure says where to look.
        used_in = {}
        for directory in production_dirs:
            for path in sorted(glob.glob(os.path.join(directory, pattern))):
                try:
                    document = load(path)
                except ValueError as error:
                    print(f"::error::{path} does not parse, so its fields were not checked: {error}")
                    failed = True
                    continue
                for key_path in key_paths(document):
                    used_in.setdefault(key_path, set()).add(os.path.basename(path))

        # Deliberately malformed fixtures (garbage, truncated) exist to test the readers' error handling
        # and contribute no key paths, so a fixture that does not parse is skipped rather than reported.
        covered = set()
        for path in glob.glob(os.path.join(fixture_dir, f"Level{level}", pattern)):
            try:
                covered |= key_paths(load(path))
            except ValueError:
                pass

        # A wrong directory would leave a side empty, and the check would pass having compared nothing.
        # Silence is not success.
        if not used_in or not covered:
            print(f"::error::Level {level}: found no production files or no fixtures to compare.")
            failed = True
            continue

        missing = sorted(set(used_in) - covered)
        for key_path in missing:
            files = sorted(used_in[key_path])
            where = ", ".join(files[:3]) + (f" and {len(files) - 3} more" if len(files) > 3 else "")
            print(f"::error::Level {level}: {key_path} is used in {where} but occurs in no fixture.")
        if missing:
            failed = True
        print(f"Level {level}: {len(used_in)} key paths in production, {len(missing)} missing from the fixtures.")

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
