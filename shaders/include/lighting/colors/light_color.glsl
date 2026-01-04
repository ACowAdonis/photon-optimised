#if !defined INCLUDE_LIGHTING_COLORS_LIGHT_COLOR
#define INCLUDE_LIGHTING_COLORS_LIGHT_COLOR

#include "/include/sky/atmosphere.glsl"
#include "/include/utility/color.glsl"
#include "/include/lighting/colors/seasonal_lighting.glsl"

uniform float moon_phase_brightness;
// Note: rainStrength, biome_may_snow, biome_may_sandstorm are declared by including shader programs

#ifdef SEASONAL_LIGHTING
uniform float yearProgress;
#ifdef vsh
// cameraPosition - use guard to avoid conflicts if already declared by aurora_colors.glsl
#ifndef AURORA_CAMERA_POSITION_DECLARED
uniform vec3 cameraPosition;
#define AURORA_CAMERA_POSITION_DECLARED
#endif
#endif
#endif

// Storm darkness: reduces sun/sky light during storms
#ifdef STORM_INTENSITY_SYSTEM
float get_storm_darkness() {
	// Use rainStrength directly for lighting (responds faster than wetness)
	// Darkness increases with storm intensity, scaled by STORM_DARKNESS setting
	float storm_intensity = rainStrength * STORM_INTENSITY_MULT;
	// Quadratic falloff: light storms have minimal darkening, heavy storms are much darker
	return sqr(storm_intensity) * 0.75 * STORM_DARKNESS;
}

// Storm desaturation: shifts light toward cool gray during overcast conditions
// Reduced intensity (0.3) to leave room for Purkinje shift at night
vec3 apply_storm_desaturation(vec3 color) {
	float storm_intensity = rainStrength * STORM_INTENSITY_MULT;
	float luma = dot(color, luminance_weights);

	// Cool gray target - slight blue tint like overcast sky
	vec3 desat_target = luma * vec3(0.90, 0.95, 1.0);

	// Desaturation strength - kept moderate to avoid compounding with Purkinje
	float desat_strength = sqr(storm_intensity) * 0.3 * STORM_DARKNESS;

	return mix(color, desat_target, desat_strength);
}
#endif

// Magic brightness adjustment so that auto exposure isn't needed
float get_sun_exposure() {
	const float base_scale = 7.0 * SUN_I;

	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.09604)));

	float daytime_mul = 1.0 + 0.5 * (time_sunset + time_sunrise) + 40.0 * blue_hour;

	float exposure = base_scale * daytime_mul;

#ifdef SEASONAL_LIGHTING
	float latitude = get_latitude(cameraPosition.z);
	exposure *= get_seasonal_sun_intensity(latitude, yearProgress);
#endif

#ifdef STORM_INTENSITY_SYSTEM
	// Reduce sun exposure during storms (clouds block sunlight)
	exposure *= 1.0 - get_storm_darkness();
#endif

	return exposure;
}

vec3 get_sun_tint() {
	float blue_hour = linear_step(0.05, 1.0, exp(-190.0 * sqr(sun_dir.y + 0.09604)));

	vec3 morning_evening_tint = vec3(1.05, 0.84, 0.93) * 1.2;
	     morning_evening_tint = mix(vec3(1.0), morning_evening_tint, sqr(pulse(sun_dir.y, 0.17, 0.40)));

	vec3 blue_hour_tint = vec3(0.95, 0.80, 1.0);
	     blue_hour_tint = mix(vec3(1.0), blue_hour_tint, blue_hour);

	// User tint

	const vec3 tint_morning = from_srgb(vec3(SUN_MR, SUN_MG, SUN_MB));
	const vec3 tint_noon    = from_srgb(vec3(SUN_NR, SUN_NG, SUN_NB));
	const vec3 tint_evening = from_srgb(vec3(SUN_ER, SUN_EG, SUN_EB));

	vec3 user_tint = mix(tint_noon, tint_morning, time_sunrise);
	     user_tint = mix(user_tint, tint_evening, time_sunset);

	vec3 tint = morning_evening_tint * blue_hour_tint * user_tint;

#ifdef SEASONAL_LIGHTING
	float latitude = get_latitude(cameraPosition.z);
	tint *= get_seasonal_color_tint(latitude, yearProgress);
#endif

	return tint;
}

float get_moon_exposure() {
	const float base_scale = 0.66 * MOON_I;

	return base_scale * moon_phase_brightness;
}

vec3 get_moon_tint() {
	const vec3 base_tint = from_srgb(vec3(MOON_R, MOON_G, MOON_B));

	return base_tint;
}

vec3 get_light_color() {
	vec3 light_color  = sunlight_color * atmosphere_transmittance(light_dir.y, planet_radius);
	     light_color  = atmosphere_post_processing(light_color);
	     light_color *= mix(get_sun_exposure() * get_sun_tint(), get_moon_exposure() * get_moon_tint(), step(0.5, sunAngle));
	     light_color *= clamp01(rcp(0.02) * light_dir.y); // fade away during day/night transition
		 light_color *= 1.0 - 0.25 * pulse(abs(light_dir.y), 0.15, 0.11);

#ifdef STORM_INTENSITY_SYSTEM
	// Desaturate light toward cool gray during storms
	light_color = apply_storm_desaturation(light_color);
#endif

	return light_color;
}

float get_skylight_boost() {
	float night_skylight_boost = 4.0 * (1.0 - smoothstep(-0.16, 0.0, sun_dir.y))
	                           - 3.0 * linear_step(0.1, 1.0, exp(-2.42 * sqr(sun_dir.y + 0.81)));

	float boost = 1.0 + max0(night_skylight_boost);

#ifdef SEASONAL_LIGHTING
	float latitude = get_latitude(cameraPosition.z);
	boost *= get_seasonal_ambient_intensity(latitude, yearProgress);
#endif

#ifdef STORM_INTENSITY_SYSTEM
	// Reduce skylight during storms (overcast sky blocks ambient light)
	// Slightly less reduction than direct sunlight since ambient is more diffuse
	boost *= 1.0 - get_storm_darkness() * 0.7;
#endif

	return boost;
}

#endif // INCLUDE_LIGHTING_COLORS_LIGHT_COLOR
