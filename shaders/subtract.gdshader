shader_type canvas_item;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 blend = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	// Subtract blend mode
	vec4 result;
	result.rgb = max(base.rgb - blend.rgb, vec3(0.0));
	result.a = base.a;
	
	COLOR = result;
} 