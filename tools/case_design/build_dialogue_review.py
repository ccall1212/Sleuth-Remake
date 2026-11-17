"""Build a single readable HTML page of all dialogue for review: python tools/case_design/build_dialogue_review.py

Lines the game colours (assets/dialogue/styles.json) are shown in that colour so the scheme can be checked by eye.
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
D = ROOT / "assets" / "dialogue"
OUT = ROOT / "docs" / "case-design" / "dialogue-review" / "index.html"
SLOT = re.compile(r"\{(\w+)\}")


def esc(text: str) -> str:
    return SLOT.sub(lambda m: f'<b class="slot">{{{m.group(1)}}}</b>', html.escape(text))


def main() -> None:
    personalities = json.loads((D / "personalities.json").read_text(encoding="utf-8"))
    personalities = personalities.get("personalities", personalities)
    system = json.loads((D / "system.json").read_text(encoding="utf-8"))
    styles = json.loads((D / "styles.json").read_text(encoding="utf-8"))
    fixtures = json.loads((ROOT / "docs/case-design/dialogue_fixtures.json").read_text(encoding="utf-8"))

    def tint(key: str, group: str) -> str:
        name = styles.get(group, {}).get(key)
        return f' style="color:{styles["colors"][name]}"' if name else ""

    legend = " ".join(f'<span style="color:{hex_}">{name} {hex_}</span>' for name, hex_ in styles["colors"].items())
    out = ['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
           '<title>Dialogue review</title><style>:root{--bg:#14171b;--fg:#e6e6ea;--mut:#9a9aa6;--acc:#efd29a}'
           'body{background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,sans-serif;margin:0 auto;max-width:980px;padding:16px}'
           'h1,h2,h3{color:var(--acc)}nav a{margin-right:12px;color:var(--acc)}li{margin:5px 0}'
           '.slot{color:#7fc4ff;font-weight:600}.mut{color:var(--mut)}'
           'details{margin:8px 0;border:1px solid #2a2f36;border-radius:6px;padding:6px 10px}summary{cursor:pointer;font-weight:600}'
           'table{border-collapse:collapse;width:100%}td{border-top:1px solid #2a2f36;padding:6px;vertical-align:top}</style>',
           '<h1>Dialogue review</h1>',
           '<p class="mut">Everything the game can say, from <code>assets/dialogue/personalities.json</code>, <code>system.json</code> and '
           '<code>styles.json</code>. <span class="slot">{slots}</span> are filled by the game. Eight personalities x 18 line types x 6 variants, '
           'plus narrator text. First question: opening + "claim commentary"; repeat: "lead claim close".</p>',
           f'<p><b>Text colours:</b> {legend} (suspicious warning yellow, stalking warning orange, blood and ambush death text red).</p>',
           '<nav><a href="#samples">Sample answers</a><a href="#system">System text</a>'
           + "".join(f'<a href="#p-{k}">{k}</a>' for k in personalities) + "</nav>"]
    out.append('<h2 id="samples">Sample answers (case seed 0, Normal, six suspects)</h2><table>')
    case = next(c for c in fixtures["cases"] if c["seed"] == 0 and c["difficulty"] == "normal")
    for ask in case["asks"]:
        out.append(f'<tr><td><b>{html.escape(ask["personality"])}</b><br><span class="mut">{ask["claim_kind"]}</span></td>'
                   f'<td>{html.escape(ask["first"])}<br><span class="mut">Asked again:</span> {html.escape(ask["repeat"])}</td></tr>')
    out.append("</table>")
    out.append('<h2 id="system">System text</h2>')
    for key, value in system.items():
        variants = [value] if isinstance(value, str) else value
        out.append(f'<details><summary>{html.escape(key)} <span class="mut">({len(variants)})</span></summary>'
                   f'<ul{tint(key, "system")}>' + "".join(f"<li>{esc(v)}</li>" for v in variants) + "</ul></details>")
    for name, lines in personalities.items():
        out.append(f'<h2 id="p-{name}">{html.escape(name)}</h2>')
        for kind, variants in lines.items():
            variants = [variants] if isinstance(variants, str) else variants
            out.append(f'<details><summary>{html.escape(kind)} <span class="mut">({len(variants)})</span></summary>'
                       f'<ul{tint(kind, "personality_lines")}>' + "".join(f"<li>{esc(v)}</li>" for v in variants) + "</ul></details>")
    out.append("</html>")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out), encoding="utf-8")
    print(OUT)


if __name__ == "__main__":
    main()
