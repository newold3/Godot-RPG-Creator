shader_type canvas_item;

// Adjustable parameters to control the curve
uniform float curvature_intensity : hint_range(-1.0, 1.0) = 0.2; // Curvature intensity
uniform float curvature_offset : hint_range(-1.0, 1.0) = 0.0; // Vertical offset of the curve
uniform bool vertical_arc = false; // If true, curves vertically instead of horizontally

void fragment() {
    // Normalized coordinates (0-1)
    vec2 uv = UV;

    if (vertical_arc) {
        // Vertical deformation (horizontal arc)
        float relative_x = uv.x - 0.5; // Centered on X
        float displacement = curvature_intensity * relative_x * relative_x;

        // Apply deformation on Y
        uv.y = uv.y - displacement + curvature_offset;
    } else {
        // Horizontal deformation (vertical arc)
        float relative_y = uv.y - 0.5; // Centered on Y
        float displacement = curvature_intensity * relative_y * relative_y;

        // Apply deformation on X
        uv.x = uv.x - displacement + curvature_offset;
    }

    // Sample the original color with the new UV coordinates
    COLOR = texture(TEXTURE, uv);

    // Optionally, we can handle areas outside the limits
    // If uv is outside the [0,1] range, make that pixel transparent
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR.a = 0.0; // Transparent
    }
}