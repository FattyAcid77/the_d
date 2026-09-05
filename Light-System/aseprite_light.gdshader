shader_type canvas_item;

// Same blend maths Aseprite uses, so the game and the .aseprite file agree.

uniform sampler2D light_tex : filter_nearest, repeat_disable;
uniform sampler2D filter_tex : filter_nearest, repeat_disable;

// Top-left corner and pixel size of the room art, in world space.
uniform vec2 room_origin = vec2(0.0, 0.0);
uniform vec2 room_size = vec2(488.0, 373.0);

uniform int light_mode : hint_enum("Normal", "Multiply", "Screen", "Overlay", "Soft Light", "Hard Light", "Addition", "Color") = 3;
uniform int filter_mode : hint_enum("Normal", "Multiply", "Screen", "Overlay", "Soft Light", "Hard Light", "Addition", "Color") = 1;
uniform float light_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float filter_opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool filter_over_light = true;

// Runtime dimmer. Leave the opacities matching Aseprite and animate these.
uniform float light_energy : hint_range(0.0, 2.0) = 1.0;
uniform vec3 light_tint : source_color = vec3(1.0, 1.0, 1.0);

varying vec2 world_pos;

vec3 b_multiply(vec3 b, vec3 s) { return b * s; }
vec3 b_screen(vec3 b, vec3 s) { return b + s - b * s; }
vec3 b_add(vec3 b, vec3 s) { return min(b + s, vec3(1.0)); }

vec3 b_hardlight(vec3 b, vec3 s) {
	return mix(2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s), step(vec3(0.5), s));
}

// Aseprite defines overlay as hard light with the two swapped.
vec3 b_overlay(vec3 b, vec3 s) { return b_hardlight(s, b); }

vec3 b_softlight(vec3 b, vec3 s) {
	vec3 d = mix(sqrt(b), ((16.0 * b - 12.0) * b + 4.0) * b, step(b, vec3(0.25)));
	return mix(b - (1.0 - 2.0 * s) * b * (1.0 - b),
	           b + (2.0 * s - 1.0) * (d - b),
	           step(vec3(0.5), s));
}

float b_lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

vec3 b_clip(vec3 c) {
	float l = b_lum(c);
	float n = min(c.r, min(c.g, c.b));
	float x = max(c.r, max(c.g, c.b));
	if (n < 0.0) { c = l + (c - l) * (l / max(l - n, 1e-5)); }
	if (x > 1.0) { c = l + (c - l) * ((1.0 - l) / max(x - l, 1e-5)); }
	return c;
}

// Hue and saturation from the layer, brightness from what is underneath.
vec3 b_color(vec3 b, vec3 s) { return b_clip(s + (b_lum(b) - b_lum(s))); }

vec3 blend_pick(vec3 b, vec3 s, int mode) {
	if (mode == 1) { return b_multiply(b, s); }
	if (mode == 2) { return b_screen(b, s); }
	if (mode == 3) { return b_overlay(b, s); }
	if (mode == 4) { return b_softlight(b, s); }
	if (mode == 5) { return b_hardlight(b, s); }
	if (mode == 6) { return b_add(b, s); }
	if (mode == 7) { return b_color(b, s); }
	return s;
}

// Blend the channels, keep the layer's own alpha, then composite. Aseprite's order.
vec3 layer_over(vec3 base, vec4 lay, int mode, float op) {
	return mix(base, blend_pick(base, lay.rgb, mode), lay.a * op);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 col = tex.rgb;

	vec2 ruv = (world_pos - room_origin) / room_size;
	if (ruv.x >= 0.0 && ruv.x <= 1.0 && ruv.y >= 0.0 && ruv.y <= 1.0) {
		vec4 l = texture(light_tex, ruv);
		l = vec4(l.rgb * light_tint, clamp(l.a * light_energy, 0.0, 1.0));
		vec4 f = texture(filter_tex, ruv);

		if (filter_over_light) {
			col = layer_over(col, l, light_mode, light_opacity);
			col = layer_over(col, f, filter_mode, filter_opacity);
		} else {
			col = layer_over(col, f, filter_mode, filter_opacity);
			col = layer_over(col, l, light_mode, light_opacity);
		}
	}

	COLOR = vec4(col, tex.a * COLOR.a);
}
