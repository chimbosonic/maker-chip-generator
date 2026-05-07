// Maker chip — embossed casino-style poker chip.
//
// Geometry: a flat central disc with embossed features on each face. The
// edge spots, logo, and text all rise from the disc surface to the same
// height — the spot tops form the "rim" silhouette of a casino chip while
// the disc itself sits inset between them.
// Total thickness = thickness_base + (sides × emboss_height).
//
// FDM print orientation: FACE UP. Embossed features on the bottom face
// land directly on the bed; use a brim if adhesion is borderline. The
// disc layer above them bridges only across the small gaps between spots
// (~4mm), which slicers handle cleanly. Top-face features print last
// with the cleanest detail.

// ---- Standard dimensions ----
diameter        = 39;     // casino standard (mm)
thickness       = 3.5;    // total chip thickness (mm) — casino standard
// Disc rim chamfer pulls the disc's outer radius in at top/bottom, which
// leaves the embossed spots sticking out past the disc edge. Keep at 0 for
// a clean spot-to-disc transition.
chip_chamfer    = 0;

// ---- Embossed faces ----
emboss_height   = 1.0;    // height of all embossed features (mm)
                          // 5 layers @ 0.2mm — strong, layer-aligned
art_on_top      = true;
art_on_bottom   = true;

// ---- Edge spots (embossed) ----
edge_spots          = 16;
edge_spot_arc_deg   = 14;
edge_spot_radial_mm = 2;  // how far each spot extends inward from the rim
spot_chamfer        = 0.3; // chamfer at each end of the spot (mm), 0 to disable

// ---- Logo ----
logo_file       = "logo.dxf"; // set to "" to disable
logo_size       = 30;     // target width in mm (height auto-scaled)
logo_x_offset   = -1;
logo_y_offset   = -1;
// Source DXF bounding box (used to recenter the artwork on origin).
logo_dxf_w      = 550;
logo_dxf_h      = 324;
logo_clip       = false;   // clip stray DXF geometry to a circle

// ---- Text ----
text_top        = "CHIMBO";
text_bottom     = "SONIC";
text_size       = 4;
text_y_offset   = 11;     // distance from chip center to text baseline (mm)
text_spacing    = 1;      // letter tracking
text_font       = "Orbitron:style=Bold";

// ---- Colors ----
// Visible in the OpenSCAD preview and preserved in 3MF / AMF exports for
// multi-material slicers. STL is colorless — for STL, export each piece
// to its own file (one tweak: comment out the other color blocks).
disc_color   = "Gold";
spot_color   = "FireBrick";
logo_color   = "Black";
text_color   = "White";

$fa = 2;
$fs = 0.4;

// ---- Derived ----
sides           = (art_on_top ? 1 : 0) + (art_on_bottom ? 1 : 0);
thickness_base  = thickness - sides * emboss_height;

// ---- Build ----
assert(thickness_base > 0,
       "thickness too small for chosen emboss_height; reduce emboss_height or increase thickness");

z_disc_bottom = art_on_bottom ? emboss_height : 0;

union() {
    if (art_on_bottom) {
        // Flip the spots so their chamfered (apex) end faces the bed,
        // matching the chamfered top end of the top-face spots above.
        color(spot_color)
            translate([0, 0, emboss_height])
                mirror([0, 0, 1])
                    spots_3d(emboss_height, spot_chamfer);
        color(logo_color)
            linear_extrude(height = emboss_height)
                face_logo_2d();
        color(text_color)
            linear_extrude(height = emboss_height)
                face_text_2d();
    }

    color(disc_color)
        translate([0, 0, z_disc_bottom])
            chip_disc();

    if (art_on_top)
        translate([0, 0, z_disc_bottom + thickness_base]) {
            color(spot_color)
                spots_3d(emboss_height, spot_chamfer);
            color(logo_color)
                linear_extrude(height = emboss_height)
                    face_logo_2d();
            color(text_color)
                linear_extrude(height = emboss_height)
                    face_text_2d();
        }
}

// Flat base disc with optional chamfered top/bottom edges.
module chip_disc() {
    r = diameter / 2;
    c = max(0, chip_chamfer);
    h = thickness_base;
    if (c > 0 && 2 * c < h) {
        rotate_extrude()
            polygon([
                [0,         0],
                [r - c,     0],
                [r,         c],
                [r,         h - c],
                [r - c,     h],
                [0,         h],
            ]);
    } else {
        cylinder(h = h, d = diameter);
    }
}

// 2D logo only. Extruded separately from the text so it can take its own
// color in the preview / multi-material export.
module face_logo_2d() {
    if (logo_file != "") logo_2d();
}

// 2D text (top label + bottom label). Same reasoning as face_logo_2d.
module face_text_2d() {
    if (text_top != "")
        translate([0, text_y_offset, 0])
            text(text_top, size = text_size, font = text_font,
                 spacing = text_spacing,
                 halign = "center", valign = "center");
    if (text_bottom != "")
        translate([0, -text_y_offset, 0])
            text(text_bottom, size = text_size, font = text_font,
                 spacing = text_spacing,
                 halign = "center", valign = "center");
}

// All embossed spots, placed around the chip. Built directly in 3D (not
// extruded from a 2D pattern) so the outer edge follows a true arc and
// the top/bottom corners can be chamfered.
module spots_3d(height, chamfer) {
    if (edge_spots > 0) {
        for (i = [0 : edge_spots - 1]) {
            rotate([0, 0, i * 360 / edge_spots])
                spot_3d(
                    diameter / 2 - edge_spot_radial_mm,
                    diameter / 2,
                    edge_spot_arc_deg,
                    height,
                    chamfer);
        }
    }
}

// One spot: rotate-extrude a chamfered radial profile by arc_deg degrees,
// centered on the +X axis.
module spot_3d(r_inner, r_outer, arc_deg, h, c) {
    rotate([0, 0, -arc_deg / 2])
        rotate_extrude(angle = arc_deg)
            spot_profile_2d(r_inner, r_outer, h, c);
}

// Cross-section of a spot: rectangle from r_inner..r_outer × 0..h with the
// TOP two corners chamfered by c. The bottom is left square so the spot
// joins flush to whatever sits below it (the bed for bottom-face spots,
// the disc for top-face spots — see the build for the orientation flip).
module spot_profile_2d(r_inner, r_outer, h, c) {
    if (c > 0 && c < h && 2 * c < r_outer - r_inner) {
        polygon([
            [r_inner,         0],
            [r_outer,         0],
            [r_outer,         h - c],
            [r_outer - c,     h],
            [r_inner + c,     h],
            [r_inner,         h - c],
        ]);
    } else {
        polygon([
            [r_inner, 0],
            [r_outer, 0],
            [r_outer, h],
            [r_inner, h],
        ]);
    }
}

// Center the DXF on the origin and optionally clip to the logo's bounding
// box. The clip is a rectangle matching logo_size × h so it cannot trim
// any of the logo itself — only geometry the resize() pulled outside the
// nominal box gets removed.
module logo_2d() {
    sf = logo_size / logo_dxf_w;
    h  = logo_dxf_h * sf;
    translate([logo_x_offset, logo_y_offset, 0])
        intersection() {
            translate([-logo_size / 2, -h / 2, 0])
                resize([logo_size, 0, 0], auto = [true, true, false])
                    import(logo_file);
            if (logo_clip) square([logo_size, h], center = true);
            else square([logo_size * 10, h * 10], center = true);
        }
}
