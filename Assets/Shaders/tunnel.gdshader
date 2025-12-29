shader_type canvas_item;

// Original Shader: @FencerDevLog https://www.youtube.com/@FencerDevLog
// Shader upgraded by @_newold https://www.youtube.com/@_newold

// Basic configuration parameters
uniform vec2 resolution = vec2(512);
uniform sampler2D tex: repeat_enable, hint_default_black;
uniform float speed: hint_range(-2.0, 2.0, 0.01) = 0.1;
uniform float stretch: hint_range(0.01, 1.0, 0.01) = 0.1;
uniform float zoom: hint_range(0.6, 10.0, 0.1) = 1.0;
uniform float final_alpha: hint_range(0.0, 1.0, 0.01) = 1.0;

// Shape selection parameters
uniform int shape_base_model: hint_enum("Square", "Circular", "Diamond", "Star", "Polygon", "Cross") = 0;
uniform int shape_target_model: hint_enum("Square", "Circular", "Diamond", "Star", "Polygon", "Cross") = 1;
uniform float shape_mix_strength: hint_range(0.0, 1.0, 0.01) = 0.3;

// Animation and shape customization parameters
uniform float rotation_speed: hint_range(-15.0, 15.0, 0.001) = 0.5;
uniform int star_points: hint_range(3, 12, 1) = 5;
uniform int polygon_sides: hint_range(3, 24, 1) = 6;

// Pulse animation parameters
uniform bool use_pulse_animation = false;
uniform float pulse_frequency: hint_range(0.1, 5.0, 0.01) = 2.0;
uniform float pulse_amplitude: hint_range(0.1, 5.0, 0.01) = 0.2;

// Final output adjustment
uniform float brightness: hint_range(0.0, 5.0, 0.1) = 1.0;

// Square shape distance function
float get_square(vec2 uv) {
    return max(abs(uv.x), abs(uv.y));
}

// Circular shape distance function (Euclidean distance)
float get_circular(vec2 uv) {
    return length(uv);
}

// Diamond shape distance function (Manhattan distance)
float get_diamond(vec2 uv) {
    return (abs(uv.x) + abs(uv.y)) * 0.7;
}

// Star shape with configurable number of points
float get_star(vec2 uv) {
    float r = length(uv);
    float theta = atan(uv.y, uv.x);
    float n = float(star_points); // Number of star points defined in the uniform
    return r * (0.8 + 0.2 * sin(n * theta));
}

// Regular polygon with configurable number of sides
float get_polygon(vec2 uv) {
    float r = length(uv);
    float theta = atan(uv.y, uv.x);
    float n = float(polygon_sides); // Number of sides defined in the uniform

    // Angle from current point to positive X axis
    float angle = theta;

    // Calculate angle to the nearest vertex of the polygon
    float segment = PI * 2.0 / n;
    float a = mod(angle, segment);
    if (a > segment / 2.0) a = segment - a;

    // Calculate distance from center to edge in that direction
    float dist = r / cos(a);

    return dist * 0.8; // Scale factor to make it proportional to other shapes
}

// Cross shape formed by two perpendicular rectangles
float get_cross(vec2 uv) {
    vec2 absUV = abs(uv);
    float horizontal = max(absUV.x * 2.5, absUV.y * 0.8);
    float vertical = max(absUV.x * 0.8, absUV.y * 2.5);
    return min(horizontal, vertical);
}

// Get the distance function for the specified shape model
float get_shape_model(vec2 uv, int model) {
    if (model == 0) return get_square(uv);
    else if (model == 1) return get_circular(uv);
    else if (model == 2) return get_diamond(uv);
    else if (model == 3) return get_star(uv);
    else if (model == 4) return get_polygon(uv);
    else if (model == 5) return get_cross(uv);
    return get_square(uv); // Default fallback
}

// Calculate the final shape by mixing base and target shapes
float get_shape(vec2 uv) {
    float base = get_shape_model(uv, shape_base_model);
    float target = get_shape_model(uv, shape_target_model);

    if (shape_base_model == shape_target_model) {
        return base * shape_mix_strength;
    } else {
        return mix(base, target, shape_mix_strength);
    }
}

// Calculate time value based on animation mode (linear or pulse)
float get_animation_time(float base_time) {
    if (use_pulse_animation) {
        // Pulse animation: Oscillates back and forth using sine function
        return pulse_amplitude * sin(base_time * pulse_frequency);
    } else {
        // Linear animation: Moves continuously in one direction
        return base_time * speed;
    }
}

void fragment() {
    // Normalize UV coordinates with aspect ratio correction
    vec2 uv = UV - 0.5;
    uv.x *= resolution.x / resolution.y;

    // Apply zoom effect by scaling UV coordinates (zoom > 1 makes tunnel appear closer/larger)
    uv = uv / zoom;

    // Apply animated rotation
    float rot_angle = TIME * rotation_speed;
    mat2 rotation_matrix = mat2(
        vec2(cos(rot_angle), -sin(rot_angle)),
        vec2(sin(rot_angle), cos(rot_angle))
    );
    uv = rotation_matrix * uv;

    // Calculate time-based animation using either linear or pulse mode
    float time = get_animation_time(TIME);
    float theta = atan(uv.y, uv.x);

    // Get the shape distance field
    float shape = get_shape(uv);

    // Calculate texture coordinates based on shape and time
    vec2 p = vec2(stretch / shape + time, 2.0 * theta / PI);

    // Sample texture and apply shape modulation
    vec3 color = texture(tex, p).rgb;
    color *= shape;
	color *= brightness;

    // Output final color
    COLOR = vec4(color, final_alpha);
}