shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 base = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
    vec3 blend = tex.rgb * COLOR.rgb;

    vec3 over = mix(2.0 * base * blend,
                    1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
                    step(0.5, base));

    COLOR = vec4(mix(base, over, tex.a * COLOR.a * strength), 1.0);
}