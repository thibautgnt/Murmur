#!/usr/bin/env python3
"""Fast repository checks that catch bad upstream merges before any Xcode build."""
import json
import re
import subprocess
import sys

errors = []

markers = subprocess.run(
    ["git", "grep", "-nE", "^(<<<<<<<|>>>>>>>)( |$)", "--", ".", ":!*.png", ":!*.jpg"],
    capture_output=True, text=True,
).stdout.strip()
if markers:
    errors.append("Merge conflict markers left in:\n" + markers)

# Murmur keeps "VoiceInk" only in the "VoiceInk Refine" model name for anything users read.
visible_voiceink = re.compile(r"VoiceInk(?! Refine)")


def strings_in(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, item in value.items():
            if key != "comment":
                yield from strings_in(item)


for catalog in ("VoiceInk/Localizable.xcstrings", "VoiceInk/InfoPlist.xcstrings"):
    try:
        with open(catalog, encoding="utf-8") as handle:
            entries = json.load(handle)["strings"]
    except (OSError, ValueError, KeyError) as error:
        errors.append(f"{catalog} is not a valid string catalog: {error}")
        continue
    for key, entry in entries.items():
        hits = [text for text in [key, *strings_in(entry)] if visible_voiceink.search(text)]
        if hits:
            errors.append(f"{catalog}: \"{key[:80]}\" still shows VoiceInk")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("Repository checks passed")
