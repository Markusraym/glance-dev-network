"""`gdn check` — a friendly pre-flight lint for a GDN app.

Catches the common mistakes before you render or submit: a bad or mismatched `id`,
a placeholder `author`, a too-fast `refresh`, undeclared or unused assets, a page
with no matching function, and lowercase text in the UPPERCASE-only fonts. Plain
messages, exits non-zero only on real errors (warnings don't fail).
"""
from __future__ import annotations

import re
from pathlib import Path

from .runner import load_manifest

# The lowercase-text check looks at string literals, but not every lowercase
# character in one reaches the panel: `%d` / `%s` / `%.1f` are format specifiers
# the `%` operator consumes, and `\n` is an escape. Ignore both, or the shipped
# template trips its own linter — "H%d L%d" draws as "H72 L60".
_NOT_DRAWN = re.compile(r"%[#0\- +]*\d*(?:\.\d+)?[a-zA-Z%]|\\[a-zA-Z]")

_KNOWN_KEYS = {
    "gdn", "id", "version", "name", "author", "description", "entry",
    "width", "height", "refresh", "pages", "inputs", "assets", "category",
    "help_url", "featured",
}

_DOCSTRING = re.compile(r'"""(?:.|\n)*?"""|\'\'\'(?:.|\n)*?\'\'\'')


def _code_only(src: str) -> str:
    """Source with docstrings and comments removed.

    Any check that looks for a code pattern has to run on code. A docstring
    explaining that something "used to be date.split(...)" is prose, and
    matching it reports the bug the comment says was fixed.
    """
    src = _DOCSTRING.sub("", src)
    return "\n".join(ln.split("#", 1)[0] for ln in src.split("\n"))


def check_app(app_dir) -> tuple:
    """Return (errors, warnings) message lists for one app folder."""
    app_dir = Path(app_dir)
    errors, warns = [], []
    if not (app_dir / "manifest.yaml").exists():
        return ([f"no manifest.yaml in {app_dir.name}"], [])
    try:
        m = load_manifest(app_dir)
    except Exception as e:  # noqa: BLE001
        return ([f"manifest is not valid YAML ({e})"], [])

    app_id = str(m.get("id", "")).strip()
    if not app_id:
        errors.append("missing `id`")
    else:
        if not re.match(r"^[a-z0-9][a-z0-9-]*$", app_id):
            errors.append(f"`id` must be lowercase letters, digits, and hyphens (got {app_id!r})")
        if app_id != app_dir.name:
            warns.append(f"`id` ({app_id}) doesn't match the folder name ({app_dir.name})")

    if not str(m.get("name", "")).strip():
        warns.append("missing `name` (the title users see)")
    author = str(m.get("author", "")).strip()
    if not author or author.lower() == "your-name":
        warns.append("`author` is still the placeholder `your-name`")
    if not str(m.get("description", "")).strip():
        warns.append("missing `description` (a one-line summary)")

    try:
        w, h = int(m.get("width", 0)), int(m.get("height", 0))
        if not (1 <= w <= 384):
            errors.append(f"`width` must be 1-384 (got {w})")
        if h != 32:
            warns.append(f"`height` is normally 32 (got {h})")
    except (TypeError, ValueError):
        errors.append("`width`/`height` must be numbers")
    try:
        refresh = int(m.get("refresh", 0))
        if refresh and refresh < 60:
            warns.append(f"`refresh` {refresh}s is very fast; 60s+ is easier on data sources")
    except (TypeError, ValueError):
        warns.append("`refresh` should be a number of seconds")

    for k in m:
        if k not in _KNOWN_KEYS:
            warns.append(f"unknown manifest key `{k}` (typo?)")

    star = app_dir / "app.star"
    if star.exists():
        src = star.read_text(encoding="utf-8")
        pages = m.get("pages") or []
        names = pages if isinstance(pages, list) else [f"page{i + 1}" for i in range(int(pages or 0))]
        for pn in names:
            if not re.search(r"(?m)^\s*def\s+" + re.escape(str(pn)) + r"\s*\(", src):
                errors.append(f"page `{pn}` has no matching `def {pn}(c, ctx):` in app.star")
        declared = set(m.get("assets") or [])
        used = set(re.findall(r"""c\.image\(\s*['"]([^'"]+)['"]""", src))
        for a in sorted(used - declared):
            errors.append(f"draws `{a}` but it's not listed under `assets:`")
        # An app that computes its asset name -- one crest per team, one icon
        # per condition -- draws with c.image(name_from_a_lookup, ...), and the
        # regex above cannot see those. Reporting every declared file as unused
        # there buries the one that really is: nwsl-scroll alone produced 32
        # false warnings. If any c.image() call takes a non-literal, stay quiet.
        computed = re.search(r"""c\.image\(\s*(?!['"])""", src) is not None
        if not computed:
            for a in sorted(declared - used):
                warns.append(f"asset `{a}` is declared but never drawn")
        # Every declared setting must actually be read in the code. Settings are read as
        # ctx.inputs.get("key") / ctx.inputs["key"], so the key appears as a quoted string;
        # if it never does, the setting is dead and confuses people who fill it in.
        for i in (m.get("inputs") or []):
            k = str(i.get("key", "")).strip() if isinstance(i, dict) else ""
            ait = str(i.get("app_input_type", "")).strip().lower() if isinstance(i, dict) else ""
            # Input keys ride the render descriptor (key-value_key-value), so '_' and '-'
            # are delimiters: a key containing them never routes to the app. Hard error for
            # api-key inputs (their value MUST arrive); a warning for any other input.
            if k and not re.match(r"^[a-zA-Z][a-zA-Z0-9]*$", k):
                safe = re.sub(r"[^a-zA-Z0-9]", "", k) or "setting"
                msg = (f"input key `{k}` must be letters and digits only, starting with a letter "
                       f"(no '_' or '-'): those are render-descriptor delimiters, so a value under "
                       f"this key never reaches the app. Rename it, e.g. `{safe}`.")
                (errors if ait == "api-key" else warns).append(msg)
            # An input a viewer can legitimately leave blank has to be READ
            # defensively. coerce() hands a blank straight back as the manifest
            # default, so an input whose default is empty reaches the app as ""
            # -- and ctx.inputs["key"], or a one-argument .get(), then produces
            # a blank the app was not expecting. That is how "if one is blank it
            # doesn't work" happens.
            req = bool(i.get("required", False)) if isinstance(i, dict) else False
            dflt_raw = i.get("default") if isinstance(i, dict) else None
            blank_default = dflt_raw is None or str(dflt_raw).strip() == ""
            if k and not req and blank_default:
                code = _code_only(src)
                subscript = re.search(r"""ctx\.inputs\[\s*['"]""" + re.escape(k) + r"""['"]\s*\]""", code)
                bare_get = re.search(r"""ctx\.inputs\.get\(\s*['"]""" + re.escape(k) + r"""['"]\s*\)""", code)
                if subscript or bare_get:
                    how = "ctx.inputs[...]" if subscript else "a one-argument .get()"
                    warns.append(
                        f"input `{k}` is optional and defaults to blank, but the app reads it with "
                        f"{how}. A viewer who leaves it empty gets an empty string. Read it as "
                        f'ctx.inputs.get("{k}", <fallback>) and handle "" explicitly, or mark the '
                        f"input `required: true` so the client refuses to save it blank.")
            if req and not blank_default:
                warns.append(f"input `{k}` is marked `required: true` but has a non-empty default "
                             f"({dflt_raw!r}), so it can never actually be blank. Drop one or the other.")

            if k and not re.search(r"""['"]""" + re.escape(k) + r"""['"]""", src):
                errors.append(f"setting `{k}` is declared but never used in app.star "
                              f'(read it with ctx.inputs.get("{k}"), or remove it from the manifest)')
            # The descriptor is colon-separated at the top level
            # (GDN:W:H:app:pages:ttl:inputs), so a VALUE containing ':' ends there and
            # the remainder is read as another field. Keys are checked above; nothing
            # checked values, which is how a pasted repo URL reached an app as the
            # string "https", and an ISO date as "2026-08-14T01".
            dflt = str(i.get("default", "")) if isinstance(i, dict) else ""
            if ":" in dflt:
                warns.append(f"input `{k}` has a default containing ':' ({dflt!r}). Values "
                             f"ride the render descriptor, which is colon-separated, so this "
                             f"is cut at the first ':' before the app sees it.")
            # Date pickers send a full ISO stamp, so the time's colons truncate it and
            # the app is handed "YYYY-MM-DDTHH". Positional parsing then fails on a
            # value the viewer did set -- silently, if it falls back to a default.
            if ait in ("date", "date-past") and k:
                code = _code_only(src)
                if re.search(r"""\.split\(\s*["']-["']\s*\)""", code) or \
                        re.search(r"\[\s*5\s*:\s*7\s*\]|\[\s*8\s*:\s*10\s*\]", code):
                    warns.append(f"input `{k}` is a date picker, but app.star parses the value "
                                 f"positionally. The value arrives truncated at the first ':' "
                                 f"of the time (\"2026-08-14T01\"), so read the digits out of it "
                                 f"instead of splitting on '-' or slicing fixed offsets.")
        for lit in re.findall(r"""c\.text[a-z_]*\(\s*['"]([^'"]*)['"]""", src):
            if any(ch.islower() for ch in _NOT_DRAWN.sub("", lit)):
                warns.append(f'text "{lit}" has lowercase; fonts are UPPERCASE-only, call .upper()')
                break

        # Open-Meteo answers in km/h and Celsius unless told otherwise. An app that
        # asks for a US zip and then prints an unlabelled wind speed is showing km/h
        # to someone who will read mph -- wrong by 1.6x, and wrong in the direction
        # that looks worse than reality.
        if "open-meteo.com" in src:
            for field, unit, human in (("wind_speed", "wind_speed_unit", "mph or kmh"),
                                       ("temperature_2m", "temperature_unit", "fahrenheit or celsius")):
                if field in src and unit not in src:
                    warns.append(f"asks Open-Meteo for `{field}` without setting `{unit}`. "
                                 f"The default is metric, so pin it ({human}) and print the "
                                 f"unit, or the number is ambiguous on the panel.")

        # Draws that can land outside the room they were given.
        try:
            from .layout_lint import layout_warnings
            w = int(m.get("width", 0) or 0)
            if w:
                warns.extend(layout_warnings(src, w))
        except Exception as e:  # noqa: BLE001
            # A lint must never be the reason a check run dies.
            warns.append(f"layout check skipped ({e})")
    return (errors, warns)


def run(app_dirs) -> int:
    total_err = 0
    for d in app_dirs:
        d = Path(d)
        errors, warns = check_app(d)
        tag = "FAIL" if errors else ("WARN" if warns else "PASS")
        print(f"{tag}  {d.name}")
        for e in errors:
            print(f"   x  {e}")
        for w in warns:
            print(f"   !  {w}")
        total_err += len(errors)
    print()
    print(f"{'FAILED' if total_err else 'OK'}: {total_err} error(s) across {len(app_dirs)} app(s)")
    return 1 if total_err else 0
