#!/usr/bin/env python3
"""Appends translation keys to both ARB files, keeping their formatting.

Usage: tool/arb_add.py keys.json
keys.json: {"key": ["srpski", "English", {"placeholders"} or omitted]}
Placeholder metadata goes to the English file only (as gen-l10n expects).
"""
import collections
import json
import sys

keys = json.load(open(sys.argv[1]), object_pairs_hook=collections.OrderedDict)
base = 'lib/app/localization/arb/'
for lang, idx in (('sr', 0), ('en', 1)):
    path = f'{base}app_{lang}.arb'
    text = open(path).read().rstrip()
    assert text.endswith('}')
    text = text[:-1].rstrip()
    lines = []
    for k, v in keys.items():
        lines.append(f'  {json.dumps(k)}: {json.dumps(v[idx], ensure_ascii=False)}')
        if lang == 'en' and len(v) > 2 and v[2]:
            meta = json.dumps({'placeholders': v[2]}, ensure_ascii=False)
            lines.append(f'  {json.dumps("@" + k)}: {meta}')
    text += ',\n' + ',\n'.join(lines) + '\n}\n'
    json.loads(text)
    open(path, 'w').write(text)
