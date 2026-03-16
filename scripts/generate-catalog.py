#!/usr/bin/env python3
"""Generate a visual snapshot catalog HTML page from CI artifacts."""
import os, sys
from pathlib import Path
from datetime import datetime

site_dir = sys.argv[1] if len(sys.argv) > 1 else "_site"
ios_dir = os.path.join(site_dir, "screenshots", "ios")
android_dir = os.path.join(site_dir, "screenshots", "android")


def find_images(base_dir):
    images = {}
    if not os.path.exists(base_dir):
        return images
    for root, _, files in os.walk(base_dir):
        for f in files:
            if f.endswith(".png"):
                rel = os.path.relpath(os.path.join(root, f), base_dir)
                images[Path(f).stem] = rel
    return images


ios_images = find_images(ios_dir)
android_images = find_images(android_dir)

# Categorize by host config preset
PRESET_TAGS = [
    ("EvolutionDark", "hc_evolutiondark_", "_EvolutionDark"),
    ("EvolutionLight", "hc_evolutionlight_", "_EvolutionLight"),
    ("TeamsDark", "hc_teamsdark_", "_TeamsDark"),
    ("TeamsLight", "hc_teamslight_", "_TeamsLight"),
    ("Default", "hc_default_", "_Default"),
]

presets = {p: [] for p, _, _ in PRESET_TAGS}
presets["Other"] = []

all_names = sorted(set(list(ios_images.keys()) + list(android_images.keys())))

for name in all_names:
    matched = False
    for preset, prefix, suffix in PRESET_TAGS:
        nl = name.lower()
        if prefix in nl or name.endswith(suffix):
            card = name
            if prefix in nl:
                idx = nl.index(prefix)
                card = name[idx + len(prefix):]
            elif name.endswith(suffix):
                card = name[:-len(suffix)]
            presets[preset].append({"card": card, "full": name})
            matched = True
            break
    if not matched:
        if name.startswith("teams_"):
            presets["TeamsLight"].append({"card": name[6:], "full": name})
        else:
            presets["Other"].append({"card": name, "full": name})

ts = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
n_ios = len(ios_images)
n_android = len(android_images)
active = [p for p, items in presets.items() if items]

# Build HTML
lines = [f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<title>AC Mobile — Visual Snapshot Catalog</title>
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
body{{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0d1117;color:#c9d1d9}}
.hdr{{text-align:center;padding:20px;background:#161b22;border-bottom:1px solid #30363d}}
.hdr h1{{font-size:20px;color:#58a6ff}}.hdr p{{font-size:12px;color:#8b949e;margin-top:4px}}
.stats{{display:flex;gap:8px;justify-content:center;margin-top:10px;flex-wrap:wrap}}
.st{{background:#21262d;padding:3px 10px;border-radius:14px;font-size:11px;color:#8b949e}}.st b{{color:#c9d1d9}}
.ctrl{{padding:10px 16px;background:#161b22;border-bottom:1px solid #30363d;display:flex;gap:8px;flex-wrap:wrap;align-items:center}}
.ctrl select,.ctrl input{{padding:5px 8px;border:1px solid #30363d;border-radius:5px;background:#0d1117;color:#c9d1d9;font-size:12px}}
.ctrl input{{flex:1;min-width:180px}}
.sec{{padding:14px 16px}}.sec-t{{font-size:15px;font-weight:600;margin-bottom:10px;padding-bottom:5px;border-bottom:2px solid #30363d}}
.sec-t.df{{color:#8b949e;border-color:#8b949e}}.sec-t.tm{{color:#6264A7;border-color:#6264A7}}
.sec-t.ev{{color:#2ecc71;border-color:#2ecc71}}.sec-t.dk{{color:#f0883e;border-color:#f0883e}}
.g{{display:grid;grid-template-columns:repeat(auto-fill,minmax(400px,1fr));gap:10px}}
.c{{background:#161b22;border:1px solid #30363d;border-radius:6px;overflow:hidden}}.c:hover{{border-color:#58a6ff}}
.ch{{padding:6px 10px;background:#21262d;font-size:12px;font-weight:500;display:flex;justify-content:space-between}}
.ch .n{{color:#c9d1d9}}.ch .b{{display:flex;gap:3px}}
.bg{{font-size:9px;padding:1px 5px;border-radius:8px}}.bg-i{{background:#1a4a7a;color:#58a6ff}}.bg-a{{background:#1a4a2e;color:#3fb950}}
.cb{{display:flex;gap:6px;padding:6px}}.cb .p{{flex:1;text-align:center}}
.cb .pl{{font-size:9px;text-transform:uppercase;color:#8b949e;letter-spacing:1px;margin-bottom:3px}}
.cb img{{max-width:100%;border:1px solid #30363d;border-radius:3px;cursor:pointer}}.cb img:hover{{border-color:#58a6ff}}
.cb .ms{{color:#f85149;font-size:10px;padding:16px 0}}
</style></head><body>
<div class="hdr"><h1>Adaptive Cards Mobile — Visual Snapshot Catalog</h1>
<p>Generated {ts} from CI artifacts</p>
<div class="stats"><span class="st">iOS: <b>{n_ios}</b></span><span class="st">Android: <b>{n_android}</b></span>
<span class="st">Presets: <b>{len(active)}</b></span><span class="st">Cards: <b>{len(all_names)}</b></span></div></div>
<div class="ctrl"><select id="pf" onchange="fc()"><option value="all">All Presets</option>"""]

for p in presets:
    if presets[p]:
        lines.append(f'<option value="{p}">{p} ({len(presets[p])})</option>')

lines.append('</select><input type="text" id="sb" placeholder="Search cards..." oninput="fc()"></div>')

for preset_name, cards in presets.items():
    if not cards:
        continue
    cls = "df"
    if "Teams" in preset_name: cls = "tm"
    elif "Evolution" in preset_name: cls = "ev"
    if "Dark" in preset_name: cls += " dk"

    lines.append(f'<div class="sec" data-p="{preset_name}">')
    lines.append(f'<div class="sec-t {cls}">{preset_name} ({len(cards)} cards)</div><div class="g">')

    for e in sorted(cards, key=lambda x: x["card"]):
        full, card = e["full"], e["card"]
        hi = full in ios_images
        ha = full in android_images
        badges = ""
        if hi: badges += '<span class="bg bg-i">iOS</span>'
        if ha: badges += '<span class="bg bg-a">And</span>'
        ii = f'<img src="screenshots/ios/{ios_images[full]}" alt="{card}" onclick="window.open(this.src)">' if hi else '<div class="ms">—</div>'
        ai = f'<img src="screenshots/android/{android_images[full]}" alt="{card}" onclick="window.open(this.src)">' if ha else '<div class="ms">—</div>'
        lines.append(f'<div class="c" data-c="{card}" data-p="{preset_name}"><div class="ch"><span class="n">{card}</span><span class="b">{badges}</span></div>')
        lines.append(f'<div class="cb"><div class="p"><div class="pl">iOS</div>{ii}</div><div class="p"><div class="pl">Android</div>{ai}</div></div></div>')

    lines.append('</div></div>')

lines.append("""<script>
function fc(){var p=document.getElementById('pf').value,s=document.getElementById('sb').value.toLowerCase();
document.querySelectorAll('.sec').forEach(function(sec){var sp=sec.dataset.p,show=p==='all'||sp===p;
sec.style.display=show?'':'none';if(show){sec.querySelectorAll('.c').forEach(function(c){
c.style.display=c.dataset.c.toLowerCase().includes(s)?'':'none'})}})}</script></body></html>""")

html = "\n".join(lines)
os.makedirs(site_dir, exist_ok=True)
with open(os.path.join(site_dir, "index.html"), "w") as f:
    f.write(html)
open(os.path.join(site_dir, ".nojekyll"), "w").close()

print(f"Generated catalog: {len(all_names)} cards, {n_ios} iOS + {n_android} Android")
print(f"Active presets: {active}")
