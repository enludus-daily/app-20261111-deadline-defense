#!/usr/bin/env python3
"""画面の日本語の文字を集め、docs/i18n/en.tsv の英語と合わせて App/Resources/Localizable.xcstrings を作る。
使い方: python3 scripts/strings-check.py [--write]
- Swift の文字列リテラルのうち日本語を含むものを集める（Content.swift の手で用意した中身と、見本の名前は除く）
- \\(…) は %lld（数）か %@（文字）にする。どちらかは en.tsv のキーで決める
- 英語の抜けがあれば exit 1
"""
import json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
JA = re.compile(r'[぀-ヿ㐀-鿿！-｠]')
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
SKIP_FILES = {"Content.swift"}
# 見本の名前など、カタログを通さない日本語（行に入っている印）
SKIP_LINE = re.compile(r'foe\("|ja \? "|//')

def literals():
    found = {}
    for path in sorted((root / "App/Sources").rglob("*.swift")):
        if path.name in SKIP_FILES:
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("//")[0] if "//" in line and '"' not in line.split("//")[0][-1:] else line
            if re.search(r'foe\("|ja \? "', line):
                continue
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("///"):
                continue
            for m in LIT.finditer(code):
                s = m.group(1)
                if JA.search(s):
                    found.setdefault(s, f"{path.relative_to(root)}:{n}")
    return found

def key_pattern(lit):
    # \(…) を、%lld か %@ のどちらにでも合う形にする
    parts = re.split(r'\\\((?:[^()]|\([^()]*\))*\)', lit)
    return "^" + "(?:%lld|%@)".join(re.escape(p.replace('\\"', '"')) for p in parts) + "$"

def main():
    tsv = {}
    for line in (root / "docs/i18n/en.tsv").read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        ja, en = line.split("\t")
        tsv[ja] = en
    missing, used = [], set()
    for lit, where in literals().items():
        pat = re.compile(key_pattern(lit))
        keys = [k for k in tsv if pat.match(k)]
        if not keys:
            missing.append(f"{where}\t{lit}")
        used.update(keys)
    unused = sorted(set(tsv) - used)
    for m in missing:
        print("英語なし:", m)
    for u in unused:
        print("使っていない:", u)
    if "--write" in sys.argv:
        strings = {}
        for ja in sorted(tsv):
            strings[ja] = {"localizations": {
                "en": {"stringUnit": {"state": "translated", "value": tsv[ja]}},
                "ja": {"stringUnit": {"state": "translated", "value": ja}},
            }}
        out = {"sourceLanguage": "ja", "strings": strings, "version": "1.0"}
        (root / "App/Resources/Localizable.xcstrings").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"書きました: {len(strings)} 件")
    print(f"日本語の文字: {len(literals())}、英語なし: {len(missing)}")
    return 1 if missing else 0

sys.exit(main())
