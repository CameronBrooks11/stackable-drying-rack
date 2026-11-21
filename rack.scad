use <tessella/tess.scad>;

z_fight = 0.01; // Small offset to prevent z-fighting in the model

basin_diameter = 150; // mm
basin_height = 8; // mm
basin_thickness = 2.4; // mm
basin_grid_diameter = 5; // mm
basin_grid_spacing = 1; // Spacing between hexagons
rod_bore_diameter = 5; // mm

layout_basins = false; // Whether to layout multiple basins in a grid

rows = 6;
cols = 5;

show_row_rods = false; // Whether to include rods in the corner bores

if (layout_basins)
    layout_childen(outer_diameter=basin_diameter + basin_thickness * 2, rows=rows, cols=cols)
        connected_basin(basin_diameter, basin_height, basin_thickness, basin_grid_diameter, basin_grid_spacing, show_rods=show_row_rods);
else
    connected_basin(basin_diameter, basin_height, basin_thickness, basin_grid_diameter, basin_grid_spacing, show_rods=show_row_rods);

bounds = layout_bounding_box(outer_diameter=basin_diameter + basin_thickness * 2, centers=hexagons_centers_rect(radius=(basin_diameter + basin_thickness * 2) / 2, n=rows, m=cols));

echo(str("Number of basins: ", rows * cols));

echo(str("X dimensions: ", bounds[1] - bounds[0]));
echo(str("Y dimensions: ", bounds[3] - bounds[2]));

module layout_childen(outer_diameter, rows, cols) {
    centers = hexagons_centers_rect(radius=outer_diameter / 2, n=rows, m=cols);
    for (i = [0:rows - 1])
        for (j = [0:cols - 1])
            translate(centers[i * cols + j])
                rotate([0, 0, 30]) // Rotate to align with the hexagonal pattern
                    // random color somewhat visually distinguishable between basins
                    // color takes values between 0 and 1, so we use a sine and cosine function to create a range of colors based on the position in the grid
                    color([(0.5 + 0.5 * sin(i * 60 + j * 60)), (0.5 + 0.5 * cos(i * 60 + j * 60)), (0.5 + 0.5 * sin(i * 60 - j * 60))])
                        children();
}

function layout_bounding_box(outer_diameter, centers) =
    let (
        radius = outer_diameter / 2,
        x_min = min([for (i = [0:len(centers) - 1]) centers[i][0] - diameter_to_width(radius)]),
        x_max = max([for (i = [0:len(centers) - 1]) centers[i][0] + diameter_to_width(radius)]),
        y_min = min([for (i = [0:len(centers) - 1]) centers[i][1] - radius]),
        y_max = max([for (i = [0:len(centers) - 1]) centers[i][1] + radius])
    ) [x_min, x_max, y_min, y_max];

function diameter_to_width(diameter) = (sqrt(3) / 2) * (diameter);

module connected_basin(diameter, height, thickness, grid_diameter, grid_spacing, dovetail_width = 20, dovetail_angle = 30, dovetail_allowance = 0.2, show_rods = false) {

    // Derived dovetail dimensions based on the basin dimensions
    dovetail_height = height / 2;
    dovetail_depth = thickness * 2;

    // Distance from flat to flat of the hexagon, which determines how far the dovetails will be from the center
    flat_width = diameter_to_width(diameter + thickness * 2);
    side_length = (diameter + thickness * 2) / 2; // Length of one side of the hexagon
    number_dovetails_per_side = floor((side_length - dovetail_width) / (dovetail_width + dovetail_depth * tan(dovetail_angle))); // Calculate how many dovetails can fit on one side
    dt_offset = (side_length / (number_dovetails_per_side)); // Offset to center the dovetails on the side

    difference() {
        union() {
            // Create the main basin structure
            basin(diameter, height, thickness, grid_diameter, grid_spacing);

            // Add dovetails around the perimeter of the basin
            for (i = [0, 1, 2])
                rotate([0, 0, i * 120])for (j = [0:number_dovetails_per_side - 1])
                    translate([dt_offset * j - dt_offset * (number_dovetails_per_side - 1) / 2, flat_width / 2, 0])
                        dovetail(dovetail_width, dovetail_height, dovetail_depth, dovetail_angle);
        }

        // Cut out the dovetails with allowance for fit
        for (i = [0, 1, 2])
            rotate([0, 0, i * 120 + 60])for (j = [0:number_dovetails_per_side - 1])
                translate([dt_offset * j - dt_offset * (number_dovetails_per_side - 1) / 2, flat_width / 2 + z_fight, -z_fight])
                    rotate([0, 0, 180])
                        dovetail(dovetail_width + dovetail_allowance, dovetail_height + dovetail_allowance, dovetail_depth + dovetail_allowance, dovetail_angle);

        // Cut double countersink cores for friction fit rods
        for (i = [0:5])
            rotate([0, 0, i * 60 + 30]) translate([0, diameter / 2 - thickness + z_fight, -z_fight])
                    double_countersink(diameter=rod_bore_diameter, height=basin_height + z_fight * 2);
    }

    // Add rods for visual reference if show_rods is true
    if (show_rods) {
        for (i = [0:5])
            rotate([0, 0, i * 60 + 30]) translate([0, diameter / 2 - thickness + z_fight, height / 2])
                    cylinder(h=basin_height * 5, d=rod_bore_diameter - 0.2);
        // Slightly smaller diameter for visual distinction
    }
}

module basin(diameter, height, thickness, grid_diameter, grid_spacing) {
    difference() {
        linear_extrude(height=height)
            circle(d=diameter + thickness * 2, $fn=6);

        // Cut out basin
        translate([0, 0, height + z_fight])
            rotate([0, 180, 0])
                linear_extrude(height=height - thickness, scale=2 / 3)
                    circle(d=diameter - thickness * 2, $fn=6);

        // Cut out holes for drainage
        lvls = round((diameter * sin(60) - grid_diameter * 2) / ( (grid_diameter + grid_spacing * 2) * 2) - 1);
        centers = hexagons_centers_radial(radius=grid_diameter, levels=lvls);
        // Generate vertices for the hexagons
        vertices = hexagons_vertices(radius=grid_diameter - grid_spacing, centers=centers, angular_offset=30);

        // Render the hexagons
        translate([0, 0, -height])
            generic_poly(
                vertices=vertices,
                paths=[[0, 1, 2, 3, 4, 5, 0]], // Hexagon paths
                centers=centers,
                extrude=height * 2
            );
    }
}

module dovetail(width, height, depth, angle) {

    linear_extrude(height=height)
        polygon(
            points=[
                [-width / 2, 0],
                [width / 2, 0],
                [width / 2 + depth * tan(angle), depth],
                [-width / 2 - depth * tan(angle), depth],
            ]
        );
}

module double_countersink(diameter, height) {
    for (i = [0, 1])
        translate([0, 0, (i ? height : 0)]) mirror([0, 0, i]) {
                linear_extrude(height=height / 2, scale=2 / 3)
                    circle(d=diameter, $fn=16);
            }
}
