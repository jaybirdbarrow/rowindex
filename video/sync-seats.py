"""Copies the seated teams from base.html into video/seats.js, so the intro
always matches the site. render-intro.sh runs this first; run it by hand
after seating a team if you want to preview intro.html in a browser.

Reads SEATED (name, arena, dark), IMGS (badge) and BUCKETS (arena names).
Seats without a badge image are left out, the same as the index grid."""
import json, os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "..", "base.html"), encoding="utf-8").read()

def block(name, close):
    m = re.search(r"^const %s=.*?^%s;" % (name, re.escape(close)), src, re.S | re.M)
    if not m:
        sys.exit("Couldn't find %s in base.html" % name)
    return m.group(0)

arenas = dict(re.findall(r'\{k:"(\w+)",n:"([^"]+)"\}', block("BUCKETS", "]")))
imgs = {int(s): p for s, p in re.findall(r'^\s*(\d+):"([^"]+)"', block("IMGS", "}"), re.M)}

seats = {}
for s, body in re.findall(r"^\s*(\d+):\{(.*)\},?\s*$", block("SEATED", "}"), re.M):
    s = int(s)
    if s not in imgs:
        continue
    field = lambda k: (re.search(r'\b%s:"([^"]*)"' % k, body) or [None, None])[1]
    seats[s] = {
        "n": field("n"),
        "a": arenas[field("chip") or field("b")],
        "dark": "dark:true" in body,
        "img": ".." + imgs[s],
    }

with open(os.path.join(here, "seats.js"), "w", encoding="utf-8") as f:
    f.write("// Generated from base.html by sync-seats.py. Don't edit by hand.\n")
    f.write("const SEATS=%s;\n" % json.dumps(seats, indent=1, ensure_ascii=False))
print("%d seats synced, newest is %d (%s)" % (len(seats), max(seats), seats[max(seats)]["n"]))
