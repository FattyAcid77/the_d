shader_type canvas_item;

// Crisp pixels, smooth light.
//
// A sprite has ONE filter setting, and the engine reads its normal map through
// the same one. With Nearest (which is what keeps pixel art sharp) the light
// can only change once per art pixel, so shading comes out in blocks.
//
// This reads the normal map through its own sampler, set to smooth, and leaves
// the colour alone. The normal sheet must be the same size as the colour sheet,
// because UV is shared between them.

uniform bool use_normal = true;
// his side art is mirrored for facing left, and a mirrored surface faces the
// other way too, so the sideways part of the normal has to flip with it
uniform bool flip_x = false;
uniform sampler2D normal_tex : filter_linear, hint_normal;

// How deep the shading goes. 1.0 is the map as drawn; higher digs the dark
// side in harder. This is the knob for "the shadow on him is too weak".
uniform float depth : hint_range(0.0, 6.0) = 2.5;

// Tick this if his lit side is upside down.
uniform bool flip_y = false;

void fragment() {
	if (use_normal) {
		vec3 n = texture(normal_tex, UV).rgb;
		if (flip_x) {
			n.r = 1.0 - n.r;
		}
		if (flip_y) {
			n.g = 1.0 - n.g;
		}
		NORMAL_MAP = n;
		NORMAL_MAP_DEPTH = depth;
	}
}
