/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_skytextured:
  Handle vanilla sun and moon and custom skies

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 frag_color;

/* RENDERTARGETS: 0 */

in vec2 uv;
in vec3 view_pos;

flat in vec3 tint;
flat in vec3 sun_color;
flat in vec3 moon_color;

// ------------
//   Uniforms
// ------------

uniform sampler2D gtexture;
uniform sampler2D noisetex;
uniform sampler2D moonTex; // Custom moon texture (via customTexture to avoid colortex15 conflict with SSR)

uniform int moonPhase;
uniform int renderStage;

uniform vec3 view_sun_dir;

#include "/include/sky/atmosphere.glsl"
#include "/include/utility/color.glsl"

const float vanilla_sun_luminance = 10.0; 
const float moon_luminance = 10.0; 

void main() {
	vec2 new_uv = uv;
	vec2 offset;

	if (renderStage == MC_RENDER_STAGE_CUSTOM_SKY) {
#ifdef CUSTOM_SKY
		frag_color  = texture(gtexture, new_uv).rgb;
		frag_color  = srgb_eotf_inv(frag_color) * rec709_to_working_color;
		frag_color *= CUSTOM_SKY_BRIGHTNESS;
#else
		frag_color  = vec3(0.0);
#endif
	} else if (dot(view_pos, view_sun_dir) > 0.0) {
		// Sun

		// NB: not using renderStage to distinguish sun and moon because it's broken in Iris for 
		// Minecraft 1.21.4

		// Cut out the sun itself (discard the halo around it)
		if (max_of(abs(offset)) > 0.25) discard;
		offset = uv * 2.0 - 1.0;

#ifdef VANILLA_SUN
		frag_color  = texture(gtexture, new_uv).rgb;
		frag_color  = srgb_eotf_inv(frag_color) * rec709_to_working_color;
		frag_color *= dot(frag_color, luminance_weights) * (sunlight_color * vanilla_sun_luminance) * sun_color;
#else 
		frag_color  = vec3(0.0);
#endif
	} else {
	 	// Moon
#ifdef VANILLA_MOON
		// Cut out the moon itself (discard the halo around it) and flip moon texture along the
		// diagonal
		offset = fract(vec2(4.0, 2.0) * uv);
		new_uv = new_uv + vec2(0.25, 0.5) * ((1.0 - offset.yx) - offset);
		offset = offset * 2.0 - 1.0;
		if (max_of(abs(offset)) > 0.25) discard;

		frag_color = texture(gtexture, new_uv).rgb * vec3(MOON_R, MOON_G, MOON_B);
#else
		// Custom textured moon with phase shadowing
		const vec3  glow_color = vec3(MOON_R <= 0.05 ? 0.0 : MOON_R - 0.05, MOON_G, MOON_B);

		// Calculate moon disk position
		offset = ((fract(vec2(4.0, 2.0) * uv) - 0.5) * rcp(0.15)) / MOON_ANGULAR_RADIUS;

		float dist = length(offset);

		// Discard pixels outside moon disk
		if (dist > 1.0) {
			discard;
		}

		// Sample custom moon texture - map offset to UV coordinates
		// offset is in range [-1, 1], map to [0, 1] for texture sampling
		vec2 moon_uv = offset * 0.5 + 0.5;
		vec3 moon_tex = texture(moonTex, moon_uv).rgb;
		moon_tex = srgb_eotf_inv(moon_tex); // Convert to linear

		// Calculate phase shadow
		float moon_shadow = 1.0;
		float a = sqrt(max(0.0, 1.0 - offset.x * offset.x));

		switch (moonPhase) {
		case 0: // Full moon
			break;

		case 1: // Waning gibbous
			moon_shadow = 1.0 - linear_step(a * 0.6 - 0.12, a * 0.6 + 0.12, -offset.y); break;

		case 2: // Last quarter
			moon_shadow = 1.0 - linear_step(a * 0.1 - 0.15, a * 0.1 + 0.15, -offset.y); break;

		case 3: // Waning crescent
			moon_shadow = linear_step(a * 0.5 - 0.12, a * 0.5 + 0.12, offset.y); break;

		case 4: // New moon
			moon_shadow = 0.0; break;

		case 5: // Waxing crescent
			moon_shadow = linear_step(a * 0.6 - 0.12, a * 0.5 + 0.12, -offset.y); break;

		case 6: // First quarter
			moon_shadow = linear_step(a * 0.1 - 0.15, a * 0.1 + 0.15, -offset.y); break;

		case 7: // Waxing gibbous
			moon_shadow = 1.0 - linear_step(a * 0.6 - 0.12, a * 0.6 + 0.12, offset.y); break;
		}

		// Apply moon color tint and phase shadow to texture
		vec3 lit_moon = moon_tex * vec3(MOON_R, MOON_G, MOON_B) * moon_shadow;

		// Earthshine: faint illumination of the dark side from Earth-reflected light
		// Visible on the shadowed portion, with a subtle blue tint from Earth's atmosphere
		float earthshine_strength = 0.07 * (1.0 - moon_shadow); // Only on dark side
		vec3 earthshine_color = vec3(0.7, 0.8, 1.0); // Slight blue tint
		vec3 earthshine = moon_tex * earthshine_color * earthshine_strength;

		// Add subtle glow at the edges
		float edge_glow = smoothstep(0.7, 1.0, dist) * 0.15;
		vec3 glow = glow_color * edge_glow;

		frag_color = max(lit_moon + earthshine, glow);
#endif

		frag_color  = srgb_eotf_inv(frag_color) * rec709_to_working_color;
		frag_color *= sunlight_color * moon_luminance;
	}	
}

