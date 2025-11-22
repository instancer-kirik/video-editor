shader_type canvas_item;

uniform sampler2D mask_texture;
uniform float feather = 0.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    vec4 mask = texture(mask_texture, UV);
    
    // Apply feathering
    float mask_value = mask.r;
    if (feather > 0.0) {
        float step = 1.0 / feather;
        vec2 pixel_size = 1.0 / vec2(textureSize(mask_texture, 0));
        
        float sum = 0.0;
        for (float x = -feather; x <= feather; x += 1.0) {
            for (float y = -feather; y <= feather; y += 1.0) {
                vec2 offset = vec2(x, y) * pixel_size;
                sum += texture(mask_texture, UV + offset).r;
            }
        }
        mask_value = sum / ((2.0 * feather + 1.0) * (2.0 * feather + 1.0));
    }
    
    // Apply mask
    color.a *= mask_value;
    
    COLOR = color;
} 