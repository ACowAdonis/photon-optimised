/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c3_taau_prep:
  Calculate neighborhood limits for TAAU

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 min_color;
layout (location = 1) out vec3 max_color;

/* RENDERTARGETS: 1,2 */

in vec2 uv;

uniform sampler2D colortex0;

#include "/include/utility/color.glsl"

vec3 min_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec3 max_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return max(a, max(b, max(c, max(d, f))));
}

// Invertible tonemapping operator (Reinhard) applied before blending the current and previous frames
// Improves the appearance of emissive objects
vec3 reinhard(vec3 rgb) {
	return rgb / (rgb + 1.0);
}

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);
	ivec2 max_texel = textureSize(colortex0, 0) - 1;

	// Fetch 3x3 neighborhood (clamped to texture bounds to prevent edge artifacts)
	// a b c
	// d e f
	// g h i
	vec3 a = texelFetch(colortex0, clamp(texel + ivec2(-1,  1), ivec2(0), max_texel), 0).rgb;
	vec3 b = texelFetch(colortex0, clamp(texel + ivec2( 0,  1), ivec2(0), max_texel), 0).rgb;
	vec3 c = texelFetch(colortex0, clamp(texel + ivec2( 1,  1), ivec2(0), max_texel), 0).rgb;
	vec3 d = texelFetch(colortex0, clamp(texel + ivec2(-1,  0), ivec2(0), max_texel), 0).rgb;
	vec3 e = texelFetch(colortex0, texel, 0).rgb;
	vec3 f = texelFetch(colortex0, clamp(texel + ivec2( 1,  0), ivec2(0), max_texel), 0).rgb;
	vec3 g = texelFetch(colortex0, clamp(texel + ivec2(-1, -1), ivec2(0), max_texel), 0).rgb;
	vec3 h = texelFetch(colortex0, clamp(texel + ivec2( 0, -1), ivec2(0), max_texel), 0).rgb;
	vec3 i = texelFetch(colortex0, clamp(texel + ivec2( 1, -1), ivec2(0), max_texel), 0).rgb;

	// Convert to YCoCg using combined function to reduce overhead
	a = reinhard_to_ycocg(a);
	b = reinhard_to_ycocg(b);
	c = reinhard_to_ycocg(c);
	d = reinhard_to_ycocg(d);
	e = reinhard_to_ycocg(e);
	f = reinhard_to_ycocg(f);
	g = reinhard_to_ycocg(g);
	h = reinhard_to_ycocg(h);
	i = reinhard_to_ycocg(i);

	// Soft minimum and maximum ("Hybrid Reconstruction Antialiasing")
	//        b         a b c
	// (min d e f + min d e f) / 2
	//        h         g h i
	min_color  = min_of(b, d, e, f, h);
	min_color += min_of(min_color, a, c, g, i);
	min_color *= 0.5;

	max_color  = max_of(b, d, e, f, h);
	max_color += max_of(max_color, a, c, g, i);
	max_color *= 0.5;

	min_color = min_color * 0.5 + 0.5;
	max_color = max_color * 0.5 + 0.5;
}

#endif
//----------------------------------------------------------------------------//

