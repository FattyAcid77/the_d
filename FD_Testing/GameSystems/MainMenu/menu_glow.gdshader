shader_type canvas_item;
// Hover glow for a MenuHotspot: brightens the art already under the outline,
// or fades in the artist's lit layer when the hotspot has one.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float strength = 0.0;
uniform float boost = 0.9;
uniform vec3 tint = vec3(1.0, 0.9, 0.72);
uniform bool use_art = false;

void fragment() {
	vec3 under = texture(screen, SCREEN_UV).rgb;
	vec3 lit = under * (vec3(1.0) + boost * strength * tint);
	if (use_art) {
		vec4 art = texture(TEXTURE, UV);
		lit = mix(under, art.rgb, art.a * strength);
	}
	COLOR = vec4(lit, 1.0);
}
