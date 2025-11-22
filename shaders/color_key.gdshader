shader_type canvas_item;

uniform vec3 key_color = vec3(0.0, 1.0, 0.0);
uniform float tolerance = 0.1;
uniform float feather = 0.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Calculate color difference
    float diff = length(color.rgb - key_color);
    
    // Calculate alpha based on difference and tolerance
    float alpha = smoothstep(tolerance, tolerance + feather, diff);
    
    // Apply alpha
    color.a *= alpha;
    
    COLOR = color;
} 