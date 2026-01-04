#if !defined INCLUDE_MISC_HEAT_HAZE
#define INCLUDE_MISC_HEAT_HAZE

/*
 * Heat Haze Effect
 *
 * Simulates atmospheric distortion caused by hot air rising from heated surfaces.
 * The effect creates subtle UV displacement that mimics the shimmering appearance
 * of air above hot terrain.
 *
 * Uses Cold Sweat's worldAmbientTemp to determine when heat haze appears.
 *
 * Cold Sweat Temperature Scale:
 *   - Internal unit: MC (Minecraft Units)
 *   - Conversion: 1 MC = 25°C = 45°F
 *   - Default safe range: 0.5-1.7 MC (10-25°C / 50-77°F)
 *   - Hot biomes (desert): can reach 3-6+ MC
 *
 * Heat haze triggers above ~30°C (1.2 MC) and reaches maximum at ~40°C (1.6 MC)
 *
 * Conditions for heat haze:
 * - Hot ambient temperature (worldAmbientTemp above threshold)
 * - Daytime (effect strongest in afternoon)
 * - Not raining
 * - Player outdoors (has sky exposure)
 */

// Cold Sweat temperature thresholds (in MC units)
// 1 MC = 25°C, so:
//   30°C = 1.2 MC (heat haze begins - warm day)
//   40°C = 1.6 MC (maximum heat haze - very hot)
#define HEAT_HAZE_TEMP_START 1.2  // ~30°C - haze begins
#define HEAT_HAZE_TEMP_MAX 1.6    // ~40°C - maximum haze intensity

/*
 * Generate animated heat haze distortion offset
 *
 * Creates a shimmering effect by combining multiple noise octaves at different
 * frequencies and animation speeds. The distortion is primarily horizontal
 * since heat causes air to rise and creates horizontal visual displacement.
 *
 * uv: Screen-space UV coordinates
 * intensity: Effect strength [0, 1]
 * time: Animation time (frameTimeCounter)
 * noise_tex: Noise texture sampler
 *
 * Returns: UV offset to apply to screen sampling
 */
vec2 get_heat_haze_offset(vec2 uv, float intensity, float time, sampler2D noise_tex) {
	if (intensity < 0.001) return vec2(0.0);

	// Scale UV for noise sampling - more horizontal variation
	vec2 noise_uv = uv * vec2(80.0, 40.0);

	// Fast animation for shimmering effect
	float t = time * 2.5;

	// Two octaves of noise for natural layered shimmer
	// Different frequencies and speeds create more organic movement
	float noise1 = texture(noise_tex, noise_uv * 0.012 + vec2(t * 0.08, t * 0.02)).r;
	float noise2 = texture(noise_tex, noise_uv * 0.019 - vec2(t * 0.05, t * 0.07)).g;

	// Combine and center around 0 [-1, 1]
	float distort = (noise1 + noise2) - 1.0;

	// Primarily horizontal distortion with subtle vertical component
	// Heat shimmer appears mostly as horizontal wavering
	vec2 offset = vec2(distort, distort * 0.25);

	// Scale by intensity and global strength
	return offset * intensity * HEAT_HAZE_STRENGTH * 0.008;
}

/*
 * Calculate heat haze intensity based on world temperature
 *
 * Uses Cold Sweat's worldAmbientTemp to determine heat intensity.
 * Effect scales from 0 at HEAT_HAZE_TEMP_START to 1 at HEAT_HAZE_TEMP_MAX.
 *
 * The temperature value already accounts for time of day, weather, biome,
 * and indoor/outdoor status, so we don't need redundant checks here.
 *
 * uv: Screen UV
 * view_distance: Distance from camera to surface
 * sun_angle: Minecraft sun angle (0=sunrise, 0.25=noon, 0.5=sunset) - for sun haze only
 * world_temp: Cold Sweat worldAmbientTemp value (in MC units)
 * view_dir: Normalized view direction in world space
 * sun_dir: Normalized sun direction
 * is_nether: Whether in Nether dimension
 * time: Animation time (frameTimeCounter)
 * noise_tex: Noise texture for spatial variation
 *
 * Returns: Heat intensity [0, 1]
 */
float get_ambient_heat_intensity(
	vec2 uv,
	float view_distance,
	float sun_angle,
	float world_temp,
	vec3 view_dir,
	vec3 sun_dir,
	bool is_nether,
	float time,
	sampler2D noise_tex
) {
	// Early exit: check temperature before expensive noise samples
	// In overworld, if temperature is below threshold, skip everything
	if (!is_nether && world_temp < HEAT_HAZE_TEMP_START) {
		return 0.0;
	}

	// Height factor: effect stronger near ground (low UV.y), fading toward sky
	float height_factor = smoothstep(0.75, 0.15, uv.y);

	// Minimum distance - very close shimmer looks wrong
	float min_dist_factor = smoothstep(3.0, 10.0, view_distance);

	// Spatial noise for patchy, irregular coverage
	vec2 noise_uv = uv * vec2(20.0, 12.0);
	float drift = time * 0.12;

	// Three octaves of noise for variation and intermittent appearance
	float noise1 = texture(noise_tex, noise_uv * 0.06 + vec2(drift, time * 0.04)).r;
	float noise2 = texture(noise_tex, noise_uv * 0.11 - vec2(drift * 0.8, time * 0.06)).g;
	float noise3 = texture(noise_tex, noise_uv * 0.17 + vec2(time * 0.03, drift * 0.5)).b;

	float spatial_noise = noise1 * 0.45 + noise2 * 0.35 + noise3 * 0.2;
	float patch_factor = smoothstep(0.45, 0.58, spatial_noise);

	float intensity = 0.0;

	if (is_nether) {
		// Nether: ambient heat throughout, constant hot environment
		intensity = 0.6 * height_factor * min_dist_factor * patch_factor;
	} else {
		// Temperature-based heat factor
		// Smoothly ramp from 0 at TEMP_START to 1 at TEMP_MAX
		// Temperature already accounts for time, weather, indoor/outdoor
		float heat_factor = smoothstep(HEAT_HAZE_TEMP_START, HEAT_HAZE_TEMP_MAX, world_temp);

		// General ambient heat haze - purely temperature driven
		intensity = heat_factor * 0.5 * height_factor * min_dist_factor * patch_factor;

		// Sun haze: extra shimmer when looking toward the sun
		// This still needs daytime check since you can't look at sun at night
		float morning_ramp = smoothstep(0.08, 0.25, sun_angle);
		float evening_fade = smoothstep(0.48, 0.38, sun_angle);
		float daytime_factor = morning_ramp * evening_fade;

		if (heat_factor > 0.1 && daytime_factor > 0.1) {
			float sun_proximity = dot(view_dir, sun_dir);
			float sun_haze = smoothstep(0.5, 0.95, sun_proximity);
			sun_haze *= heat_factor * daytime_factor * 0.25;
			sun_haze *= smoothstep(0.38, 0.52, spatial_noise);
			intensity = max(intensity, sun_haze);
		}
	}

	return intensity;
}

#endif // INCLUDE_MISC_HEAT_HAZE
