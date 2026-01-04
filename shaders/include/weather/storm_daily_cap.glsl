#if !defined INCLUDE_WEATHER_STORM_DAILY_CAP
#define INCLUDE_WEATHER_STORM_DAILY_CAP

/*
 * Daily Storm Intensity Cap System
 *
 * Provides variance between rain events based on:
 * - Day of the season (pseudo-random daily variance)
 * - Latitude (tropical monsoons, polar blizzards)
 * - Season (summer thunderstorms, winter blizzards)
 *
 * Each day has a "weather personality" that determines the MAXIMUM storm intensity
 * if a rain event occurs. This creates variety - not every rain becomes a full storm.
 *
 * Returns: Storm cap [0.1, 1.0]
 *   0.1-0.25 = Light shower / flurries only
 *   0.25-0.5 = Moderate rain/snow possible
 *   0.5-0.75 = Heavy precipitation possible
 *   0.75-1.0 = Full storm/blizzard potential
 */

#include "/include/misc/latitude.glsl"
#include "/include/lighting/colors/seasonal_lighting.glsl"

// Hash function for pseudo-random daily variance
float storm_daily_hash(float seed) {
	return fract(sin(seed * 12.9898 + 78.233) * 43758.5453);
}

/*
 * Calculate the daily storm intensity cap
 *
 * latitude: Normalized latitude [0, 1] from get_latitude()
 * year_progress: yearProgress uniform [0, 1]
 * world_day: worldDay uniform (Minecraft day counter)
 * is_snow: true if precipitation is snow (biome_may_snow > 0.5)
 *
 * Returns: Storm intensity cap [0.1, 1.0]
 */
float get_storm_daily_cap(float latitude, float year_progress, int world_day, bool is_snow) {
	// Calculate day within current season (approximately 0-30)
	// yearProgress goes 0-1 over the year, so each season is 0.25
	float season_progress = fract(year_progress * 4.0);
	int season_index = int(floor(year_progress * 4.0)); // 0=spring, 1=summer, 2=fall, 3=winter
	int day_of_season = int(season_progress * 30.0);

	// Get latitude band (0-5 for the 6 climate zones)
	int latitude_band = int(floor(latitude * 6.0));

	// Create a unique seed for this day/season/latitude combination
	// The seed should be stable within a day but vary between days
	float seed = float(day_of_season)
	           + float(season_index) * 37.0
	           + float(latitude_band) * 157.0
	           + float(world_day % 97) * 7.0;

	// Get base random roll for this day [0, 1]
	float daily_roll = storm_daily_hash(seed);

	// Calculate seasonal bias
	float summer_factor = max(0.0, 1.0 - abs(float(season_index) - 1.0)); // Peak at summer (season 1)
	float winter_factor = max(0.0, 1.0 - abs(float(season_index) - 3.0) * 0.5); // Peak at winter (season 3)

	// Biases reduced to make heavy storms/fog rarer
	// Heavy fog (cap > 0.6) should be uncommon, whiteouts (cap > 0.8) should be rare
	float seasonal_bias = 0.0;
	if (is_snow) {
		// Snow: winter at high latitudes favors intense blizzards (reduced)
		float high_lat = get_high_latitude_factor(latitude);
		seasonal_bias = winter_factor * high_lat * 0.25; // Up to +0.25 for polar winter
	} else {
		// Rain: summer in temperate/tropical favors thunderstorms (reduced)
		float temperate = get_temperate_factor(latitude);
		float tropical = get_tropical_factor(latitude);
		float savanna = get_savanna_factor(latitude);

		// Tropical monsoon season (around equinoxes - spring/fall)
		float monsoon = (season_index == 0 || season_index == 2) ? 0.15 : 0.0;

		seasonal_bias = summer_factor * temperate * 0.2   // Summer thunderstorms
		              + tropical * (0.1 + monsoon)        // Tropical storms + monsoons
		              + savanna * summer_factor * 0.15;   // Savanna wet season
	}

	// Calculate latitude bias (independent of season) - reduced
	// Note: Tropical latitude bias removed - tropical humidity already affects fog through fog.glsl
	float latitude_bias = 0.0;
	if (is_snow) {
		// Polar regions: inherently more intense snow
		float polar = get_polar_factor(latitude);
		float cold = get_cold_factor(latitude);
		latitude_bias = polar * 0.15 + cold * 0.1;
	}
	// Rain: no latitude bias (tropical removed to prevent excessive fog)

	// Combine: base roll scaled + biases
	// Base roll reduced from 0.6 to 0.35 - heavy storms now require good roll + biases
	// Most days will be light-moderate (cap 0.1-0.4), heavy fog is uncommon
	float storm_cap = daily_roll * 0.35 + 0.1 + seasonal_bias + latitude_bias;

	// Clamp to valid range [0.1, 1.0]
	// Minimum 0.1 ensures even the lightest rain has some effect
	return clamp(storm_cap, 0.1, 1.0);
}

#endif // INCLUDE_WEATHER_STORM_DAILY_CAP
