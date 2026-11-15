# stackable-drying-rack

Parametric, modular drying rack system with stackable units for customizable airflow, capacity, and footprint.

## Usage

Depends on OpenSCAD and uses the [tessella library](https://github.com/CameronBrooks11/tessella)
at `v0.1.0`, which `scadman.lock` pins. With [scadman](https://github.com/CameronBrooks11/scadman)
installed, render or open the rack with it on the library path:

```sh
scadman run rack.scad -o rack.stl   # or: scadman sync, then add the folder `scadman env` prints to OPENSCADPATH
```

Without scadman, clone tessella at that tag into your OpenSCAD libraries folder:

```sh
git clone --branch v0.1.0 https://github.com/CameronBrooks11/tessella.git
```
