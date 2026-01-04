# Environmental Effects Integration Plan

This document outlines planned shader effects that integrate season, latitude, time of day, weather, and player temperature data from the modified Oculus + Serene Seasons + Cold Sweat stack.

## World Model

### Climate Bands (Latitude System)

The modpack uses Natural Temperature mod which generates climate bands based on north-south position (Z coordinate):

```
Latitude Model (Z-axis):
    |  ARCTIC/ANTARCTIC  |  (high |Z|, very cold)
    |     SUBARCTIC      |
    |     TEMPERATE      |
    |    SUBTROPICAL     |
    |     TROPICAL       |  (near Z=0, hot)
    |    SUBTROPICAL     |
    |     TEMPERATE      |
    |     SUBARCTIC      |
    |  ARCTIC/ANTARCTIC  |  (high |Z|, very cold)
```

**Configurable Parameters** (to be added to settings.glsl):
- `LATITUDE_SCALE`: Blocks per climate zone transition (e.g., 5000-10000)
- `LATITUDE_ORIGIN_Z`: Z coordinate of equator (default 0)

### Cold Sweat Temperature Scales (Calibrated)

Cold Sweat uses an internal temperature unit called **Minecraft Units (MC)**.

#### Conversion Formula
```
1 MC = 25°C = 45°F
```

#### World Ambient Temperature (`worldAmbientTemp`)
- **Conversion**: `Celsius = worldAmbientTemp * 25`
- **Default safe range**: 0.5-1.7 MC (10-25°C / 50-77°F)
- **Hot biome examples**:
  - Desert: 2.67-6.39 MC (67-160°C range over day/night)
  - Jungle: 4.22-4.83 MC (105-120°C)
  - Badlands: 4.67-6.67 MC (117-167°C)
- **Cold biome examples**:
  - Snowy Taiga: -0.28-1.61 MC (-7 to 40°C)
  - Frozen Peaks: -0.61-0.61 MC (-15 to 15°C)

#### Player Body Temperature (`playerBodyTemp`)
- **Comfortable zone**: around 0 (internal scale)
- **Heat damage threshold**: internal value ~100 (player sees gauge at max)
- **Cold damage threshold**: internal value ~-100 (player sees gauge at min)

#### Shader Usage
```glsl
// Heat haze thresholds (in MC units)
#define HEAT_HAZE_TEMP_START 1.2  // ~30°C - haze begins
#define HEAT_HAZE_TEMP_MAX 1.6    // ~40°C - maximum haze
```

---

## Implemented Effects

### 1. Temperature-Based Heat Haze ✓

**Status**: IMPLEMENTED

**Previous State**: Heat haze applied based on `biome_arid` and `biome_temperature`

**Current Implementation**: Heat haze now uses Cold Sweat's `worldAmbientTemp` directly

**How it works**:
```glsl
// Temperature-based heat factor (in heat_haze.glsl)
#define HEAT_HAZE_TEMP_START 1.2  // ~30°C - haze begins
#define HEAT_HAZE_TEMP_MAX 1.6    // ~40°C - maximum haze

float heat_factor = smoothstep(HEAT_HAZE_TEMP_START, HEAT_HAZE_TEMP_MAX, world_temp);
```

**Conditions for heat haze**:
- World temperature above ~30°C (1.2 MC)
- Daytime (effect peaks in afternoon)
- Not raining
- Player outdoors (sky exposure)
- Not underwater

**Benefits**:
- Accurately reflects actual game temperature from Cold Sweat
- No biome detection needed - temperature handles everything
- Works in any hot environment (deserts, tropical, summer days)
- Integrates with Cold Sweat's temperature modifiers (time, biome, altitude, etc.)

---

### 2. Heatstroke Effects ✓

**Status**: IMPLEMENTED

**Trigger**: Player body temperature rises above 35 (Cold Sweat internal scale, where 0 = neutral)

**Effects**:
- Pulsing brightness (heartbeat effect, 45-90 BPM based on heat level)
- Reddish tint during pulse
- Vignette darkening at screen edges (tunnel vision)
- Blur/distortion at higher temperatures (50+)
- Desaturation

**Implementation**:
```glsl
// Linear intensity from 35 to 100
float linear_intensity = (player_temp - 35.0) / (100.0 - 35.0);

// Applied effects scale linearly for predictable early warning
color = apply_heatstroke_pulse(color, linear_intensity, time);
color = apply_heatstroke_vignette(color, uv, linear_intensity, time);
```

---

### 3. Aurora Borealis Latitude Restriction

**Status**: TO BE IMPLEMENTED (modification of existing aurora system)

**Current State**: Aurora appears everywhere at night

**Planned Change**: Restrict aurora to high latitudes only (subarctic and polar regions)

**Implementation Approach**:
```glsl
// Aurora only visible at high latitudes
float aurora_latitude = smoothstep(TEMPERATE_LATITUDE, SUBARCTIC_LATITUDE, abs(cameraPosition.z));

// Existing aurora intensity multiplied by latitude factor
float aurora_intensity = base_aurora_intensity * aurora_latitude;
```

**Benefits**:
- More realistic - auroras occur near magnetic poles
- Creates distinct visual identity for polar regions
- Encourages exploration to see the effect

---

### 4. Ice Crystal / Diamond Dust Effect ✓

**Status**: IMPLEMENTED (Dual Implementation)

**Conditions**:
- Arctic regions only (|Z| >= 6666 blocks, configurable via LATITUDE_SCALE)
- Clear weather (low `rainStrength`)
- Daytime (sun above horizon)
- Forward scattering bias (effect strongest when looking toward sun)

**Visual Effect**:
- Subtle sparkling particles in the air
- Small bright specular highlights that drift slowly
- More visible when looking toward sun (forward scattering)
- Very subtle - should not obstruct view

**Dual Implementation**:

1. **Sky-based** (`include/sky/diamond_dust.glsl`):
   - Renders crystals at infinity (sky backdrop)
   - Uses cell-based procedural sparkle generation (similar to stars)
   - Called from `sky.glsl` during sky rendering
   - Creates distant atmospheric sparkle effect

2. **Post-process depth-aware** (`include/misc/diamond_dust_postprocess.glsl`):
   - Renders crystals between player and terrain
   - Uses depth buffer to show sparkles at varying distances
   - Called from `final.fsh` as post-process effect
   - Each crystal has a procedural "depth layer" - only visible when terrain is behind it
   - Creates mid-range sparkle effect against blocks/terrain

Both implementations share the same conditions and settings but complement each other:
- Sky version: distant crystals visible in open sky areas
- Post-process version: near/mid-range crystals visible against terrain

**Implementation Example**:
```glsl
// Sky version (in sky.glsl)
sky += draw_diamond_dust(ray_dir, sun_dir, cameraPosition.z, rainStrength, frameTimeCounter);

// Post-process version (in final.fsh)
fragment_color = apply_diamond_dust_postprocess(
    fragment_color, uv, depth, cameraPosition.z,
    sun_dir, view_direction, rainStrength, frameTimeCounter
);
```

---

### 5. Weather Intensity & Variation System

#### 5.1 Rain Intensity Tiers

| Tier | Intensity | Visual Effects |
|------|-----------|----------------|
| Light Drizzle | 0.0-0.3 | Sparse particles, minimal fog increase |
| Moderate Rain | 0.3-0.6 | Standard rain, moderate fog |
| Heavy Rain | 0.6-0.85 | Dense particles, significant fog, darker sky |
| Downpour/Storm | 0.85-1.0 | Maximum density, heavy fog, very dark, lightning |

**Modifiers by Region**:
- **Tropical**: More frequent heavy rain, sudden onset
- **Temperate**: Varied intensity, longer duration
- **Subarctic**: Light persistent rain/drizzle

#### 5.2 Snow Intensity Tiers

| Tier | Conditions | Visual Effects |
|------|------------|----------------|
| Light Flurries | Low intensity, any wind | Sparse, drifting snowflakes |
| Steady Snow | Moderate intensity | Regular snowfall |
| Heavy Snow | High intensity | Dense, reduced visibility |
| Blizzard | High intensity + high wind | Horizontal snow, severe whiteout, fog |

**Blizzard Conditions**:
```glsl
float blizzard_factor = rainStrength * wind_factor * polar_factor * winterFactor;
// Adds horizontal displacement to snow particles
// Increases fog density dramatically
// Reduces visibility range
```

#### 5.3 Tropical Storms

**Conditions**: Tropical latitude + high rainStrength + summer/autumn

**Effects**:
- Extreme rain density
- Dramatic sky darkening
- Enhanced wind effects on rain angle
- Possible waterspout/cyclone ambient effects

#### 5.4 Sky Darkness by Weather

```glsl
// Base darkness from rain
float weather_darkness = rainStrength * 0.4;

// Storm intensity multiplier
float storm_intensity = smoothstep(0.7, 1.0, rainStrength);
weather_darkness += storm_intensity * 0.3;

// Tropical storm boost
weather_darkness += tropical_factor * storm_intensity * 0.2;

// Apply to sky and ambient lighting
sky_color *= (1.0 - weather_darkness);
ambient_light *= (1.0 - weather_darkness * 0.5);
```

---

### 6. Wind & Particle Effects

#### 6.1 Dust/Sand in Arid Regions

**Conditions**: Subtropical/tropical arid areas + wind + dry weather

#### 6.2 Wind-Affected Fog

```glsl
// Fog density reduction with wind (disperses fog)
float wind_fog_modifier = 1.0 - wind_factor * 0.3;

// But fog moves/animates more with wind
float fog_animation_speed = base_speed * (1.0 + wind_factor * 2.0);
```

---

### 7. Seasonal Light Tinting & Intensity

#### 7.1 Seasonal Color Temperature

| Season | Color Shift | Rationale |
|--------|-------------|-----------|
| Spring | Slightly cool, high saturation | Fresh, vibrant |
| Summer | Warm, high intensity | Strong sun |
| Autumn | Warm amber tint | Golden hour extended |
| Winter | Cool blue tint, lower intensity | Weak sun angle |

**Implementation**:
```glsl
vec3 seasonal_tint = mix(
    mix(spring_tint, summer_tint, smoothstep(0.0, 0.25, yearProgress)),
    mix(autumn_tint, winter_tint, smoothstep(0.5, 0.75, yearProgress)),
    smoothstep(0.25, 0.5, yearProgress)
);

// Intensity variation
float seasonal_intensity = mix(0.9, 1.1, summerFactor) * mix(1.0, 0.85, winterFactor);
```

#### 7.2 Latitude-Modified Seasonal Intensity

At higher latitudes, seasonal variation is more extreme:
```glsl
// Polar regions: extreme seasonal variation
// Equatorial: minimal seasonal variation
float seasonal_extremity = mix(0.3, 1.0, polar_factor);

float winter_darkening = winterFactor * seasonal_extremity * 0.3;
float summer_brightening = summerFactor * seasonal_extremity * 0.15;
```

#### 7.3 Dawn/Dusk Duration by Season & Latitude

**Golden Hour Duration**:
- Summer at high latitudes: Extended golden hour (sun at low angle for longer)
- Winter at high latitudes: Brief or non-existent
- Equatorial: Consistent year-round

```glsl
// Extend twilight transition at high latitudes in summer
float twilight_extension = polar_factor * summerFactor;
float golden_hour_width = base_width * (1.0 + twilight_extension);
```

---

### 8. Hypothermia / Cold Stress Effects ✓

**Status**: IMPLEMENTED

**Trigger**: Player body temperature drops below -35 (Cold Sweat internal scale, where 0 = neutral)

**Effects**:
- Screen shake (shivering): Sharp, jittery tremors that increase with cold intensity
- Blue vignette: Constant frost tint creeping from screen edges (additive, no darkening)
- Frost texture overlay: Custom texture (image/frost_overlay.png) fading in from edges
- Chromatic aberration: Color separation at edges like light through ice
- Day/night compensation: Frost visibility adjusts based on scene brightness

**Implementation**:
```glsl
// Linear intensity from -35 to -100
float linear_intensity = (HYPOTHERMIA_TEMP_START - player_temp) / (HYPOTHERMIA_TEMP_START - HYPOTHERMIA_TEMP_MAX);

// Applied effects
vec2 shaken_uv = apply_hypothermia_shake(uv, linear_intensity, time);
color = apply_hypothermia_vignette(color, uv, linear_intensity, time);
color = apply_hypothermia_frost(color, color_sampler, frost_sampler, uv, linear_intensity, time);
```

**Frost Texture Requirements** (image/frost_overlay.png):
- RGBA PNG, recommended 512x512 or 1024x1024
- RGB = frost color (white/pale blue ice crystals)
- Alpha = opacity (where frost appears - concentrate toward edges/corners)
- Design for screen-space overlay, not tiling

---

## Implementation Priority

### Phase 1: Core Latitude System
1. Add latitude calculation helpers
2. Restrict aurora to high latitudes (subarctic/polar)
3. Test and tune latitude scale parameters

**Note**: Fog behavior and density may be investigated separately, but fog colors will inherit from environmental lighting changes rather than being explicitly latitude-based.

### Phase 2: Weather Intensity
1. Implement rain/snow intensity tiers
2. Add weather-based sky darkening
3. Implement blizzard conditions for polar regions
4. Add tropical storm intensity modifier

### Phase 3: Seasonal Light
1. Add seasonal color temperature shifts
2. Implement latitude-modified seasonal intensity
3. Add dawn/dusk duration variations

### Phase 4: Particle Effects
1. ~~Ice crystal/diamond dust effect~~ ✓ (implemented)
2. Wind-affected precipitation angles

### Phase 5: Player Temperature Effects ✓
1. ~~Calibrate Cold Sweat internal values~~ ✓ (done: -100 to 100 scale, 0 = neutral)
2. ~~Add heat stress screen effects~~ ✓ (implemented as heatstroke effects)
3. ~~Add cold stress screen effects~~ ✓ (implemented as hypothermia effects)

---

## Configuration Parameters

New settings to add to `settings.glsl`:

```glsl
// Latitude System
#define LATITUDE_EFFECTS
#define LATITUDE_SCALE 8000.0        // Blocks per major climate transition
#define LATITUDE_ORIGIN_Z 0.0        // Z coordinate of equator

// Weather Intensity
#define DYNAMIC_WEATHER_INTENSITY
#define BLIZZARD_EFFECTS
#define TROPICAL_STORM_EFFECTS

// Seasonal Lighting
#define SEASONAL_LIGHT_TINT
#define SEASONAL_LIGHT_INTENSITY
#define LATITUDE_SEASONAL_EXTREMITY

// Particle Effects
#define DIAMOND_DUST_EFFECT

// Player Temperature
#define PLAYER_TEMP_EFFECTS
#define HEAT_STRESS_THRESHOLD 50.0  // Internal Cold Sweat value (needs calibration)
#define COLD_STRESS_THRESHOLD -50.0
```

---

## Technical Considerations

### Performance
- Latitude calculations are cheap (just math on `cameraPosition.z`)
- Particle effects need careful optimization
- Diamond dust should use LOD or be view-distance limited
- Weather intensity variations are essentially free

### Compatibility
- Effects should gracefully degrade when mods not present
- Use default/fallback values for missing uniforms
- Latitude effects work independently of mod integration

### Testing
- Test at various world coordinates
- Verify transitions are smooth
- Check performance impact of new effects
- Validate seasonal/temperature thresholds match gameplay feel
