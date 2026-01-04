#if !defined INCLUDE_MISC_HEATSTROKE
#define INCLUDE_MISC_HEATSTROKE

/*
 * Heatstroke Visual Effects
 *
 * Simulates the disorienting visual effects of overheating/heatstroke.
 * Integrates with Cold Sweat's player body temperature system.
 *
 * Effects:
 * - Blur/distortion: Wobbly, unfocused vision
 * - Pulse throbbing: Periodic brightness waves simulating heartbeat
 * - Danger vignette: Darkening edges as consciousness fades
 *
 * Cold Sweat playerBodyTemp scale (-100 to 100):
 * - 0: Neutral/comfortable temperature
 * - 35: Effects begin (player getting warm)
 * - 100: Maximum effects (near heat damage threshold)
 */

// Temperature thresholds for heatstroke effects (Cold Sweat internal units)
#define HEATSTROKE_TEMP_START 35.0   // Effects begin (early warning)
#define HEATSTROKE_TEMP_MAX 100.0    // Maximum effect intensity

/*
 * Calculate heatstroke intensity from player body temperature
 *
 * player_temp: Cold Sweat playerBodyTemp value
 *
 * Returns: Effect intensity [0, 1]
 */
float get_heatstroke_intensity(float player_temp) {
	return smoothstep(HEATSTROKE_TEMP_START, HEATSTROKE_TEMP_MAX, player_temp);
}

/*
 * Apply heatstroke blur/distortion effect
 *
 * Creates impaired vision through:
 * - Gentle overall wobble (dizziness)
 * - Radial blur increasing toward edges (losing peripheral focus)
 * - Slight desaturation (fading vision)
 *
 * color_sampler: Scene color texture
 * uv: Screen UV coordinates
 * intensity: Effect intensity [0, 1]
 * time: Animation time (frameTimeCounter)
 *
 * Returns: Blurred/distorted color
 */
vec3 apply_heatstroke_blur(sampler2D color_sampler, vec2 uv, float intensity, float time) {
	if (intensity < 0.001) return texture(color_sampler, uv).rgb;

	// Gentle, slow wobble for dizziness (slower frequencies, less harsh)
	float wobble_slow = sin(time * 0.8) * cos(time * 0.5);
	float wobble_med = sin(time * 1.3 + uv.y * 3.0) * cos(time * 1.1 + uv.x * 2.5);

	// Very subtle UV offset - just enough to feel "off"
	vec2 wobble_offset = vec2(wobble_slow + wobble_med * 0.3, wobble_med + wobble_slow * 0.3);
	wobble_offset *= intensity * HEATSTROKE_BLUR_STRENGTH * 0.004;

	// Radial blur: blur increases toward screen edges (tunnel vision / peripheral blur)
	vec2 center = vec2(0.5);
	vec2 to_center = center - uv;
	float dist_from_center = length(to_center);

	// Blur strength increases with distance from center
	float radial_blur_strength = dist_from_center * intensity * HEATSTROKE_BLUR_STRENGTH * 0.015;

	// Direction for radial blur (toward center)
	vec2 blur_dir = normalize(to_center + 0.0001); // avoid div by zero

	// Sample along radial direction with smooth weighting
	vec3 color = vec3(0.0);
	float total_weight = 0.0;

	// Gaussian-ish weights for smooth blur
	const int samples = 5;
	float weights[5] = float[](0.227, 0.194, 0.121, 0.054, 0.016);

	for (int i = 0; i < samples; i++) {
		float offset_dist = float(i) * radial_blur_strength * 0.4;
		vec2 sample_offset = blur_dir * offset_dist + wobble_offset;

		// Sample both directions along the radial line
		color += texture(color_sampler, uv + sample_offset).rgb * weights[i];
		if (i > 0) {
			color += texture(color_sampler, uv - sample_offset).rgb * weights[i];
			total_weight += weights[i];
		}
		total_weight += weights[i];
	}

	color /= total_weight;

	// Subtle desaturation as vision fades
	float desat_amount = intensity * 0.25 * HEATSTROKE_BLUR_STRENGTH;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luminance), desat_amount);

	return color;
}

/*
 * Apply pulse throbbing effect
 *
 * Creates periodic brightness waves simulating elevated heartbeat.
 * Pulse rate increases with temperature (faster heart rate when hot).
 *
 * color: Input color
 * intensity: Effect intensity [0, 1]
 * time: Animation time (frameTimeCounter)
 *
 * Returns: Color with pulse effect applied
 */
vec3 apply_heatstroke_pulse(vec3 color, float intensity, float time) {
	if (intensity < 0.001) return color;

	// Pulse rate increases with intensity (45-90 BPM equivalent)
	// Slower, more ominous feeling - like a heavy, labored heartbeat
	// At low intensity: ~0.75 Hz (45 BPM)
	// At high intensity: ~1.5 Hz (90 BPM)
	float pulse_rate = mix(0.75, 1.5, intensity);

	// Create heartbeat-like rhythm: quick double-beat then pause
	float beat_phase = fract(time * pulse_rate);

	// First beat
	float beat1 = smoothstep(0.0, 0.05, beat_phase) * smoothstep(0.15, 0.05, beat_phase);
	// Second beat (slightly weaker, after short delay)
	float beat2 = smoothstep(0.18, 0.23, beat_phase) * smoothstep(0.33, 0.23, beat_phase) * 0.6;

	float heartbeat = beat1 + beat2;

	// Apply subtle brightness pulse
	// At max intensity, brightness varies by ~10%
	float pulse_strength = heartbeat * intensity * HEATSTROKE_PULSE_STRENGTH * 0.1;

	// Slight reddish tint during pulse (blood rushing)
	vec3 pulse_tint = vec3(1.0 + pulse_strength * 0.5, 1.0, 1.0 - pulse_strength * 0.2);

	return color * (1.0 + pulse_strength) * pulse_tint;
}

/*
 * Apply danger vignette effect
 *
 * Darkens the edges of the screen to simulate tunnel vision / losing consciousness.
 * The effect intensifies and pulses as temperature approaches maximum.
 *
 * color: Input color
 * uv: Screen UV coordinates
 * intensity: Effect intensity [0, 1]
 * time: Animation time (frameTimeCounter)
 *
 * Returns: Color with vignette applied
 */
vec3 apply_heatstroke_vignette(vec3 color, vec2 uv, float intensity, float time) {
	if (intensity < 0.001) return color;

	// Distance from screen center
	vec2 centered = uv - 0.5;
	float dist = length(centered);

	// Base vignette - starts subtle, becomes very strong at max intensity
	// At intensity 0.5: gentle darkening at edges
	// At intensity 1.0: severe tunnel vision
	float vignette_start = mix(0.8, 0.3, intensity);  // Where darkening begins
	float vignette_end = mix(1.2, 0.6, intensity);    // Where it reaches full dark

	float vignette = smoothstep(vignette_start, vignette_end, dist);

	// Add pulsing to the vignette at high intensity (vision fading in and out)
	float pulse_intensity = smoothstep(0.5, 1.0, intensity); // Only pulse at higher temps
	float vignette_pulse = sin(time * 1.5) * 0.15 * pulse_intensity;
	vignette = clamp(vignette + vignette_pulse, 0.0, 1.0);

	// Vignette color: dark with slight red tint (blood pressure)
	vec3 vignette_color = vec3(0.05, 0.0, 0.0);

	// Apply vignette with strength based on settings
	// Capped at 50% max darkness to keep some visibility even at extreme temps
	float vignette_strength = vignette * intensity * HEATSTROKE_VIGNETTE_STRENGTH * 0.5;

	return mix(color, vignette_color, vignette_strength);
}

/*
 * Apply all heatstroke effects
 *
 * Combines blur, pulse, and vignette effects based on player temperature.
 * Uses the already-processed fragment_color for pulse/vignette, and only
 * samples from texture when blur distortion is needed.
 *
 * fragment_color: Already-processed scene color (from CAS, etc.)
 * color_sampler: Scene color texture (for blur sampling at offset UVs)
 * uv: Screen UV coordinates
 * player_temp: Cold Sweat playerBodyTemp value
 * time: Animation time (frameTimeCounter)
 *
 * Returns: Final color with all heatstroke effects applied
 */
vec3 apply_heatstroke_effects(vec3 fragment_color, sampler2D color_sampler, vec2 uv, float player_temp, float time) {
	// Early exit if below threshold
	if (player_temp < HEATSTROKE_TEMP_START) {
		return fragment_color;
	}

	// Linear scale for pulse/vignette (simpler, more predictable)
	// temp 35 → 0, temp 100 → 1
	float linear_intensity = (player_temp - HEATSTROKE_TEMP_START) / (HEATSTROKE_TEMP_MAX - HEATSTROKE_TEMP_START);
	linear_intensity = clamp(linear_intensity, 0.0, 1.0);

	// Smoothstep intensity for blur (keeps the gradual onset around temp 50)
	float blur_intensity = get_heatstroke_intensity(player_temp);

	vec3 color;

	// Apply blur if intensity is significant (requires texture sampling)
	// Blur only kicks in noticeably around temp 50+ (blur_intensity ~0.1+)
	if (blur_intensity > 0.1) {
		vec3 blurred = apply_heatstroke_blur(color_sampler, uv, blur_intensity, time);
		// Mix: at low intensity, favor processed color; at high intensity, use blurred
		float blur_blend = smoothstep(0.1, 0.5, blur_intensity);
		color = mix(fragment_color, blurred, blur_blend);
	} else {
		color = fragment_color;
	}

	// Apply pulse and vignette with linear intensity for predictable early warning
	color = apply_heatstroke_pulse(color, linear_intensity, time);
	color = apply_heatstroke_vignette(color, uv, linear_intensity, time);

	return color;
}

#endif // INCLUDE_MISC_HEATSTROKE
