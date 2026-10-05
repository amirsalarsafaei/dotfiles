# Texture credits

- `earth.jpg`: channels packed, cropped to 18°N–82°N, 8192×1456, JPEG 4:4:4.
  - Red, city lights: NASA Earth Observatory, Black Marble 2016 (https://earthobservatory.nasa.gov/features/NightLights), public domain. Point lights isolated with a top-hat filter so moonlit terrain does not glow.
  - Green, clouds: Solar System Scope 8k Earth clouds (https://www.solarsystemscope.com/textures/), CC BY 4.0.
  - Blue, terrain: NASA Earth Observatory, Blue Marble Next Generation, July 2004 (https://visibleearth.nasa.gov/collection/1484/blue-marble), public domain. Greyscale; oceans are near zero, so it doubles as the land mask.
- `earth-16k.jpg`: same packing and crop at 16384×2912, loaded only on monitors taller than 1600 physical pixels. Channels histogram-matched to `earth.jpg` so the shader tuning carries over.
  - Red, city lights: NASA Earth Observatory, Black Marble 2016 500 m grayscale tiles A1–D1 (https://earthobservatory.nasa.gov/features/NightLights), public domain. Box-downsampled, background removed with a wide opening so large cities stay solid.
  - Green, clouds: the `earth.jpg` cloud channel upscaled 2× (Lanczos).
  - Blue, terrain: NASA Blue Marble Next Generation, July 2004, 21600×10800 (https://visibleearth.nasa.gov/collection/1484/blue-marble), public domain. Luma masked to land by color.
- `moon.jpg`: Solar System Scope 8k Moon (https://www.solarsystemscope.com/textures/), CC BY 4.0. Greyscale, resized to 1024×512.
- `milky-way.jpg`: NASA/Goddard Scientific Visualization Studio, Deep Star Maps 2020 (https://svs.gsfc.nasa.gov/4851), public domain. Galactic-plane band, log tone-mapped to greyscale.
- `die-intel.jpg`: Fritzchens Fritz, "Intel@intel7(10nmESF)@RaptorLake@RPL(8P+16E)@i9-13900K@ES DSCx06 poly@5xDIC Lambda" (https://commons.wikimedia.org/wiki/User:Fritzchens_Fritz), CC0. Graded to the board palette and cropped to the die, 2560 wide; shown on the motherboard scene's pump LCD for Intel CPUs.
- `die-amd.jpg`: Fritzchens Fritz, "AMD@7nm@Zen3@Cezanne@Ryzen 5 5600G" die shot (https://commons.wikimedia.org/wiki/User:Fritzchens_Fritz), CC0. Same grading, 2048 wide; shown for AMD CPUs.
