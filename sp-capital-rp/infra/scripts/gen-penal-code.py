#!/usr/bin/env python3
"""Gera packages/shared/penal-code.json a partir de docs/sp-capital-rp/publico/codigo-penal.md."""
import json, re, sys, pathlib

root = pathlib.Path(__file__).resolve().parents[3]
src = root / 'docs/sp-capital-rp/publico/codigo-penal.md'
out = root / 'sp-capital-rp/packages/shared/penal-code.json'

articles, title = [], None
for line in src.read_text(encoding='utf-8').splitlines():
    m = re.match(r'^## (Título [IVX]+ — .+)$', line)
    if m:
        title = m.group(1); continue
    m = re.match(r'^\| (\d{3}) \| (.+?) \| (\+?\d+) \| (.+?) \|\s*(.*?)\s*\|$', line)
    if not m:
        continue
    art, name, months, fine, flag = m.groups()
    fine_value = re.search(r'R\$ ([\d.]+)', fine)
    articles.append({
        'article': int(art),
        'title': title,
        'crime': name.strip(),
        'months': int(months.lstrip('+')),
        'additive': months.startswith('+'),
        'fineCents': int(fine_value.group(1).replace('.', '')) * 100 if fine_value else 0,
        'fineText': fine.strip(),
        'bail': flag.strip() == 'F',
        'trial': '⚖️' in flag,
    })

if len(articles) < 40:
    sys.exit(f'poucos artigos encontrados ({len(articles)}): formato do markdown mudou?')
out.write_text(json.dumps({'version': '1.0', 'monthToMinutes': 1, 'maxMonths': 120, 'articles': articles},
                          ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'{len(articles)} artigos → {out.relative_to(root)}')
