/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_weather:
  Handle rain and snow particles

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

out vec2 uv;

flat out vec4 tint;

// ------------
//   Uniforms
// ------------

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform float rainStrength;

uniform int frameCounter;

uniform vec2 taa_offset;
uniform vec2 view_pixel_size;

// Storm intensity system requires additional uniforms for latitude/season calculation
#ifdef STORM_INTENSITY_SYSTEM
uniform float yearProgress;
uniform int worldDay;
uniform float biome_may_snow;

#include "/include/weather/storm_daily_cap.glsl"
#endif

void main() {
	uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;

	tint = gl_Color;

	vec3 view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

#ifdef SLANTED_RAIN
	// Storm intensity scaling: wind tilt increases with rain strength
	// Base: light rain (0.15, 30deg), Peak storm: (0.50, 50deg)
#ifdef STORM_INTENSITY_SYSTEM
	// Calculate daily storm cap based on latitude, season, and day
	float latitude = get_latitude(cameraPosition.z);
	bool is_snow = biome_may_snow > 0.5;
	float storm_daily_cap = get_storm_daily_cap(latitude, yearProgress, worldDay, is_snow);

	// Apply storm cap to wind intensity
	float storm_wind = min(rainStrength * STORM_WIND_MULT, storm_daily_cap);
	// Base tilt varies with daily cap: calm days have more vertical rain
	// Cap 0.1-0.3 (calm): base_tilt 0.05-0.10 (nearly vertical rain)
	// Cap 0.6-1.0 (stormy): base_tilt 0.15 (normal slant)
	float base_tilt = mix(0.05, 0.15, smoothstep(0.2, 0.6, storm_daily_cap));
	float base_angle = mix(20.0, 30.0, smoothstep(0.2, 0.6, storm_daily_cap));
	float rain_tilt_amount = base_tilt + 0.35 * storm_wind;
	float rain_tilt_angle  = (base_angle + 20.0 * storm_wind) * degree;
#else
	const float rain_tilt_amount = 0.25;
	const float rain_tilt_angle  = 30.0 * degree;
#endif
	vec2 rain_tilt_offset = rain_tilt_amount * vec2(cos(rain_tilt_angle), sin(rain_tilt_angle));

	vec3 scene_pos = transform(gbufferModelViewInverse, view_pos);
	vec3 world_pos = scene_pos + cameraPosition;

	// Wind variation: more chaotic in storms
#ifdef STORM_INTENSITY_SYSTEM
	float wind_variation = 0.3 + 0.4 * storm_wind;
	float tilt_wave = (1.0 - wind_variation) + wind_variation * sin(dot(world_pos, vec3(5.0)));
#else
	float tilt_wave = 0.7 + 0.3 * sin(dot(world_pos, vec3(5.0)));
#endif
	scene_pos.xz -= rain_tilt_offset * tilt_wave * scene_pos.y;

	view_pos = transform(gbufferModelView, scene_pos);
#endif

	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.66;
#endif

	gl_Position = clip_pos;
}

