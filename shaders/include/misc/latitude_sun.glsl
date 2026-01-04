#if !defined INCLUDE_MISC_LATITUDE_SUN
#define INCLUDE_MISC_LATITUDE_SUN

/*
 * Latitude-Based Sun Path System
 *
 * Adjusts the sun's arc across the sky based on:
 * - Player latitude (distance from equator)
 * - Current season (from Serene Seasons yearProgress)
 *
 * Effects:
 * - At equator: Sun passes nearly overhead, minimal seasonal variation
 * - At higher latitudes: Sun arcs lower in sky, more seasonal variation
 * - Summer: Sun higher in sky
 * - Winter: Sun lower in sky
 *
 * Both hemispheres behave identically (no inverted seasons).
 * Bounded to reasonable values - no extreme polar day/night simulation.
 */

#include "/include/misc/latitude.glsl"

// Maximum solar declination (Earth-like ~23.45 degrees)
#define SOLAR_DECLINATION_MAX 23.45

// Maximum latitude effect on sun path (degrees)
// At poles, this is added to the base sun path rotation
#define LATITUDE_SUN_OFFSET_MAX 45.0

/*
 * Get solar declination based on time of year
 * This is the seasonal component of sun position
 *
 * year_progress: Progress through year [0, 1] from Serene Seasons
 *                0.0 = start of spring
 *                0.25 = start of summer
 *                0.5 = start of autumn
 *                0.75 = start of winter
 *
 * Returns: Solar declination in degrees [-23.45, +23.45]
 *          Positive = sun higher (summer)
 *          Negative = sun lower (winter)
 */
float get_solar_declination(float year_progress) {
	// Summer solstice at yearProgress ~0.375 (mid-summer)
	// Winter solstice at yearProgress ~0.875 (mid-winter)
	// Use sine wave offset to align peaks correctly
	float angle = (year_progress - 0.125) * 6.28318530718; // 2*PI, offset so peak at 0.375
	return SOLAR_DECLINATION_MAX * sin(angle);
}

/*
 * Get latitude-based sun path offset
 * Higher latitudes = sun arcs lower in sky
 *
 * latitude: Normalized latitude [0, 1] (0=equator, 1=pole)
 *
 * Returns: Base latitude offset in degrees [0, LATITUDE_SUN_OFFSET_MAX]
 */
float get_latitude_sun_offset(float latitude) {
	// Quadratic curve for more gradual change near equator
	// and stronger effect at high latitudes
	return LATITUDE_SUN_OFFSET_MAX * latitude * latitude;
}

/*
 * Get combined sun path adjustment
 * Combines latitude and seasonal effects
 *
 * latitude: Normalized latitude [0, 1]
 * year_progress: Progress through year [0, 1]
 *
 * Returns: Total sun path adjustment in degrees
 *          This is ADDED to the existing sunPathRotation
 */
float get_sun_path_adjustment(float latitude, float year_progress) {
	// Base latitude offset (always pushes sun lower at high latitudes)
	float latitude_offset = get_latitude_sun_offset(latitude);

	// Seasonal variation (scaled by latitude - equator has minimal seasonal change)
	float declination = get_solar_declination(year_progress);
	float seasonal_multiplier = get_seasonal_extremity(latitude); // From latitude.glsl
	float seasonal_offset = -declination * seasonal_multiplier; // Negative because lower declination = higher rotation

	// Combine: latitude always adds rotation, season modulates it
	// Apply intensity setting
	return (latitude_offset + seasonal_offset) * LATITUDE_SUN_PATH_INTENSITY;
}

/*
 * Create rotation matrix around X-axis (east-west)
 * Used to adjust sun direction based on latitude/season
 *
 * angle: Rotation angle in radians
 *
 * Returns: 3x3 rotation matrix
 */
mat3 rotation_matrix_x(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat3(
		1.0, 0.0, 0.0,
		0.0,   c,  -s,
		0.0,   s,   c
	);
}

/*
 * Get adjusted sun direction based on latitude and season
 * Applies additional rotation to the engine-provided sun_dir
 *
 * sun_dir_input: Original sun direction from Iris/OptiFine
 * camera_z: Camera Z position for latitude calculation
 * year_progress: Progress through year [0, 1] from Serene Seasons
 *
 * Returns: Adjusted sun direction vector (normalized)
 */
vec3 get_latitude_adjusted_sun_dir(vec3 sun_dir_input, float camera_z, float year_progress) {
	float latitude = get_latitude(camera_z);

	// Get adjustment in degrees, convert to radians
	float adjustment_deg = get_sun_path_adjustment(latitude, year_progress);
	float adjustment_rad = adjustment_deg * 0.01745329251994; // PI/180

	// Apply rotation around X-axis (east-west axis)
	// This tilts the sun's path north/south
	mat3 rotation = rotation_matrix_x(adjustment_rad);

	return normalize(rotation * sun_dir_input);
}

/*
 * Get adjusted moon direction (opposite of adjusted sun)
 */
vec3 get_latitude_adjusted_moon_dir(vec3 sun_dir_input, float camera_z, float year_progress) {
	return -get_latitude_adjusted_sun_dir(sun_dir_input, camera_z, year_progress);
}

/*
 * Get adjusted light direction (sun or moon depending on time)
 */
vec3 get_latitude_adjusted_light_dir(vec3 sun_dir_input, float camera_z, float year_progress, float sun_angle) {
	vec3 adjusted_sun = get_latitude_adjusted_sun_dir(sun_dir_input, camera_z, year_progress);
	return sun_angle < 0.5 ? adjusted_sun : -adjusted_sun;
}

#endif // INCLUDE_MISC_LATITUDE_SUN
