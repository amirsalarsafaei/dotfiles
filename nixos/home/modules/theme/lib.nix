{ }:
let
  stripHash =
    color:
    if builtins.substring 0 1 color == "#" then
      builtins.substring 1 (builtins.stringLength color - 1) color
    else
      color;

  hexByteToInt = byte: (builtins.fromTOML "value = 0x${byte}").value;

  hexToRgb =
    color:
    let
      hex = stripHash color;
      r = hexByteToInt (builtins.substring 0 2 hex);
      g = hexByteToInt (builtins.substring 2 2 hex);
      b = hexByteToInt (builtins.substring 4 2 hex);
    in
    "${toString r}, ${toString g}, ${toString b}";

  rgba = color: alpha: "rgba(${hexToRgb color}, ${toString alpha})";
  withAlpha = color: alphaHex: "#${stripHash color}${alphaHex}";
in
{
  inherit
    stripHash
    hexToRgb
    rgba
    withAlpha
    ;
}
