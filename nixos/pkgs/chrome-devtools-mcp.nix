{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nodejs,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "chrome-devtools-mcp";
  version = "1.9.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-${finalAttrs.version}.tgz";
    hash = "sha256-X3U7HL9XdcjkNxE1Is0QwfDO/RZSHgVyVA1XhgVWwTM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/chrome-devtools-mcp $out/bin
    cp -r build LICENSE package.json $out/lib/chrome-devtools-mcp/

    makeWrapper ${nodejs}/bin/node $out/bin/chrome-devtools-mcp \
      --add-flags $out/lib/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js

    runHook postInstall
  '';

  meta = {
    description = "MCP server exposing Chrome DevTools for browser inspection and automation";
    homepage = "https://github.com/ChromeDevTools/chrome-devtools-mcp";
    license = lib.licenses.asl20;
    mainProgram = "chrome-devtools-mcp";
    platforms = lib.platforms.linux;
  };
})
