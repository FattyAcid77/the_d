shader_type canvas_item;
// Blurs whatever is behind this rect (the game world) so the clipboard reads
// clearly on top of it. Cheap mipmap blur — no big sample loop.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.2;
uniform vec4 tint : source_color = vec4(0.05, 0.05, 0.07, 0.45);

void fragment() {
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, blur_amount).rgb;
	COLOR.rgb = mix(blurred, tint.rgb, tint.a);
	COLOR.a = 1.0;
}
