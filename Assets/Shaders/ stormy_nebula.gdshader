shader_type canvas_item;

// Author: FencerDevLog: https://www.youtube.com/watch?v=xP9dq2nVZac

/* Resolution of the canvas item */
uniform vec2 resolution = vec2(1920.0, 1080.0);

/* Animation speed factor */
uniform float speed : hint_range(0.0, 4.0, 0.01) = 1.0;

/* Zoom factor for scaling fractal structures */
uniform float zoom : hint_range(0.1, 20.0, 0.01) = 5.0;

/* Number of iterations for Fractal Brownian Motion */
uniform int octaves = 5;

/* Color shade A */
uniform vec3 colorA : source_color = vec3(0.5);

/* Color shade B */
uniform vec3 colorB : source_color = vec3(0.5, 0.2, 0.1);

/* Color shade C */
uniform vec3 colorC : source_color = vec3(1.0);

/* Color shade D */
uniform vec3 colorD : source_color = vec3(0.6, 0.4, 0.1);

/* Visual contrast adjustment */
uniform float contrast : hint_range(0.01, 10.0, 0.01) = 2.0;

/* Transparency threshold for alpha channel filtering */
uniform float alpha_threshold : hint_range(0.0, 1.0, 0.01) = 0.0;

const float F2 = 0.366025403;
const float G2 = 0.211324865;

vec2 srandom(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}


float noise(vec2 p) {
	vec2 i = floor(p + (p.x + p.y) * F2);
	vec2 a = p - i + (i.x + i.y) * G2;
	vec2 o = (a.x > a.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec2 b = a - o + G2;
	vec2 c = a - 1.0 + 2.0 * G2;
	vec3 w = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
	vec3 d = vec3(dot(a, srandom(i)), dot(b, srandom(i + o)), dot(c, srandom(i + 1.0)));
	return 70.0 * dot(w * w * w * w, d);
}


float FBM(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}


void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= resolution.x / resolution.y;
	uv *= zoom;
	uv += FBM(uv);
	
	float time = TIME * speed;
	
	vec2 a = uv + vec2(sin(time * 1.5), sin(time * 0.9));
	vec2 b = uv + vec2(cos(time * 0.7), sin(time * 1.9));
	vec2 c = uv + vec2(sin(time * 2.1), cos(time * 1.1));
	vec2 d = uv + vec2(cos(time * 1.3), cos(time * 1.5));
	
	vec3 color = colorA / length(a);
	color += colorB / length(b);
	color += colorC / length(c);
	color += colorD / length(d);
	
	color /= contrast;
	color *= 0.8 / (3.5 + color);
	
	float avg = (color.r + color.g + color.b) / 3.0;
	
	COLOR = vec4(color, (avg <= alpha_threshold) ? 0.0 : 1.0);
}