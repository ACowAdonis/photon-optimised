#if !defined INCLUDE_MISC_MOD_UNIFORMS_DEBUG
#define INCLUDE_MISC_MOD_UNIFORMS_DEBUG

/*
 * Mod Uniforms Debug Display
 *
 * Displays debug information for uniforms provided by modified Oculus:
 * - Serene Seasons: currentSeason, currentSubSeason, seasonProgress, yearProgress, seasonDay, daysPerSeason
 * - Cold Sweat: playerBodyTemp, worldAmbientTemp
 *
 * Enable with DEBUG_MOD_UNIFORMS in settings.glsl
 */

// Helper: Draw a single digit at position
float draw_digit(vec2 uv, int digit, vec2 pos, vec2 size) {
	vec2 local = (uv - pos) / size;
	if (local.x < 0.0 || local.x > 1.0 || local.y < 0.0 || local.y > 1.0) return 0.0;

	// Simple 3x5 pixel font for digits 0-9 and minus
	// Each digit is encoded as 15 bits (3 wide x 5 tall, bottom to top)
	const int font[12] = int[12](
		0x7B6F, // 0: 111 101 101 101 111
		0x2492, // 1: 010 010 010 010 010
		0x73E7, // 2: 111 001 111 100 111
		0x73CF, // 3: 111 001 111 001 111
		0x5BC9, // 4: 101 101 111 001 001
		0x79CF, // 5: 111 100 111 001 111
		0x79EF, // 6: 111 100 111 101 111
		0x7249, // 7: 111 001 001 001 001
		0x7BEF, // 8: 111 101 111 101 111
		0x7BCF, // 9: 111 101 111 001 111
		0x0380, // -: 000 000 111 000 000
		0x0000  // (space)
	);

	// Font encoding: row 0 = bottom, row 4 = top; within row: bit 0 = right, bit 2 = left
	// Screen coords (OpenGL): y=0 is bottom, x=0 is left
	// Only need to flip x (columns are right-to-left in font)
	int ix = 2 - int(local.x * 2.99);  // Flip x: screen left → font left (bit 2)
	int iy = int(local.y * 4.99);      // No flip: screen bottom → font bottom (row 0)
	int bit_index = iy * 3 + ix;

	int d = clamp(digit, 0, 11);
	return float((font[d] >> bit_index) & 1);
}

// Helper: Draw a number (integer) at position
float draw_int(vec2 uv, int value, vec2 pos, vec2 char_size, int max_digits) {
	float result = 0.0;
	bool negative = value < 0;
	int v = abs(value);

	for (int i = 0; i < max_digits; i++) {
		int digit = (v / int(pow(10.0, float(max_digits - 1 - i)))) % 10;

		// Skip leading zeros except for last digit
		if (i == 0 && negative) {
			result += draw_digit(uv, 10, pos + vec2(float(i) * char_size.x * 1.3, 0.0), char_size); // minus sign
		} else {
			result += draw_digit(uv, digit, pos + vec2(float(i) * char_size.x * 1.3, 0.0), char_size);
		}
	}
	return clamp(result, 0.0, 1.0);
}

// Helper: Draw a float (00.00 format) at position
float draw_float(vec2 uv, float value, vec2 pos, vec2 char_size) {
	float result = 0.0;
	bool negative = value < 0.0;
	float v = abs(value);

	// Integer part (2 digits for values up to 99)
	int int_part = int(v);
	int tens = (int_part / 10) % 10;
	int ones = int_part % 10;
	result += draw_digit(uv, tens, pos, char_size);
	result += draw_digit(uv, ones, pos + vec2(char_size.x * 1.3, 0.0), char_size);

	// Decimal point (simple dot at baseline - bottom of character in OpenGL coords)
	vec2 dot_pos = pos + vec2(char_size.x * 2.6, 0.0);
	vec2 dot_local = (uv - dot_pos) / char_size;
	if (dot_local.x > 0.3 && dot_local.x < 0.7 && dot_local.y > 0.0 && dot_local.y < 0.25) {
		result += 1.0;
	}

	// Decimal part (2 digits)
	int dec_part = int(fract(v) * 100.0);
	for (int i = 0; i < 2; i++) {
		int digit = (dec_part / int(pow(10.0, float(1 - i)))) % 10;
		result += draw_digit(uv, digit, pos + vec2(float(i) * char_size.x * 1.3 + char_size.x * 3.0, 0.0), char_size);
	}

	return clamp(result, 0.0, 1.0);
}

// Helper: Draw a simple label bar
float draw_bar(vec2 uv, float value, vec2 pos, vec2 size) {
	vec2 local = (uv - pos) / size;
	if (local.x < 0.0 || local.x > 1.0 || local.y < 0.0 || local.y > 1.0) return 0.0;

	// Border
	if (local.x < 0.02 || local.x > 0.98 || local.y < 0.1 || local.y > 0.9) return 0.5;

	// Fill based on value
	if (local.x < value * 0.96 + 0.02) return 0.8;

	return 0.1;
}

/*
 * Main debug overlay function
 *
 * Call this at the end of your fragment shader to overlay debug info.
 * Returns color with debug overlay applied.
 */
vec3 apply_mod_uniforms_debug(
	vec3 color,
	vec2 uv,
	int current_season,
	int current_sub_season,
	float season_progress,
	float year_progress,
	int season_day,
	int days_per_season,
	float player_body_temp,
	float world_ambient_temp
) {
	// Debug panel position and sizing (top-left corner)
	vec2 panel_start = vec2(0.02, 0.02);
	vec2 char_size = vec2(0.008, 0.016);
	float line_height = 0.025;
	float bar_width = 0.15;

	vec3 text_color = vec3(1.0, 1.0, 1.0);
	vec3 bg_color = vec3(0.0, 0.0, 0.0);

	// Background panel
	vec2 panel_size = vec2(0.28, 0.38);
	vec2 panel_local = (uv - panel_start + vec2(0.01, -0.005)) / panel_size;
	if (panel_local.x > 0.0 && panel_local.x < 1.0 && panel_local.y > 0.0 && panel_local.y < 1.0) {
		color = mix(color, bg_color, 0.75);
	}

	float text = 0.0;
	int line = 0;

	// === SERENE SEASONS SECTION ===

	// Line 0: currentSeason (0-3)
	vec2 pos = panel_start + vec2(0.0, float(line) * line_height);
	text += draw_int(uv, current_season, pos, char_size, 1);
	// Season name indicator (colored box)
	vec2 box_pos = pos + vec2(0.025, 0.0);
	vec2 box_local = (uv - box_pos) / vec2(0.04, char_size.y);
	if (box_local.x > 0.0 && box_local.x < 1.0 && box_local.y > 0.0 && box_local.y < 1.0) {
		vec3 season_colors[4] = vec3[4](
			vec3(0.4, 0.9, 0.4),  // Spring - green
			vec3(0.9, 0.8, 0.2),  // Summer - yellow
			vec3(0.9, 0.5, 0.2),  // Autumn - orange
			vec3(0.6, 0.8, 1.0)   // Winter - light blue
		);
		color = season_colors[clamp(current_season, 0, 3)];
	}
	line++;

	// Line 1: currentSubSeason (0-11)
	pos = panel_start + vec2(0.0, float(line) * line_height);
	text += draw_int(uv, current_sub_season, pos, char_size, 2);
	line++;

	// Line 2: seasonProgress (0.0-1.0) with bar
	pos = panel_start + vec2(0.0, float(line) * line_height);
	text += draw_float(uv, season_progress, pos, char_size);
	text += draw_bar(uv, season_progress, pos + vec2(0.08, 0.0), vec2(bar_width, char_size.y));
	line++;

	// Line 3: yearProgress (0.0-1.0) with bar - THE KEY UNIFORM
	pos = panel_start + vec2(0.0, float(line) * line_height);
	text += draw_float(uv, year_progress, pos, char_size);
	text += draw_bar(uv, year_progress, pos + vec2(0.08, 0.0), vec2(bar_width, char_size.y));
	// Highlight this one as important
	vec2 highlight_local = (uv - pos + vec2(0.005, 0.003)) / vec2(0.24, line_height);
	if (highlight_local.x > 0.0 && highlight_local.x < 1.0 && highlight_local.y > 0.0 && highlight_local.y < 1.0) {
		color = mix(color, vec3(0.2, 0.4, 0.2), 0.3);
	}
	line++;

	// Line 4: seasonDay
	pos = panel_start + vec2(0.0, float(line) * line_height);
	text += draw_int(uv, season_day, pos, char_size, 2);
	line++;

	// Line 5: daysPerSeason
	pos = panel_start + vec2(0.0, float(line) * line_height);
	text += draw_int(uv, days_per_season, pos, char_size, 3);
	line++;

	// Spacer
	line++;

	// === COLD SWEAT SECTION ===

	// Line 7: playerBodyTemp
	pos = panel_start + vec2(0.0, float(line) * line_height);
	// Handle negative temps
	float display_temp = clamp(player_body_temp, -99.0, 99.0);
	text += draw_float(uv, abs(display_temp), pos + vec2(display_temp < 0.0 ? 0.015 : 0.0, 0.0), char_size);
	if (display_temp < 0.0) {
		text += draw_digit(uv, 10, pos, char_size); // minus sign
	}
	// Temperature color indicator
	vec2 temp_box_pos = pos + vec2(0.08, 0.0);
	vec2 temp_box_local = (uv - temp_box_pos) / vec2(0.03, char_size.y);
	if (temp_box_local.x > 0.0 && temp_box_local.x < 1.0 && temp_box_local.y > 0.0 && temp_box_local.y < 1.0) {
		// Blue (cold) to red (hot) gradient based on temp
		float temp_normalized = clamp(player_body_temp * 0.1 + 0.5, 0.0, 1.0);
		color = mix(vec3(0.3, 0.5, 1.0), vec3(1.0, 0.3, 0.2), temp_normalized);
	}
	line++;

	// Line 8: worldAmbientTemp
	pos = panel_start + vec2(0.0, float(line) * line_height);
	display_temp = clamp(world_ambient_temp, -99.0, 99.0);
	text += draw_float(uv, abs(display_temp), pos + vec2(display_temp < 0.0 ? 0.015 : 0.0, 0.0), char_size);
	if (display_temp < 0.0) {
		text += draw_digit(uv, 10, pos, char_size);
	}
	// World temperature color indicator
	temp_box_pos = pos + vec2(0.08, 0.0);
	temp_box_local = (uv - temp_box_pos) / vec2(0.03, char_size.y);
	if (temp_box_local.x > 0.0 && temp_box_local.x < 1.0 && temp_box_local.y > 0.0 && temp_box_local.y < 1.0) {
		float temp_normalized = clamp(world_ambient_temp * 0.05 + 0.5, 0.0, 1.0);
		color = mix(vec3(0.3, 0.5, 1.0), vec3(1.0, 0.3, 0.2), temp_normalized);
	}
	line++;

	// Spacer
	line++;

	// === COMPUTED VALUES SECTION ===

	// Line 10: seasonContinuous (yearProgress * 4)
	pos = panel_start + vec2(0.0, float(line) * line_height);
	float season_continuous = year_progress * 4.0;
	text += draw_float(uv, season_continuous, pos, char_size);
	line++;

	// Line 11: Summer factor
	pos = panel_start + vec2(0.0, float(line) * line_height);
	float summer_factor = 1.0 - abs(year_progress - 0.375) * 4.0;
	summer_factor = clamp(summer_factor, 0.0, 1.0);
	text += draw_float(uv, summer_factor, pos, char_size);
	text += draw_bar(uv, summer_factor, pos + vec2(0.08, 0.0), vec2(bar_width, char_size.y));
	line++;

	// Line 12: Winter factor
	pos = panel_start + vec2(0.0, float(line) * line_height);
	float winter_factor = 1.0 - abs(year_progress - 0.875) * 4.0;
	winter_factor = clamp(winter_factor, 0.0, 1.0);
	text += draw_float(uv, winter_factor, pos, char_size);
	text += draw_bar(uv, winter_factor, pos + vec2(0.08, 0.0), vec2(bar_width, char_size.y));
	line++;

	// Apply text
	color = mix(color, text_color, text);

	return color;
}

/*
 * Visual season tint test
 *
 * Applies a subtle color tint based on yearProgress to verify
 * the uniform is updating correctly as seasons change.
 */
vec3 apply_season_tint_test(vec3 color, float year_progress, float intensity) {
	// Create a color that cycles through the year
	// Spring (0.0-0.25): Green tint
	// Summer (0.25-0.5): Yellow/warm tint
	// Autumn (0.5-0.75): Orange/red tint
	// Winter (0.75-1.0): Blue/cool tint

	vec3 spring_color = vec3(0.5, 0.8, 0.4);
	vec3 summer_color = vec3(0.9, 0.8, 0.3);
	vec3 autumn_color = vec3(0.9, 0.5, 0.2);
	vec3 winter_color = vec3(0.5, 0.7, 0.95);

	vec3 season_tint;
	float t = year_progress * 4.0;

	if (t < 1.0) {
		season_tint = mix(spring_color, summer_color, t);
	} else if (t < 2.0) {
		season_tint = mix(summer_color, autumn_color, t - 1.0);
	} else if (t < 3.0) {
		season_tint = mix(autumn_color, winter_color, t - 2.0);
	} else {
		season_tint = mix(winter_color, spring_color, t - 3.0);
	}

	return mix(color, color * season_tint, intensity);
}

#endif // INCLUDE_MISC_MOD_UNIFORMS_DEBUG
