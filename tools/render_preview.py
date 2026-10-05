#!/usr/bin/env python3
"""Render Lua test-harness widget snapshots for layout inspection.

Client-supplied WoW textures are unavailable in these previews.
"""

import html
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREENS = [
    ("main", "Planner"),
    ("checkpoints", "Checkpoint tree"),
    ("graph", "Expanded graph"),
    ("skill", "Skill ranks"),
    ("simulation", "Simulator"),
    ("advanced", "Advanced"),
    ("races", "Races"),
    ("pets", "Pets"),
]
POINTS = {
    "TOPLEFT": (0, 0),
    "TOP": (0.5, 0),
    "TOPRIGHT": (1, 0),
    "LEFT": (0, 0.5),
    "CENTER": (0.5, 0.5),
    "RIGHT": (1, 0.5),
    "BOTTOMLEFT": (0, 1),
    "BOTTOM": (0.5, 1),
    "BOTTOMRIGHT": (1, 1),
}


def rgba(c, default=1):
    c = c or [1, 1, 1]
    return f"rgba({int(c[0] * 255)},{int(c[1] * 255)},{int(c[2] * 255)},{c[3] if len(c) > 3 else default})"


def plain(text):
    return re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text or "")


def colored(text):
    out, opened = [], False
    for part in re.split(r"(\|c[0-9a-fA-F]{8}|\|r)", text or ""):
        if part.startswith("|c"):
            if opened:
                out.append("</span>")
            out.append('<span style="color:#' + part[4:] + '">')
            opened = True
        elif part == "|r":
            if opened:
                out.append("</span>")
                opened = False
        else:
            out.append(html.escape(part))
    if opened:
        out.append("</span>")
    return "".join(out).replace("\n", "<br>")


def render(snapshot):
    d = json.loads(snapshot.read_text())
    objects = {o["id"]: o for o in d["objects"]}
    root = d["root"]
    rects, levels = {}, {}

    def rect(oid):
        if oid in rects:
            return rects[oid]
        o = objects.get(oid)
        if not o:
            return (0, 0, 1280, 824)
        if oid == root:
            r = (0, 0, o["width"], o["height"])
            rects[oid] = r
            return r
        parent = objects.get(o.get("parent"))
        pr = rect(o.get("parent"))
        if o.get("allPoints"):
            r = rect(o["allPoints"])
            rects[oid] = r
            return r
        w, h = o["width"], o["height"]
        if o["kind"] == "FontString" and h == 0:
            text, size = plain(o.get("text")), o.get("fontSize", 13)
            lines = (
                sum(
                    max(1, math.ceil(len(line) * size * 0.51 / max(1, w)))
                    for line in text.split("\n")
                )
                if o.get("wrap") is not False
                else 1
            )
            h = size * 1.2 * lines
        if not h and o["kind"] == "Line":
            h = pr[3]
        x, y = pr[0], pr[1]
        anchors = o["anchors"] or []
        if anchors:
            anchor = anchors[0]
            point = anchor[0]
            if len(anchor) >= 2 and isinstance(anchor[1], dict):
                relative = rect(anchor[1]["ref"])
                relative_point = (
                    anchor[2] if len(anchor) > 2 and isinstance(anchor[2], str) else point
                )
                ox = anchor[3] if len(anchor) > 3 else 0
                oy = anchor[4] if len(anchor) > 4 else 0
            else:
                relative, relative_point = pr, point
                ox = anchor[1] if len(anchor) > 1 else 0
                oy = anchor[2] if len(anchor) > 2 else 0
            ap, rp = POINTS[point], POINTS[relative_point]
            x, y = (
                relative[0] + rp[0] * relative[2] + ox - ap[0] * w,
                relative[1] + rp[1] * relative[3] - oy - ap[1] * h,
            )
            if len(anchors) > 1 and point == "LEFT" and anchors[1][0] == "RIGHT":
                right = anchors[1]
                offset = right[1] if len(right) > 1 and isinstance(right[1], (int, float)) else 0
                w = pr[0] + pr[2] + offset - x
        if parent and parent.get("scrollChild") == oid:
            x -= parent.get("horizontal", 0)
            y -= parent.get("vertical", 0)
        r = (x, y, w, h)
        rects[oid] = r
        return r

    def frame_level(oid):
        if oid in levels:
            return levels[oid]
        o = objects.get(oid)
        if not o:
            return 0
        parent_level = frame_level(o.get("parent"))
        strata = {
            "BACKGROUND": 0,
            "LOW": 1000,
            "MEDIUM": 2000,
            "HIGH": 3000,
            "DIALOG": 4000,
            "FULLSCREEN": 5000,
            "FULLSCREEN_DIALOG": 6000,
            "TOOLTIP": 7000,
        }
        base = strata.get(o.get("strata"), (parent_level // 1000) * 1000)
        if o.get("level") is not None:
            value = base + o["level"]
        elif o.get("strata"):
            value = base
        else:
            value = parent_level + (0 if o["kind"] in ("Texture", "FontString", "Line") else 1)
        levels[oid] = value
        return value

    fragments = []
    bounds = []
    for o in objects.values():
        x, y, w, h = rect(o["id"])
        if o["kind"] == "Line":
            x, y, w, h = rect(o["parent"])
        css = [f"left:{x:.2f}px", f"top:{y:.2f}px", f"width:{w:.2f}px", f"height:{h:.2f}px"]
        z = (
            frame_level(o["id"]) * 20
            + {"BACKGROUND": 1, "ARTWORK": 8, "OVERLAY": 15}.get(o.get("layer"), 0)
            + (o.get("sublevel") or 0)
        )
        css.append(f"z-index:{z}")
        opacity = o.get("alpha", 1)
        p = objects.get(o.get("parent"))
        clip = [0, 0, 1280, 824]
        while p:
            opacity *= p.get("alpha", 1)
            if p["kind"] == "ScrollFrame":
                px, py, pw, ph = rect(p["id"])
                clip = [
                    max(clip[0], px),
                    max(clip[1], py),
                    min(clip[2], px + pw),
                    min(clip[3], py + ph),
                ]
            p = objects.get(p.get("parent"))
        if x + w <= clip[0] or y + h <= clip[1] or x >= clip[2] or y >= clip[3]:
            continue
        inset = (
            max(0, clip[1] - y),
            max(0, x + w - clip[2]),
            max(0, y + h - clip[3]),
            max(0, clip[0] - x),
        )
        if any(inset):
            css.append("clip-path:inset(" + " ".join(f"{v:.2f}px" for v in inset) + ")")
        css.append(f"opacity:{opacity}")
        content = ""
        if o.get("bg"):
            css.append("background:" + rgba(o["bg"]))
            css.append("border:1px solid " + rgba(o.get("border", [0.2, 0.24, 0.28])))
        if o["kind"] == "Texture":
            texture = o.get("texture", "")
            if "\\Icons\\" in texture:
                name = texture.split("\\")[-1].replace(".tga", ".jpg")
                css.append(
                    "background: center / cover url('/data/icons/large/" + html.escape(name) + "')"
                )
                if o.get("desaturated"):
                    css.append("filter:grayscale(1) brightness(.65)")
            elif "Media\\Tree" in texture:
                n = int(texture[-5])
                themes = ["#193332", "#2e2436", "#272f25"]
                css.append(f"background:linear-gradient(180deg,{themes[n - 1]},#0c1319)")
            elif "UI-CheckBox-Check" in texture:
                content = '<svg viewBox="0 0 20 20"><path d="M4 10 L8 14 L16 5" fill="none" stroke="#59d9ff" stroke-width="2.5"/></svg>'
            elif o.get("color"):
                css.append("background:" + rgba(o["color"]))
            elif "WHITE8X8" in texture:
                css.append("background:" + rgba(o.get("vertex", [0.38, 0.47, 0.53])))
        elif o["kind"] == "Line":
            start, finish = o.get("start"), o.get("finish")
            if start and finish:
                content = f'<svg width="{w}" height="{h}" style="overflow:visible"><line x1="{start[1]}" y1="{-start[2]}" x2="{finish[1]}" y2="{-finish[2]}" stroke="{rgba(o.get("color"))}" stroke-width="{o.get("thickness", 2)}"/></svg>'
        elif o["kind"] == "FontString":
            css.extend(
                [
                    "color:" + rgba(o.get("textColor")),
                    f"font-size:{o.get('fontSize', 13)}px",
                    "line-height:1.2",
                    "text-align:" + o.get("justifyH", "LEFT").lower(),
                ]
            )
            if o.get("wrap") is False:
                css.append("white-space:nowrap;overflow:hidden;text-overflow:ellipsis")
            content = colored(o.get("text", ""))
            bounds.append(
                {
                    "id": o["id"],
                    "text": plain(o.get("text")),
                    "x": x,
                    "y": y,
                    "width": w,
                    "height": h,
                    "size": o.get("fontSize", 13),
                }
            )
        elif o["kind"] == "EditBox":
            if o.get("text"):
                inset = o.get("insets", [10, 10, 0, 0])
                content = (
                    '<span style="display:block;padding:'
                    + str(inset[2] or 7)
                    + "px "
                    + str(inset[1])
                    + "px 0 "
                    + str(inset[0])
                    + 'px">'
                    + html.escape(o["text"])
                    + "</span>"
                )
                css.append(
                    "font-size:13px;color:#e3ebef;overflow:hidden;white-space:normal;word-break:break-all"
                )
        fragments.append(
            '<div data-kind="'
            + o["kind"]
            + '" data-id="'
            + str(o["id"])
            + '" style="'
            + ";".join(css)
            + '">'
            + content
            + "</div>"
        )
    nav = " ".join(
        f'<a href="/preview/{name}.html"'
        + (' class="current"' if name == snapshot.stem else "")
        + ">"
        + title
        + "</a>"
        for name, title in SCREENS
    )
    page = (
        '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Forever Talents · Lua UI review</title><style>*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 50% 30%,#253342,#0a0f16 65%);color:#dce5ec;font-family:"DejaVu Sans",Arial,sans-serif}header{padding:20px 28px;font-size:13px;color:#8fa3b3;display:flex;justify-content:space-between}a{color:#9db4c5;text-decoration:none;margin-left:18px}.current{color:#ebac65}.window{position:relative;overflow:hidden;width:1280px;height:824px;margin:10px auto 40px;box-shadow:0 22px 100px #000a}.window>div{position:absolute}footer{text-align:center;font-size:12px;color:#7f929f;padding:0 16px 24px}</style><header><span>FOREVER TALENTS · actual Lua widget layout</span><nav>'
        + nav
        + '</nav></header><main class="window">'
        + "".join(fragments)
        + "</main><footer>Development render from the WoW API harness. Native talent artwork is supplied by the game; browser view shows the bundled fallback. In-game visual validation remains pending.</footer></html>"
    )
    return page, bounds


def main():
    all_bounds = {}
    for name, _ in SCREENS:
        page, bounds = render(ROOT / "preview" / (name + ".json"))
        (ROOT / "preview" / (name + ".html")).write_text(page)
        all_bounds[name] = bounds
    (ROOT / "preview/text-bounds.json").write_text(json.dumps(all_bounds, indent=2))
    print(f"Rendered {len(SCREENS)} screens from the addon Lua UI snapshots.")


if __name__ == "__main__":
    main()
