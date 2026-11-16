"""Render the rack and check the parts fit.

usage: python3 tests/test_rack.py [OPENSCAD]

Run with tessella on OPENSCADPATH (`just test` does this through scadman).

- rack.scad renders with --hardwarnings, as one basin and as 1x2, 2x1 and 2x2
  layouts.
- One basin is 8 mm tall and, across the flats, its outer hexagon plus one
  row of dovetail tabs: (150 + 2 * 2.4) * sqrt(3) / 2 + 2 * 2.4 = 138.861 mm.
- Neighbouring basins sit one flat-to-flat width apart, 134.061 mm, so each
  basin's tabs reach into its neighbour's slots.
- The layouts' volume is exactly the basins' volumes added up: the tabs sit in
  the slots without colliding. A tab wider than its slot shows up as overlap.
"""

import math
import os
import re
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RACK = os.path.join(ROOT, "rack.scad")
OUTER = 150 + 2 * 2.4                    # basin_diameter + 2 * basin_thickness
FLAT = OUTER * math.sqrt(3) / 2          # outer hexagon across the flats
TAB = 2 * 2.4                            # dovetail depth: 2 * basin_thickness

results = []


def check(label, ok, got):
    results.append(bool(ok))
    print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")


def run(openscad, out, *args):
    r = subprocess.run([openscad, "--hardwarnings", *args, "-o", out], capture_output=True, text=True)
    bad = [l for l in r.stderr.splitlines() if "WARNING" in l or "ERROR" in l]
    return r.returncode == 0 and not bad, (bad[:1] or [f"exit {r.returncode}"])[0], r.stderr


def mesh(path):
    """Signed volume and bounding-box size of a binary STL."""
    data = open(path, "rb").read()
    (n,) = struct.unpack_from("<I", data, 80)
    vol, lo, hi = 0.0, [1e9] * 3, [-1e9] * 3
    for i in range(n):
        t = struct.unpack_from("<9f", data, 84 + i * 50 + 12)
        a, b, c = t[0:3], t[3:6], t[6:9]
        vol += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0])
                + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6
        for p in (a, b, c):
            for k in range(3):
                lo[k], hi[k] = min(lo[k], p[k]), max(hi[k], p[k])
    return vol, [hi[k] - lo[k] for k in range(3)]


def main():
    openscad = sys.argv[1] if len(sys.argv) > 1 else "openscad"
    with tempfile.TemporaryDirectory() as tmp:
        stl = os.path.join(tmp, "out.stl")

        ok, why, _ = run(openscad, stl, "--export-format", "binstl", RACK)
        check("one basin renders", ok, why if not ok else "no warnings")
        if not ok:
            return
        one, size = mesh(stl)
        check("one basin's size", abs(size[1] - (FLAT + TAB)) < 0.01 and abs(size[2] - 8) < 0.01,
              f"{size[1]:.3f} x {size[2]:.3f} mm across the flats x tall; want {FLAT + TAB:.3f} x 8")

        probe = os.path.join(tmp, "centres.scad")
        with open(probe, "w") as f:
            f.write("use <tessella/tess.scad>;\n"
                    f"echo(c=hexagons_centers_rect(radius={OUTER / 2}, n=1, m=2));\n"
                    f"echo(c=hexagons_centers_rect(radius={OUTER / 2}, n=2, m=1));\n")
        ok, why, err = run(openscad, os.path.join(tmp, "c.echo"), "--export-format", "echo", probe)
        gaps = []
        for line in open(os.path.join(tmp, "c.echo")).read().splitlines() if ok else []:
            pts = [tuple(map(float, p)) for p in re.findall(r"\[([-\d.e]+), ([-\d.e]+)\]", line)]
            gaps.append(math.dist(pts[0], pts[1]))
        check("neighbours sit one flat-to-flat width apart", len(gaps) == 2 and all(abs(g - FLAT) < 0.01 for g in gaps),
              f"{', '.join(f'{g:.3f}' for g in gaps) or why} mm; want {FLAT:.3f}")

        for rows, cols in ((1, 2), (2, 1), (2, 2)):
            ok, why, _ = run(openscad, stl, "--export-format", "binstl", "-D", "layout_basins=true",
                             "-D", f"rows={rows}", "-D", f"cols={cols}", RACK)
            if not ok:
                check(f"{rows}x{cols} layout renders", False, why)
                continue
            vol, _ = mesh(stl)
            n = rows * cols
            check(f"{rows}x{cols} layout: tabs sit in slots without overlap", abs(vol - n * one) < 0.5,
                  f"{vol:.1f} mm3; {n} basins alone {n * one:.1f}")

    print(f"{sum(results)} of {len(results)} checks passed")


if __name__ == "__main__":
    main()
    sys.exit(0 if results and all(results) else 1)
