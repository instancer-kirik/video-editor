shader_type canvas_item;

uniform float feather : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	
	// Apply feathering to alpha
	float alpha = base.a;
	if (feather > 0.0) {
		float edge_dist = min(UV.x, min(UV.y, min(1.0 - UV.x, 1.0 - UV.y)));
		alpha *= smoothstep(0.0, feather, edge_dist);
	}
	
	COLOR = vec4(base.rgb, alpha);
} 