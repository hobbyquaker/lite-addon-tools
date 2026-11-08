#!/usr/bin/env python3
"""Prints share/VERSIONS: the version of each package in the addon, from `make show-info`.

    versions.py <show-info.json> <buildroot version> <package>...
"""
import json
import sys

info = json.load(open(sys.argv[1]))
print(f"# lite-addon-tools: the packages inside, as Buildroot {sys.argv[2]} built them")
tc = next((v for k, v in info.items() if k.startswith('toolchain-external-bootlin')), None)
if tc:
    print(f"toolchain-external-bootlin {tc.get('version', '?')}")
missing = []
for p in sys.argv[3:]:
    if p not in info:
        missing.append(p)
        continue
    print(f"{p} {info[p].get('version', '?')}")
if missing:
    sys.exit(f"not in show-info: {' '.join(missing)}")
