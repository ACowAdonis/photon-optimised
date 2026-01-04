#if !defined INCLUDE_MISC_DISTANT_WATER
#define INCLUDE_MISC_DISTANT_WATER

#include "/include/lighting/specular_lighting.glsl"
#include "/include/misc/purkinje_shift.glsl"
#include "/include/surface/water_normal.glsl"

#ifdef LATITUDE_SUN_PATH
#include "/include/misc/latitude_sun.glsl"
#endif

vec4 draw_distant_water(
	vec3 position_screen,
	vec3 position_view,
	vec3 position_world,
	vec3 direction_world,
	vec3 flat_normal,
	vec3 tint,
	vec2 light_levels,
	float view_distance,
	float layer_distance,
	float frozen_biome_factor
) {
	vec4 water_color = vec4(0.0);

	// Use hardcoded TBN matrix pointing upwards that is the same for DH water and regular water
	const mat3 tbn = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, 0.0, 1.0),
		vec3(0.0, 1.0, 0.0)
	);

	// Common fog 

	float fog_visibility = common_fog(view_distance, false).a;

	// Cloud shadows 

#if defined WORLD_OVERWORLD && defined CLOUD_SHADOWS
	float cloud_shadows = get_cloud_shadows(colortex8, position_world - cameraPosition);
#else
	const float cloud_shadows = 1.0;
#endif

	// Use latitude-adjusted light direction for consistency with regular water reflections
#ifdef LATITUDE_SUN_PATH
	vec3 adjusted_light_dir = get_latitude_adjusted_light_dir(sun_dir, cameraPosition.z, yearProgress, sunAngle);
#else
	vec3 adjusted_light_dir = light_dir;
#endif

	// Water absorption approx (must match gbuffers_water)

	vec3 biome_water_color = srgb_eotf_inv(1.45 * tint.rgb) * rec709_to_working_color;
	vec3 absorption_coeff = biome_water_coeff(biome_water_color);

	mat2x3 water_fog = water_fog_simple(
		light_color * cloud_shadows,
		ambient_color,
		absorption_coeff,
		light_levels,
		layer_distance,
		dot(adjusted_light_dir, direction_world),
		0.0
	);

	float brightness_control = 1.0 - exp(-0.33 * layer_distance);
		  brightness_control = (1.0 - light_levels.y) + brightness_control * light_levels.y;

	water_color.rgb = water_fog[0] * (1.0 + 6.0 * sqr(water_fog[1])) * brightness_control * fog_visibility;
	water_color.a   = 1.0 - water_fog[1].x;

	// Get water wave normal 

	// Account for 1/8 height difference between water and terrain
	vec3 water_surface_pos = position_world - vec3(0.0, rcp(8.0), 0.0);

	vec3 normal = flat_normal;

#ifdef WATER_WAVES
	if (flat_normal.y > eps) {
		vec2 coord = -(water_surface_pos * tbn).xy;
		vec3 wave_normal = get_water_normal(
			water_surface_pos,
			flat_normal,
			coord,
			vec2(0.0),
			light_levels.y,
			false
		);
		// OPT: Reduce wave intensity in frozen biomes (calmer water) but keep some motion
		// Mix factor: 0.15 minimum waves in frozen areas, full waves in warm areas
		float wave_intensity = mix(0.15, 1.0, frozen_biome_factor);
		normal = tbn * mix(vec3(0.0, 0.0, 1.0), wave_normal, wave_intensity);
	}
#endif
	
	// Specular highlight

#if (defined WORLD_OVERWORLD || defined WORLD_END)
	float NoL = dot(normal, adjusted_light_dir);
	float NoV = clamp01(dot(normal, -direction_world));
	float LoV = dot(adjusted_light_dir, -direction_world);
	float halfway_norm = inversesqrt(2.0 * LoV + 2.0);
	float NoH = (NoL + NoV) * halfway_norm;
	float LoH = LoV * halfway_norm + halfway_norm;

	water_color.rgb += get_specular_highlight(water_material, NoL, NoV, NoH, LoV, LoH) * light_color * cloud_shadows * fog_visibility;
#endif

	// Specular reflections

#if defined ENVIRONMENT_REFLECTIONS || defined SKY_REFLECTIONS
	mat3 new_tbn = get_tbn_matrix(normal);
	water_color.rgb += get_specular_reflections(
		water_material,
		new_tbn,
		position_screen,
		position_view,
		position_world,
		normal,
		flat_normal,
		direction_world,
		direction_world * new_tbn,
		light_levels.y,
		true
	) * fog_visibility;
#endif

	// Purkinje shift

	water_color.rgb = purkinje_shift(water_color.rgb, light_levels);

	return water_color;
}

#endif // INCLUDE_MISC_DISTANT_WATER
