#if !defined INCLUDE_SKY_STARS
#define INCLUDE_SKY_STARS

// Stars with round radial falloff
// Based on https://www.shadertoy.com/view/Md2SR3 but rewritten to avoid squarish artifacts

// Star magnitude class brightness values (adjusted for visibility)
// Reduced to 4 classes with tighter brightness range
const float star_magnitude_brightness[4] = float[4](
	1.000,  // Magnitude 1 (brightest)
	0.650,  // Magnitude 2
	0.400,  // Magnitude 3
	0.250   // Magnitude 4 (dimmest visible)
);

// Cumulative probability thresholds for each magnitude class
// Fewer dim stars for cleaner sky
const float star_magnitude_threshold[4] = float[4](
	0.04,   // Top 4% are mag 1
	0.16,   // Next 12% are mag 2
	0.50,   // Next 34% are mag 3
	1.0     // Rest (50%) are mag 4 - reduced from 65%
);

// Computes star contribution from a single cell
// galaxy_color provides regional tinting from the galaxy density map
vec3 star_from_cell(vec2 cell_id, vec2 pixel_coord, float star_threshold, float scintillation_factor, vec3 galaxy_color) {
	// Narrower temperature range for more natural star colors
	const float min_temp = 4500.0;  // Warm white-yellow (K-class)
	const float max_temp = 9500.0;  // Cool blue-white (A-class)

	vec4 noise = hash4(cell_id);

	// Check if this cell contains a star
	float star_presence = linear_step(star_threshold, 1.0, noise.x);
	if (star_presence < 0.001) return vec3(0.0);

	// Star position within cell (0.1 to 0.9 to keep away from edges)
	vec2 star_pos = cell_id + 0.1 + 0.8 * hash2(cell_id + 127.3);

	// Distance from pixel to star center
	float dist = length(pixel_coord - star_pos);

	// Determine magnitude class based on secondary noise value
	float magnitude_roll = noise.y;
	float magnitude_brightness = star_magnitude_brightness[3]; // Default to dimmest
	float magnitude_size = 0.42; // Base size for dimmest stars

	for (int i = 0; i < 4; i++) {
		if (magnitude_roll < star_magnitude_threshold[i]) {
			magnitude_brightness = star_magnitude_brightness[i];
			// Size range: magnitude 1 = 0.56, magnitude 4 = 0.42
			magnitude_size = 0.42 + 0.14 * (1.0 - float(i) / 3.0);
			break;
		}
	}

	// Radial falloff - creates round stars
	float radial = 1.0 - smoothstep(0.0, magnitude_size, dist);
	radial = radial * radial; // Sharper falloff toward edges

	// Increased base luminosity for better visibility
	float star = star_presence * magnitude_brightness * radial * STARS_INTENSITY * 7.0;

	// Star color from blackbody temperature (use separate noise to decorrelate from magnitude)
	float temp_noise = hash1(cell_id.x + cell_id.y * 317.1);
	float temp = mix(min_temp, max_temp, temp_noise);
	vec3 color = blackbody(temp);

	// Blend star color with galaxy regional color for subtle tinting
	// This gives stars in the Milky Way band a slight color influence from the nebulosity
	float galaxy_influence = 0.25; // 25% influence from galaxy color
	float galaxy_lum = dot(galaxy_color, vec3(0.33));
	if (galaxy_lum > 0.001) {
		vec3 galaxy_tint = galaxy_color / galaxy_lum; // Normalized color
		color = mix(color, color * galaxy_tint, galaxy_influence);
	}

	// Atmospheric scintillation (twinkling)
	// More pronounced near horizon where atmospheric path is longer
	float twinkle_offset = tau * noise.w;
	vec2 pos_hash = hash2(cell_id + 73.1);

	// Multi-frequency twinkling for realistic scintillation
	float twinkle = 0.0;
	twinkle += 0.5  * cos(frameTimeCounter * 2.0 + twinkle_offset);
	twinkle += 0.3  * cos(frameTimeCounter * 5.0 + pos_hash.x * tau);
	twinkle += 0.2  * cos(frameTimeCounter * 11.0 + pos_hash.y * tau);

	// Base twinkle amount modulated by atmospheric scintillation factor
	float twinkle_amount = noise.z * scintillation_factor;
	star *= 1.0 - twinkle_amount * twinkle;

	return star * color;
}

// Sample stars from a 3x3 neighborhood of cells for proper radial rendering
vec3 stable_star_field(vec2 coord, float star_threshold, float scintillation_factor, vec3 galaxy_color) {
	coord = abs(coord) + 33.3 * step(0.0, coord);
	vec2 cell = floor(coord);

	vec3 result = vec3(0.0);

	// Check 3x3 neighborhood to catch stars near cell boundaries
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor_cell = cell + vec2(float(x), float(y));
			result += star_from_cell(neighbor_cell, coord, star_threshold, scintillation_factor, galaxy_color);
		}
	}

	return result;
}

#ifdef SHOOTING_STARS
// Shooting star (meteor) effect - simple and clean
vec3 draw_shooting_star(vec3 ray_dir) {
	// Meteor timing
	const float base_duration = 0.4;
	const float meteor_interval = 25.0;  // ~2-3 per minute, like a good meteor shower night

	float meteor_slot = floor(frameTimeCounter / meteor_interval);

	// Generate random meteor properties
	vec4 meteor_props = hash4(vec2(meteor_slot, meteor_slot * 73.1));
	vec2 extra_rand = hash2(vec2(meteor_slot * 41.7, meteor_slot + 99.1));

	// Meteor "size class" (0-1) - correlates duration, head size, tail width/length
	// Larger meteors last longer and have bigger features
	float size_factor = extra_rand.x;

	// Variable duration: 0.4 to 2.4 seconds (larger = longer, up to 6x base)
	float meteor_duration = base_duration * (1.0 + size_factor * 5.0);

	float meteor_time = fract(frameTimeCounter / meteor_interval) * meteor_interval;

	// Early exit if not during meteor phase
	if (meteor_time > meteor_duration) return vec3(0.0);

	// Random start position on sky hemisphere
	float start_theta = meteor_props.x * tau;
	float start_phi = 0.35 + meteor_props.y * 0.45;  // 35-80 degrees elevation

	vec3 meteor_start = normalize(vec3(
		cos(start_theta) * cos(start_phi),
		sin(start_phi),
		sin(start_theta) * cos(start_phi)
	));

	// Meteor direction (downward with random horizontal drift)
	vec2 dir_rand = hash2(vec2(meteor_slot + 17.3, meteor_slot));
	vec3 meteor_dir = normalize(vec3(
		(dir_rand.x - 0.5) * 0.5,
		-0.8 - meteor_props.z * 0.2,
		(dir_rand.y - 0.5) * 0.5
	));

	// Variable speed: 0.4 to 0.8
	float travel_speed = 0.4 + extra_rand.y * 0.4;

	// Animation progress with smooth fade in/out
	float progress = meteor_time / meteor_duration;
	// Gradual fade in over first 25%, fade out over last 35%
	float fade_in = smoothstep(0.0, 0.25, progress);
	float fade_out = smoothstep(1.0, 0.65, progress);
	float time_fade = fade_in * fade_out;

	// Current head position
	float travel = progress * travel_speed;
	vec3 head_pos = normalize(meteor_start + meteor_dir * travel);

	// Angular distance from ray to meteor head
	float head_dist = acos(clamp(dot(ray_dir, head_pos), -1.0, 1.0));

	// Variable head size: smaller meteors have tighter heads (higher multiplier)
	// Range: 550 (large/soft) to 2400 (small/tight)
	float head_tightness = 2400.0 - size_factor * 1850.0;
	float head_glow = exp(-head_dist * head_tightness);

	// Trail: sample multiple points behind the head
	vec3 trail_color = vec3(0.0);
	const int trail_samples = 36;  // High sample count for smooth trails on large meteors

	// Variable tail length: 0.04 to 0.20 (2x range, correlated with size)
	// Base range from meteor_props.w, scaled by size_factor
	float base_trail = 0.04 + meteor_props.w * 0.08;
	float trail_length = base_trail * (0.5 + size_factor);  // 0.5x to 1.5x base

	// Trail width scale - correlated with size (smaller meteors = thinner trails)
	float width_scale = 0.5 + size_factor * 0.5;  // 0.5x to 1.0x

	// Accumulate trail with overlapping Gaussian contributions for smooth appearance
	for (int i = 1; i <= trail_samples; i++) {
		float t = float(i) / float(trail_samples);

		// Position along trail (behind head)
		vec3 trail_pos = normalize(head_pos - meteor_dir * trail_length * t);

		// Distance from ray to this trail point
		float trail_dist = acos(clamp(dot(ray_dir, trail_pos), -1.0, 1.0));

		// Trail width - wider Gaussians for better overlap, especially on large meteors
		float trail_width = (0.0018 + t * 0.0035) * width_scale;

		// Smooth falloff along trail length (cubic for gradual fade)
		float length_falloff = (1.0 - t) * (1.0 - t * t);

		// Gaussian falloff from trail center
		float radial_falloff = exp(-trail_dist * trail_dist / (trail_width * trail_width));

		float trail_brightness = length_falloff * radial_falloff;

		// Color: more white, subtle warm tint toward tail
		vec3 segment_color = mix(vec3(1.0, 1.0, 1.0), vec3(1.0, 0.85, 0.7), t * 0.6);
		trail_color += trail_brightness * segment_color;
	}

	// Normalize for sample count (base was tuned for 6 samples)
	trail_color *= 6.0 / float(trail_samples);

	// Combine head and trail
	vec3 head_color = vec3(1.0, 1.0, 1.0) * head_glow * 5.0;
	vec3 result = head_color + trail_color * 2.0;

	return result * time_fade * STARS_INTENSITY * 8.0;
}
#endif

vec3 draw_stars(vec3 ray_dir, float galaxy_luminance, vec3 galaxy_color) {
	// Star density is driven by galaxy luminance map:
	// - Bright galaxy regions = more stars (lower threshold)
	// - Dark regions = fewer stars (higher threshold)
#if defined WORLD_OVERWORLD
	float night_factor = smoothstep(-0.2, 0.05, -sun_dir.y);
	// Base density is very sparse, galaxy map dramatically increases density in bright regions
	float base_density = 0.015 * STARS_COVERAGE * night_factor;
	// Very strong boost for visible density variation
	float galaxy_density_boost = 1.0 * STARS_COVERAGE * galaxy_luminance * night_factor;
	float star_threshold = 1.0 - base_density - galaxy_density_boost;
#else
	float star_threshold = 1.0 - 0.028 * STARS_COVERAGE;
#endif

	// Atmospheric scintillation factor - stronger near horizon
	// ray_dir.y = 0 at horizon, 1 at zenith
	float elevation = abs(ray_dir.y);
	float scintillation_factor = mix(1.0, 0.2, elevation); // 100% twinkle at horizon, 20% at zenith

	// Project ray direction onto the plane
	vec2 coord  = ray_dir.xy * rcp(abs(ray_dir.z) + length(ray_dir.xy)) + 41.21 * sign(ray_dir.z);
	     coord *= 600.0;

	vec3 stars = stable_star_field(coord, star_threshold, scintillation_factor, galaxy_color);

#ifdef SHOOTING_STARS
	// Only show meteors at night (fade in as sun goes below horizon)
	#if defined WORLD_OVERWORLD
		float meteor_night_factor = smoothstep(0.0, -0.15, sun_dir.y);
		stars += draw_shooting_star(ray_dir) * meteor_night_factor;
	#else
		// Other dimensions: always show meteors (no day/night cycle)
		stars += draw_shooting_star(ray_dir);
	#endif
#endif

	// Moon phase affects star visibility:
	// Full moon (1.0) = dimmer stars (moonlight washes them out)
	// New moon (0.5) = brighter stars (darker sky)
#if defined WORLD_OVERWORLD
	float moon_star_factor = mix(1.25, 0.75, moon_phase_brightness);
	stars *= moon_star_factor;
#endif

	return stars;
}

#endif // INCLUDE_SKY_STARS
