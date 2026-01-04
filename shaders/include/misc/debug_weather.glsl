#if !defined INCLUDE_MISC_DEBUG_WEATHER
#define INCLUDE_MISC_DEBUG_WEATHER

uniform int worldTime;
uniform int worldDay;
uniform float sunAngle;

uniform float rainStrength;
uniform float wetness;

uniform vec3 light_dir;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

uniform float world_age;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

uniform float biome_cave;
uniform float biome_temperate;
uniform float biome_arid;
uniform float biome_snowy;
uniform float biome_taiga;
uniform float biome_jungle;
uniform float biome_swamp;
uniform float biome_may_rain;
uniform float biome_may_snow;
uniform float biome_temperature;
uniform float biome_humidity;

uniform float desert_sandstorm;

// Storm daily cap requires additional uniforms
#ifdef STORM_INTENSITY_SYSTEM
uniform vec3 cameraPosition;
uniform float yearProgress;

#include "/include/weather/storm_daily_cap.glsl"
#endif

#include "/include/weather/core.glsl"
#include "/include/weather/clouds.glsl"

void debug_weather(inout vec3 color) {
	const int number_col = 30;

	Weather weather = get_weather();
	CloudsParameters clouds_params = get_clouds_parameters(weather);

	begin_text(ivec2(gl_FragCoord.xy) / debug_text_scale, debug_text_position);
	text.bg_col = vec4(0.0);
	print((_W, _E, _A, _T, _H, _E, _R));
	print_line();
	print((_T, _e, _m, _p, _e, _r, _a, _t, _u, _r, _e));
	text.char_pos.x = number_col;
	print_float(weather.temperature);
	print_line();
	print((_H, _u, _m, _i, _d, _i, _d, _i, _t, _y));
	text.char_pos.x = number_col;
	print_float(weather.humidity);
	print_line();
	print((_B, _i, _o, _m, _e, _space, _t, _e, _m, _p, _e, _r, _a, _t, _u, _r, _e));
	text.char_pos.x = number_col;
	print_float(biome_temperature);
	print_line();
	print((_B, _i, _o, _m, _e, _space, _r, _a, _i, _n, _f, _a, _l, _l));
	text.char_pos.x = number_col;
	print_float(biome_humidity);
	print_line();
	print((_W, _i, _n, _d));
	text.char_pos.x = number_col;
	print_float(weather.wind);
	print_line();
	print_line();
	print((_C, _L, _O, _U, _D, _S));
	print_line();
	print((_C, _u, _m, _u, _l, _u, _s, _space, _c, _o, _n, _g, _e, _s, _t, _u, _s, _space, _b, _l, _e, _n, _d));
	text.char_pos.x = number_col;
	print_float(clouds_params.cumulus_congestus_blend);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _0, _space, _c, _o, _v, _e, _r, _a, _g, _e, _space, _m, _i, _n));
	text.char_pos.x = number_col;
	print_float(clouds_params.l0_coverage.x);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _0, _space, _c, _o, _v, _e, _r, _a, _g, _e, _space, _m, _a, _x));
	text.char_pos.x = number_col;
	print_float(clouds_params.l0_coverage.y);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _0, _space, _c, _u, _m, _u, _l, _u, _s, _minus, _s, _t, _r, _a, _t, _u, _s, _space, _b, _l, _e, _n, _d));
	text.char_pos.x = number_col;
	print_float(clouds_params.l0_cumulus_stratus_blend);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _1, _space, _c, _o, _v, _e, _r, _a, _g, _e, _space, _m, _i, _n));
	text.char_pos.x = number_col;
	print_float(clouds_params.l1_coverage.x);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _1, _space, _c, _o, _v, _e, _r, _a, _g, _e, _space, _m, _a, _x));
	text.char_pos.x = number_col;
	print_float(clouds_params.l1_coverage.y);
	print_line();
	print((_L, _a, _y, _e, _r, _space, _1, _space, _c, _u, _m, _u, _l, _u, _s, _minus, _s, _t, _r, _a, _t, _u, _s, _space, _b, _l, _e, _n, _d));
	text.char_pos.x = number_col;
	print_float(clouds_params.l1_cumulus_stratus_blend);
	print_line();
	print((_C, _i, _r, _r, _u, _s, _space, _a, _m, _o, _u, _n, _t));
	text.char_pos.x = number_col;
	print_float(clouds_params.cirrus_amount);
	print_line();
	print((_C, _i, _r, _r, _o, _c, _u, _m, _u, _l, _u, _s, _space, _a, _m, _o, _u, _n, _t));
	text.char_pos.x = number_col;
	print_float(clouds_params.cirrocumulus_amount);
	print_line();
	print((_N, _o, _c, _t, _i, _l, _u, _c, _e, _n, _t, _space, _a, _m, _o, _u, _n, _t));
	text.char_pos.x = number_col;
	print_float(clouds_params.noctilucent_amount);
	print_line();
	print((_C, _r, _e, _p, _u, _s, _c, _u, _l, _a, _r, _space, _r, _a, _y, _s, _space, _a, _m, _o, _u, _n, _t));
	text.char_pos.x = number_col;
	print_float(clouds_params.crepuscular_rays_amount);
	print_line();

#ifdef STORM_INTENSITY_SYSTEM
	print_line();
	print((_S, _T, _O, _R, _M));
	print_line();

	// Calculate daily storm cap
	float latitude = get_latitude(cameraPosition.z);
	bool is_snow = biome_may_snow > 0.5;
	float daily_cap = get_storm_daily_cap(latitude, yearProgress, worldDay, is_snow);

	// Show latitude and season info
	print((_L, _a, _t, _i, _t, _u, _d, _e));
	text.char_pos.x = number_col;
	print_float(latitude);
	print_line();

	print((_Y, _e, _a, _r, _space, _p, _r, _o, _g, _r, _e, _s, _s));
	text.char_pos.x = number_col;
	print_float(yearProgress);
	print_line();

	print((_W, _o, _r, _l, _d, _space, _d, _a, _y));
	text.char_pos.x = number_col;
	print_int(worldDay);
	print_line();

	print((_D, _a, _i, _l, _y, _space, _c, _a, _p));
	text.char_pos.x = number_col;
	print_float(daily_cap);
	print_line();

	print_line();

	print((_R, _a, _i, _n, _space, _s, _t, _r, _e, _n, _g, _t, _h));
	text.char_pos.x = number_col;
	print_float(rainStrength);
	print_line();

	// Storm intensity WITH daily cap applied
	float storm_intensity = min(rainStrength * STORM_INTENSITY_MULT, daily_cap);
	print((_S, _t, _o, _r, _m, _space, _i, _n, _t, _e, _n, _s, _i, _t, _y));
	text.char_pos.x = number_col;
	print_float(storm_intensity);
	print_line();

	// Storm tier: 0=Drizzle, 1=Rain, 2=Heavy, 3=Storm
	int storm_tier = storm_intensity < 0.25 ? 0 : (storm_intensity < 0.5 ? 1 : (storm_intensity < 0.75 ? 2 : 3));
	print((_S, _t, _o, _r, _m, _space, _t, _i, _e, _r));
	text.char_pos.x = number_col;
	print_int(storm_tier);
	print_line();

	print((_B, _i, _o, _m, _e, _space, _m, _a, _y, _space, _r, _a, _i, _n));
	text.char_pos.x = number_col;
	print_float(biome_may_rain);
	print_line();
	print((_B, _i, _o, _m, _e, _space, _m, _a, _y, _space, _s, _n, _o, _w));
	text.char_pos.x = number_col;
	print_float(biome_may_snow);
	print_line();

	// Fog multiplier (calculated same as in fog.glsl, with cap and baseline variance)
	// Light days (cap 0.1-0.3) have reduced baseline fog (0.7-0.85)
	// Coefficient reduced from 2.0 to 1.25 to prevent excessive fog in humid biomes
	float fog_baseline = mix(0.7, 1.0, smoothstep(0.2, 0.6, daily_cap));
	float storm_fog_mult = fog_baseline + sqr(storm_intensity) * 1.25 * STORM_FOG_MULT;
	print((_F, _o, _g, _space, _b, _a, _s, _e, _l, _i, _n, _e));
	text.char_pos.x = number_col;
	print_float(fog_baseline);
	print_line();
	print((_F, _o, _g, _space, _m, _u, _l, _t, _i, _p, _l, _i, _e, _r));
	text.char_pos.x = number_col;
	print_float(storm_fog_mult);
	print_line();

	// Wind strength (calculated same as in gbuffers_weather.vsh, with cap and baseline variance)
	// Light days have more vertical rain (base_tilt 0.05-0.15)
	float storm_wind = min(rainStrength * STORM_WIND_MULT, daily_cap);
	float base_tilt = mix(0.05, 0.15, smoothstep(0.2, 0.6, daily_cap));
	float rain_tilt = base_tilt + 0.35 * storm_wind;
	print((_W, _i, _n, _d, _space, _b, _a, _s, _e, _space, _t, _i, _l, _t));
	text.char_pos.x = number_col;
	print_float(base_tilt);
	print_line();
	print((_R, _a, _i, _n, _space, _t, _i, _l, _t));
	text.char_pos.x = number_col;
	print_float(rain_tilt);
	print_line();
#endif

	end_text(color);
}

#endif // INCLUDE_MISC_DEBUG_WEATHER
