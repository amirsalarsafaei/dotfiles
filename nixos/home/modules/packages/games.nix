{
  pkgs,
  isWork ? false,
  ...
}:
pkgs.lib.optionals (!isWork) [
  pkgs.hmcl
]
