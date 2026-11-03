{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "clip-image";
  version = "0.1.0";

  src = ./clip-image;

  cargoHash = "sha256-jEnlaX3SzRAze6ehLvP7FTqcRzYnR2WGIrzLa/394F4=";

  meta = {
    description = "Copy a PNG to the Wayland clipboard as both image data and a file reference";
    license = lib.licenses.mit;
    mainProgram = "clip-image";
    platforms = lib.platforms.linux;
  };
}
