{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
  python3,
}:

buildNpmPackage (finalAttrs: {
  pname = "mcp-chrome-bridge";
  version = "1.0.31";

  src = fetchurl {
    url = "https://registry.npmjs.org/mcp-chrome-bridge/-/mcp-chrome-bridge-${finalAttrs.version}.tgz";
    hash = "sha256-1KSh9vF27zQgjZ/iJqW/5w2Nd6sowOKOIQTZXvSYIms=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    substituteInPlace dist/mcp/mcp-server.js \
      --replace-fail "if (exports.mcpServer) {" "if (false) {"
  '';

  npmDepsHash = "sha256-/NmGU39LX9EGkrdtNKMuTpI8HUnUOTwywQ0jwbzPB8s=";

  nativeBuildInputs = [ python3 ];

  dontNpmBuild = true;

  postInstall = ''
    echo ${lib.getExe nodejs} > $out/lib/node_modules/mcp-chrome-bridge/dist/node_path.txt
  '';

  meta = {
    description = "Native messaging host and MCP server for the Chrome MCP Server extension";
    homepage = "https://github.com/hangwin/mcp-chrome";
    license = lib.licenses.mit;
    mainProgram = "mcp-chrome-bridge";
    platforms = lib.platforms.linux;
  };
})
