#!/usr/bin/env python3
import os
import re
from pathlib import Path

BASE_DIR = Path('app/javascript/dashboard/i18n/locale')
if not BASE_DIR.exists():
    print('Locale directory not found:', BASE_DIR)
    exit(1)

conflict_start = '<<<<<<< HEAD'
conflict_mid = '=======\n'
conflict_end_re = re.compile(r'^>>>>>>> .+$', re.MULTILINE)

files_changed = []
for root, dirs, files in os.walk(BASE_DIR):
    for f in files:
        if not f.endswith('.json') and not f.endswith('.js') and not f.endswith('.json5'):
            continue
        path = Path(root) / f
        text = path.read_text(encoding='utf-8')
        if conflict_start in text:
            original = text
            new_text = ''
            i = 0
            while True:
                idx = text.find(conflict_start, i)
                if idx == -1:
                    new_text += text[i:]
                    break
                # append text before conflict
                new_text += text[i:idx]
                # find mid
                mid_idx = text.find('\n=======', idx)
                if mid_idx == -1:
                    # malformed, stop
                    print('Malformed conflict in', path)
                    new_text += text[idx:]
                    break
                # head content starts after conflict_start + newline
                head_start = idx + len(conflict_start)
                # allow optional newline
                if text[head_start:head_start+1] == '\n':
                    head_start += 1
                head_content = text[head_start:mid_idx+1] if text[mid_idx:mid_idx+1] != '\n' else text[head_start:mid_idx]
                # find end marker from mid_idx
                end_match = conflict_end_re.search(text, mid_idx)
                if not end_match:
                    print('No end marker for conflict in', path)
                    new_text += text[idx:]
                    break
                end_idx = end_match.end()
                # append head content only
                new_text += head_content
                i = end_idx
            # write backup
            backup = path.with_suffix(path.suffix + '.orig')
            if not backup.exists():
                backup.write_text(original, encoding='utf-8')
            path.write_text(new_text, encoding='utf-8')
            files_changed.append(str(path))

print('Files changed:', len(files_changed))
for p in files_changed:
    print(p)
