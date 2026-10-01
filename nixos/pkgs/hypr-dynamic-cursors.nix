{
  lib,
  mkHyprlandPlugin,
  fetchFromGitHub,
}:
mkHyprlandPlugin {
  pluginName = "hypr-dynamic-cursors";
  version = "0-unstable-2026-08-04";

  src = fetchFromGitHub {
    owner = "VirtCode";
    repo = "hypr-dynamic-cursors";
    rev = "5a224284872208b5324759d535d65061043725de";
    hash = "sha256-BQjuQplkQFA30/7evDxmEAvr2ArIG09JffEBQhuzo80=";
  };

  dontUseCmakeConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    mv out/dynamic-cursors.so $out/lib/libhypr-dynamic-cursors.so

    runHook postInstall
  '';

  meta = {
    description = "Plugin to make your Hyprland cursor more realistic";
    homepage = "https://github.com/VirtCode/hypr-dynamic-cursors";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
