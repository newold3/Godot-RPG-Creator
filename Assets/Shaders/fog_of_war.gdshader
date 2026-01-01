shader_type canvas_item;

uniform vec4 fog_points[800]; // Maximum number of points
uniform int active_fog_points; // Current number of active points
uniform sampler2D hole_texture; // Hole texture
uniform vec2 scale; // Inverse scale to compensate for transform

void fragment() {
    // Fragment coordinates in shader space
    vec2 frag_pos = FRAGCOORD.xy * scale;

    // Initial fragment color (black fog by default)
    vec4 final_color = vec4(0.0, 0.0, 0.0, 1.0);

    // Get hole texture size
    vec2 hole_texture_size = vec2(textureSize(hole_texture, 0));

    // Iterate through active points
    for (int i = 0; i < active_fog_points; i++) {
        vec4 point = fog_points[i];
        
        // Extract coordinates and animation
        float time = point.x;
        float mode = point.y; // 0: disappear, 1: appear
        vec2 position = point.zw;

        // Evaluate hole opacity based on time
        float alpha = clamp(mode == 1.0 ? time : 1.0 - time, 0.0, 1.0);

        // Calculate hole dimensions in shader space
        vec2 adjusted_hole_size = hole_texture_size * scale * alpha;

        // UV coordinates relative to hole texture
        vec2 uv = (frag_pos - position) / adjusted_hole_size + 0.5;

        // Check if fragment is inside hole texture
        if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
            vec4 hole_tex = texture(hole_texture, uv);

            // Mix hole texture with base color
            if (hole_tex.a > 0.0) {
                final_color = mix(final_color, vec4(0.0, 0.0, 0.0, 0.0), hole_tex.a * alpha);
            }
        }
    }

    COLOR = final_color;
}
