# Photon Optimised - Project Context

## Overview

This is a customised fork of Photon Shaders (by SixthSurge) for Minecraft, focusing on environmental immersion and mod integrations. The shader runs on Iris/OptiFine and targets gameplay-focused visual enhancements.

## Key Systems

### Latitude Climate System
- Files: `include/misc/latitude.glsl`, `include/misc/latitude_sun.glsl`
- Player Z-coordinate determines latitude (0 = equator, increases toward poles)
- Affects sun path, seasonal intensity, aurora visibility

### Seasonal Lighting
- Files: `include/lighting/colors/seasonal_lighting.glsl`, `include/lighting/colors/light_color.glsl`
- Integrates with Serene Seasons mod via `yearProgress` uniform
- Modifies sun intensity, color tinting, ambient light

### Storm Intensity System
- Files: `include/weather/fog.glsl`, `include/weather/core.glsl`, `include/lighting/diffuse_lighting.glsl`
- Uses `rainStrength` and `wetness` uniforms
- Affects lighting desaturation, shadow softening (gated by skylight for caves)

### Temperature Effects
- Files: `include/misc/hypothermia.glsl`, `include/misc/heatstroke.glsl`, `include/misc/heat_haze.glsl`
- Integrates with Cold Sweat mod via `worldAmbientTemp` uniform
- Visual feedback for extreme temperatures

### Custom Uniforms (via modified Oculus)
- `yearProgress` - Serene Seasons year progress [0,1]
- `worldAmbientTemp` - Cold Sweat temperature
- `storm_daily_cap` - Daily storm intensity cap (planned)
- `biome_may_snow`, `biome_may_rain` - Biome weather flags

## Architecture

### Shader Pipeline
- `gbuffers_*` - Geometry rendering passes
- `d0_sky_map` - Sky/lighting color calculation
- `d4_deferred_shading` - Main deferred lighting
- `c0_vl` - Volumetric lighting
- `c1_blend_layers` - Layer compositing, distant water

### Key Patterns
- Feature toggles via `#ifdef` (e.g., `LATITUDE_SUN_PATH`, `STORM_INTENSITY_SYSTEM`)
- Uniforms declared in shader programs, accessed via `colortex4` for pre-computed values
- Light color and ambient color computed in `d0_sky_map.vsh`, stored for other passes

## Development Notes

- Always test changes with both VL enabled and disabled paths
- Cave lighting uses `light_levels.y` (skylight) to gate outdoor-only effects
- Storm effects should not affect underground/indoor areas
- Latitude system uses Z-coordinate; northern hemisphere = positive Z

## Mod Integration Requirements

For full functionality, the following mods provide uniforms:
- Serene Seasons (or compatible) - `yearProgress`
- Cold Sweat - `worldAmbientTemp`
- Modified Oculus fork - Additional custom uniforms

Without these mods, features gracefully degrade to defaults.
