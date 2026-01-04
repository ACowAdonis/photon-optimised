# Mod Uniforms Integration (Modified Oculus)

This document describes the custom uniforms exposed by a modified version of Oculus that integrates with Serene Seasons and Cold Sweat mods.

## Overview

The modified Oculus shader loader exposes additional uniforms that allow shaders to react to:
- **Serene Seasons**: Seasonal cycle data (season, progress through year, day within season)
- **Cold Sweat**: Player and world temperature data

## Available Uniforms

### Serene Seasons Uniforms

| Uniform | GLSL Type | Range | Description |
|---------|-----------|-------|-------------|
| `currentSeason` | `int` | 0-3 | Season index: 0=SPRING, 1=SUMMER, 2=AUTUMN, 3=WINTER |
| `currentSubSeason` | `int` | 0-11 | Sub-season index (see table below) |
| `seasonProgress` | `float` | 0.0-1.0 | Progress through the current season |
| `yearProgress` | `float` | 0.0-1.0 | Progress through the entire year (config-independent) |
| `seasonDay` | `int` | 0 to daysPerSeason-1 | Day within the current season |
| `daysPerSeason` | `int` | varies | Days per season from mod config (default 24) |

#### Sub-Season Index Reference

| Index | SubSeason | Index | SubSeason |
|-------|-----------|-------|-----------|
| 0 | EARLY_SPRING | 6 | EARLY_AUTUMN |
| 1 | MID_SPRING | 7 | MID_AUTUMN |
| 2 | LATE_SPRING | 8 | LATE_AUTUMN |
| 3 | EARLY_SUMMER | 9 | EARLY_WINTER |
| 4 | MID_SUMMER | 10 | MID_WINTER |
| 5 | LATE_SUMMER | 11 | LATE_WINTER |

### Cold Sweat Uniforms

| Uniform | GLSL Type | Range | Description |
|---------|-----------|-------|-------------|
| `playerBodyTemp` | `float` | varies | Player's core body temperature (Cold Sweat internal scale) |
| `worldAmbientTemp` | `float` | varies | World temperature at player's current position |

**Note on Cold Sweat Temperature Scale:**
- The internal values exposed are NOT the 0-100 player-facing temperature
- Cold Sweat uses an internal scale where comfortable is around 0
- Negative values = cold, positive values = hot
- The player-facing display (0-100) is a UI transformation of this internal value

### Default Values (When Mods Not Installed)

| Uniform | Default Value |
|---------|---------------|
| `currentSeason` | 1 (summer) |
| `currentSubSeason` | 4 (mid-summer) |
| `seasonProgress` | 0.5 |
| `yearProgress` | 0.375 (~mid-summer position) |
| `seasonDay` | 12 |
| `daysPerSeason` | 24 |
| `playerBodyTemp` | 0.0 |
| `worldAmbientTemp` | 0.0 |

## Usage in Shaders

### Declaring Uniforms

```glsl
// Serene Seasons
uniform int currentSeason;
uniform int currentSubSeason;
uniform float seasonProgress;
uniform float yearProgress;
uniform int seasonDay;
uniform int daysPerSeason;

// Cold Sweat
uniform float playerBodyTemp;
uniform float worldAmbientTemp;
```

### Key Design Notes

#### Config-Independent Season Tracking

`yearProgress` is the most reliable uniform for effects that span the entire year - it's always 0.0-1.0 regardless of how many days are configured per season.

**Recommended:** Use `yearProgress` instead of `worldDay % 96` for seasonal effects.

#### Computing Continuous Season Values

```glsl
// Option 1: Using yearProgress (recommended - always works regardless of config)
float seasonContinuous = yearProgress * 4.0;  // 0.0 to 4.0 through year

// Option 2: Using currentSeason + seasonProgress
float seasonContinuous = float(currentSeason) + seasonProgress;  // Also 0.0 to 4.0
```

#### Seasonal Intensity Curves

```glsl
// Winter peaks at yearProgress ~ 0.875 (mid-winter)
float winterFactor = 1.0 - abs(yearProgress - 0.875) * 4.0;
winterFactor = clamp(winterFactor, 0.0, 1.0);

// Summer peaks at yearProgress ~ 0.375 (mid-summer)
float summerFactor = 1.0 - abs(yearProgress - 0.375) * 4.0;
summerFactor = clamp(summerFactor, 0.0, 1.0);

// Spring peaks at yearProgress ~ 0.125 (mid-spring)
float springFactor = 1.0 - abs(yearProgress - 0.125) * 4.0;
springFactor = clamp(springFactor, 0.0, 1.0);

// Autumn peaks at yearProgress ~ 0.625 (mid-autumn)
float autumnFactor = 1.0 - abs(yearProgress - 0.625) * 4.0;
autumnFactor = clamp(autumnFactor, 0.0, 1.0);
```

## Debug Tools

Debug options are available in `settings.glsl`:

```glsl
// Mod Uniforms Debug (Serene Seasons / Cold Sweat via modified Oculus)
//#define DEBUG_MOD_UNIFORMS          // Show debug overlay with all mod uniform values
//#define DEBUG_MOD_UNIFORMS_TINT     // Apply subtle season color tint to verify yearProgress
  #define DEBUG_MOD_UNIFORMS_TINT_INTENSITY 0.15
```

- **DEBUG_MOD_UNIFORMS**: Displays an overlay panel showing all uniform values in real-time
- **DEBUG_MOD_UNIFORMS_TINT**: Applies a color tint that cycles through seasons (green->yellow->orange->blue)

Access via shader settings: **Misc -> Developer**

## Lightning Strike Uniforms

The modified Oculus also exposes lightning strike position data for dynamic lighting effects.

### Available Uniforms

| Uniform | GLSL Type | Update Frequency | Description |
|---------|-----------|------------------|-------------|
| `lightningStrikePos` | `vec3` | PER_TICK | World-space coordinates of lightning strike |
| `lightningStrikeDistance` | `float` | PER_TICK | Distance from player eye to strike (blocks) |
| `lightningBoltPosition` | `vec4` | PER_TICK | Legacy: xyz = camera-relative position, w = active flag |

### Default Values (No Active Lightning)

| Uniform | Value |
|---------|-------|
| `lightningStrikePos` | `vec3(0.0, 0.0, 0.0)` |
| `lightningStrikeDistance` | `-1.0` |
| `lightningBoltPosition` | `vec4(0.0, 0.0, 0.0, 0.0)` |

### Detecting Active Lightning

```glsl
// Recommended: Check distance (-1.0 means no lightning)
bool hasLightning = lightningStrikeDistance >= 0.0;

// Alternative: Check legacy w component
bool hasLightning = lightningBoltPosition.w > 0.5;
```

### Screen-Space Transformation for Occlusion

```glsl
if (lightningStrikeDistance >= 0.0) {
    // Transform world position to clip space
    vec3 strike_scene = lightningStrikePos - cameraPosition;
    vec3 strike_view = (gbufferModelView * vec4(strike_scene, 1.0)).xyz;
    vec4 strike_clip = gbufferProjection * vec4(strike_view, 1.0);

    // Screen coordinates (0-1 range)
    vec2 strike_screen = (strike_clip.xy / strike_clip.w) * 0.5 + 0.5;

    // Visibility checks
    bool in_front = strike_clip.w > 0.0;
    bool on_screen = all(greaterThan(strike_screen, vec2(0.0))) &&
                     all(lessThan(strike_screen, vec2(1.0)));

    // Depth-based occlusion (sample depth buffer)
    if (on_screen && in_front) {
        float scene_depth = texture(depthtex1, strike_screen).x;
        float strike_depth = strike_clip.z / strike_clip.w * 0.5 + 0.5;
        bool visible = strike_depth > scene_depth;  // Behind geometry = visible sky
    }

    // Distance-based intensity
    float intensity = 1.0 / (1.0 + lightningStrikeDistance * 0.01);
}
```

### Implementation Notes

- Position is interpolated for smooth movement during the strike
- If multiple lightning bolts exist, the first one found is reported
- Works with existing `thunderStrength` uniform for overall storm intensity
- Lightning entities exist briefly (~0.5 seconds), so check each frame
- The `lightningStrikeDistance` uniform is the most reliable way to detect active lightning

### Potential Uses

- **Directional flash**: Light the scene from the strike direction rather than uniform flash
- **Occlusion-aware flash**: Reduce flash intensity when lightning is behind terrain/buildings
- **Distance attenuation**: Closer strikes produce brighter flashes
- **Delayed thunder**: Use distance to calculate appropriate audio delay (not shader-relevant but useful context)

## Update Frequency

These uniforms are updated periodically, not every frame:
- Season uniforms: ~every 20 seconds
- Temperature uniforms: ~every 1.5 seconds
- Lightning uniforms: every tick (PER_TICK) - real-time updates required

This is intentional for performance - seasonal/temperature effects should be gradual anyway. Lightning requires real-time updates due to its brief duration.

## Testing Procedure

1. Install modified Oculus jar with Serene Seasons and/or Cold Sweat
2. Load world with Photon shader
3. Enable `DEBUG_MOD_UNIFORMS` in settings.glsl
4. Use `/season set <spring|summer|autumn|winter>` to change seasons
5. Verify `currentSeason`, `yearProgress`, and visual effects update correctly
6. Test with non-default config: Change season length in Serene Seasons config, verify `yearProgress` still works correctly (should always be 0.0-1.0)
7. For Cold Sweat: Expose player to temperature extremes and verify `playerBodyTemp` changes

## Files

- **Uniform declarations**: `shaders/program/final.fsh` (lines 36-45)
- **Debug overlay code**: `shaders/include/misc/mod_uniforms_debug.glsl`
- **Debug settings**: `shaders/settings.glsl` (lines 526-529)
