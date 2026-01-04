#if !defined INCLUDE_LIGHTING_COLORS_SEASONAL_LIGHTING
#define INCLUDE_LIGHTING_COLORS_SEASONAL_LIGHTING

#include "/include/misc/latitude.glsl"

/*
 * Seasonal Lighting System
 *
 * Provides lighting variations based on latitude and time of year.
 * Uses Serene Seasons yearProgress (0.0-1.0) where:
 *   ~0.125 = Early Spring (transitioning back to baseline)
 *   ~0.375 = Summer peak (brightest at high latitudes)
 *   ~0.625 = Autumn (transitioning into winter darkness)
 *   ~0.875 = Winter peak (darkest, coldest tones)
 *
 * Design philosophy:
 *   - Full seasonal cycle: summer brightening AND winter darkening
 *   - Regional: Effects scale with latitude from equator to poles
 *   - Tropical/desert regions remain relatively stable
 *   - Extreme effects at polar latitudes (up to 40% darker in winter, 15% brighter in summer)
 *   - Winter brings cooler/bluer tones and reduced ambient light
 *   - Smooth sinusoidal transitions through all seasons
 */

/*
 * Get season factor: -1.0 at winter peak, +1.0 at summer peak
 * Uses sinusoidal curve for smooth seasonal transitions
 */
float get_season_factor(float year_progress) {
	// cos curve offset so summer (0.375) = +1, winter (0.875) = -1
	return cos(tau * (year_progress - 0.375));
}

/*
 * Get winter factor: 0.0 in summer, +1.0 at winter peak
 * Used for effects that only apply in winter (color tint, ambient reduction)
 */
float get_winter_factor(float year_progress) {
	return max(0.0, -get_season_factor(year_progress));
}

/*
 * Get high latitude factor for seasonal effects
 * Returns 0.0 in tropical, ramps up more aggressively through polar
 *
 * Latitude zones (normalized 0-1):
 *   0.00 - 0.20: Tropical - minimal effect
 *   0.20 - 0.40: Desert/Savanna - slight effect
 *   0.40 - 0.60: Temperate - moderate effect
 *   0.60 - 0.80: Cold - strong effect
 *   0.80 - 1.00: Polar - maximum effect
 */
float get_high_latitude_factor(float latitude) {
	// Start ramping from tropical boundary, accelerate towards poles
	// Use squared curve for more aggressive scaling at high latitudes
	float base = smoothstep(LATITUDE_TROPICAL_END, 1.0, latitude);
	return base * base; // Square for more pronounced polar effects
}

/*
 * Get sun intensity multiplier based on latitude and season
 *
 * At equator: ~1.0 year-round (minimal variation)
 * At poles:
 *   Summer: up to ~1.15x (brighter)
 *   Winter: down to ~0.60x (darker)
 *
 * latitude: Normalized latitude [0, 1] from get_latitude()
 * year_progress: yearProgress uniform [0, 1]
 *
 * Returns: Intensity multiplier [0.60, 1.15]
 */
float get_seasonal_sun_intensity(float latitude, float year_progress) {
#ifndef SEASONAL_LIGHTING
	return 1.0;
#else
	float season = get_season_factor(year_progress); // -1 winter, +1 summer
	float high_lat = get_high_latitude_factor(latitude);

	// Asymmetric scaling: more darkening in winter than brightening in summer
	// Winter: up to 40% darker, Summer: up to 15% brighter
	float winter_strength = 0.40;
	float summer_strength = 0.15;

	float variation = season > 0.0
		? SEASONAL_LIGHTING_INTENSITY * summer_strength * season * high_lat
		: SEASONAL_LIGHTING_INTENSITY * winter_strength * season * high_lat;

	return 1.0 + variation;
#endif
}

/*
 * Get seasonal color temperature tint
 *
 * Summer/tropical: No change (vec3(1.0))
 * Winter at high latitudes: Blue shift for stark, cold feeling
 *
 * Returns: RGB tint multiplier
 */
vec3 get_seasonal_color_tint(float latitude, float year_progress) {
#ifndef SEASONAL_LIGHTING
	return vec3(1.0);
#else
	float winter = get_winter_factor(year_progress);
	float high_lat = get_high_latitude_factor(latitude);

	// Combined seasonal effect strength
	float effect = SEASONAL_LIGHTING_COLOR_SHIFT * winter * high_lat;

	// Winter color shift: cooler/bluer tones
	// More pronounced at polar regions for stark winter atmosphere
	return vec3(
		1.0 - 0.06 * effect,  // R: down to ~0.94 at max
		1.0 - 0.02 * effect,  // G: down to ~0.98 at max
		1.0 + 0.04 * effect   // B: up to ~1.04 at max
	);
#endif
}

/*
 * Get ambient/skylight seasonal intensity
 *
 * Summer: no change (1.0)
 * Winter at high latitudes: significant reduction for stark atmosphere
 *   Temperate: ~0.85x
 *   Cold: ~0.70x
 *   Polar: ~0.50x
 *
 * Returns: Ambient multiplier [0.50, 1.0]
 */
float get_seasonal_ambient_intensity(float latitude, float year_progress) {
#ifndef SEASONAL_LIGHTING
	return 1.0;
#else
	float winter = get_winter_factor(year_progress);
	float high_lat = get_high_latitude_factor(latitude);

	// More aggressive ambient reduction than sun intensity
	// Maximum reduction at polar winter: 50%
	float darkening = SEASONAL_LIGHTING_INTENSITY * 0.50 * winter * high_lat;

	return 1.0 - darkening;
#endif
}

#endif // INCLUDE_LIGHTING_COLORS_SEASONAL_LIGHTING
