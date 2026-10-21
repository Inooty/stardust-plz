shader_type canvas_item;

const float pixel_size = 3.0;   // grid size for light/shadow snapping
const float light_steps = 128.0;  // brightness bands; lower = harsher, 0 disables (see below)

vec4 texturePointSmooth(sampler2D smp, vec2 uv, vec2 px)
{
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);
	vec2 lxy = sqrt(ddx * ddx + ddy * ddy);

	vec2 uv_pixels = uv / px;

	vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5);
	vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;

	uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5)) * px / lxy + vec2(0.5), 0.0, 1.0);

	uv = uv_pixels_floor * px;

	return textureGrad(smp, uv + uv_dxy_pixels * px, ddx, ddy);
}

void fragment()
{
	LIGHT_VERTEX.xy = floor(LIGHT_VERTEX.xy / pixel_size) * pixel_size;
	SHADOW_VERTEX = floor(SHADOW_VERTEX / pixel_size) * pixel_size;

	COLOR = texturePointSmooth(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
}

void light()
{
	// Quantize the light's intensity into bands
	vec3 lit = floor(LIGHT_COLOR.rgb * LIGHT_ENERGY * light_steps + 0.5) / light_steps;
	LIGHT = vec4(lit * COLOR.rgb, LIGHT_COLOR.a);
}