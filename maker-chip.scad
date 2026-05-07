include <qr.scad> // scadqr — https://github.com/xypwn/scadqr

// Maker chip — embossed casino-style poker chip.
//
// A flat central disc with embossed edge spots, logo, and text on each
// face. All embossed features rise to the same height — the spots form
// the chip's "rim" silhouette, the logo and labels share that plane.
//
// Total thickness = thickness_base + (sides × emboss_height), where
// `sides` is 1 or 2 depending on art_on_top / art_on_bottom.
//
// FDM print orientation: FACE UP. Bottom-face features sit on the bed
// (use a brim if adhesion is borderline); the disc bridges the small
// gaps between bottom spots; top-face features print last with the
// cleanest detail.

// =============================================================
// Parameters
// =============================================================

// ---- Disc ----
diameter        = 39;     // casino standard (mm)
thickness       = 3.5;    // total chip thickness (mm)
chip_chamfer    = 0;      // disc-edge chamfer (mm). Keep 0 so the spots
                          // sit flush against the disc's outer wall.

// ---- Embossed faces ----
emboss_height   = 1.0;    // height of every embossed feature (mm).
                          // 5 layers @ 0.2mm — strong, layer-aligned.
art_on_top      = true;
art_on_bottom   = true;

// ---- Edge spots ----
edge_spots          = 16;
edge_spot_arc_deg   = 14;
edge_spot_radial_mm = 2;  // depth from the rim inward (mm)
spot_chamfer        = 0.3; // chamfer at the spot's apex (outward face)

// ---- Logo ----
logo_file       = "logo.svg"; // "" disables. SVG with closed paths works
                              // best (DXF needs LWPOLYLINE, not LINE).
logo_size       = 30;     // target width in mm (height auto-scaled)
logo_x_offset   = 0;
logo_y_offset   = -1;
// Source artwork bounding box, used to recenter on the origin. Read it
// from the SVG's viewBox (or the DXF's $EXTMAX) and update on file swap.
logo_dxf_w      = 1580;
logo_dxf_h      = 970;

// ---- Text (front face) ----
text_top        = "Chimbo";
text_bottom     = "Sonic";
text_size       = 4;
text_y_offset   = 11;     // distance from chip center to baseline (mm)
text_spacing    = 1;      // letter tracking
text_font       = "Orbitron:style=Bold";

// ---- QR code (back face) ----
// QR is generated natively in OpenSCAD by scadqr (qr.scad). The QR is
// X-mirrored by default so it scans correctly after the chip is flipped
// over (Y-axis flip — natural "page flip"). For shorter encoded payloads,
// modules are larger and easier to scan on a printed chip.
qr_text         = "https://chimbosonic.com"; // "" disables
qr_error_correction = "M";  // "L"/"M"/"Q"/"H" — higher = more robust, larger QR
qr_size         = 22;       // QR width in mm (square)
qr_x_offset     = 0;
qr_y_offset     = 0;
qr_mirror_x     = true;     // see comment above

// ---- Colors ----
// Shown in the OpenSCAD preview; preserved when exporting to 3MF / AMF
// for multi-material slicers. STL exports drop colors.
disc_color      = "Gold";
spot_color      = "FireBrick";
logo_color      = "Green";
text_color      = "White";
qr_color        = "Black";

// ---- Rendering ----
$fa = 2;
$fs = 0.4;

// =============================================================
// Derived
// =============================================================

sides           = (art_on_top ? 1 : 0) + (art_on_bottom ? 1 : 0);
thickness_base  = thickness - sides * emboss_height;
z_disc_bottom   = art_on_bottom ? emboss_height : 0;

assert(thickness_base > 0,
       "thickness too small for chosen emboss_height; reduce emboss_height or increase thickness");

// =============================================================
// Build
// =============================================================

union() {
    // Bottom face: QR + spots, flipped so spot apexes (chamfered) face
    // the bed. The Z-mirror is geometric only; QR readability is handled
    // separately by qr_mirror_x.
    if (art_on_bottom)
        translate([0, 0, emboss_height])
            mirror([0, 0, 1])
                face_layer_back();

    color(disc_color)
        translate([0, 0, z_disc_bottom])
            chip_disc();

    // Top face: logo + text + spots.
    if (art_on_top)
        translate([0, 0, z_disc_bottom + thickness_base])
            face_layer_front();
}

// =============================================================
// Modules
// =============================================================

// Front face: spots + logo + text. Sits at z = 0 .. emboss_height.
module face_layer_front() {
    color(spot_color)
        spots_3d(emboss_height, spot_chamfer);

    if (logo_file != "")
        color(logo_color)
            linear_extrude(height = emboss_height)
                logo_2d();

    if (text_top != "" || text_bottom != "")
        color(text_color)
            linear_extrude(height = emboss_height)
                text_labels_2d();
}

// Back face: spots + QR code. Sits at z = 0 .. emboss_height.
module face_layer_back() {
    color(spot_color)
        spots_3d(emboss_height, spot_chamfer);

    if (qr_text != "")
        color(qr_color)
            linear_extrude(height = emboss_height)
                qr_2d();
}

// Flat disc body. Optional chamfer pulls the rim in at top + bottom; the
// embossed spots rely on a vertical wall, so chip_chamfer should usually
// stay at 0.
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

// Imported DXF logo, scaled to logo_size width and recentered on the
// origin. The DXF's native origin sits at one corner of its bounding
// box — the translate compensates so the logo's BB center is at (0, 0),
// then user offsets nudge it from there.
module logo_2d() {
    sf = logo_size / logo_dxf_w;
    h  = logo_dxf_h * sf;
    translate([logo_x_offset - logo_size / 2,
               logo_y_offset - h / 2, 0])
        resize([logo_size, 0, 0], auto = [true, true, false])
            import(logo_file);
}

// QR code generated natively via scadqr. The X-mirror compensates for
// the camera-flip the user does to scan the back of the chip — set
// qr_mirror_x to false if your natural flip axis is different.
module qr_2d() {
    translate([qr_x_offset, qr_y_offset, 0])
        scale([qr_mirror_x ? -1 : 1, 1, 1])
            qr(qr_text,
               error_correction = qr_error_correction,
               width            = qr_size,
               height           = qr_size,
               thickness        = 0,
               center           = true);
}

// Top + bottom labels, centered horizontally on the chip and offset
// vertically by ±text_y_offset.
module text_labels_2d() {
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

// All embossed spots, evenly spaced around the chip axis.
module spots_3d(h, c) {
    if (edge_spots > 0)
        for (i = [0 : edge_spots - 1])
            rotate([0, 0, i * 360 / edge_spots])
                spot_3d(diameter / 2 - edge_spot_radial_mm,
                        diameter / 2,
                        edge_spot_arc_deg, h, c);
}

// One spot: rotate-extrude a chamfered radial profile by arc_deg
// degrees, centered on the +X axis. rotate_extrude(angle=...) follows
// the chip's true outer arc.
module spot_3d(r_inner, r_outer, arc_deg, h, c) {
    rotate([0, 0, -arc_deg / 2])
        rotate_extrude(angle = arc_deg)
            spot_profile_2d(r_inner, r_outer, h, c);
}

// Cross-section of a spot in (radial, vertical) coordinates: rectangle
// with the TOP two corners chamfered. The bottom is square so the spot
// joins flush to the disc — see the build for the bottom-face flip.
module spot_profile_2d(r_inner, r_outer, h, c) {
    chamfered = (c > 0 && c < h && 2 * c < r_outer - r_inner);
    if (chamfered)
        polygon([
            [r_inner,         0],
            [r_outer,         0],
            [r_outer,         h - c],
            [r_outer - c,     h],
            [r_inner + c,     h],
            [r_inner,         h - c],
        ]);
    else
        polygon([
            [r_inner, 0],
            [r_outer, 0],
            [r_outer, h],
            [r_inner, h],
        ]);
}
