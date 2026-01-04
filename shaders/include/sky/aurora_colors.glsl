#if !defined INCLUDE_SKY_AURORA_COLORS
#define INCLUDE_SKY_AURORA_COLORS

#include "/include/utility/random.glsl"

// Latitude-based aurora visibility
// When SEASONAL_LIGHTING is enabled, auroras only appear at high latitudes (>5000 blocks from origin)
#ifdef SEASONAL_LIGHTING
// Declare cameraPosition with guard to avoid conflicts with other files
#if defined(vsh) && !defined(AURORA_CAMERA_POSITION_DECLARED)
uniform vec3 cameraPosition;
#define AURORA_CAMERA_POSITION_DECLARED
#endif
#include "/include/misc/latitude.glsl"
#endif

/*
 * Aurora Color Palette
 *
 * Based on real aurora physics:
 * - Green (557.7nm): Oxygen emission at 100-300km altitude - most common aurora color
 * - Red (630nm): Oxygen at higher altitudes (200-500km) - upper curtain edges
 * - Blue/Purple: Nitrogen ions at lower altitudes
 * - Pink/Magenta: Mix of red and blue at curtain edges
 *
 * Removed unrealistic yellows and oranges which don't occur in real auroras.
 *
 * [0] - bottom/lower curtain color (typically green or pink)
 * [1] - top/upper curtain color (typically red, blue, or purple)
 */
mat2x3 get_aurora_colors() {
	const mat2x3[] aurora_colors = mat2x3[](
		// Classic green aurora with red top (most common, ~60% of auroras)
		mat2x3(
			vec3(0.10, 1.00, 0.30), // bright green (oxygen 557.7nm)
			vec3(0.80, 0.15, 0.20)  // deep red (oxygen 630nm)
		)
		// Green with subtle red edge
		, mat2x3(
			vec3(0.05, 0.95, 0.25), // green
			vec3(0.60, 0.20, 0.25)  // muted red
		)
		// Green to purple transition (nitrogen influence)
		, mat2x3(
			vec3(0.10, 1.00, 0.35), // green
			vec3(0.50, 0.20, 0.70)  // purple
		)
		// Blue-green with purple top
		, mat2x3(
			vec3(0.15, 0.80, 0.50), // teal-green
			vec3(0.45, 0.15, 0.65)  // purple
		)
		// Pink/magenta lower curtains (rarer, high energy events)
		, mat2x3(
			vec3(0.90, 0.30, 0.50), // pink
			vec3(0.30, 0.10, 0.60)  // deep purple
		)
		// Vibrant green to blue
		, mat2x3(
			vec3(0.05, 1.00, 0.25), // vivid green
			vec3(0.20, 0.40, 0.85)  // blue (nitrogen N2+)
		)
		// Pale green with pink edges
		, mat2x3(
			vec3(0.20, 0.90, 0.40), // pale green
			vec3(0.70, 0.25, 0.45)  // pink
		)
		// Deep purple curtains (proton aurora)
		, mat2x3(
			vec3(0.55, 0.20, 0.70), // purple
			vec3(0.35, 0.15, 0.55)  // deep violet
		)
		// White-green to red (bright storm)
		, mat2x3(
			vec3(0.50, 1.00, 0.50), // bright white-green
			vec3(0.85, 0.20, 0.15)  // vivid red
		)
		// Subtle green glow
		, mat2x3(
			vec3(0.08, 0.75, 0.25), // muted green
			vec3(0.40, 0.20, 0.50)  // soft purple
		)
	);

	uint day_index = uint(worldDay);
	     day_index = lowbias32(day_index) % aurora_colors.length();

	return aurora_colors[day_index];
}

/*
 * Get aurora visibility amount
 *
 * Returns 0.0 (no aurora) to 1.0 (full aurora)
 *
 * When SEASONAL_LIGHTING is enabled:
 * - Auroras only appear at high latitudes (cold/polar zones, >5000 blocks from origin)
 * - Intensity increases with latitude (strongest near poles)
 * - Still respects day-based rarity settings
 *
 * When SEASONAL_LIGHTING is disabled:
 * - Falls back to original biome_may_snow behavior
 */
float get_aurora_amount() {
	float night = smoothstep(0.0, 0.2, -sun_dir.y);

#if   AURORA_NORMAL == AURORA_NEVER
	float aurora_normal = 0.0;
#elif AURORA_NORMAL == AURORA_RARELY
	float aurora_normal = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_NORMAL == AURORA_ALWAYS
	float aurora_normal = 1.0;
#endif

#if   AURORA_SNOW == AURORA_NEVER
	float aurora_snow = 0.0;
#elif AURORA_SNOW == AURORA_RARELY
	float aurora_snow = float(lowbias32(uint(worldDay)) % 5 == 1);
#elif AURORA_SNOW == AURORA_ALWAYS
	float aurora_snow = 1.0;
#endif

#ifdef SEASONAL_LIGHTING
	// Latitude-based aurora visibility (cameraPosition declared above with guard pattern)
	float latitude = get_latitude(cameraPosition.z);

	// Aurora visibility based on latitude:
	// - Starts appearing in cold zone (latitude > 0.6, ~4800 blocks)
	// - Full visibility in polar zone (latitude > 0.8, ~6400 blocks)
	float latitude_factor = smoothstep(0.6, 0.85, latitude);

	// Combine: use the "snow" aurora chance at high latitudes
	// This respects user settings (AURORA_SNOW) while gating on latitude
	float aurora_chance = mix(aurora_normal, aurora_snow, latitude_factor);

	return night * aurora_chance * latitude_factor;
#else
	// Original behavior: biome-based
	return night * mix(aurora_normal, aurora_snow, biome_may_snow);
#endif
}

#endif // INCLUDE_SKY_AURORA_COLORS
