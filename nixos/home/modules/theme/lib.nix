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

  hexDigit = value: builtins.substring value 1 "0123456789abcdef";
  byteToHex = value: hexDigit (value / 16) + hexDigit (value - value / 16 * 16);

  mix =
    from: to: percent:
    let
      channel =
        offset:
        let
          a = hexByteToInt (builtins.substring offset 2 (stripHash from));
          b = hexByteToInt (builtins.substring offset 2 (stripHash to));
        in
        byteToHex ((a * (100 - percent) + b * percent + 50) / 100);
    in
    "#${channel 0}${channel 2}${channel 4}";
in
{
  inherit
    stripHash
    hexToRgb
    rgba
    withAlpha
    mix
    ;
}
