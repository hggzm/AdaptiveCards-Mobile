#!/usr/bin/env python3
"""
Generate a visual snapshot catalog HTML page from CI artifacts.

Handles the different naming conventions between iOS and Android:
- iOS:     {card}_{DeviceConfig}.png         e.g. accordion_iPhone_15_Pro.png
- Android: ...Tests_snapshot_{preset}[{card}]_{suffix}.png
           e.g. ..._defaultConfig[accordion]_accordion.png

Groups cards by preset (Default, Teams, Evolution) and shows
side-by-side iOS + Android screenshots.
"""
import os, sys, re
from pathlib import Path
from datetime import datetime

site_dir = sys.argv[1] if len(sys.argv) > 1 else "_site"
ios_dir = os.path.join(site_dir, "screenshots", "ios")
android_dir = os.path.join(site_dir, "screenshots", "android")

# ── Discover all PNGs ────────────────────────────────────────

def find_all_pngs(base_dir):
    """Return list of (relative_path, stem) for every PNG under base_dir."""
    results = []
    if not os.path.exists(base_dir):
        return results
    for root, _, files in os.walk(base_dir):
        for f in files:
            if f.endswith(".png"):
                rel = os.path.relpath(os.path.join(root, f), base_dir)
                results.append((rel, Path(f).stem))
    return results

ios_pngs = find_all_pngs(ios_dir)
android_pngs = find_all_pngs(android_dir)

# ── Parse iOS filenames ──────────────────────────────────────
# Pattern: {cardName}_{device}[_{variant}].png
# Device configs: iPhone_15_Pro, iPad_Portrait, iPhone_SE, etc.
# Variants: Dark, A11y_XXXL, A11y_XL, etc.

IOS_DEVICE_SUFFIXES = [
    "_iPhone_15_Pro_A11y_XXXL", "_iPhone_15_Pro_A11y_XL",
    "_iPhone_15_Pro_A11y_XS", "_iPhone_15_Pro_A11y_Medium",
    "_iPhone_15_Pro_Dark", "_iPhone_15_Pro_Landscape",
    "_iPhone_15_Pro",
    "_iPhone_SE_Dark", "_iPhone_SE_Landscape", "_iPhone_SE",
    "_iPad_Portrait_Dark", "_iPad_Landscape", "_iPad_Portrait",
]

def parse_ios_name(stem):
    """Extract (card_name, device_config) from an iOS baseline filename."""
    for suffix in IOS_DEVICE_SUFFIXES:
        if stem.endswith(suffix):
            card = stem[:-len(suffix)]
            return card, suffix[1:]  # strip leading _
    return stem, "unknown"

# ── Parse Android filenames ──────────────────────────────────
# AllCardsDiscoveryTests:
#   ..._snapshot_defaultConfig[{card}]_{card}.png
#   ..._snapshot_teamsConfig[{card}]_teams_{card}.png
# HostConfigSnapshotTests:
#   ..._snapshot_{preset}Config[{card}]_hc_{preset}_{card}.png

ANDROID_PATTERN = re.compile(
    r'_snapshot_(\w+Config)\[([^\]]+)\]_(.+)$'
)

def parse_android_name(stem):
    """Extract (card_name, config_name) from an Android Paparazzi filename."""
    m = ANDROID_PATTERN.search(stem)
    if m:
        config = m.group(1)  # e.g. defaultConfig, teamsConfig, evolutionLightConfig
        card = m.group(2)    # e.g. accordion, simple-text
        return card, config
    return stem, "unknown"

# ── Build unified card index ─────────────────────────────────

# Map: preset -> card_name -> {ios: [paths], android: [paths]}
PRESET_MAP = {
    "defaultConfig": "Default",
    "teamsConfig": "Teams",
    "evolutionLightConfig": "EvolutionLight",
    "evolutionDarkConfig": "EvolutionDark",
    "teamsDarkConfig": "TeamsDark",
    "teamsLightConfig": "TeamsLight",
}

# iOS device configs to presets (iOS baselines are all default config)
IOS_PRESET = "Default"

catalog = {}  # preset -> card -> {ios: rel_path, android: rel_path, ios_device: str}

# Process iOS
for rel, stem in ios_pngs:
    card, device = parse_ios_name(stem)
    key = f"{card}|{device}"
    preset = IOS_PRESET
    if preset not in catalog:
        catalog[preset] = {}
    if key not in catalog[preset]:
        catalog[preset][key] = {"card": card, "device": device, "ios": None, "android": None}
    catalog[preset][key]["ios"] = rel

# Process Android
for rel, stem in android_pngs:
    card, config = parse_android_name(stem)
    preset = PRESET_MAP.get(config, config)
    if preset not in catalog:
        catalog[preset] = {}
    # For Android, use card name as key (no device variant)
    key = card
    if key not in catalog[preset]:
        catalog[preset][key] = {"card": card, "device": "Phone", "ios": None, "android": None}
    catalog[preset][key]["android"] = rel

# Now cross-link: for Default preset, match iOS cards (with device suffix) to Android cards
# An iOS entry like accordion|iPhone_15_Pro should match Android accordion
if "Default" in catalog:
    android_by_card = {}
    ios_entries = {}
    for key, entry in catalog["Default"].items():
        if entry["android"]:
            android_by_card[entry["card"]] = entry["android"]
        if entry["ios"] and "|" in key:
            ios_entries[key] = entry

    # Fill in Android paths for iOS entries that lack them
    for key, entry in ios_entries.items():
        if not entry["android"] and entry["card"] in android_by_card:
            entry["android"] = android_by_card[entry["card"]]

    # Fill in iOS paths for Android entries that have no iOS yet
    # Use the iPhone_15_Pro variant as the primary iOS match
    ios_by_card = {}
    for key, entry in catalog["Default"].items():
        if entry["ios"] and entry.get("device") == "iPhone_15_Pro":
            ios_by_card[entry["card"]] = entry["ios"]

    for key, entry in catalog["Default"].items():
        if not entry["ios"] and entry["card"] in ios_by_card:
            entry["ios"] = ios_by_card[entry["card"]]

# Do the same for Teams preset - match to iOS baselines (which are all default config)
for preset in ["Teams", "TeamsLight", "TeamsDark", "EvolutionLight", "EvolutionDark"]:
    if preset not in catalog:
        continue
    for key, entry in catalog[preset].items():
        if not entry["ios"] and entry["card"] in ios_by_card:
            # Show the default iOS baseline as reference
            pass  # Don't cross-fill — keep it honest about what's missing

# ── Generate HTML ────────────────────────────────────────────

ts = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
n_ios = len(ios_pngs)
n_android = len(android_pngs)
total_cards = sum(len(entries) for entries in catalog.values())
active_presets = [p for p in catalog if catalog[p]]

# Count paired vs unpaired
paired = sum(1 for p in catalog for e in catalog[p].values() if e["ios"] and e["android"])
ios_only = sum(1 for p in catalog for e in catalog[p].values() if e["ios"] and not e["android"])
android_only = sum(1 for p in catalog for e in catalog[p].values() if not e["ios"] and e["android"])

html = f"""<!DOCTYPE html>
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
.st.good{{color:#3fb950}}.st.warn{{color:#f0883e}}
.ctrl{{padding:10px 16px;background:#161b22;border-bottom:1px solid #30363d;display:flex;gap:8px;flex-wrap:wrap;align-items:center}}
.ctrl select,.ctrl input{{padding:5px 8px;border:1px solid #30363d;border-radius:5px;background:#0d1117;color:#c9d1d9;font-size:12px}}
.ctrl input{{flex:1;min-width:180px}}
.ctrl label{{font-size:12px;color:#8b949e;display:flex;align-items:center;gap:4px}}
.sec{{padding:14px 16px}}.sec-t{{font-size:15px;font-weight:600;margin-bottom:10px;padding-bottom:5px;border-bottom:2px solid #30363d}}
.sec-t.df{{color:#8b949e;border-color:#8b949e}}.sec-t.tm{{color:#6264A7;border-color:#6264A7}}
.sec-t.ev{{color:#2ecc71;border-color:#2ecc71}}.sec-t.dk{{color:#f0883e;border-color:#f0883e}}
.g{{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:10px}}
.c{{background:#161b22;border:1px solid #30363d;border-radius:6px;overflow:hidden}}.c:hover{{border-color:#58a6ff}}
.c.paired{{border-left:3px solid #3fb950}}.c.ios-only{{border-left:3px solid #58a6ff}}.c.android-only{{border-left:3px solid #3fb950}}
.ch{{padding:6px 10px;background:#21262d;font-size:12px;font-weight:500;display:flex;justify-content:space-between}}
.ch .n{{color:#c9d1d9}}.ch .d{{color:#8b949e;font-size:10px}}
.cb{{display:flex;gap:6px;padding:6px}}.cb .p{{flex:1;text-align:center}}
.cb .pl{{font-size:9px;text-transform:uppercase;color:#8b949e;letter-spacing:1px;margin-bottom:3px}}
.cb img{{max-width:100%;border:1px solid #30363d;border-radius:3px;cursor:pointer}}.cb img:hover{{border-color:#58a6ff}}
.cb .ms{{color:#484f58;font-size:10px;padding:16px 0;font-style:italic}}
</style></head><body>
<div class="hdr"><h1>Adaptive Cards Mobile — Visual Snapshot Catalog</h1>
<p>Generated {ts} from CI artifacts</p>
<div class="stats">
<span class="st">iOS: <b>{n_ios}</b></span>
<span class="st">Android: <b>{n_android}</b></span>
<span class="st good">Paired: <b>{paired}</b></span>
<span class="st warn">iOS only: <b>{ios_only}</b></span>
<span class="st warn">Android only: <b>{android_only}</b></span>
<span class="st">Presets: <b>{len(active_presets)}</b></span>
</div></div>
<div class="ctrl">
<select id="pf" onchange="fc()"><option value="all">All Presets</option>
"""

# Preset order
PRESET_ORDER = ["Default", "Teams", "TeamsLight", "TeamsDark", "EvolutionLight", "EvolutionDark"]
ordered_presets = [p for p in PRESET_ORDER if p in catalog] + [p for p in catalog if p not in PRESET_ORDER]

for p in ordered_presets:
    n = len(catalog[p])
    html += f'<option value="{p}">{p} ({n})</option>\n'

html += """</select>
<input type="text" id="sb" placeholder="Search cards..." oninput="fc()">
<label><input type="checkbox" id="po" onchange="fc()"> Paired only</label>
</div>
"""

# Emit sections
for preset in ordered_presets:
    entries = catalog[preset]
    if not entries:
        continue

    cls = "df"
    if "Teams" in preset: cls = "tm"
    elif "Evolution" in preset: cls = "ev"
    if "Dark" in preset: cls += " dk"

    n_paired = sum(1 for e in entries.values() if e["ios"] and e["android"])
    html += f'<div class="sec" data-p="{preset}">\n'
    html += f'<div class="sec-t {cls}">{preset} ({len(entries)} entries, {n_paired} paired)</div><div class="g">\n'

    for key in sorted(entries.keys()):
        e = entries[key]
        card = e["card"]
        device = e.get("device", "")
        has_ios = e["ios"] is not None
        has_android = e["android"] is not None
        is_paired = has_ios and has_android

        css = "paired" if is_paired else ("ios-only" if has_ios else "android-only")
        device_label = f' <span class="d">{device}</span>' if device and device != "Phone" else ""

        ios_img = f'<img src="screenshots/ios/{e["ios"]}" alt="{card} iOS" loading="lazy" onclick="window.open(this.src)">' if has_ios else '<div class="ms">not recorded</div>'
        and_img = f'<img src="screenshots/android/{e["android"]}" alt="{card} Android" loading="lazy" onclick="window.open(this.src)">' if has_android else '<div class="ms">not recorded</div>'

        html += f'<div class="c {css}" data-c="{card}" data-p="{preset}" data-paired="{1 if is_paired else 0}">'
        html += f'<div class="ch"><span class="n">{card}</span>{device_label}</div>'
        html += f'<div class="cb"><div class="p"><div class="pl">iOS</div>{ios_img}</div>'
        html += f'<div class="p"><div class="pl">Android</div>{and_img}</div></div></div>\n'

    html += '</div></div>\n'

html += """<script>
function fc(){
  var p=document.getElementById('pf').value;
  var s=document.getElementById('sb').value.toLowerCase();
  var po=document.getElementById('po').checked;
  document.querySelectorAll('.sec').forEach(function(sec){
    var sp=sec.dataset.p, show=p==='all'||sp===p;
    sec.style.display=show?'':'none';
    if(show){sec.querySelectorAll('.c').forEach(function(c){
      var nm=c.dataset.c.toLowerCase().includes(s);
      var paired=c.dataset.paired==='1';
      c.style.display=(nm&&(!po||paired))?'':'none';
    })}
  });
}
</script></body></html>"""

# Write
os.makedirs(site_dir, exist_ok=True)
with open(os.path.join(site_dir, "index.html"), "w") as f:
    f.write(html)
open(os.path.join(site_dir, ".nojekyll"), "w").close()

print(f"Generated catalog:")
print(f"  Total entries: {total_cards}")
print(f"  iOS PNGs:      {n_ios}")
print(f"  Android PNGs:  {n_android}")
print(f"  Paired:        {paired}")
print(f"  iOS only:      {ios_only}")
print(f"  Android only:  {android_only}")
print(f"  Presets:        {', '.join(ordered_presets)}")
