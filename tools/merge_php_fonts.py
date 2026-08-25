"""Merge PHP bitmap fonts (bitmap_<name>.php) into gdn/data/fonts.json.

Add-only by design: a font name already present in fonts.json is never
overwritten — the shipped glyphs are the ones every deployed panel agrees
on. New names are appended.

Usage:
    python3 tools/merge_php_fonts.py path/to/bitmap_10x15_outline.php [more...]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

FONTS_JSON = Path(__file__).resolve().parent.parent / "gdn" / "data" / "fonts.json"

# 'A'=> [ ...rows... ]  — keys are single characters (possibly escaped).
_GLYPH_KEY = re.compile(r"'((?:\\.|[^'\\]))'\s*=>\s*\[")
_ROW = re.compile(r"\[\s*([01](?:\s*,\s*[01])*)\s*\]")


def parse_php_bitmap(path: Path) -> dict:
    """{char: [[0/1,...], ...]} from one bitmap_*.php file."""
    src = path.read_text(encoding="utf-8", errors="replace")
    keys = list(_GLYPH_KEY.finditer(src))
    glyphs = {}
    for i, m in enumerate(keys):
        ch = m.group(1)
        if ch.startswith("\\"):
            ch = ch[1:]  # '\'' -> ', '\\' -> backslash
        end = keys[i + 1].start() if i + 1 < len(keys) else len(src)
        body = src[m.end():end]
        rows = [[int(v) for v in row.split(",")]
                for row in (r.replace(" ", "") for r in _ROW.findall(body))]
        if rows:
            glyphs[ch] = rows
    return glyphs


def main(paths):
    fonts = json.loads(FONTS_JSON.read_text(encoding="utf-8"))
    added, skipped = [], []
    for p in paths:
        p = Path(p)
        name = re.sub(r"^bitmap_", "", p.stem)
        if name in fonts:
            skipped.append(name)
            continue
        glyphs = parse_php_bitmap(p)
        if not glyphs:
            print(f"!! {p}: no glyphs parsed, skipping")
            continue
        heights = {len(rows) for rows in glyphs.values()}
        widths = {len(rows[0]) for rows in glyphs.values()}
        fonts[name] = {"glyphs": glyphs}
        added.append((name, len(glyphs), sorted(heights), sorted(widths),
                      " " in glyphs))
    if added:
        FONTS_JSON.write_text(json.dumps(fonts, separators=(",", ":")),
                              encoding="utf-8")
    for name, n, hs, ws, sp in added:
        print(f"added {name}: {n} glyphs, heights {hs}, widths {ws}, "
              f"space glyph: {'yes' if sp else 'NO'}")
    for name in skipped:
        print(f"kept existing {name} (not overwritten)")


if __name__ == "__main__":
    main(sys.argv[1:])
