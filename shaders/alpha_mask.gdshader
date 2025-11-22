shader_type canvas_item;

uniform float feather : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D mask_texture;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 mask = texture(mask_texture, UV);
	
	// Apply mask with feathering
	float alpha = base.a * mask.r;
	if (feather > 0.0) {
		alpha = smoothstep(0.0, feather, alpha);
	}
	
	COLOR = vec4(base.rgb, alpha);
} 