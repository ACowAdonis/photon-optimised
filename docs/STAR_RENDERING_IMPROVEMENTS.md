# Star Rendering Improvements Plan

## Current Implementation

**File:** `shaders/include/sky/stars.glsl`

The current star system uses:
- Procedural hash-based generation at grid coordinates
- 4-point bilinear interpolation with cubic smoothing
- Fixed temperature range (4500K-8500K)
- Simple cosine-based twinkling
- Stereographic projection with 600.0 scale factor

## Known Issues

### 1. Squarish Star Appearance (Priority: HIGH)

**Problem:** Stars appear square/diamond-shaped rather than round.

**Root Cause:** The `stable_star_field()` function uses bilinear interpolation:
```glsl
star * (1.0 - f.x) * (1.0 - f.y)  // This creates axis-aligned square falloff
```

This multiplication of X and Y factors creates a rectangular brightness profile instead of a circular one.

**Solution:** Replace bilinear interpolation with radial distance-based falloff:
```glsl
vec3 stable_star_field(vec2 coord, float star_threshold) {
    vec2 i = floor(coord);
    vec2 f = fract(coord);

    vec3 result = vec3(0.0);

    // Sample 3x3 neighborhood for smooth circular stars
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec2 offset = vec2(x, y);
            vec2 star_pos = i + offset;

            // Get star properties at this grid point
            vec4 noise = hash4(star_pos);

            // Star center is offset within its cell
            vec2 star_center = offset + noise.xy * 0.5 - 0.25;

            // Radial distance from current position to star center
            float dist = length(f - star_center);

            // Circular falloff (gaussian-like)
            float falloff = exp(-dist * dist * 16.0);

            // Apply star brightness threshold
            float star = linear_step(star_threshold, 1.0, noise.z);
            star = pow16(star) * falloff;

            // Color and twinkle
            float temp = mix(min_temp, max_temp, noise.w);
            result += star * blackbody(temp);
        }
    }
    return result * STARS_INTENSITY;
}
```

**Performance Impact:** MEDIUM
- Increases from 4 to 9 grid samples
- But hash4() is cheap, and this only runs for sky pixels
- Could optimize with 2x2 sampling for distant/dim stars

---

## Planned Improvements

### 2. Atmospheric Scintillation (Priority: HIGH)

**Goal:** Stars twinkle more intensely near the horizon due to atmospheric turbulence.

**Implementation:**
```glsl
// In unstable_star_field(), modify twinkling:
float horizon_factor = 1.0 - abs(ray_dir_y);
float scintillation = 1.0 + 3.0 * sqr(sqr(horizon_factor));
twinkle_amount *= scintillation;
```

**Performance Impact:** NEGLIGIBLE
- Single multiply-add operation
- Requires passing `ray_dir.y` to the function

---

### 3. Extended Color Temperature Range (Priority: MEDIUM)

**Goal:** More color variety - cool red giants and hot blue stars.

**Current:** 4500K - 8500K (K-type orange to A-type white)
**Proposed:** 3000K - 15000K (M-type red to B-type blue)

```glsl
const float min_temp = 3000.0;  // Red giants (Betelgeuse-like)
const float max_temp = 15000.0; // Blue giants (Rigel-like)
```

**Performance Impact:** NONE
- Constants only, no runtime change

---

### 4. Star Magnitude Classes (Priority: MEDIUM)

**Goal:** Visual depth with rare bright stars, common dim stars.

**Implementation:**
```glsl
float magnitude_class = noise.x;
float star_brightness, star_size;

if (magnitude_class > 0.997) {
    // Very rare bright stars (0.3%) - magnitude -1 to 1
    star_brightness = 3.0;
    star_size = 2.0;
} else if (magnitude_class > 0.97) {
    // Uncommon medium stars (3%) - magnitude 2-3
    star_brightness = 1.0;
    star_size = 1.2;
} else {
    // Common dim stars - magnitude 4+
    star_brightness = linear_step(star_threshold, 1.0, noise.x);
    star_brightness = pow16(star_brightness);
    star_size = 0.8;
}
```

**Performance Impact:** LOW
- Few conditional branches
- Could use step() functions to avoid branching

---

### 5. Shooting Stars / Meteors (Priority: LOW)

**Goal:** Occasional meteor streaks for visual interest.

**Implementation:** New function `draw_meteor()`:
```glsl
vec3 draw_meteor(vec3 ray_dir, float time) {
    // Spawn meteor every 20-40 seconds
    float meteor_cycle = 30.0;
    float meteor_seed = floor(time / meteor_cycle);
    float meteor_phase = fract(time / meteor_cycle);

    // Only visible for first 15% of cycle
    if (meteor_phase > 0.15) return vec3(0.0);

    // Random start position and direction
    vec2 origin = hash2(vec2(meteor_seed, 0.0)) * 1.6 - 0.8;
    vec2 dir = normalize(hash2(vec2(meteor_seed, 1.0)) - 0.5);

    // Project ray to 2D
    vec2 sky_coord = ray_dir.xy / (abs(ray_dir.z) + 0.001);

    // Distance to meteor trail line
    vec2 to_point = sky_coord - origin;
    float along = dot(to_point, dir);
    float trail_pos = along - meteor_phase * 3.0;

    if (trail_pos < 0.0 || trail_pos > 0.3) return vec3(0.0);

    float perp = length(to_point - dir * along);
    float brightness = exp(-perp * 100.0) * (1.0 - trail_pos / 0.3);

    return vec3(1.0, 0.95, 0.85) * brightness * 5.0;
}
```

**Performance Impact:** LOW
- Only ~20 operations
- Early-exit for 85% of time
- Could be toggled with `#define SHOOTING_STARS`

---

### 6. Milky Way Star Density (Priority: LOW)

**Goal:** More stars visible in the galactic plane.

**Implementation:**
```glsl
// In draw_stars(), modify threshold based on galaxy:
float galaxy_density_boost = 1.0 + 1.5 * galaxy_luminance;
float star_threshold = 1.0 - 0.05 * STARS_COVERAGE * galaxy_density_boost * ...;
```

**Performance Impact:** NEGLIGIBLE
- Single multiply operation

---

## Performance Summary

| Improvement | Cost | Visual Impact | Priority |
|-------------|------|---------------|----------|
| Round stars (3x3 grid) | +5 hash4 calls | HIGH | HIGH |
| Round stars (2x2 grid) | +0 hash4 calls | MEDIUM | HIGH |
| Atmospheric scintillation | ~0 | MEDIUM | HIGH |
| Extended temperatures | 0 | LOW | MEDIUM |
| Magnitude classes | ~2 branches | MEDIUM | MEDIUM |
| Shooting stars | ~20 ops (early exit) | LOW | LOW |
| Galaxy density boost | ~1 op | LOW | LOW |

### Overall Performance Notes

1. **Star rendering only affects sky pixels** - typically <30% of screen
2. **Stars are rendered once to sky map** - not per-frame for every pixel
3. **hash4() is very cheap** - ~15 ALU operations
4. **Main cost is the stable_star_field loop** - currently 4 iterations

### Recommended Implementation Order

1. **Round stars fix** - Highest visual impact, addresses main complaint
2. **Atmospheric scintillation** - Free realism boost
3. **Extended temperature range** - Zero cost improvement
4. **Magnitude classes** - Adds visual depth
5. **Shooting stars** - Optional feature with toggle

---

## Settings to Add

```glsl
// settings.glsl additions:
#define STARS_ROUND_FALLOFF        // Use circular falloff (slight perf cost)
#define STARS_SCINTILLATION        // Horizon twinkling effect
//#define SHOOTING_STARS           // Occasional meteor streaks (disabled by default)
#define STARS_TEMPERATURE_MIN 3000.0
#define STARS_TEMPERATURE_MAX 15000.0
```

---

## Testing Checklist

- [ ] Verify stars appear round, not square
- [ ] Check star visibility at different times of night
- [ ] Confirm no visible grid patterns
- [ ] Test performance impact with shader profiler
- [ ] Verify twinkling increases near horizon
- [ ] Check color variety (red and blue stars visible)
- [ ] Test in different dimensions (Overworld, End)
- [ ] Verify shooting stars don't cause flickering (if implemented)

---

# Galaxy Rendering Improvements

## Current Implementation

**Files:**
- `shaders/include/sky/sky.glsl` (lines 44-72) - `draw_galaxy()` function
- `shaders/image/galaxy.png` - Source texture (2048x1024, equirectangular)
- `shaders/image/galaxy.png.mcmeta` - Texture settings (blur: true)

**Current approach:**
```glsl
vec3 draw_galaxy(vec3 ray_dir, out float galaxy_luminance) {
    const vec3 galaxy_tint = vec3(0.75, 0.66, 1.0) * GALAXY_INTENSITY;

    // Spherical projection
    float lon = atan(ray_dir.x, ray_dir.z);
    float lat = fast_acos(-ray_dir.y);

    vec3 galaxy = texture(galaxy_sampler, vec2(lon * rcp(tau) + 0.5, lat * rcp(pi))).rgb;

    galaxy = srgb_eotf_inv(galaxy) * rec709_to_working_color;
    galaxy *= galaxy_intensity * galaxy_tint;

    // Saturation boost (factor of 2.0 INCREASES saturation)
    galaxy = mix(vec3(galaxy_luminance), galaxy, 2.0);

    return max0(galaxy);
}
```

## Known Issues

### 1. Pixelated/Low Resolution Appearance (Priority: HIGH)

**Problem:** The galaxy texture appears blocky, especially near zenith and when looking closely.

**Root Causes:**
- **Texture resolution:** 2048x1024 is stretched across entire sky sphere
- **Equirectangular distortion:** Pixels near poles cover more angular area
- **No mipmapping strategy:** Single LOD for all viewing angles

**Analysis:**
- At 2048x1024, each texel covers ~0.18° of sky
- Human eye can resolve ~1 arcminute (0.017°) - texture is 10x coarser
- Polar regions are even worse due to projection stretching

---

### 2. Pinkish/Magenta Color Cast (Priority: HIGH)

**Problem:** Galaxy appears too pink/magenta instead of natural brown/blue tones.

**Root Causes:**

1. **Source image color:** The original `galaxy.png` likely has pink tones
2. **Tint multiplier:** `vec3(0.75, 0.66, 1.0)` boosts blue but doesn't suppress pink
3. **Saturation boost:** `mix(..., 2.0)` AMPLIFIES existing colors including pink
   - Factor > 1.0 extrapolates beyond original, making saturated colors more saturated

**Real Milky Way colors:**
- Core regions: Warm yellow/orange (old stars, dust)
- Spiral arms: Blue-white (young stars)
- Dust lanes: Dark brown/reddish absorption
- Overall: Should lean warm brown/gold with blue accents, NOT pink

---

## Proposed Solutions

### Option A: Replace Galaxy Texture (Easiest)

**Requirements for new image:**
- **Resolution:** 4096x2048 minimum, 8192x4096 ideal
- **Format:** PNG, 8-bit or 16-bit RGB
- **Projection:** Equirectangular (latitude/longitude)
- **Color profile:** sRGB, color-corrected to remove pink cast
- **Content:** Realistic Milky Way panorama with brown/gold core, blue arms

**Recommended sources:**
- ESO/ESA astronomical panoramas (check licensing)
- NASA Gaia star survey composites
- Custom composite from astrophotography

**Shader changes needed:**
```glsl
// Adjust tint to complement new image
const vec3 galaxy_tint = vec3(0.9, 0.85, 1.0) * GALAXY_INTENSITY;  // Less aggressive

// Reduce saturation boost
galaxy = mix(vec3(galaxy_luminance), galaxy, 1.3);  // Was 2.0
```

**Performance Impact:** NONE (same texture lookup)

---

### Option B: Color Correction in Shader (Medium effort)

**Apply color grading to fix pink cast without replacing image:**

```glsl
vec3 draw_galaxy(vec3 ray_dir, out float galaxy_luminance) {
    // ... existing texture lookup ...

    // Color correction to shift pink toward brown/blue
    // Reduce magenta by suppressing red in mid-tones
    float pink_suppression = smoothstep(0.1, 0.4, galaxy.r - galaxy.b);
    galaxy.r *= 1.0 - 0.3 * pink_suppression;

    // Warm up the core regions (high luminance = more orange)
    float core_warmth = smoothstep(0.3, 0.8, galaxy_luminance);
    galaxy *= mix(vec3(1.0), vec3(1.1, 0.95, 0.85), core_warmth);

    // Cooler blue tint for dim regions (spiral arms)
    float arm_coolness = smoothstep(0.2, 0.05, galaxy_luminance);
    galaxy *= mix(vec3(1.0), vec3(0.9, 0.95, 1.1), arm_coolness);

    // Reduce overall saturation boost
    galaxy = mix(vec3(dot(galaxy, luminance_weights_rec709)), galaxy, 1.5);  // Was 2.0

    return max0(galaxy);
}
```

**Performance Impact:** LOW (~5 extra ALU ops)

---

### Option C: Procedural Galaxy (Most effort, best quality)

**Generate the Milky Way band procedurally instead of using a texture.**

**Advantages:**
- Infinite resolution - no pixelation ever
- Perfect color control
- Can integrate with star density
- Seamless with procedural stars

**Implementation approach:**

```glsl
vec3 draw_procedural_galaxy(vec3 ray_dir, out float galaxy_luminance) {
    // Galactic coordinate transformation
    // Milky Way runs roughly along celestial equator, tilted ~60°
    const vec3 galactic_north = normalize(vec3(0.0, 0.46, 0.89));  // Approximate
    const vec3 galactic_center = normalize(vec3(-0.87, -0.22, 0.44));

    float galactic_lat = asin(dot(ray_dir, galactic_north));
    float galactic_lon = atan(
        dot(ray_dir, cross(galactic_north, galactic_center)),
        dot(ray_dir, galactic_center)
    );

    // Core brightness - gaussian centered on galactic center
    float core_dist = length(vec2(galactic_lon, galactic_lat * 2.0));
    float core = exp(-core_dist * core_dist * 2.0);

    // Galactic plane - narrow band along equator
    float plane = exp(-galactic_lat * galactic_lat * 50.0);

    // Add fractal noise for dust lanes and structure
    vec2 noise_coord = vec2(galactic_lon * 3.0, galactic_lat * 10.0);
    float structure = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; ++i) {
        structure += amp * (texture(noisetex, noise_coord * 0.1).r - 0.5);
        noise_coord *= 2.1;
        amp *= 0.5;
    }

    // Combine components
    float brightness = plane * (0.3 + 0.7 * core) * (0.7 + 0.3 * structure);

    // Color gradient: warm core -> cool arms
    vec3 core_color = vec3(1.0, 0.85, 0.65);   // Warm gold
    vec3 arm_color = vec3(0.7, 0.8, 1.0);      // Cool blue
    vec3 dust_color = vec3(0.4, 0.25, 0.15);   // Brown dust

    vec3 color = mix(arm_color, core_color, core);
    color = mix(color, dust_color, max0(-structure) * plane);

    galaxy_luminance = brightness;
    return color * brightness * GALAXY_INTENSITY;
}
```

**Performance Impact:** MEDIUM
- ~50 ALU ops + 4 noise texture samples
- But eliminates 2K texture memory bandwidth
- Could be cached to sky map (rendered once)

---

### Option D: Hybrid Approach (Recommended)

**Use low-res density map + procedural detail:**

1. **Density map:** 512x256 grayscale texture defining overall structure
2. **Procedural color:** Generate colors based on position and density
3. **Procedural detail:** Add high-frequency noise for dust lanes

```glsl
vec3 draw_hybrid_galaxy(vec3 ray_dir, out float galaxy_luminance) {
    // Sample low-res density map
    float lon = atan(ray_dir.x, ray_dir.z);
    float lat = fast_acos(-ray_dir.y);
    float density = texture(galaxy_density_map, vec2(lon * rcp(tau) + 0.5, lat * rcp(pi))).r;

    // High-frequency procedural detail
    vec2 detail_coord = vec2(lon, lat) * 20.0;
    float detail = texture(noisetex, detail_coord * 0.05).r;
    detail = detail * 0.3 + 0.7;

    float brightness = density * detail;

    // Procedural coloring based on galactic position
    float galactic_lat_approx = abs(ray_dir.y * 0.8 + ray_dir.x * 0.2);
    float is_core = smoothstep(0.3, 0.0, galactic_lat_approx) * smoothstep(0.5, 0.8, density);

    vec3 color = mix(
        vec3(0.75, 0.82, 1.0),   // Arm color (blue-white)
        vec3(1.0, 0.88, 0.7),    // Core color (warm gold)
        is_core
    );

    galaxy_luminance = brightness;
    return color * brightness * GALAXY_INTENSITY;
}
```

**Performance Impact:** LOW
- Small texture + simple procedural
- Best quality/performance ratio

---

## Image Replacement Guidelines

If supplying a new galaxy image:

### Technical Requirements

| Property | Minimum | Recommended |
|----------|---------|-------------|
| Resolution | 4096x2048 | 8192x4096 |
| Bit depth | 8-bit | 16-bit |
| Format | PNG | PNG or EXR |
| Projection | Equirectangular | Equirectangular |
| Color space | sRGB | sRGB or Linear |

### Color Guidelines

**DO include:**
- Warm yellow/orange galactic core (color temp ~4000K)
- Blue-white spiral arm regions (color temp ~8000K)
- Dark brown dust lanes
- Subtle red emission nebulae (Hα regions)

**DO NOT include:**
- Magenta/pink overall cast
- Over-saturated neon colors
- Visible image seams
- Star points (handled by star system)

### Recommended Edits to Source Images

1. **Desaturate slightly** (reduce saturation 10-20%)
2. **Shift hue** away from magenta toward yellow/orange
3. **Increase contrast** in dust lanes
4. **Remove bright stars** (will be added procedurally)
5. **Ensure seamless wrapping** at longitude edges

---

## Performance Summary - Galaxy Options

| Approach | Texture Memory | ALU Cost | Quality | Effort |
|----------|---------------|----------|---------|--------|
| Current | 6 MB (2K) | Low | Low | - |
| New 4K texture | 24 MB | Low | Medium | Low |
| New 8K texture | 96 MB | Low | High | Low |
| Shader color fix | 6 MB | Low | Medium | Low |
| Procedural | 0 | Medium | High | High |
| Hybrid | 0.5 MB | Low | High | Medium |

---

## Galaxy Testing Checklist

- [ ] No visible pixelation when looking at zenith
- [ ] Color appears natural (warm brown/gold core, blue arms)
- [ ] No pink/magenta cast visible
- [ ] Smooth transition at texture seams (longitude wrap)
- [ ] Appropriate brightness relative to stars
- [ ] No banding in gradients
- [ ] Performance acceptable (check frame times)

---

# Implementation Roadmap

## Phase 1: Star Rendering Improvements

### 1.1 Round Star Fix (Priority: HIGH)
- [ ] Replace bilinear interpolation with radial distance falloff
- [ ] Test 2×2 sampling (performance-neutral)
- [ ] Test 3×3 sampling if 2×2 insufficient
- [ ] Verify no visible grid patterns remain
- [ ] Confirm stars appear circular at all zoom levels

### 1.2 Atmospheric Scintillation (Priority: HIGH)
- [ ] Add `ray_dir.y` parameter to star functions
- [ ] Implement horizon-dependent twinkle intensity
- [ ] Tune scintillation curve for realism
- [ ] Test at various horizon angles

### 1.3 Extended Color Temperature (Priority: MEDIUM)
- [ ] Expand range from 4500-8500K to 3000-15000K
- [ ] Verify red giants visible (Betelgeuse-like)
- [ ] Verify blue giants visible (Rigel-like)
- [ ] Check color distribution looks natural

### 1.4 Star Magnitude Classes (Priority: MEDIUM)
- [ ] Implement 3-tier brightness system
- [ ] Rare bright stars (0.3%) with larger size
- [ ] Medium stars (3%) with moderate brightness
- [ ] Common dim stars (96.7%) as background
- [ ] Tune distribution for visual appeal

### 1.5 Shooting Stars (Priority: LOW, Optional)
- [ ] Implement `draw_meteor()` function
- [ ] Add `#define SHOOTING_STARS` toggle
- [ ] Configure spawn frequency (default: ~30 seconds)
- [ ] Test visual appearance and trail fade

---

## Phase 2: Galaxy Image Replacement

### 2.1 Source New Image
- [ ] Obtain high-resolution Milky Way panorama (4K-8K)
- [ ] Verify licensing permits use in shader pack
- [ ] Check source image color profile (sRGB preferred)

### 2.2 Image Transformation for Minecraft
- [ ] Convert to equirectangular projection if needed
- [ ] Ensure correct aspect ratio (2:1 for full sphere)
- [ ] Align galactic plane to desired sky position
- [ ] Handle coordinate system differences (Y-up vs Z-up)

### 2.3 Color Correction
- [ ] Remove any pink/magenta cast
- [ ] Shift overall tone toward warm brown/gold core
- [ ] Ensure blue-white spiral arm regions
- [ ] Desaturate slightly (10-20%) to prevent over-saturation in shader
- [ ] Adjust contrast in dust lanes

### 2.4 Star Removal from Galaxy Image
- [ ] Remove bright individual stars from source image
- [ ] Use clone/healing or frequency separation
- [ ] Stars will be added procedurally for consistency
- [ ] Preserve nebulae and diffuse glow

### 2.5 Seamless Wrapping
- [ ] Ensure left/right edges match perfectly (longitude wrap)
- [ ] Check for visible seams at 0°/360° boundary
- [ ] Verify smooth transition at poles (if visible)

### 2.6 Export and Integration
- [ ] Export as PNG (8-bit or 16-bit)
- [ ] Replace `shaders/image/galaxy.png`
- [ ] Update `galaxy.png.mcmeta` if needed
- [ ] Test in-game appearance

---

## Phase 3: Galaxy Shader Enhancements

### 3.1 Reduce Saturation Boost
- [ ] Change `mix(..., 2.0)` to `mix(..., 1.3)` or lower
- [ ] Test with new image to find optimal value
- [ ] Ensure colors remain vibrant but not over-saturated

### 3.2 Adjust Tint Multiplier
- [ ] Modify `galaxy_tint` to complement new image
- [ ] Remove pink-amplifying components
- [ ] Test various tint values for natural appearance

### 3.3 Star Density Integration
- [ ] Increase procedural star density in galaxy regions
- [ ] Use `galaxy_luminance` to modulate star threshold
- [ ] Create visible "star clouds" in Milky Way band
- [ ] Ensure smooth transition between galaxy and dark sky

### 3.4 Soft Glow/Blur Effect (Optional)
- [ ] Add subtle bloom around bright galaxy regions
- [ ] Implement as post-process or in-shader blur
- [ ] Use gaussian or similar soft falloff
- [ ] Keep performance impact minimal

### 3.5 Dust Lane Masking (Optional)
- [ ] Reduce star visibility in dark dust lanes
- [ ] Use galaxy texture luminance as mask
- [ ] Creates realistic "dark rift" appearance
- [ ] Subtle effect - stars should dim, not disappear

---

## Phase 4: Integration and Polish

### 4.1 Star-Galaxy Interaction
- [ ] Ensure stars and galaxy complement each other
- [ ] Bright galaxy regions should have denser stars
- [ ] Dark dust lanes should have fewer visible stars
- [ ] Color temperatures should harmonize

### 4.2 Brightness Balance
- [ ] Tune relative brightness of stars vs galaxy
- [ ] Galaxy should be subtle backdrop, not overwhelming
- [ ] Brightest stars should stand out against galaxy
- [ ] Test at various `STARS_INTENSITY` and `GALAXY_INTENSITY` values

### 4.3 Time-of-Night Transitions
- [ ] Verify smooth fade-in at dusk
- [ ] Check appearance at midnight (full visibility)
- [ ] Verify smooth fade-out at dawn
- [ ] Test moon interaction (bright moon should dim stars/galaxy)

### 4.4 Dimension-Specific Tuning
- [ ] Test Overworld appearance
- [ ] Test End dimension appearance
- [ ] Adjust parameters per-dimension if needed

---

## Task Summary

| ID | Task | Priority | Status | Dependencies |
|----|------|----------|--------|--------------|
| **Phase 1: Stars** |
| 1.1 | Round star fix | HIGH | TODO | None |
| 1.2 | Atmospheric scintillation | HIGH | TODO | None |
| 1.3 | Extended color temperature | MEDIUM | TODO | None |
| 1.4 | Star magnitude classes | MEDIUM | TODO | 1.1 |
| 1.5 | Shooting stars | LOW | TODO | None |
| **Phase 2: Galaxy Image** |
| 2.1 | Source new galaxy image | HIGH | TODO | None |
| 2.2 | Image transformation | HIGH | TODO | 2.1 |
| 2.3 | Color correction | HIGH | TODO | 2.1 |
| 2.4 | Star removal | MEDIUM | TODO | 2.1 |
| 2.5 | Seamless wrapping | HIGH | TODO | 2.2 |
| 2.6 | Export and integration | HIGH | TODO | 2.3, 2.4, 2.5 |
| **Phase 3: Galaxy Shader** |
| 3.1 | Reduce saturation boost | HIGH | TODO | 2.6 |
| 3.2 | Adjust tint multiplier | HIGH | TODO | 2.6 |
| 3.3 | Star density integration | MEDIUM | TODO | 1.1, 2.6 |
| 3.4 | Soft glow effect | LOW | TODO | 2.6 |
| 3.5 | Dust lane masking | LOW | TODO | 2.6, 3.3 |
| **Phase 4: Integration** |
| 4.1 | Star-galaxy interaction | MEDIUM | TODO | 3.3 |
| 4.2 | Brightness balance | MEDIUM | TODO | 3.1, 3.2 |
| 4.3 | Time transitions | LOW | TODO | 4.2 |
| 4.4 | Dimension tuning | LOW | TODO | 4.2 |
| **Phase 5: Moon** |
| 5.1 | Moon texture support | HIGH | TODO | None |
| 5.2 | Source moon texture | HIGH | TODO | None |
| 5.3 | Earthshine effect | MEDIUM | TODO | 5.1 |
| 5.4 | Soft terminator | MEDIUM | TODO | 5.1 |
| 5.5 | Limb darkening | LOW | TODO | 5.1 |
| 5.6 | Moon settings integration | MEDIUM | TODO | 5.1, 5.3, 5.4 |

---

## Notes

### Image Transformation Considerations

When transforming a source image to Minecraft's sky projection:

1. **Coordinate System:**
   - Minecraft uses Y-up coordinate system
   - Many astronomical images use Z-up or celestial coordinates
   - May need 90° rotation or axis swap

2. **Projection Type:**
   - Target: Equirectangular (cylindrical)
   - Common sources: Equirectangular, Hammer, Mollweide, fisheye
   - Use GIMP/Photoshop polar coordinates or specialized tools

3. **Field of View:**
   - Full sphere = 360° × 180°
   - Aspect ratio must be exactly 2:1
   - Partial panoramas need padding or stretching

4. **Galactic Plane Orientation:**
   - Real Milky Way is tilted ~60° to celestial equator
   - May want to adjust for aesthetic positioning in Minecraft sky
   - Consider where galactic center appears relative to moon

### Recommended Workflow

```
1. Source high-res image
   ↓
2. Convert projection (if needed)
   ↓
3. Rotate/align galactic plane
   ↓
4. Color correct (remove pink, warm up core)
   ↓
5. Remove bright stars
   ↓
6. Ensure seamless wrap
   ↓
7. Desaturate 10-20%
   ↓
8. Export PNG → shaders/image/galaxy.png
   ↓
9. Adjust shader parameters (tint, saturation)
   ↓
10. Test and iterate
```

### Performance Budget

All planned changes combined should add no more than:
- **VRAM:** +90 MB maximum (8K texture)
- **Frame time:** +0.1 ms maximum (sky pixels only)
- **Acceptable on:** GTX 1060 / RX 580 or better

---

# Moon Rendering Improvements

## Current Implementation

**Files:**
- `shaders/program/gbuffers_skytextured.fsh` (lines 72-139) - Main moon rendering
- `shaders/include/sky/sky.glsl` - Moon integration with atmosphere
- `shaders/shaders.properties` (lines 473-487) - Phase brightness values

**Current approach:**
- **Procedural rendering** (not texture-based) when `VANILLA_MOON` is disabled
- Uses noise texture (`noisetex`) for surface detail (craters/features)
- Moon phases calculated programmatically with shadow terminator
- Two-color system: lit surface + subtle glow

**Current settings** (in `settings.glsl`):
```glsl
#define MOON_PHASE_AFFECTS_BRIGHTNESS
#define MOON_R 0.75
#define MOON_G 0.83
#define MOON_B 1.00
#define MOON_I 1.00
#define MOON_ANGULAR_RADIUS 0.7  // degrees (range: 0.1-3.0)
//#define VANILLA_MOON           // disabled = procedural moon
```

**Phase handling:**
- `moonPhase` uniform: 0-7 (Full → Waning → New → Waxing → Full)
- Shadow terminator calculated from `offset.x` position
- Phase 4 (New Moon) = completely dark, not rendered

---

## Known Issues

### 1. Low Detail Surface Features

**Problem:** Procedural noise creates generic, unrealistic lunar surface.

**Root Cause:**
- Simple Perlin noise doesn't match real lunar maria/crater patterns
- No distinction between dark maria (seas) and bright highlands
- Surface detail formula is basic: `pow1d5(noise.x) * 0.75 + 0.6 * cube(noise.y)`

### 2. Uniform Coloration

**Problem:** Moon appears uniformly colored without realistic variation.

**Real Moon features:**
- Dark gray maria (ancient lava plains)
- Bright white/gray highlands
- Tycho crater rays (bright streaks)
- Subtle color variations (blue titanium-rich, orange glass regions)

### 3. Sharp Phase Terminator

**Problem:** Day/night terminator on moon is too sharp/clean.

**Reality:** Terminator has soft gradient due to:
- Lunar surface roughness (mountains/craters catch light)
- No atmosphere, but terrain creates penumbra
- Earthshine illuminates dark side slightly

### 4. No Earthshine

**Problem:** Dark side of moon is completely black.

**Reality:** Earth reflects sunlight onto moon's dark side, creating subtle illumination visible during crescent phases.

---

## Proposed Solutions

### Option A: High-Resolution Moon Texture (Recommended)

**Replace procedural generation with realistic lunar texture.**

**Requirements for moon texture:**
- **Resolution:** 2048×2048 minimum, 4096×4096 ideal
- **Format:** PNG, 8-bit RGB
- **Content:** Orthographic lunar surface (as seen from Earth)
- **Color:** Grayscale or subtle natural color variation
- **Features:** Visible maria, major craters (Tycho, Copernicus), highlands

**Implementation approach:**
```glsl
// In gbuffers_skytextured.fsh, replace procedural section:
#ifdef MOON_TEXTURE
    // Sample lunar surface texture
    vec2 moon_uv = offset * 0.5 + 0.5;  // Map [-1,1] to [0,1]
    vec3 moon_surface = texture(moon_texture_sampler, moon_uv).rgb;

    // Apply phase shadow
    moon_surface *= moon_shadow;

    // Add earthshine to dark side
    #ifdef MOON_EARTHSHINE
    float earthshine = (1.0 - moon_shadow) * 0.02 * earthshine_intensity;
    moon_surface += vec3(0.3, 0.35, 0.45) * earthshine;  // Bluish earthshine
    #endif

    frag_color = moon_surface * lit_color;
#else
    // Existing procedural code...
#endif
```

**Performance Impact:** NEGLIGIBLE
- Single texture lookup replaces noise sampling
- Actually slightly faster than procedural

---

### Option B: Enhanced Procedural Moon

**Improve procedural generation without textures.**

**Enhancements:**
1. Add distinct maria (dark regions) using shaped noise
2. Add major crater patterns
3. Soft terminator with terrain-based roughness
4. Earthshine for dark side

```glsl
// Enhanced procedural moon surface
float get_moon_surface(vec2 uv) {
    // Base lunar highlands (bright)
    float highlands = 0.8;

    // Maria (dark seas) - approximate shapes
    float mare_serenitatis = 1.0 - smoothstep(0.2, 0.25, length(uv - vec2(0.1, 0.2)));
    float mare_tranquillitatis = 1.0 - smoothstep(0.15, 0.2, length(uv - vec2(0.2, 0.0)));
    float mare_imbrium = 1.0 - smoothstep(0.25, 0.3, length(uv - vec2(-0.2, 0.25)));

    float maria = max(mare_serenitatis, max(mare_tranquillitatis, mare_imbrium));

    // Crater detail from noise
    float craters = texture(noisetex, uv * 4.0).r * 0.15;

    // Tycho rays (bright streaks from impact)
    float tycho_dist = length(uv - vec2(0.0, -0.4));
    float tycho_rays = smoothstep(0.3, 0.0, tycho_dist) * 0.2;

    return highlands - maria * 0.4 + craters + tycho_rays;
}
```

**Performance Impact:** LOW
- Slightly more ALU than current
- No additional textures needed

---

### Option C: Phase-Specific Textures

**Use 8 separate textures for each moon phase.**

**Advantages:**
- Perfectly accurate phase appearance
- Can include pre-rendered earthshine
- Highest visual quality

**Disadvantages:**
- 8× texture memory
- More complex texture management
- Less flexible for custom phase values

**Implementation:**
```glsl
// Select texture based on moonPhase uniform
vec3 moon_surface = texture(moon_phase_textures[moonPhase], moon_uv).rgb;
```

**Performance Impact:** NEGLIGIBLE (single texture lookup)
**Memory Impact:** HIGH (8 × 4MB = 32MB for 2K textures)

---

## Moon Texture Guidelines

If supplying custom moon texture(s):

### Technical Requirements

| Property | Minimum | Recommended |
|----------|---------|-------------|
| Resolution | 1024×1024 | 2048×2048 or 4096×4096 |
| Bit depth | 8-bit | 8-bit (16-bit unnecessary) |
| Format | PNG | PNG |
| Projection | Orthographic (Earth-facing) | Orthographic |
| Orientation | North up, standard libration | Centered on visible face |

### Visual Guidelines

**DO include:**
- Mare Tranquillitatis, Mare Serenitatis, Mare Imbrium (dark regions)
- Tycho crater with ray system (bright streaks at bottom)
- Copernicus crater (prominent bright crater)
- Highland/maria contrast
- Subtle limb darkening (edges slightly darker)

**DO NOT include:**
- Stars or space background (must be transparent or masked)
- Atmospheric effects
- Overly saturated colors
- Phase shadowing (handled by shader)

### Recommended Sources

- NASA Lunar Reconnaissance Orbiter (LRO) imagery
- USGS Lunar maps
- Rendered 3D lunar globes (Celestia, etc.)
- Astrophotography composites

---

## Implementation Roadmap - Moon

### 5.1 Moon Texture Support (Priority: HIGH)
- [ ] Add `#define MOON_TEXTURE` toggle
- [ ] Create texture sampler for moon surface
- [ ] Implement UV mapping from ray direction
- [ ] Apply existing phase shadow system to texture
- [ ] Test with placeholder texture

### 5.2 Source/Create Moon Texture (Priority: HIGH)
- [ ] Obtain high-resolution lunar surface image
- [ ] Verify licensing for shader pack use
- [ ] Process to correct projection/orientation
- [ ] Remove any background/stars
- [ ] Adjust contrast and color balance

### 5.3 Earthshine Effect (Priority: MEDIUM)
- [ ] Add `#define MOON_EARTHSHINE` toggle
- [ ] Calculate earthshine intensity based on phase
- [ ] Apply subtle blue-tinted illumination to dark side
- [ ] Tune intensity for realism (should be subtle)

### 5.4 Soft Terminator (Priority: MEDIUM)
- [ ] Add surface roughness to terminator calculation
- [ ] Sample noise to create irregular day/night boundary
- [ ] Simulate light catching crater rims
- [ ] Test across all 8 phases

### 5.5 Limb Darkening (Priority: LOW)
- [ ] Darken moon edges slightly (realistic scattering)
- [ ] Use distance from center for falloff
- [ ] Subtle effect - should not be obvious

### 5.6 Settings Integration (Priority: MEDIUM)
- [ ] Add moon texture path to settings
- [ ] Add earthshine intensity slider
- [ ] Add terminator softness control
- [ ] Update settings.glsl with new options

---

## Moon Task Summary

| ID | Task | Priority | Status | Dependencies |
|----|------|----------|--------|--------------|
| 5.1 | Moon texture support | HIGH | TODO | None |
| 5.2 | Source moon texture | HIGH | TODO | None |
| 5.3 | Earthshine effect | MEDIUM | TODO | 5.1 |
| 5.4 | Soft terminator | MEDIUM | TODO | 5.1 |
| 5.5 | Limb darkening | LOW | TODO | 5.1 |
| 5.6 | Settings integration | MEDIUM | TODO | 5.1, 5.3, 5.4 |

---

## Moon Performance Summary

| Approach | Texture Memory | ALU Cost | Quality |
|----------|---------------|----------|---------|
| Current procedural | 0 | Low | Low |
| Single texture | 4-16 MB | Very Low | High |
| 8 phase textures | 32-128 MB | Very Low | Highest |
| Enhanced procedural | 0 | Medium | Medium |

**Recommendation:** Single high-resolution texture (Option A) provides the best quality/performance ratio. Earthshine and soft terminator can be added incrementally.
