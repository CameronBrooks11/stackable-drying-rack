default:
    @just --list

# Render the rack alone and in layouts, and check its size and that neighbours' dovetails fit
test:
    scadman sync
    OPENSCADPATH="$(scadman env)" python3 tests/test_rack.py

# Render the README picture into docs/img/
images:
    @mkdir -p docs/img
    scadman sync
    OPENSCADPATH="$(scadman env)" openscad --render --imgsize=900,600 --viewall --autocenter --camera=0,0,0,50,0,30,0 --colorscheme=Tomorrow -D layout_basins=true -D rows=2 -D cols=2 -o docs/img/2x2-layout.png rack.scad

# Everything CI runs, bar the tests
check: fmt-check

# Format the .scad sources with topiary (.topiary/languages.ncl)
fmt:
    git ls-files -z '*.scad' | xargs -0 -r topiary format

# Check the .scad sources are formatted, without changing them
fmt-check:
    git ls-files -z '*.scad' | xargs -0 -r -n1 topiary format --check
