#if !defined INCLUDE_MISC_LIGHTNING_FLASH
#define INCLUDE_MISC_LIGHTNING_FLASH

// Current implementation uses uniform flash intensity across the scene.
//
// FUTURE ENHANCEMENT: Modified Oculus exposes lightning position uniforms:
//   - lightningStrikePos (vec3): World-space coordinates of strike
//   - lightningStrikeDistance (float): Distance from player to strike (-1.0 if none)
//   - lightningBoltPosition (vec4): Legacy, xyz = camera-relative, w = active flag
//
// These could enable:
//   - Directional lighting from strike location
//   - Distance-based intensity falloff
//   - Occlusion-aware flash (reduced when strike is behind geometry)
//
// See docs/MOD_UNIFORMS_INTEGRATION.md for full documentation.

#ifdef LIGHTNING_FLASH
	#if defined IS_IRIS
		uniform float lightning_flash_iris;
		#define LIGHTNING_FLASH_UNIFORM lightning_flash_iris
	#else
		uniform float lightning_flash_of;
		#define LIGHTNING_FLASH_UNIFORM lightning_flash_of
	#endif
#else
	#define LIGHTNING_FLASH_UNIFORM 0.0
#endif

// Base lightning flash intensity multiplier
// Higher value = more dramatic scene illumination during strikes
const float lightning_flash_base_intensity = 8.0;

// Lightning intensity scales with storm strength for more dramatic thunderstorms
// At peak storm: intensity can reach 12.0 (3x base)
// Note: The daily storm cap system limits rainStrength effects in other shaders,
// but actual lightning events are controlled by Minecraft. This intensity scaling
// just affects how bright the flash appears. Using rainStrength directly here
// ensures the visual matches when Minecraft decides to spawn lightning.
#ifdef STORM_INTENSITY_SYSTEM
	// Note: rainStrength should already be declared in shaders that include this
	#define lightning_flash_intensity (lightning_flash_base_intensity * (1.0 + 2.0 * rainStrength * STORM_INTENSITY_MULT))
#else
	#define lightning_flash_intensity lightning_flash_base_intensity
#endif

#endif // INCLUDE_MISC_LIGHTNING_FLASH
