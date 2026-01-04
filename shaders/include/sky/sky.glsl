#if !defined INCLUDE_SKY_SKYsky
#define INCLUDE_SKY_SKY

#include "/include/utility/color.glsl"
#include "/include/utility/dithering.glsl"
#include "/include/utility/fast_math.glsl"
#include "/include/utility/random.glsl"

//----------------------------------------------------------------------------//
#if   defined WORLD_OVERWORLD

#include "/include/lighting/colors/light_color.glsl"
#include "/include/lighting/colors/weather_color.glsl"
#include "/include/lighting/bsdf.glsl"
#include "/include/misc/lightning_flash.glsl"
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/projection.glsl"
#include "/include/sky/rainbow.glsl"
#include "/include/sky/stars.glsl"
#include "/include/utility/geometry.glsl"

#ifdef LATITUDE_SUN_PATH
#include "/include/misc/latitude_sun.glsl"
#endif

#if defined PROGRAM_DEFERRED0
#include "/include/sky/clouds.glsl"

#if defined CREPUSCULAR_RAYS && !defined BLOCKY_CLOUDS
#include "/include/sky/crepuscular_rays.glsl"
#endif
#endif

const float sun_luminance  = 40.0; // luminance of sun disk
const float moon_luminance = 10.0; // luminance of moon disk

vec3 draw_sun(vec3 ray_dir) {
#ifdef LATITUDE_SUN_PATH
	vec3 visual_sun_dir = get_latitude_adjusted_sun_dir(sun_dir, cameraPosition.z, yearProgress);
#else
	vec3 visual_sun_dir = sun_dir;
#endif

	float nu = dot(ray_dir, visual_sun_dir);

	// Limb darkening model from http://www.physics.hmc.edu/faculty/esin/a101/limbdarkening.pdf
	const vec3 alpha = vec3(0.429, 0.522, 0.614);
	float center_to_edge = max0(sun_angular_radius - fast_acos(nu));
	vec3 limb_darkening = pow(vec3(1.0 - sqr(1.0 - center_to_edge)), 0.5 * alpha);

	return sun_luminance * sun_color * step(0.0, center_to_edge) * limb_darkening;
}

#ifdef GALAXY
// Sample galaxy texture as a density/color map for procedural stars
// Returns nothing visible - the galaxy image guides star placement and tinting
void sample_galaxy_map(vec3 ray_dir, out float galaxy_luminance, out vec3 galaxy_color) {
	// Equirectangular projection for equatorial coordinates
	float lon = atan(ray_dir.x, ray_dir.z);
	float lat = fast_acos(ray_dir.y);

	vec3 galaxy = texture(
		galaxy_sampler,
		vec2(lon * rcp(tau), lat * rcp(pi))
	).rgb;

	// Convert to linear color space
	galaxy = srgb_eotf_inv(galaxy) * rec709_to_working_color;

	// Apply intensity scaling based on time of day
	float night_intensity = 0.05 + 1.0 * linear_step(-0.1, 0.25, -sun_dir.y);
	galaxy *= night_intensity * GALAXY_INTENSITY;

	galaxy_luminance = dot(galaxy, luminance_weights_rec709);
	galaxy_color = galaxy;
}
#endif

vec3 draw_sky(
	vec3 ray_dir, 
	vec3 atmosphere, 
	vec4 clouds_and_aurora, 
	float clouds_apparent_distance
) {
	vec3 sky = vec3(0.0);

#if defined SHADOW
	// Trick to make stars rotate with sun and moon
	mat3 rot = (sunAngle < 0.5)
		? mat3(shadowModelViewInverse)
		: mat3(-shadowModelViewInverse[0].xyz, shadowModelViewInverse[1].xyz, -shadowModelViewInverse[2].xyz);

	vec3 celestial_dir = ray_dir * rot;

	// Sidereal drift: stars move slightly faster than the sun/moon
	// Real difference is ~4 min/day; this creates a subtle drift over long play sessions
	float star_drift_angle = frameTimeCounter * 0.00008; // Very slow rotation
	float sd_cos = cos(star_drift_angle);
	float sd_sin = sin(star_drift_angle);
	mat3 star_drift_rot = mat3(
		sd_cos,  0.0, sd_sin,
		0.0,     1.0, 0.0,
		-sd_sin, 0.0, sd_cos
	);
	vec3 star_celestial_dir = celestial_dir * star_drift_rot;
#else
	vec3 celestial_dir = ray_dir;
	vec3 star_celestial_dir = ray_dir;
#endif

	// Galaxy density/color map for stars (drifts with stars)

#ifdef GALAXY
	float galaxy_luminance;
	vec3 galaxy_color;
	sample_galaxy_map(star_celestial_dir, galaxy_luminance, galaxy_color);
#else
	const float galaxy_luminance = 0.0;
	const vec3 galaxy_color = vec3(0.0);
#endif

	// Sun, moon stars

#if defined PROGRAM_DEFERRED4
	vec3 skytextured_output = texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0).rgb;
	sky += texelFetch(colortex0, ivec2(gl_FragCoord.xy), 0).rgb;

	// Shader sun
	#ifndef VANILLA_SUN
	sky += draw_sun(ray_dir);
	#endif

	// Stars (density and color influenced by galaxy map, with sidereal drift)
	#ifdef STARS
	float stars_visibility = clamp01(1.0 - dot(skytextured_output, vec3(0.33) * 256.0));
	vec3 stars = draw_stars(star_celestial_dir, galaxy_luminance, galaxy_color) * stars_visibility;

	// Darken overall night sky by 50% for deeper blacks
	stars *= 0.5;
	sky += stars;
	#endif

	// Subtle nebulous glow from galaxy map - adds depth without looking static
	#ifdef GALAXY
	// Softer glow: use sqrt to compress luminance range for smoother blending
	float soft_luminance = sqrt(galaxy_luminance);
	// Glow intensity varies with moon phase (brighter glow when moon is dimmer)
	float moon_glow_factor = mix(1.25, 0.75, moon_phase_brightness);
	// Very subtle glow that blends smoothly across the sky
	float glow_intensity = 0.025 * soft_luminance * stars_visibility * moon_glow_factor;
	vec3 glow_color = galaxy_color / max(galaxy_luminance, 0.001); // Normalized color
	sky += glow_color * glow_intensity;
	#endif
#endif

	// Atmosphere

	sky *= atmosphere_transmittance(ray_dir.y, planet_radius) * (1.0 - rainStrength);
	sky += atmosphere;

	// Clouds, aurora, crepuscular rays

	sky *= clouds_and_aurora.a;   // Transmittance
	sky += clouds_and_aurora.rgb; // Scattering

	// Rainbow

	sky = draw_rainbows(
		sky, 
		ray_dir, 
		mix(clouds_apparent_distance, 1e6, linear_step(1.0, 0.95, clouds_and_aurora.w))
	);

	// Cave sky fix

#if !defined PROGRAM_DEFERRED0
	// Fade lower part of sky into cave fog color when underground so that the sky isn't visible
	// beyond the render distance
	float underground_sky_fade = biome_cave * smoothstep(-0.1, 0.1, 0.4 - ray_dir.y);
	sky = mix(sky, vec3(0.0), underground_sky_fade);
#endif

	return sky;
}

#if   defined PROGRAM_DEFERRED0
vec4 get_clouds_and_aurora(vec3 ray_dir, vec3 clear_sky, out float clouds_apparent_distance) {
	clouds_apparent_distance = 1e6;

	ivec2 texel   = ivec2(gl_FragCoord.xy);
	      texel.x = texel.x % (sky_map_res.x - 4);

	float dither = interleaved_gradient_noise(vec2(texel));

	// Clouds

#ifndef BLOCKY_CLOUDS
	const vec3 air_viewer_pos = vec3(0.0, planet_radius, 0.0);
	CloudsResult result = draw_clouds(air_viewer_pos, ray_dir, clear_sky, -1.0, dither);

	// Lightning flash
	result.scattering.rgb += LIGHTNING_FLASH_UNIFORM * lightning_flash_intensity * result.scattering.a;
#else
	CloudsResult result = clouds_not_hit;
#endif

	clouds_apparent_distance = result.apparent_distance;

	// Aurora

	vec3 aurora = draw_aurora(ray_dir, dither);

	vec4 clouds_and_aurora = vec4(
		result.scattering.xyz + aurora * result.transmittance,
		result.transmittance
	);

	// Crepuscular rays

#if defined CREPUSCULAR_RAYS && !defined BLOCKY_CLOUDS
	vec4 crepuscular_rays = draw_crepuscular_rays(
		colortex8, 
		ray_dir, 
		false,
		0.5
	);
	clouds_and_aurora *= crepuscular_rays.w;
	clouds_and_aurora.rgb += crepuscular_rays.xyz;
#endif

	return clouds_and_aurora;
}

vec3 draw_sky(vec3 ray_dir) {
#ifdef LATITUDE_SUN_PATH
	vec3 visual_sun_dir = get_latitude_adjusted_sun_dir(sun_dir, cameraPosition.z, yearProgress);
	vec3 visual_moon_dir = -visual_sun_dir;
#else
	vec3 visual_sun_dir = sun_dir;
	vec3 visual_moon_dir = moon_dir;
#endif

	vec3 atmosphere = atmosphere_scattering(
		ray_dir,
		sun_color,
		visual_sun_dir,
		moon_color,
		visual_moon_dir,
		true
	);
	float clouds_apparent_distance;
	vec4 clouds_and_aurora = get_clouds_and_aurora(ray_dir, atmosphere, clouds_apparent_distance);
	return draw_sky(ray_dir, atmosphere, clouds_and_aurora, clouds_apparent_distance);
}
#endif

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

vec3 draw_sky(vec3 ray_dir) {
	return ambient_color;
}

//----------------------------------------------------------------------------//
#elif defined WORLD_END

#include "/include/misc/end_lighting_fix.glsl"
#include "/include/sky/atmosphere.glsl"
#include "/include/sky/stars.glsl"

const float sun_solid_angle = cone_angle_to_solid_angle(sun_angular_radius);
const vec3 end_sun_color = vec3(1.0, 0.5, 0.25);

vec3 draw_sun(vec3 ray_dir) {
	float nu = dot(ray_dir, sun_dir);
	float r = fast_acos(nu);

	// Sun disk

	const vec3 alpha = vec3(0.6, 0.5, 0.4);
	float center_to_edge = max0(sun_angular_radius - r);
	vec3 limb_darkening = pow(vec3(1.0 - sqr(1.0 - center_to_edge)), 0.5 * alpha);
	vec3 sun_disk = vec3(r < sun_angular_radius);

	// Solar flare effect

	// Transform the coordinate space such that z is parallel to sun_dir
	vec3 tangent = sun_dir.y == 1.0 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), sun_dir));
	vec3 bitangent = normalize(cross(tangent, sun_dir));
	mat3 rot = mat3(tangent, bitangent, sun_dir);

	// Vector from ray dir to sun dir
	vec2 q = ((ray_dir - sun_dir) * rot).xy;

	float theta = fract(linear_step(-pi, pi, atan(q.y, q.x)) + 0.015 * frameTimeCounter - 0.33 * r);

	float flare = texture(noisetex, vec2(theta, r - 0.025 * frameTimeCounter)).x;
	      flare = pow5(flare) * exp(-25.0 * (r - sun_angular_radius));
		  flare = r < sun_angular_radius ? 0.0 : flare;

	return end_sun_color * rcp(sun_solid_angle) * max0(sun_disk + 0.1 * flare);
}

vec3 draw_sky(vec3 ray_dir) {
	// Sky gradient

	float up_gradient = linear_step(0.0, 0.4, ray_dir.y) + linear_step(0.1, 0.8, -ray_dir.y);
	vec3 sky = ambient_color * mix(0.1, 0.04, up_gradient);
	float mie_phase = cornette_shanks_phase(dot(ray_dir, sun_dir), 0.6);
	sky += 0.1 * (ambient_color + 0.5 * end_sun_color) * mie_phase;

#if defined PROGRAM_DEFERRED4
	// Sun

	#ifdef END_SUN_EFFECT
	sky += draw_sun(ray_dir);
	#endif

	// Stars

	vec3 stars_fade = exp2(-0.1 * max0(1.0 - ray_dir.y) / max(ambient_color, eps)) * linear_step(-0.2, 0.0, ray_dir.y);
	sky += draw_stars(ray_dir, 0.0, vec3(0.0)).xzy * stars_fade;
#endif

	return sky;
}

#endif

#endif // INCLUDE_SKY_SKY
