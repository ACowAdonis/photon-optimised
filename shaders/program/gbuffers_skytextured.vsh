/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/gbuffers_skytextured:
  Handle vanilla sun and moon and custom skies

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"


out vec2 uv;
out vec3 view_pos;

flat out vec3 tint;
flat out vec3 sun_color;
flat out vec3 moon_color;

// ------------
//   Uniforms
// ------------

uniform float sunAngle;
uniform float rainStrength;

uniform vec2 taa_offset;

uniform vec3 sun_dir;
uniform vec3 light_dir;

uniform float frameTimeCounter;
uniform float eyeAltitude;

uniform mat4 gbufferModelViewInverse;

uniform int worldDay;

uniform float camera_z;
uniform float year_progress;

uniform float time_sunrise;
uniform float time_noon;
uniform float time_sunset;
uniform float time_midnight;

#include "/include/lighting/colors/light_color.glsl"

void main() {
	sun_color = get_sun_exposure() * get_sun_tint();
	moon_color = get_moon_exposure() * get_moon_tint();

	uv   = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.xy + gl_TextureMatrix[0][3].xy;
	tint = gl_Color.rgb;

	view_pos = transform(gl_ModelViewMatrix, gl_Vertex.xyz);

#ifdef LATITUDE_SUN_PATH
	// Rotate sky geometry to match latitude-adjusted celestial positions
	// Apply to all geometry - sun is rendered procedurally anyway when VANILLA_SUN is off

	// Calculate latitude from camera Z position (using custom uniform from shaders.properties)
	float dist_from_equator = abs(camera_z - LATITUDE_ORIGIN_Z);
	float latitude = clamp(dist_from_equator / LATITUDE_SCALE, 0.0, 1.0);

	// Latitude offset (stronger at high latitudes)
	float lat_offset = 45.0 * latitude * latitude;

	// Seasonal variation - use yearProgress uniform from Serene Seasons
	float season_angle = (year_progress - 0.125) * tau;
	float declination = 23.45 * sin(season_angle);
	float season_mult = mix(0.3, 1.0, latitude);
	float season_offset = -declination * season_mult;

	// Combined rotation in radians
	float rot_rad = (lat_offset + season_offset) * LATITUDE_SUN_PATH_INTENSITY * 0.01745329;

	// Rotation around WORLD X-axis (not view X-axis)
	float c = cos(rot_rad);
	float s = sin(rot_rad);
	mat3 rot_world_x = mat3(
		1.0, 0.0, 0.0,
		0.0,   c,  -s,
		0.0,   s,   c
	);

	// Transform to world space, rotate, transform back to view space
	vec3 world_dir = mat3(gbufferModelViewInverse) * view_pos;
	world_dir = rot_world_x * world_dir;
	view_pos = transpose(mat3(gbufferModelViewInverse)) * world_dir;
#endif

	vec4 clip_pos = project(gl_ProjectionMatrix, view_pos);

#if   defined TAA && defined TAAU
	clip_pos.xy  = clip_pos.xy * taau_render_scale + clip_pos.w * (taau_render_scale - 1.0);
	clip_pos.xy += taa_offset * clip_pos.w;
#elif defined TAA
	clip_pos.xy += taa_offset * clip_pos.w * 0.75;
#endif

	gl_Position = clip_pos;
}

