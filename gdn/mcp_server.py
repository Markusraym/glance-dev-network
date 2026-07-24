"""`gdn mcp` — an MCP (Model Context Protocol) server for the GDN toolkit.

Exposes the SDK to AI assistants as callable tools: scaffold an app, render a
page (the assistant *sees* the panel as an image and can iterate on it),
validate, and look up fonts/colors/text widths. Run it with `gdn mcp`, or let
a client launch it via the `.mcp.json` at the repo root — cloning the repo and
opening Claude Code inside it is all the setup there is.

The protocol is JSON-RPC 2.0 over stdio, newline-delimited. A tools-only MCP
server needs exactly five methods (initialize, the initialized notification,
ping, tools/list, tools/call), so this speaks the protocol directly instead of
adding an SDK dependency — `pip install -e .` stays as light as it is today,
and the server works offline like the rest of gdn. stdout carries protocol
frames ONLY; anything human-readable goes to stderr.
"""
from __future__ import annotations

import base64
import io
import json
import sys
from pathlib import Path

from . import __version__, colors, fonts

PROTOCOL_VERSION = "2025-06-18"

# The model reads text off a rendered panel far more reliably when the PNG is
# upscaled; 4x nearest-neighbor keeps pixels crisp and the payload tiny.
RENDER_SCALE = 4


# ---------------------------------------------------------------- tools

def _tool(name, description, properties, required):
    return {
        "name": name,
        "description": description,
        "inputSchema": {
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": False,
        },
    }


TOOLS = [
    _tool(
        "create_app",
        "Scaffold a new GDN app folder (manifest.yaml + app.star) from the "
        "working template. Use a lowercase-hyphen folder name like "
        "apps/surf-report. After creating, edit app.star, then render_app to "
        "see it and validate_app before calling it done.",
        {"path": {"type": "string",
                  "description": "Folder to create, e.g. apps/surf-report"}},
        ["path"],
    ),
    _tool(
        "render_app",
        "Render one page of an app and RETURN THE PANEL AS AN IMAGE (shown "
        "4x actual size) so you can see exactly what the LED panel will "
        "display. Also returns the app's own print() output. Look at the "
        "image carefully — check for clipped text, overlapping elements, and "
        "unreadable colors — and iterate until it looks right. For apps that "
        "fetch data, ALSO render once with simulate_offline=true and once "
        "with a nonsense input (bad ZIP, unknown city) to see the fallback "
        "screens — a panel on a wall must show something sensible when the "
        "data is missing.",
        {
            "app_dir": {"type": "string", "description": "The app folder"},
            "page": {"type": "integer",
                     "description": "1-based page number (default 1)"},
            "inputs": {"type": "object", "additionalProperties": {"type": "string"},
                       "description": "Input values, e.g. {\"zip\": \"10001\"}"},
            "now": {"type": "string",
                    "description": "Optional ISO time to render as-if, "
                                   "e.g. 2027-12-31T23:59"},
            "simulate_offline": {
                "type": "boolean",
                "description": "Make every http.get fail (status_code 0, no "
                               "cache) to see the app's no-data fallback."},
        },
        ["app_dir"],
    ),
    _tool(
        "validate_app",
        "Fully render every page of an app and run the publish-time lint — "
        "the same check `gdn submit` and CI run — plus a no-network render "
        "to confirm the app falls back gracefully when its API is down. "
        "ALWAYS run this before telling the user an app is finished, and fix "
        "every error it reports.",
        {"app_dir": {"type": "string", "description": "The app folder"}},
        ["app_dir"],
    ),
    _tool(
        "write_previews",
        "Render the catalog preview images into the app's preview/ folder — "
        "preview/<page>.png at native resolution plus preview/preview.png, "
        "the stacked poster (the same files Studio and `gdn submit` "
        "generate). Run this once the app looks right, so the app folder is "
        "catalog-complete.",
        {"app_dir": {"type": "string", "description": "The app folder"}},
        ["app_dir"],
    ),
    _tool(
        "list_fonts",
        "List the bundled bitmap fonts with their pixel heights. Fonts have "
        "UPPERCASE letters only — lowercase draws nothing.",
        {}, [],
    ),
    _tool(
        "measure_text",
        "Measure how many pixels wide a string is in a given font, and "
        "whether it fits common panel widths. Use before choosing a font so "
        "text doesn't get clipped.",
        {
            "text": {"type": "string", "description": "The text to measure"},
            "font": {"type": "string",
                     "description": "Font name, e.g. 5x7 (see list_fonts)"},
        },
        ["text", "font"],
    ),
    _tool(
        "list_colors",
        "List the named colors (with hex values) that color=\"...\" accepts. "
        "Any #rrggbb hex also works.",
        {}, [],
    ),
]


def _text(s):
    return {"type": "text", "text": s}


def _image(png_bytes):
    return {
        "type": "image",
        "data": base64.b64encode(png_bytes).decode("ascii"),
        "mimeType": "image/png",
    }


def tool_create_app(args):
    from .cli import TEMPLATES, _personalize
    import shutil
    dest = Path(args["path"]).resolve()
    if dest.exists() and any(dest.iterdir()):
        return [_text(f"error: {dest} already exists and is not empty")], True
    shutil.copytree(TEMPLATES / "example-star", dest, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    _personalize(dest)
    return [_text(
        f"Created {dest} with manifest.yaml and app.star (a working example).\n"
        f"Next: edit {dest / 'app.star'}, then render_app to see it."
    )], False


def _scaled_png(canvas):
    """canvas -> PNG bytes at RENDER_SCALE, nearest-neighbor (crisp pixels)."""
    img = canvas.img.resize(
        (canvas.width * RENDER_SCALE, canvas.height * RENDER_SCALE),
        resample=0,  # PIL.Image.NEAREST
    )
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


import contextlib
import os


@contextlib.contextmanager
def _offline(enabled):
    """Flip GDN_HTTP_OFFLINE for the sandboxed child (it inherits our env)."""
    if not enabled:
        yield
        return
    os.environ["GDN_HTTP_OFFLINE"] = "1"
    try:
        yield
    finally:
        os.environ.pop("GDN_HTTP_OFFLINE", None)


def tool_render_app(args):
    from .starhost import (StarError, StarTimeout, app_page_count,
                           run_star_app_sandboxed)
    from .scene import SceneError, render_scene
    app_dir = Path(args["app_dir"]).resolve()
    if not (app_dir / "app.star").exists():
        return [_text(f"error: {app_dir} has no app.star")], True
    page = int(args.get("page") or 1)
    offline = bool(args.get("simulate_offline"))
    try:
        with _offline(offline):
            scene, logs = run_star_app_sandboxed(
                app_dir, args.get("inputs") or {}, only_page=page,
                now=args.get("now") or None, return_logs=True)
        canvases = render_scene(scene, asset_dir=app_dir)
    except (StarError, StarTimeout, SceneError) as e:
        msg = getattr(e, "message", None) or "; ".join(
            getattr(e, "errors", []) or [str(e)])
        if offline:
            msg += ("\n(simulate_offline was on: the app CRASHES with no "
                    "network — add a fallback drawing for status_code != 200)")
        return [_text(f"RENDER FAILED: {msg}")], True
    name, canvas = next(iter(canvases.items()))
    pages = app_page_count(app_dir)
    caption = (f"Page {page}/{pages} ({name}) — {canvas.width}x{canvas.height} "
               f"panel, shown {RENDER_SCALE}x actual size.")
    if offline:
        caption += ("\nsimulate_offline=true: every http.get failed — this is "
                    "the app's no-data fallback screen.")
    if logs:
        caption += "\napp print() output:\n" + "\n".join(logs)
    return [_text(caption), _image(_scaled_png(canvas))], False


def tool_validate_app(args):
    from .starhost import (StarError, StarTimeout, app_page_count,
                           run_star_app_sandboxed)
    from .scene import SceneError, render_scene
    from .check import check_app
    app_dir = Path(args["app_dir"]).resolve()
    if not (app_dir / "app.star").exists():
        return [_text(f"error: {app_dir} has no app.star")], True
    try:
        pages = max(1, app_page_count(app_dir))
        for pg in range(1, pages + 1):
            scene = run_star_app_sandboxed(app_dir, {}, only_page=pg)
            render_scene(scene, asset_dir=app_dir)  # full render == validation
    except (StarError, StarTimeout, SceneError) as e:
        msg = getattr(e, "message", None) or "; ".join(
            getattr(e, "errors", []) or [str(e)])
        return [_text(f"FAIL: {msg}")], True
    errors, warns = check_app(app_dir)
    if errors:
        return [_text("FAIL (lint):\n" + "\n".join(f"- {e}" for e in errors))], True
    # A panel on a wall must show *something* when its API is down: render once
    # with HTTP disabled and warn if the app crashes instead of falling back.
    try:
        with _offline(True):
            scene = run_star_app_sandboxed(app_dir, {}, only_page=1)
        render_scene(scene, asset_dir=app_dir)
    except (StarError, StarTimeout, SceneError):
        warns = list(warns) + [
            "app CRASHES when http.get fails — draw a fallback when "
            "status_code != 200 (check it with render_app simulate_offline)"]
    out = f"PASS — {pages} page{'s' if pages != 1 else ''} render cleanly."
    if warns:
        out += "\nwarnings:\n" + "\n".join(f"- {w}" for w in warns)
    return [_text(out)], False


def tool_write_previews(args):
    app_dir = Path(args["app_dir"]).resolve()
    if not (app_dir / "app.star").exists():
        return [_text(f"error: {app_dir} has no app.star")], True
    from .preview import write_previews
    try:
        write_previews(app_dir)
    except Exception as e:  # noqa: BLE001
        return [_text(f"preview generation failed: {e!r}")], True
    made = sorted(p.name for p in (app_dir / "preview").glob("*.png"))
    return [_text("Wrote preview/ images: " + ", ".join(made))], False


def tool_list_fonts(args):
    lines = [f"{n:16s} height {fonts.font_height(n):2d}px"
             for n in fonts.list_fonts()]
    lines.append("\nUPPERCASE only — lowercase letters draw nothing; "
                 "call .upper() on input text.")
    return [_text("\n".join(lines))], False


def tool_measure_text(args):
    name = args["font"]
    if name not in fonts.list_fonts():
        return [_text(f"error: unknown font {name!r} — see list_fonts")], True
    text = args["text"]
    w = fonts.text_width(name, text)
    h = fonts.font_height(name)
    fits = ", ".join(f"{p}px: {'yes' if w <= p else 'NO'}"
                     for p in (64, 128, 192, 384))
    missing = sorted({c for c in text
                      if c != " " and fonts.char_width(fonts.get_glyphs(name), c) == 0})
    out = f"{text!r} in {name}: {w}px wide, {h}px tall. Fits panel width {fits}."
    if missing:
        out += (f"\nWARNING: these characters have no glyph in {name} and are "
                f"skipped silently: {' '.join(missing)}")
    return [_text(out)], False


def tool_list_colors(args):
    seen = {}
    for n, rgb in colors.NAMED.items():
        seen.setdefault(tuple(rgb), []).append(n)
    lines = [f"{' / '.join(names):24s} #{r:02x}{g:02x}{b:02x}"
             for (r, g, b), names in seen.items()]
    lines.append("\nAny #rrggbb hex string also works.")
    return [_text("\n".join(lines))], False


HANDLERS = {
    "create_app": tool_create_app,
    "render_app": tool_render_app,
    "validate_app": tool_validate_app,
    "write_previews": tool_write_previews,
    "list_fonts": tool_list_fonts,
    "measure_text": tool_measure_text,
    "list_colors": tool_list_colors,
}


# ---------------------------------------------------------------- protocol

def _result(id_, result):
    return {"jsonrpc": "2.0", "id": id_, "result": result}


def _error(id_, code, message):
    return {"jsonrpc": "2.0", "id": id_, "error": {"code": code, "message": message}}


def _handle(msg):
    """Return the response dict for one request, or None for notifications."""
    method, id_ = msg.get("method"), msg.get("id")
    if method == "initialize":
        return _result(id_, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "gdn", "version": __version__},
        })
    if method == "ping":
        return _result(id_, {})
    if method == "tools/list":
        return _result(id_, {"tools": TOOLS})
    if method == "tools/call":
        params = msg.get("params") or {}
        handler = HANDLERS.get(params.get("name"))
        if handler is None:
            return _error(id_, -32602, f"unknown tool {params.get('name')!r}")
        try:
            content, is_error = handler(params.get("arguments") or {})
        except Exception as e:  # noqa: BLE001 — a tool bug must not kill the server
            content, is_error = [_text(f"tool crashed: {e!r}")], True
        return _result(id_, {"content": content, "isError": is_error})
    if id_ is None:
        return None  # notification (e.g. notifications/initialized) — no reply
    return _error(id_, -32601, f"method not found: {method}")


def serve() -> int:
    """Speak newline-delimited JSON-RPC on stdin/stdout until EOF."""
    stdin = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8")
    stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", newline="\n")
    print(f"gdn mcp: serving {len(TOOLS)} tools on stdio", file=sys.stderr)
    for line in stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            resp = _error(None, -32700, "parse error")
        else:
            resp = _handle(msg)
        if resp is not None:
            stdout.write(json.dumps(resp) + "\n")
            stdout.flush()
    return 0
