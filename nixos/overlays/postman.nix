# Postman overlay for ARM and x86_64 support
final: prev: {
  postman = prev.postman.overrideAttrs (old: rec {
    version = "2025-01-15";
    src = final.fetchurl (
      if final.stdenv.hostPlatform.isAarch64 then {
        url = "https://dl.pstmn.io/download/latest/linux_arm";
        sha256 = "Kvxm2KA0zIrAJOORRHBFffQDdSDVJMrpZ83u6zlNMkk=";
        name = "${old.pname}-${version}.tar.gz";
      } else {
        url = "https://dl.pstmn.io/download/latest/linux_64";
        sha256 = "saczZ6e3WxGstqD9kbfxVoQKnC0gHVqEZWiNL2GRLtM=";
        name = "${old.pname}-${version}.tar.gz";
      }
    );
    buildInputs = old.buildInputs ++ [ final.xdg-utils ];
    postFixup = ''
      pushd $out/share/postman
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" postman
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" chrome_crashpad_handler
      for file in $(find . -type f \( -name \*.node -o -name postman -o -name \*.so\* \) ); do
        ORIGIN=$(patchelf --print-rpath $file); \
        patchelf --set-rpath "${final.lib.makeLibraryPath old.buildInputs}:$ORIGIN" $file
      done
      popd
      wrapProgram $out/bin/postman --set PATH ${final.lib.makeBinPath [ final.openssl final.xdg-utils ]}:\$PATH
    '';
  });
}
