shader_type canvas_item;

uniform float feather = 0.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Calculate luminance
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Apply feathering
    if (feather > 0.0) {
        vec2 pixel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
        float sum = 0.0;
        
        for (float x = -feather; x <= feather; x += 1.0) {
            for (float y = -feather; y <= feather; y += 1.0) {
                vec2 offset = vec2(x, y) * pixel_size;
                vec4 sample = texture(TEXTURE, UV + offset);
                sum += dot(sample.rgb, vec3(0.299, 0.587, 0.114));
            }
        }
        luminance = sum / ((2.0 * feather + 1.0) * (2.0 * feather + 1.0));
    }
    
    // Apply luminance as alpha
    color.a *= luminance;
    
    COLOR = color;
} 