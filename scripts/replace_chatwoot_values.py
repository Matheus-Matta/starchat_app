#!/usr/bin/env python3
# ...existing code...
import os
import re
import json
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PATTERN = re.compile(r"chatwoot", re.IGNORECASE)
IGNORED_DIRS = {".git", "node_modules", "vendor", "dist", "build", "__pycache__"}

def repl(m):
    tok = m.group(0)
    if tok.isupper():
        return "STARCHATS"
    if tok[0].isupper():
        return "Starchats"
    return "starchats"

def replace_in_obj(obj):
    if isinstance(obj, str):
        return PATTERN.sub(repl, obj)
    if isinstance(obj, list):
        return [replace_in_obj(i) for i in obj]
    if isinstance(obj, dict):
        return {k: replace_in_obj(v) for k, v in obj.items()}
    return obj

def process_json_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        # fallback to plain text replacement for non-strict JSON files
        return process_text_file(path)

    new_data = replace_in_obj(data)
    if new_data != data:
        bak = path + ".bak"
        shutil.copy2(path, bak)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(new_data, f, ensure_ascii=False, indent=2)
        print(f"UPDATED JSON: {path} (backup: {bak})")
        return True
    return False

def process_text_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            txt = f.read()
    except Exception as e:
        print(f"SKIP (read error): {path} ({e})")
        return False
    new_txt = PATTERN.sub(repl, txt)
    if new_txt != txt:
        bak = path + ".bak"
        shutil.copy2(path, bak)
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_txt)
        print(f"UPDATED TEXT: {path} (backup: {bak})")
        return True
    return False

def should_skip_dir(d):
    return any(part in IGNORED_DIRS for part in d.split(os.sep))

def main():
    changed = []
    for root, dirs, files in os.walk(ROOT):
        # prune ignored dirs
        dirs[:] = [d for d in dirs if d not in IGNORED_DIRS]
        if should_skip_dir(root):
            continue
        for fn in files:
            if fn.endswith(".bak") or fn.endswith(".orig") or fn.endswith(".mergebak"):
                continue
            if not fn.lower().endswith(".json"):
                continue
            path = os.path.join(root, fn)
            try:
                if process_json_file(path):
                    changed.append(path)
            except Exception as e:
                print(f"ERROR processing {path}: {e}")
    print(f"\nDone. Files changed: {len(changed)}")
    if changed:
        for p in changed:
            print(" -", os.path.relpath(p, ROOT))

if __name__ == "__main__":
    main()
# ...existing code...