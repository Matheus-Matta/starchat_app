#!/usr/bin/env python3
"""Corrige arquivos JSON que contenham dois objetos concatenados (ex: }\n{) mantendo o primeiro objeto válido.
Cria backup com sufixo .bak antes de sobrescrever.
"""
import os
import json

ROOTS=[
    'app/javascript/widget/i18n/locale',
    'app/javascript/dashboard/i18n/locale',
]

def extract_first_json(s):
    # find first '{'
    i = s.find('{')
    if i == -1:
        return None
    depth = 0
    in_str = False
    esc = False
    for idx in range(i, len(s)):
        ch = s[idx]
        if in_str:
            if esc:
                esc = False
            elif ch == '\\':
                esc = True
            elif ch == '"':
                in_str = False
            continue
        else:
            if ch == '"':
                in_str = True
            elif ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    return s[i:idx+1]
    return None


def try_parse(s):
    try:
        return json.loads(s)
    except Exception:
        return None


def fix_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        txt = f.read()
    # quick check: if valid, skip
    if try_parse(txt) is not None:
        return False, 'valid'
    # try to extract first JSON object
    first = extract_first_json(txt)
    if not first:
        return False, 'no-json'
    parsed = try_parse(first)
    if parsed is None:
        return False, 'first-invalid'
    # write backup
    bak = path + '.bak'
    with open(bak, 'w', encoding='utf-8') as f:
        f.write(txt)
    # pretty write first object
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(parsed, f, ensure_ascii=False, indent=2)
        f.write('\n')
    return True, bak


def main():
    changed = []
    checked = 0
    for root in ROOTS:
        if not os.path.isdir(root):
            continue
        for dirpath,_,filenames in os.walk(root):
            for fn in filenames:
                if not fn.endswith('.json'):
                    continue
                path = os.path.join(dirpath, fn)
                checked += 1
                ok, info = fix_file(path)
                if ok:
                    changed.append((path, info))
                elif ok is False and info not in ('valid',):
                    # record failures optionally
                    pass
    print(f'Checked {checked} files, fixed {len(changed)} files')
    for p,b in changed:
        print('Fixed:', p, 'backup->', b)

if __name__ == '__main__':
    main()
