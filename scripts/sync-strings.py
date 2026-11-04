#!/usr/bin/env python3
"""Syncs FingerPick/Resources/Localizable.xcstrings with the strings the compiler extracted.

Xcode updates String Catalogs when building in the IDE. Command-line builds don't, so CI and
scripted builds run this after `xcodebuild build` (SWIFT_EMIT_LOC_STRINGS=YES):

    scripts/sync-strings.py <DerivedData>/Build/Intermediates.noindex [--check]

New keys are added, keys no longer in code are marked stale, and the plural forms below are
written for the development language (en-AU). --check exits 1 if the catalogue is out of date.
"""
import json
import pathlib
import sys

CATALOGUE = pathlib.Path(__file__).resolve().parent.parent / "FingerPick/Resources/Localizable.xcstrings"
LANGUAGE = "en-AU"

# Keys with a count, and their singular form.
PLURALS = {
    "%lld fingers down": "%lld finger down",
    "Waiting for at least %lld fingers": "Waiting for at least %lld finger",
    "Best with up to %lld players": "Best with up to %lld player",
    "Split into %lld teams": "Split into %lld team",
    "Needs at least %lld fingers, so someone is left out.": "Needs at least %lld finger, so someone is left out.",
}


def extracted(intermediates: pathlib.Path) -> dict[str, str]:
    keys: dict[str, str] = {}
    # App and widget targets (they share the catalogue), not tests.
    paths = []
    for target in ("FingerPick", "FingerPickWidgets"):
        paths += intermediates.glob(f"FingerPick.build/*/{target}.build/Objects-normal/*/*.stringsdata")
    for path in sorted(paths):
        data = json.loads(path.read_text())
        for entry in data.get("tables", {}).get("Localizable", []):
            keys.setdefault(entry["key"], entry.get("comment", ""))
    return keys


def plural(one: str, other: str) -> dict:
    unit = lambda value: {"stringUnit": {"state": "translated", "value": value}}
    return {LANGUAGE: {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}}


def main() -> int:
    intermediates = pathlib.Path(sys.argv[1])
    check = "--check" in sys.argv
    found = extracted(intermediates)
    if not found:
        print(f"No .stringsdata under {intermediates}; build first.", file=sys.stderr)
        return 1

    catalogue = json.loads(CATALOGUE.read_text())
    before = json.dumps(catalogue, sort_keys=True)
    strings = catalogue.setdefault("strings", {})
    for key, comment in found.items():
        entry = strings.setdefault(key, {})
        entry.pop("extractionState", None)
        if comment:
            entry["comment"] = comment
        if key in PLURALS:
            entry["localizations"] = plural(PLURALS[key], key)
    for key, entry in strings.items():
        if key not in found:
            entry["extractionState"] = "stale"
    catalogue["sourceLanguage"] = LANGUAGE
    catalogue["strings"] = dict(sorted(strings.items()))

    if json.dumps(catalogue, sort_keys=True) == before:
        print(f"{CATALOGUE.name} is up to date ({len(found)} strings).")
        return 0
    if check:
        print(f"{CATALOGUE.name} is out of date; run scripts/sync-strings.py.", file=sys.stderr)
        return 1
    CATALOGUE.write_text(json.dumps(catalogue, indent=2, ensure_ascii=False, separators=(",", " : ")) + "\n")
    print(f"Updated {CATALOGUE.name} ({len(found)} strings).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
