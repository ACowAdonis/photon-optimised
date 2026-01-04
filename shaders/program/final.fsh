/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/program/final.glsl:
  CAS, dithering, debug views

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

layout (location = 0) out vec3 fragment_color;

in vec2 uv;

// ------------
//   Uniforms
// ------------

uniform sampler2D colortex0; // Scene color

#if DEBUG_VIEW == DEBUG_VIEW_SAMPLER
uniform sampler2D DEBUG_SAMPLER;
#endif

uniform float viewHeight;
uniform float frameTimeCounter;

#ifdef COLORED_LIGHTS
uniform sampler2D shadowtex0;
#endif

// Cold Sweat player temperature (from modified Oculus)
#if defined HEATSTROKE_EFFECTS || defined HYPOTHERMIA_EFFECTS
uniform float playerBodyTemp;    // Cold Sweat player body temperature
#endif

// Mod uniforms from modified Oculus (Serene Seasons / Cold Sweat) - debug only
#if defined DEBUG_MOD_UNIFORMS || defined DEBUG_MOD_UNIFORMS_TINT
uniform int currentSeason;       // 0=spring, 1=summer, 2=autumn, 3=winter
uniform int currentSubSeason;    // 0-11 sub-season index
uniform float seasonProgress;    // 0.0-1.0 progress through current season
uniform float yearProgress;      // 0.0-1.0 progress through entire year (config-independent)
uniform int seasonDay;           // Day within current season
uniform int daysPerSeason;       // Days per season from mod config
#if !defined HEATSTROKE_EFFECTS && !defined HYPOTHERMIA_EFFECTS
uniform float playerBodyTemp;    // Cold Sweat player body temperature
#endif
uniform float worldAmbientTemp;  // Cold Sweat world temperature at player position
#endif

#include "/include/utility/bicubic.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/text_rendering.glsl"

#ifdef DISTANCE_VIEW
uniform sampler2D depthtex0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec2 view_res;
uniform vec2 taa_offset;

uniform float near;
uniform float far;

#include "/include/misc/distant_horizons.glsl"
#include "/include/utility/space_conversion.glsl"
#endif

const int debug_text_scale = 2;
ivec2 debug_text_position = ivec2(0, int(viewHeight) / debug_text_scale);

#if DEBUG_VIEW == DEBUG_VIEW_WEATHER
#include "/include/misc/debug_weather.glsl"
#endif

#if defined DEBUG_MOD_UNIFORMS || defined DEBUG_MOD_UNIFORMS_TINT
#include "/include/misc/mod_uniforms_debug.glsl"
#endif

#ifdef HEATSTROKE_EFFECTS
#include "/include/misc/heatstroke.glsl"
#endif

#ifdef HYPOTHERMIA_EFFECTS
uniform sampler2D frostOverlayTex; // Custom frost overlay texture
#include "/include/misc/hypothermia.glsl"
#endif

// Storm vignette effect (outdoor only)
#ifdef STORM_INTENSITY_SYSTEM
uniform float rainStrength;
uniform float eye_skylight;
uniform int isEyeInWater;

/*
 * Storm Vignette Effect
 *
 * Darkens screen edges during heavy storms for oppressive atmosphere.
 * Only applies outdoors (eye_skylight > 0) and not underwater.
 */
vec3 apply_storm_vignette(vec3 color, vec2 uv, float storm_intensity, float skylight, int in_water) {
	// Only apply outdoors and not underwater
	// Starts at 0.4 (heavy rain) - subtle complement to lighting changes
	if (storm_intensity < 0.4 || skylight < 0.1 || in_water != 0) {
		return color;
	}

	// Effect starts at storm intensity 0.4 (heavy rain), peaks at full storm
	float effect_intensity = smoothstep(0.4, 1.0, storm_intensity);

	// Reduce effect when partially indoors
	effect_intensity *= smoothstep(0.1, 0.5, skylight);

	// Distance from screen center - subtle effect mostly at far edges
	vec2 centered = uv - 0.5;
	float dist = length(centered);

	// Vignette only affects outer edges of screen
	float vignette_start = mix(0.75, 0.55, effect_intensity);
	float vignette_end = mix(1.2, 0.85, effect_intensity);

	float vignette = smoothstep(vignette_start, vignette_end, dist);

	// Dark gray with slight blue tint (rainy atmosphere)
	vec3 vignette_color = vec3(0.02, 0.02, 0.03);

	// Subtle effect: max ~10% edge darkening at peak intensity (halved from 0.2)
	float vignette_strength = vignette * effect_intensity * STORM_VIGNETTE * 0.1;

	return mix(color, vignette_color, vignette_strength);
}
#endif

vec3 min_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
	return min(a, min(b, min(c, min(d, f))));
}

vec3 max_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
	return max(a, max(b, max(c, max(d, f))));
}

// FidelityFX contrast-adaptive sharpening filter
// https://github.com/GPUOpen-Effects/FidelityFX-CAS
vec3 cas_filter(sampler2D sampler, ivec2 texel, const float sharpness) {
#ifndef CAS
	return display_eotf(texelFetch(sampler, texel, 0).rgb);
#endif

	// Fetch 3x3 neighborhood
	// a b c
	// d e f
	// g h i
	vec3 a = texelFetch(sampler, texel + ivec2(-1, -1), 0).rgb;
	vec3 b = texelFetch(sampler, texel + ivec2( 0, -1), 0).rgb;
	vec3 c = texelFetch(sampler, texel + ivec2( 1, -1), 0).rgb;
	vec3 d = texelFetch(sampler, texel + ivec2(-1,  0), 0).rgb;
	vec3 e = texelFetch(sampler, texel, 0).rgb;
	vec3 f = texelFetch(sampler, texel + ivec2( 1,  0), 0).rgb;
	vec3 g = texelFetch(sampler, texel + ivec2(-1,  1), 0).rgb;
	vec3 h = texelFetch(sampler, texel + ivec2( 0,  1), 0).rgb;
	vec3 i = texelFetch(sampler, texel + ivec2( 1,  1), 0).rgb;

    // Convert to sRGB before performing CAS
    a = display_eotf(a);
    b = display_eotf(b);
    c = display_eotf(c);
    d = display_eotf(d);
    e = display_eotf(e);
    f = display_eotf(f);
    g = display_eotf(g);
    h = display_eotf(h);
    i = display_eotf(i);

	// Soft min and max. These are 2x bigger (factored out the extra multiply)
	vec3 min_color  = min_of(d, e, f, b, h);
	     min_color += min_of(min_color, a, c, g, i);

	vec3 max_color  = max_of(d, e, f, b, h);
	     max_color += max_of(max_color, a, c, g, i);

	// Smooth minimum distance to the signal limit divided by smooth max
	vec3 w  = clamp01(min(min_color, 2.0 - max_color) / max_color);
	     w  = 1.0 - sqr(1.0 - w); // Shaping amount of sharpening
	     w *= -1.0 / mix(8.0, 5.0, sharpness);

	// Filter shape:
	// 0 w 0
	// w 1 w
	// 0 w 0
	vec3 weight_sum = 1.0 + 4.0 * w;
	return clamp01((b + d + f + h) * w + e) / weight_sum;
}

void draw_iris_required_error_message() {
	fragment_color = vec3(sqr(sin(uv.xy + vec2(0.4, 0.2) * frameTimeCounter)) * 0.5 + 0.3, 1.0);
	begin_text(ivec2(gl_FragCoord.xy) / 3, ivec2(0, viewHeight / 3));
	text.fg_col = vec4(0.0, 0.0, 0.0, 1.0);
	text.bg_col = vec4(0.0);
	print((_I, _r, _i, _s, _space, _i, _s, _space, _r, _e, _q, _u, _i, _r, _e, _d, _space, _f, _o, _r, _space, _f, _e, _a, _t, _u, _r, _e, _space, _quote, _C, _o, _l, _o, _r, _e, _d, _space, _L, _i, _g, _h, _t, _s, _quote));
	print_line(); print_line(); print_line();
	print((_H, _o, _w, _space, _t, _o, _space, _f, _i, _x, _colon));
	print_line();
	print((_space, _space, _minus, _space, _D, _i, _s, _a, _b, _l, _e, _space, _C, _o, _l, _o, _r, _e, _d, _space, _L, _i, _g, _h, _t, _s, _space, _i, _n, _space, _t, _h, _e, _space, _L, _i, _g, _h, _t, _i, _n, _g, _space, _m, _e, _n, _u));
	print_line();
	print((_space, _space, _minus, _space, _I, _n, _s, _t, _a, _l, _l, _space, _I, _r, _i, _s, _space, _1, _dot, _6, _space, _o, _r, _space, _a, _b, _o, _v, _e));
	print_line();
	end_text(fragment_color);
}

void main() {
#if defined COLORED_LIGHTS && !defined IS_IRIS
	draw_iris_required_error_message();
	return;
#endif

    ivec2 texel = ivec2(gl_FragCoord.xy);

	if (abs(MC_RENDER_QUALITY - 1.0) < 0.01) {
		fragment_color = cas_filter(colortex0, texel, CAS_INTENSITY * 2.0 - 1.0);
	} else {
		fragment_color = catmull_rom_filter_fast_rgb(colortex0, uv, 0.6);
	    fragment_color = display_eotf(fragment_color);
	}

	fragment_color = dither_8bit(fragment_color, bayer16(vec2(texel)));

#if   DEBUG_VIEW == DEBUG_VIEW_SAMPLER
	if (clamp(texel, ivec2(0), ivec2(textureSize(DEBUG_SAMPLER, 0))) == texel) {
		fragment_color = texelFetch(DEBUG_SAMPLER, texel, 0).rgb;
		fragment_color = display_eotf(fragment_color);
	}
#elif DEBUG_VIEW == DEBUG_VIEW_WEATHER 
	debug_weather(fragment_color);
#endif

#ifdef DISTANCE_VIEW 
	float depth = texelFetch(depthtex0, ivec2(uv * view_res * taau_render_scale), 0).x;

	vec3 position_screen = vec3(uv, depth);
	vec3 position_view = screen_to_view_space(gbufferProjectionInverse, position_screen, true);

	bool is_sky = depth == 1.0;

	#ifdef DISTANT_HORIZONS
    float depth_dh = texelFetch(dhDepthTex, texel, 0).x;
	bool is_dh_terrain = is_distant_horizons_terrain(depth, depth_dh);

	if (is_dh_terrain) {
		position_view = screen_to_view_space(dhProjectionInverse, vec3(uv, depth_dh), true);
	}

	is_sky = is_sky && depth_dh == 1.0;
	#endif

	#if DISTANCE_VIEW_METHOD == DISTANCE_VIEW_DISTANCE
	float dist = length(position_view);
	#elif DISTANCE_VIEW_METHOD == DISTANCE_VIEW_DEPTH 
	float dist = -position_view.z;
	#endif

	fragment_color = is_sky 
		? vec3(1.0)
		: vec3(clamp01(dist * rcp(DISTANCE_VIEW_MAX_DISTANCE)));
#endif

#if defined COLORED_LIGHTS && (defined WORLD_NETHER || !defined SHADOW)
	// Must sample shadowtex0 so that the shadow map is rendered
	if (uv.x < 0.0) {
		fragment_color = texture(shadowtex0, uv).rgb;
	}
#endif

	// Heatstroke visual effects (Cold Sweat player temperature)
#ifdef HEATSTROKE_EFFECTS
	fragment_color = apply_heatstroke_effects(fragment_color, colortex0, uv, playerBodyTemp, frameTimeCounter);
#endif

	// Hypothermia visual effects (Cold Sweat player temperature)
#ifdef HYPOTHERMIA_EFFECTS
	fragment_color = apply_hypothermia_effects(fragment_color, colortex0, frostOverlayTex, uv, playerBodyTemp, frameTimeCounter);
#endif

	// Storm vignette effect (outdoor only, disabled underwater/indoors)
#ifdef STORM_INTENSITY_SYSTEM
	float storm_intensity = rainStrength * STORM_INTENSITY_MULT;
	fragment_color = apply_storm_vignette(fragment_color, uv, storm_intensity, eye_skylight, isEyeInWater);
#endif

	// Mod uniforms debug overlay (Serene Seasons / Cold Sweat)
#ifdef DEBUG_MOD_UNIFORMS_TINT
	fragment_color = apply_season_tint_test(fragment_color, yearProgress, DEBUG_MOD_UNIFORMS_TINT_INTENSITY);
#endif

#ifdef DEBUG_MOD_UNIFORMS
	fragment_color = apply_mod_uniforms_debug(
		fragment_color,
		uv,
		currentSeason,
		currentSubSeason,
		seasonProgress,
		yearProgress,
		seasonDay,
		daysPerSeason,
		playerBodyTemp,
		worldAmbientTemp
	);
#endif
}

#include "/include/buffers.glsl"
