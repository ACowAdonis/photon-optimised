#if !defined INCLUDE_MISC_LATITUDE
#define INCLUDE_MISC_LATITUDE

/*
 * Latitude-Based Climate System
 *
 * Provides climate band calculations based on world Z-coordinate (north-south axis).
 * Designed to integrate with Natural Temperature mod's climate model.
 *
 * Climate Model (symmetric around equator at Z=0):
 *   |Z| = 0      : Tropical (equator)
 *   |Z| ~ 1333   : Desert/Arid
 *   |Z| ~ 2666   : Savanna/Subtropical
 *   |Z| ~ 4000   : Temperate
 *   |Z| ~ 5333   : Cold/Subarctic
 *   |Z| ~ 6666+  : Polar/Arctic
 *   |Z| = 8000   : Poles
 *
 * Default configuration: LATITUDE_SCALE = 8000 (blocks from equator to pole)
 */

// Climate band enum-like constants for readability
#define CLIMATE_TROPICAL   0
#define CLIMATE_DESERT     1
#define CLIMATE_SAVANNA    2
#define CLIMATE_TEMPERATE  3
#define CLIMATE_COLD       4
#define CLIMATE_ARCTIC     5
#define CLIMATE_POLAR      5  // Alias for backwards compatibility

// Band width in blocks (LATITUDE_SCALE / 6)
#define LATITUDE_BAND_WIDTH (LATITUDE_SCALE / 6.0)

// Arctic boundary in blocks (5 * band width = 6666 at default scale)
#define LATITUDE_ARCTIC_BLOCKS (LATITUDE_BAND_WIDTH * 5.0)

/*
 * Get normalized latitude (0 = equator, 1 = pole)
 *
 * camera_z: Camera Z position (cameraPosition.z)
 *
 * Returns: Normalized latitude [0, 1] clamped
 */
float get_latitude(float camera_z) {
	float distance_from_equator = abs(camera_z - LATITUDE_ORIGIN_Z);
	return clamp(distance_from_equator / LATITUDE_SCALE, 0.0, 1.0);
}

/*
 * Get climate band boundaries as normalized latitude values
 * Each band is approximately 1/6th of the total range (0 to 1)
 */
#define LATITUDE_TROPICAL_END    0.167  // ~1333 blocks at default scale
#define LATITUDE_DESERT_END      0.333  // ~2666 blocks
#define LATITUDE_SAVANNA_END     0.500  // ~4000 blocks
#define LATITUDE_TEMPERATE_END   0.667  // ~5333 blocks
#define LATITUDE_COLD_END        0.833  // ~6666 blocks
// Above 0.833 = Polar

/*
 * Get smooth factor for tropical climate band (full at equator, fades out)
 * Returns 1.0 at equator, 0.0 outside tropical zone
 */
float get_tropical_factor(float latitude) {
	return 1.0 - smoothstep(0.0, LATITUDE_TROPICAL_END + 0.05, latitude);
}

/*
 * Get smooth factor for desert/arid climate band
 * Peak in desert zone, fades to adjacent zones
 */
float get_desert_factor(float latitude) {
	float fade_in = smoothstep(LATITUDE_TROPICAL_END - 0.05, LATITUDE_TROPICAL_END + 0.05, latitude);
	float fade_out = 1.0 - smoothstep(LATITUDE_DESERT_END - 0.05, LATITUDE_DESERT_END + 0.1, latitude);
	return fade_in * fade_out;
}

/*
 * Get smooth factor for savanna/subtropical climate band
 */
float get_savanna_factor(float latitude) {
	float fade_in = smoothstep(LATITUDE_DESERT_END - 0.05, LATITUDE_DESERT_END + 0.05, latitude);
	float fade_out = 1.0 - smoothstep(LATITUDE_SAVANNA_END - 0.05, LATITUDE_SAVANNA_END + 0.1, latitude);
	return fade_in * fade_out;
}

/*
 * Get smooth factor for temperate climate band
 */
float get_temperate_factor(float latitude) {
	float fade_in = smoothstep(LATITUDE_SAVANNA_END - 0.05, LATITUDE_SAVANNA_END + 0.05, latitude);
	float fade_out = 1.0 - smoothstep(LATITUDE_TEMPERATE_END - 0.05, LATITUDE_TEMPERATE_END + 0.1, latitude);
	return fade_in * fade_out;
}

/*
 * Get smooth factor for cold/subarctic climate band
 */
float get_cold_factor(float latitude) {
	float fade_in = smoothstep(LATITUDE_TEMPERATE_END - 0.05, LATITUDE_TEMPERATE_END + 0.05, latitude);
	float fade_out = 1.0 - smoothstep(LATITUDE_COLD_END - 0.05, LATITUDE_COLD_END + 0.1, latitude);
	return fade_in * fade_out;
}

/*
 * Get smooth factor for polar/arctic climate band
 */
float get_polar_factor(float latitude) {
	return smoothstep(LATITUDE_COLD_END - 0.05, LATITUDE_COLD_END + 0.1, latitude);
}

/*
 * Get combined "hot climate" factor (tropical + desert + partial savanna)
 * Used for heat haze and similar hot-weather effects
 *
 * latitude: Normalized latitude [0, 1]
 * year_progress: Progress through the year [0, 1] from Serene Seasons
 *
 * Returns: Heat factor [0, 1] accounting for latitude and season
 */
float get_heat_climate_factor(float latitude, float year_progress) {
	// Tropical: always hot
	float tropical = get_tropical_factor(latitude);

	// Desert: very hot
	float desert = get_desert_factor(latitude);

	// Savanna: hot in summer, mild otherwise
	float savanna = get_savanna_factor(latitude);

	// Calculate summer factor (peaks at yearProgress ~0.375 which is mid-summer)
	float summer_factor = 1.0 - abs(year_progress - 0.375) * 4.0;
	summer_factor = clamp(summer_factor, 0.0, 1.0);

	// Tropical and desert are always hot
	// Savanna gets partial heat year-round but more in summer
	float base_heat = tropical + desert * 0.9 + savanna * 0.4;

	// Add seasonal boost to savanna and slight boost to temperate in peak summer
	float seasonal_heat = savanna * 0.5 * summer_factor;

	// Temperate can get heat waves in peak summer
	float temperate = get_temperate_factor(latitude);
	seasonal_heat += temperate * 0.3 * summer_factor * summer_factor; // Squared for sharper peak

	return clamp(base_heat + seasonal_heat, 0.0, 1.0);
}

/*
 * Get combined "cold climate" factor (polar + cold + partial temperate in winter)
 * Used for ice crystals, breath vapor, and similar cold-weather effects
 *
 * latitude: Normalized latitude [0, 1]
 * year_progress: Progress through the year [0, 1] from Serene Seasons
 *
 * Returns: Cold factor [0, 1] accounting for latitude and season
 */
float get_cold_climate_factor(float latitude, float year_progress) {
	// Polar: always cold
	float polar = get_polar_factor(latitude);

	// Cold/subarctic: very cold
	float cold = get_cold_factor(latitude);

	// Temperate: cold in winter
	float temperate = get_temperate_factor(latitude);

	// Calculate winter factor (peaks at yearProgress ~0.875 which is mid-winter)
	float winter_factor = 1.0 - abs(year_progress - 0.875) * 4.0;
	winter_factor = clamp(winter_factor, 0.0, 1.0);

	// Polar is always frozen, cold zones are very cold year-round
	float base_cold = polar + cold * 0.85;

	// Add seasonal cold to temperate regions
	float seasonal_cold = temperate * 0.6 * winter_factor;

	// Cold regions get even colder in winter
	seasonal_cold += cold * 0.15 * winter_factor;

	// Even savanna can get chilly nights in winter (mild effect)
	float savanna = get_savanna_factor(latitude);
	seasonal_cold += savanna * 0.15 * winter_factor * winter_factor;

	return clamp(base_cold + seasonal_cold, 0.0, 1.0);
}

/*
 * Get seasonal intensity multiplier based on latitude
 * Higher latitudes have more extreme seasonal variation
 *
 * latitude: Normalized latitude [0, 1]
 *
 * Returns: Seasonal extremity factor [0.3, 1.0]
 *          0.3 at equator (minimal seasonal variation)
 *          1.0 at poles (maximum seasonal variation)
 */
float get_seasonal_extremity(float latitude) {
	return mix(0.3, 1.0, latitude);
}

/*
 * Check if position is in arctic zone (|Z| >= 6666 blocks by default)
 *
 * camera_z: Camera Z position (cameraPosition.z)
 *
 * Returns: true if in arctic zone
 */
bool is_arctic(float camera_z) {
	return abs(camera_z - LATITUDE_ORIGIN_Z) >= LATITUDE_ARCTIC_BLOCKS;
}

/*
 * Get smooth arctic intensity factor
 *
 * Returns 0.0 outside arctic, smoothly ramps to 1.0 within arctic.
 * Uses ~200 block transition zone for smooth fade-in.
 *
 * camera_z: Camera Z position (cameraPosition.z)
 *
 * Returns: Arctic intensity [0, 1]
 */
float get_arctic_factor(float camera_z) {
	float distance_from_equator = abs(camera_z - LATITUDE_ORIGIN_Z);
	// Smooth transition over ~200 blocks at arctic boundary
	return smoothstep(LATITUDE_ARCTIC_BLOCKS - 100.0, LATITUDE_ARCTIC_BLOCKS + 100.0, distance_from_equator);
}

/*
 * Check if position is in cold or arctic zone (|Z| >= 5333 blocks by default)
 *
 * camera_z: Camera Z position (cameraPosition.z)
 *
 * Returns: true if in cold or arctic zone
 */
bool is_cold_or_arctic(float camera_z) {
	float distance_from_equator = abs(camera_z - LATITUDE_ORIGIN_Z);
	return distance_from_equator >= (LATITUDE_BAND_WIDTH * 4.0); // Temperate end
}

/*
 * Get climate zone index from world position
 *
 * camera_z: Camera Z position (cameraPosition.z)
 *
 * Returns: Climate zone index (CLIMATE_TROPICAL to CLIMATE_ARCTIC)
 */
int get_climate_zone(float camera_z) {
	float lat = get_latitude(camera_z);

	if (lat < LATITUDE_TROPICAL_END)  return CLIMATE_TROPICAL;
	if (lat < LATITUDE_DESERT_END)    return CLIMATE_DESERT;
	if (lat < LATITUDE_SAVANNA_END)   return CLIMATE_SAVANNA;
	if (lat < LATITUDE_TEMPERATE_END) return CLIMATE_TEMPERATE;
	if (lat < LATITUDE_COLD_END)      return CLIMATE_COLD;
	return CLIMATE_ARCTIC;
}

#endif // INCLUDE_MISC_LATITUDE
