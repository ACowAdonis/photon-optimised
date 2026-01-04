#if !defined INCLUDE_MISC_HYPOTHERMIA
#define INCLUDE_MISC_HYPOTHERMIA

/*
 * Hypothermia Visual Effects
 *
 * Simulates the visual effects of freezing/hypothermia.
 * Integrates with Cold Sweat's player body temperature system.
 *
 * Effects:
 * - Screen shake: Shivering tremors that increase with cold
 * - Blue vignette: Constant frost tint creeping from screen edges (additive, no darkening)
 * - Frost texture: Custom ice overlay fading in from edges (image/frost_overlay.png)
 * - Chromatic aberration: Color separation at edges like light through ice
 *
 * Frost Texture Requirements (image/frost_overlay.png):
 * - RGBA PNG, recommended 512x512 or 1024x1024
 * - RGB = frost color (white/pale blue ice crystals)
 * - Alpha = opacity (where frost appears - concentrate toward edges/corners)
 * - Design for screen-space overlay, not tiling
 *
 * Cold Sweat playerBodyTemp scale (-100 to 100):
 * - 0: Neutral/comfortable temperature
 * - -35: Effects begin (player getting cold)
 * - -100: Maximum effects (near cold damage threshold)
 */

// Temperature thresholds for hypothermia effects (Cold Sweat internal units)
#define HYPOTHERMIA_TEMP_START -35.0   // Effects begin (early warning)
#define HYPOTHERMIA_TEMP_MAX -100.0    // Maximum effect intensity

/*
 * Calculate hypothermia intensity from player body temperature
 *
 * player_temp: Cold Sweat playerBodyTemp value
 *
 * Returns: Effect intensity [0, 1]
 */
float get_hypothermia_intensity(float player_temp) {
	// Note: we're going from -35 down to -100, so use inverted smoothstep
	return smoothstep(HYPOTHERMIA_TEMP_START, HYPOTHERMIA_TEMP_MAX, player_temp);
}

/*
 * Apply shivering screen shake effect
 *
 * Simulates involuntary muscle tremors from cold.
 * Quick, jittery movements that increase with intensity.
 *
 * uv: Screen UV coordinates
 * intensity: Effect intensity [0, 1]
 * time: Animation time (frameTimeCounter)
 *
 * Returns: Offset UV coordinates
 */
vec2 apply_hypothermia_shake(vec2 uv, float intensity, float time) {
	if (intensity < 0.001) return uv;

	// Shivering: fast, erratic, jittery - NOT smooth wobble
	// Use very high frequencies with sharp transitions
	float base_speed = 40.0 + intensity * 20.0;

	// Multiple high frequencies create irregular jitter
	// Using floor/fract to create sharp, discontinuous motion
	float jitter_phase = time * base_speed;
	float sharp_x = fract(sin(floor(jitter_phase) * 127.1) * 43758.5453) - 0.5;
	float sharp_y = fract(sin(floor(jitter_phase * 1.3) * 311.7) * 43758.5453) - 0.5;

	// Blend with some smooth component for slight continuity
	float smooth_x = sin(time * base_speed * 0.7) * 0.3 + sin(time * base_speed * 1.1) * 0.2;
	float smooth_y = cos(time * base_speed * 0.9) * 0.25 + cos(time * base_speed * 1.3) * 0.2;

	// Mix sharp jitter with smooth - more sharp at high intensity
	float sharp_blend = 0.4 + intensity * 0.4;
	float shake_x = mix(smooth_x, sharp_x, sharp_blend);
	float shake_y = mix(smooth_y, sharp_y, sharp_blend);

	// Occasional violent tremor bursts
	float tremor_phase = fract(time * 0.6);
	float tremor = smoothstep(0.0, 0.03, tremor_phase) * smoothstep(0.12, 0.03, tremor_phase);
	tremor *= 2.5;

	vec2 shake = vec2(shake_x, shake_y) * (1.0 + tremor);

	// Add position-dependent variation so edges shake more than center
	// This prevents the "sliding" look of uniform offset
	vec2 centered = uv - 0.5;
	float edge_factor = length(centered) * 2.0; // 0 at center, ~1 at edges
	edge_factor = 0.6 + edge_factor * 0.8; // Range: 0.6 at center to 1.4 at edges

	// Scale: keep amplitude modest but motion sharp
	shake *= intensity * intensity * HYPOTHERMIA_SHAKE_STRENGTH * 0.0025 * edge_factor;

	return uv + shake;
}

/*
 * Apply frost vignette effect
 *
 * Creates a light blue-white frost tint creeping from screen edges.
 * This is purely additive - it should NOT darken the screen.
 * Cold is relentless - no pulsing.
 *
 * color: Input color
 * uv: Screen UV coordinates
 * intensity: Effect intensity [0, 1]
 * time: Animation time (unused, kept for consistency)
 *
 * Returns: Color with frost vignette applied
 */
vec3 apply_hypothermia_vignette(vec3 color, vec2 uv, float intensity, float time) {
	if (intensity < 0.001) return color;

	// Distance from screen center
	vec2 centered = uv - 0.5;
	float dist = length(centered);

	// Vignette creeps in from edges as cold increases
	float vignette_start = mix(0.5, 0.15, intensity);
	float vignette_end = mix(0.8, 0.45, intensity);

	float vignette = smoothstep(vignette_start, vignette_end, dist);

	// Calculate effect strength - more visible than before
	float effect_strength = vignette * intensity * HYPOTHERMIA_VIGNETTE_STRENGTH;

	// Frost tint: pale blue added on top (purely additive, no darkening)
	// Stronger values so the effect is actually visible
	vec3 frost_add = vec3(0.08, 0.12, 0.20) * effect_strength;

	// Add the blue tint
	vec3 result = color + frost_add;

	// Subtle desaturation toward edges at high intensity
	float luminance = dot(result, vec3(0.299, 0.587, 0.114));
	result = mix(result, vec3(luminance) + frost_add * 0.5, effect_strength * 0.3);

	return result;
}

/*
 * Apply frost/ice effect using texture overlay and chromatic aberration
 *
 * Simulates looking through ice at screen edges:
 * - Frost texture overlay fading in from edges
 * - Chromatic aberration (color separation) like light refracting through ice
 *
 * color: Input color
 * color_sampler: Scene texture for offset sampling
 * frost_sampler: Frost overlay texture (RGBA, alpha = opacity)
 * uv: Screen UV coordinates
 * intensity: Effect intensity [0, 1]
 * time: Animation time (unused, kept for API consistency)
 *
 * Returns: Color with frost effect applied
 */
vec3 apply_hypothermia_frost(vec3 color, sampler2D color_sampler, sampler2D frost_sampler, vec2 uv, float intensity, float time) {
	if (intensity < 0.2) return color; // Frost only at moderate+ cold

	// Frost forms from edges inward
	vec2 centered = uv - 0.5;
	float dist_from_center = length(centered);

	// Edge factor - frost starts at edges
	float edge_start = mix(0.5, 0.25, intensity);
	float edge_end = mix(0.75, 0.5, intensity);
	float frost_factor = smoothstep(edge_start, edge_end, dist_from_center);

	if (frost_factor < 0.01) return color;

	// Direction from center (for radial chromatic aberration)
	vec2 radial_dir = normalize(centered + 0.0001);

	// Chromatic aberration - color channels separate like light through ice prism
	float aberration_strength = frost_factor * intensity * HYPOTHERMIA_FROST_STRENGTH * 0.008;

	// Sample RGB channels at slightly different positions
	vec2 r_offset = radial_dir * aberration_strength * 1.0;
	vec2 g_offset = radial_dir * aberration_strength * 0.5;
	vec2 b_offset = radial_dir * aberration_strength * 0.0;

	float r = display_eotf(texture(color_sampler, uv + r_offset).rgb).r;
	float g = display_eotf(texture(color_sampler, uv + g_offset).rgb).g;
	float b = display_eotf(texture(color_sampler, uv + b_offset).rgb).b;

	vec3 aberrated = vec3(r, g, b);

	// Blend aberration with original based on frost factor
	vec3 result = mix(color, aberrated, frost_factor * 0.7);

	// === Dynamic frost effects ===

	// Slow UV crawl - frost "creeping" inward imperceptibly
	// Direction is toward center, speed increases slightly with intensity
	vec2 crawl_dir = -normalize(centered + 0.0001); // toward center
	float crawl_speed = 0.003 * intensity; // very slow
	vec2 frost_uv = uv + crawl_dir * sin(time * 0.15) * crawl_speed;

	// Sample frost texture overlay with slight blur to reduce pixelation
	// Multi-sample blur: sample at center plus 4 offset positions
	vec2 texel_size = 1.0 / vec2(textureSize(frost_sampler, 0));
	float blur_radius = 1.5; // Texels to blur

	vec4 frost_tex = texture(frost_sampler, frost_uv) * 0.4;
	frost_tex += texture(frost_sampler, frost_uv + vec2(blur_radius, 0.0) * texel_size) * 0.15;
	frost_tex += texture(frost_sampler, frost_uv + vec2(-blur_radius, 0.0) * texel_size) * 0.15;
	frost_tex += texture(frost_sampler, frost_uv + vec2(0.0, blur_radius) * texel_size) * 0.15;
	frost_tex += texture(frost_sampler, frost_uv + vec2(0.0, -blur_radius) * texel_size) * 0.15;

	// Noise-based opacity variation - simulates light catching frost differently
	// Creates subtle "breathing" shimmer without obvious animation
	float noise_time = time * 0.4; // slow variation
	float opacity_noise = sin(uv.x * 23.0 + noise_time) * sin(uv.y * 17.0 - noise_time * 0.7);
	opacity_noise = opacity_noise * 0.15 + 1.0; // range: 0.85 to 1.15

	// Frost texture alpha controls where frost appears
	// Multiply by frost_factor so it only shows at edges, and by intensity
	// Additional 0.6 multiplier for base transparency reduction
	float frost_opacity = frost_tex.a * frost_factor * intensity * HYPOTHERMIA_FROST_STRENGTH * 0.6;
	frost_opacity *= opacity_noise; // apply subtle variation

	// Tint the frost toward pale blue instead of pure white
	vec3 frost_tint = vec3(0.75, 0.85, 1.0); // Pale blue tint
	vec3 tinted_frost = frost_tex.rgb * frost_tint;

	// Day/night compensation: reduce frost brightness in bright scenes
	// so it doesn't overwhelm during daytime but stays visible at night
	float scene_luminance = dot(result, vec3(0.299, 0.587, 0.114));
	float brightness_compensation = mix(1.0, 0.5, smoothstep(0.1, 0.6, scene_luminance));

	// Subtle refraction - scene behind frost is slightly distorted
	// Only where frost is visible, scaled by frost opacity
	float refract_strength = frost_opacity * 0.008;
	vec2 refract_offset = vec2(
		sin(uv.y * 40.0 + time * 0.3) * refract_strength,
		cos(uv.x * 35.0 - time * 0.25) * refract_strength
	);

	// Re-sample scene with refraction offset where frost is thick
	if (refract_strength > 0.0005) {
		vec3 refracted = display_eotf(texture(color_sampler, uv + refract_offset).rgb);
		result = mix(result, refracted, frost_opacity * 0.4);
	}

	// Blend frost texture color (additive blend to brighten, not darken)
	result += tinted_frost * frost_opacity * brightness_compensation;

	return result;
}

/*
 * Apply all hypothermia effects
 *
 * Combines shake, vignette, and frost effects based on player temperature.
 *
 * fragment_color: Already-processed scene color (from CAS, etc.)
 * color_sampler: Scene color texture (for shake/frost offset sampling)
 * frost_sampler: Frost overlay texture
 * uv: Screen UV coordinates
 * player_temp: Cold Sweat playerBodyTemp value
 * time: Animation time (frameTimeCounter)
 *
 * Returns: Final color with all hypothermia effects applied
 */
vec3 apply_hypothermia_effects(vec3 fragment_color, sampler2D color_sampler, sampler2D frost_sampler, vec2 uv, float player_temp, float time) {
	// Early exit if above threshold (not cold enough)
	if (player_temp > HYPOTHERMIA_TEMP_START) {
		return fragment_color;
	}

	// Linear scale from -35 to -100
	// temp -35 → 0, temp -100 → 1
	float linear_intensity = (HYPOTHERMIA_TEMP_START - player_temp) / (HYPOTHERMIA_TEMP_START - HYPOTHERMIA_TEMP_MAX);
	linear_intensity = clamp(linear_intensity, 0.0, 1.0);

	vec3 color;

	// Apply screen shake (shivering) - requires resampling at offset UV
	if (linear_intensity > 0.1) {
		vec2 shaken_uv = apply_hypothermia_shake(uv, linear_intensity, time);
		// Sample from texture at shaken position, apply display_eotf to match color space
		color = display_eotf(texture(color_sampler, shaken_uv).rgb);
	} else {
		color = fragment_color;
	}

	// Apply frost vignette (light blue tint from edges)
	color = apply_hypothermia_vignette(color, uv, linear_intensity, time);

	// Apply frost effect (texture overlay + chromatic aberration at edges)
	color = apply_hypothermia_frost(color, color_sampler, frost_sampler, uv, linear_intensity, time);

	return color;
}

#endif // INCLUDE_MISC_HYPOTHERMIA
