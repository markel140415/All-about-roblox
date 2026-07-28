#!/usr/bin/env python3
"""
Test harness for the AnimTeacher plugin logic.

The plugin ships as Luau for Roblox Studio, but the pure-logic modules
(Brain/*, Core/*, Data/*) avoid Roblox APIs so they can be executed in a
plain Lua interpreter. This harness rewrites the Roblox-style requires
(shared with tools/build.py) and runs the Lua test files in tests/.

Usage:  python3 tests/harness.py [tests/test_foo.lua ...]
"""
import os
import sys
import glob

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

try:
    from lupa import LuaRuntime
except ImportError:
    sys.exit("lupa is required: pip install lupa")

import bundler  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")


def build_runtime():
    """A Lua runtime preloaded with every src/ module under _require()."""
    lua = LuaRuntime(unpack_returned_tuples=True)

    # `load` returns (nil, message) on failure, so compile through a wrapper
    # that reports the error instead of storing a tuple in the registry.
    compile_fn = lua.eval(
        """
        function(src, name)
            local chunk, err = load(src, '@' .. name)
            if not chunk then return nil, tostring(err) end
            return chunk, nil
        end
        """
    )

    registry = lua.eval("{}")
    for module_path, file_path in bundler.discover(SRC):
        source = bundler.rewrite(module_path, bundler.read(file_path), call="_require")
        chunk, err = compile_fn(source, f"{module_path}.luau")
        if chunk is None:
            raise RuntimeError(f"syntax error in {module_path}: {err}")
        registry[module_path] = chunk

    lua.globals()["__registry"] = registry
    lua.execute(
        """
        local cache = {}
        function _require(name)
            if cache[name] ~= nil then return cache[name] end
            local factory = __registry[name]
            if factory == nil then error("module not found: " .. tostring(name), 2) end
            local result = factory()
            cache[name] = result
            return result
        end
        """
    )
    lua.globals()["SRC_DIR"] = SRC
    lua.globals()["ROOT_DIR"] = ROOT
    return lua


def run_file(lua, path):
    source = bundler.read(path)
    compile_fn = lua.eval(
        """
        function(src, name)
            local chunk, err = load(src, '@' .. name)
            if not chunk then return nil, tostring(err) end
            return chunk, nil
        end
        """
    )
    chunk, err = compile_fn(source, path)
    if chunk is None:
        raise RuntimeError(f"failed to compile {path}: {err}")
    return chunk()


def ensure_bundle():
    """
    test_plugin.lua runs the built bundle, so rebuild first. Otherwise the
    suite could pass against a stale build while src/ is broken.
    """
    import subprocess

    result = subprocess.run(
        [sys.executable, os.path.join(ROOT, "tools", "build.py")],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr)
        raise SystemExit("build failed; aborting tests")


def main():
    args = sys.argv[1:]
    if args:
        files = [a if os.path.isabs(a) else os.path.join(ROOT, a) for a in args]
    else:
        files = sorted(glob.glob(os.path.join(ROOT, "tests", "test_*.lua")))

    ensure_bundle()

    if not files:
        print("no test files found")
        return 1

    total_failures = 0
    for path in files:
        print(f"\n=== {os.path.relpath(path, ROOT)} ===")
        try:
            lua = build_runtime()
            failures = run_file(lua, path)
        except Exception as exc:  # noqa: BLE001
            print(f"ERROR: {exc}")
            total_failures += 1
            continue
        total_failures += int(failures or 0)

    print("\n" + "=" * 46)
    if total_failures == 0:
        print("ALL TESTS PASSED")
        return 0
    print(f"{int(total_failures)} FAILURE(S)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
