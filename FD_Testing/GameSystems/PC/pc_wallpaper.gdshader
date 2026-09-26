shader_type canvas_item;
// The wallpaper on the PC screen. pc_screen.gd drives the uniforms: the drift
// (zoom and centre), the flicker (brightness) and the art-pixel grid.

uniform vec2 cells = vec2(400.0, 202.0);
uniform bool pixelate = true;
uniform float zoom = 1.0;
uniform vec2 center = vec2(0.5);
uniform float brightness = 1.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	// one sample per art pixel, so a moving picture still reads as a low-res screen
	if (pixelate) {
		uv = (floor(uv * cells) + 0.5) / cells;
	}
	uv = center + (uv - 0.5) / zoom;
	vec4 c = texture(TEXTURE, uv) * tint;
	COLOR = vec4(c.rgb * brightness, c.a);
}
