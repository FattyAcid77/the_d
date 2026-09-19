shader_type canvas_item;

// This exposes a slot in the inspector to drag and drop your overlay image
uniform sampler2D overlay_texture : hint_default_black;

void fragment() {
    // Get the base texture color (the original texture on your node)
    vec4 base = texture(TEXTURE, UV);

    // Get the overlay texture color
    vec4 blend = texture(overlay_texture, UV);

    vec3 result;

    // Apply the Photoshop Overlay math channel by channel
    // Red Channel
    result.r = base.r < 0.5 ? (2.0 * base.r * blend.r) : (1.0 - 2.0 * (1.0 - base.r) * (1.0 - blend.r));
    // Green Channel
    result.g = base.g < 0.5 ? (2.0 * base.g * blend.g) : (1.0 - 2.0 * (1.0 - base.g) * (1.0 - blend.g));
    // Blue Channel
    result.b = base.b < 0.5 ? (2.0 * base.b * blend.b) : (1.0 - 2.0 * (1.0 - base.b) * (1.0 - blend.b));

    // Output the final mixed color, keeping the original alpha transparency
    COLOR = vec4(result, base.a * blend.a);
}