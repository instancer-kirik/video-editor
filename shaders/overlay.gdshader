shader_type canvas_item;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec4 blend = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0);
    
    vec4 result;
    if (base.r < 0.5) {
        result.r = 2.0 * base.r * blend.r;
    } else {
        result.r = 1.0 - 2.0 * (1.0 - base.r) * (1.0 - blend.r);
    }
    if (base.g < 0.5) {
        result.g = 2.0 * base.g * blend.g;
    } else {
        result.g = 1.0 - 2.0 * (1.0 - base.g) * (1.0 - blend.g);
    }
    if (base.b < 0.5) {
        result.b = 2.0 * base.b * blend.b;
    } else {
        result.b = 1.0 - 2.0 * (1.0 - base.b) * (1.0 - blend.b);
    }
    result.a = base.a;
    
    COLOR = result;
} 