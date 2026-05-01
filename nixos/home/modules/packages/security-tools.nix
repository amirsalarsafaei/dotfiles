{ pkgs, ... }:
[
  pkgs.yubikey-manager
  pkgs.totp-cli
  (pkgs.pass.withExtensions (exts: [ exts.pass-otp ]))
  pkgs.burpsuite
  pkgs.age
]
