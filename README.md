# Photon Optimised

A customised fork of [Photon Shaders](https://github.com/sixthsurge/photon) by SixthSurge, with environmental immersion enhancements and mod integrations.

![Screenshot](docs/images/rainbow.png)

## About This Fork

This is a modified version of Photon Shaders optimised for immersive gameplay with environmental effects that respond to latitude, seasons, and weather conditions. It includes integrations with mods like Serene Seasons and Cold Sweat for enhanced environmental feedback.

**Original Shader:** [Photon Shaders by SixthSurge](https://github.com/sixthsurge/photon)

## New Features

### Latitude-Based Climate System
- Sun path varies by latitude (higher latitudes = lower sun arc)
- Seasonal variation in sun height (summer sun higher, winter sun lower)
- Climate zones based on player Z-coordinate position
- Latitude affects aurora visibility, seasonal intensity, and environmental effects

### Seasonal Lighting Integration
- Integrates with Serene Seasons mod via `yearProgress` uniform
- Seasonal sun intensity variation (brighter summers, dimmer winters)
- Seasonal color tinting (cooler tones in winter)
- Seasonal ambient light adjustments

### Enhanced Storm System
- Storm intensity affects lighting (darker, desaturated light during storms)
- Shadow softening during overcast conditions (outdoor areas only)
- Underwater color responds to above-water weather
- Purkinje shift reduction during storms to prevent color compounding

### Temperature-Based Effects
- Hypothermia visual effects (frost overlay, desaturation, vignette)
- Heatstroke visual effects (heat distortion, warm tint)
- Integrates with Cold Sweat mod via `worldAmbientTemp` uniform
- Seasonal heat haze in hot biomes

### Sky and Celestial Improvements
- Custom moon texture with earthshine on shadowed portion
- Sidereal drift for stars (subtle rotation over time)
- Moon phase affects galaxy glow intensity
- Latitude-adjusted sun/moon reflections on distant water
- Enhanced crepuscular rays with proper horizon fade

### Beacon Beam Enhancements
- Pulsing glow effect with ethereal haze
- Soft edges via dithered alpha for dreamy appearance
- Enhanced bloom pickup for atmospheric glow
- Compatible with Via Romana path rendering

### Other Improvements
- Reduced wave intensity in frozen biomes (calmer water under ice)
- Lightning bolt rendering with natural eye adaptation flash
- Shiny entity rendering fixes (dedicated material mask for mobs)
- Various shadow and lighting fixes

## Requirements

- [Iris Shaders](https://irisshaders.dev/download) (recommended) or [OptiFine](https://optifine.net/home)
- Minecraft 1.16.5 or above

### Optional Mod Integrations
- [Serene Seasons](https://www.curseforge.com/minecraft/mc-mods/serene-seasons) - For seasonal lighting effects
- [Cold Sweat](https://www.curseforge.com/minecraft/mc-mods/cold-sweat) - For temperature-based visual effects
- [Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/distant-horizons) - Extended render distance support

## Installation

1. Install Iris or OptiFine
2. Download the shader pack from this repository
3. Place the zip file in your `.minecraft/shaderpacks` folder
4. Select the shader in-game

## Configuration

Many of the new features can be configured in the shader settings:
- **Latitude Sun Path** - Enable/disable latitude-based sun positioning
- **Seasonal Lighting** - Enable/disable Serene Seasons integration
- **Storm Intensity System** - Enable/disable enhanced storm effects
- **Hypothermia/Heatstroke Effects** - Enable/disable temperature visuals

## Original Photon Features

- Fully revamped sky, lighting and water
- Detailed clouds with many layers and cloud types
- Immersive weather system providing different skies each day
- Voxel-based colored lighting (enabled with Ultra profile, requires Iris)
- Screen-space reflections
- Volumetric fog
- Soft shadows with variable-size penumbras
- Detailed ambient occlusion (GTAO)
- Camera effects: bloom, depth of field, motion blur
- Much improved image quality with TAA, FXAA and CAS
- Advanced temporal upscaling (disabled by default) for low end devices
- Extensive settings menu allowing you to customize every aspect of the shader
- Full labPBR resource pack support

## Compatibility

- Nvidia, AMD and Intel GPUs
- Iris version 1.5 and above
- OptiFine on Minecraft 1.16.5 and above
- Compatible with Distant Horizons
- Apple Metal: Disable *SH Skylight* and *Colored Shadows*

## Credits

### Original Photon Shader
- [SixthSurge](https://github.com/sixthsurge) - Original Photon Shaders

### Original Acknowledgments
- [NakiriRuri](https://github.com/NakiriRuri) and [OrzMiku](https://github.com/Orzmiku) - Chinese Simplified translation
- [ChunghwaMC](https://github.com/ChunghwaMC) - Chinese Traditional translation
- [Jmayk](https://github.com/Jmayk-dev) - Italian translation
- [Timtaran](https://github.com/Timtaran) - Russian translation
- sincerity - Estonian translation
- Patatagod69 - Dutch translation
- [Emin](https://github.com/EminGT) - Shadow bias method from Complementary Reimagined
- [DrDesten](https://github.com/DrDesten) - Depth tolerance calculation for SSR
- [Jessie](https://github.com/Jessie-LC) - f0 and f82 values for labPBR hardcoded metals
- [Sledgehammer Games](https://www.sledgehammergames.com/) - Bloom downsampling method
- http://momentsingrapics.de/ - Blue noise texture
- [NASA Scientific Visualization Studio](https://svs.gsfc.nasa.gov/4851) - Galaxy image

## License

This project inherits the Photon Shaders license from SixthSurge. See [LICENSE](LICENSE) for full terms.

Key points:
- Free to use, modify, and learn from
- Redistribution allowed with restrictions on monetized platforms
- Must include license in substantial copies
- No warranty provided
