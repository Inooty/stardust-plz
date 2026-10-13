shader_type canvas_item;

// Automatic smoothing
// independent of geometry and perspective
vec4 texturePointSmooth(sampler2D smp, vec2 uv, vec2 pixel_size)
{
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);
	vec2 lxy = sqrt(ddx * ddx + ddy * ddy);
	
	vec2 uv_pixels = uv / pixel_size;
	
	vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5f);
	vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;
	
	uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5f)) * pixel_size / lxy + vec2(0.5f), 0.0f, 1.0f);
	
	uv = uv_pixels_floor * pixel_size;
	
	return textureGrad(smp, uv + uv_dxy_pixels * pixel_size, ddx, ddy);
}

void fragment()
{
	COLOR = texturePointSmooth(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
}

// Add this function to process Godot 2D lights
void light() {
	// LIGHT_VERTEX_COLOR accounts for any CanvasModulate or ambient dark colors
	// LIGHT_COLOR is the color/energy of your Directional or Point lights
	// LIGHT is the accumulated light color hitting this pixel
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_COLOR.a, LIGHT_COLOR.a);
}