shader_type canvas_item;

// Main parameters
uniform float progress : hint_range(0, 1) = 0.0;
uniform int sides : hint_range(3, 50) = 6;
uniform vec4 color : source_color = vec4(1.0);
uniform bool rotate = true;
uniform float rotation_speed = 1.0;
uniform float start_angle : hint_range(-360, 360) = 0.0;
uniform bool invert_animation = false;
uniform bool maintain_aspect_ratio = true;

void fragment() {
    if (progress <= 0.0) {
        discard;
    }
    
    // 1. ASPECT RATIO ADJUSTMENT
    vec2 aspect_ratio = vec2(1.0);
    if (maintain_aspect_ratio) {
        aspect_ratio = vec2(
            min(1.0, TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x),
            min(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y)
        );
    }
    
    // 2. UV COORDINATE PREPARATION
    vec2 uv = (UV - vec2(0.5)) * 2.0;
    uv *= aspect_ratio;
    
    // 3. COMBINED ROTATION
    float base_rot = radians(start_angle);
    float dynamic_rot = rotate ? progress * TAU * rotation_speed : 0.0;
    mat2 rot_matrix = mat2(
        vec2(cos(base_rot + dynamic_rot), sin(base_rot + dynamic_rot)),
        vec2(-sin(base_rot + dynamic_rot), cos(base_rot + dynamic_rot))
    );
    uv = rot_matrix * uv;
    
    // 4. ANIMATION MODE HANDLING
    float progress_effect = invert_animation ? 1.0 : progress;
    uv /= mix(0.001, 1.0, progress_effect);
    
    // 5. GEOMETRIC POLYGON CALCULATION
    float n = float(sides);
    float sector_angle = TAU / n;
    float half_angle = sector_angle * 0.5;
    
    vec2 corner = aspect_ratio;
    float corner_dist = length(corner);
    float corner_theta = atan(corner.y, corner.x);
    
    float theta_mod = mod(corner_theta + half_angle, sector_angle);
    float max_radius = corner_dist * cos(half_angle - abs(half_angle - theta_mod));
    
    // 6. EFFECTIVE RADIUS CALCULATION
    float current_angle = atan(uv.y, uv.x);
    current_angle = mod(mod(current_angle, TAU) + half_angle, sector_angle);
    float poly_radius = max_radius / cos(half_angle - abs(half_angle - current_angle));
    
    // 7. FILL LOGIC FOR BOTH MODES
    float dist = length(uv);
    float threshold = invert_animation ? poly_radius * (1.0 - progress) : poly_radius;
    
    if ((invert_animation && dist >= threshold) || (!invert_animation && dist <= threshold)) {
        COLOR = color;
    } else {
        discard;
    }
}