#!/usr/bin/env python3
"""
Shared module-resolution logic for the AnimTeacher plugin.

The source in src/ is written as idiomatic Roblox ModuleScripts using
`require(script.Parent.Foo)`. Two consumers need to resolve those paths:

  * tools/build.py   - bundles everything into one installable plugin file
  * tests/harness.py - runs the pure-logic modules in a plain Lua interpreter

Both import from here so the resolution rules can never drift apart.
"""
import os
import re

# require(script.Parent.Text)                  -> sibling module
# require(script.Parent.Parent.Data.Knowledge) -> walk up, then down
REQUIRE_RE = re.compile(r"require\s*\(\s*(script(?:\.[A-Za-z_][A-Za-z0-9_]*)+)\s*\)")


def resolve(module_path, expression):
    """
    Resolve a Roblox-style require expression to a dotted module id.

    module_path: dotted id of the module doing the requiring, e.g. "Brain.Answer"
    expression:  e.g. "script.Parent.Parent.Data.Knowledge"

    Returns e.g. "Data.Knowledge".
    """
    parts = expression.split(".")
    if parts[0] != "script":
        raise ValueError(f"unsupported require: {expression}")

    # `script` is the module itself, so the first `.Parent` yields its folder.
    cursor = module_path.split(".")

    for part in parts[1:]:
        if part == "Parent":
            if not cursor:
                raise ValueError(
                    f"require in {module_path} walks above the source root: {expression}"
                )
            cursor.pop()
        else:
            cursor.append(part)

    return ".".join(cursor)


def rewrite(module_path, source, call="__require"):
    """Replace every Roblox require in `source` with `call("Dotted.Id")`."""

    def sub(match):
        target = resolve(module_path, match.group(1))
        return f'{call}("{target}")'

    return REQUIRE_RE.sub(sub, source)


def discover(src_dir):
    """
    Walk src/ and return an ordered list of (module_path, absolute_file_path).

    Ordering is deterministic (sorted) so bundle output is reproducible.
    """
    found = []
    for dirpath, dirnames, filenames in os.walk(src_dir):
        dirnames.sort()
        for filename in sorted(filenames):
            if not filename.endswith((".luau", ".lua")):
                continue
            full = os.path.join(dirpath, filename)
            rel = os.path.relpath(full, src_dir)
            module_path = os.path.splitext(rel)[0].replace(os.sep, ".")
            found.append((module_path, full))
    return found


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()
