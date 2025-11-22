shader_type canvas_item;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec4 blend = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0);
    
    vec4 result;
    result.rgb = base.rgb * blend.rgb;
    result.a = base.a;
    
    COLOR = result;
} 