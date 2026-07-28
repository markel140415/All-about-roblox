#!/usr/bin/env python3
"""
Bundles src/ into installable Roblox Studio plugin files.

Outputs (into build/):
  AnimTeacher.luau  - a single self-contained plugin script
  AnimTeacher.rbxmx - the same script wrapped as a Roblox model file

Roblox plugins that live in the local Plugins folder must be one file, so the
ModuleScript tree in src/ is flattened into a table of factory functions with
a tiny require shim. Module semantics (single evaluation, cached result) are
preserved.

Usage:  python3 tools/build.py
"""
import os
import sys
import html
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bundler  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
BUILD = os.path.join(ROOT, "build")

ENTRY = "Main"

HEADER = """--[[
	AnimTeacher — AI Animation Teacher for Roblox Studio
	Учитель анимации для Roblox Studio

	GENERATED FILE — do not edit by hand.
	Source lives in src/; rebuild with:  python3 tools/build.py

	Install:
	  1. In Studio, insert a Script into ServerStorage.
	  2. Paste this entire file into it.
	  3. Right-click the script -> "Save as Local Plugin".
	  4. Delete the original script from ServerStorage.
	  5. The plugin appears on the Plugins tab as "Animation Teacher".

	Built: {built}
	Modules: {count}
]]
"""

SHIM = """
local __modules = {}
local __cache = {}

local function __require(name)
	local cached = __cache[name]
	if cached ~= nil then
		return cached
	end
	local factory = __modules[name]
	if factory == nil then
		error("AnimTeacher: module not found: " .. tostring(name), 2)
	end
	-- Mark before running so a cyclic require fails loudly instead of hanging.
	__cache[name] = false
	local result = factory()
	if result == nil then
		result = true
	end
	__cache[name] = result
	return result
end
"""


def build_bundle():
    modules = bundler.discover(SRC)
    if not modules:
        raise SystemExit("no modules found in src/")

    names = [name for name, _ in modules]
    if ENTRY not in names:
        raise SystemExit(f"entry module {ENTRY!r} not found in src/")

    parts = [
        HEADER.format(
            built=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
            count=len(modules),
        ),
        SHIM,
    ]

    for module_path, file_path in modules:
        source = bundler.rewrite(module_path, bundler.read(file_path), call="__require")
        parts.append(f'\n__modules["{module_path}"] = function()\n')
        # Indent one level so the bundle stays readable.
        for line in source.splitlines():
            parts.append(("\t" + line).rstrip() + "\n")
        parts.append("end\n")

    parts.append(f'\nreturn __require("{ENTRY}")\n')
    return "".join(parts), len(modules)


RBXMX_TEMPLATE = """<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" \
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
  <Item class="Script" referent="RBX0">
    <Properties>
      <string name="Name">AnimTeacher</string>
      <token name="RunContext">0</token>
      <bool name="Disabled">false</bool>
      <ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>
    </Properties>
  </Item>
</roblox>
"""


def main():
    os.makedirs(BUILD, exist_ok=True)

    bundle, count = build_bundle()

    luau_path = os.path.join(BUILD, "AnimTeacher.luau")
    with open(luau_path, "w", encoding="utf-8") as handle:
        handle.write(bundle)

    # CDATA cannot contain the sequence "]]>"; the bundle uses ]] for long
    # strings, so guard against an accidental terminator.
    if "]]>" in bundle:
        raise SystemExit("bundle contains ']]>' which would break the .rbxmx CDATA block")

    rbxmx_path = os.path.join(BUILD, "AnimTeacher.rbxmx")
    with open(rbxmx_path, "w", encoding="utf-8") as handle:
        handle.write(RBXMX_TEMPLATE.format(source=bundle))

    size_kb = os.path.getsize(luau_path) / 1024
    print(f"bundled {count} modules")
    print(f"  {os.path.relpath(luau_path, ROOT)}  ({size_kb:.1f} KB)")
    print(f"  {os.path.relpath(rbxmx_path, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
