{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
}:

buildNpmPackage (finalAttrs: {
  pname = "browser-mcp";
  version = "0.1.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/@browsermcp/mcp/-/mcp-${finalAttrs.version}.tgz";
    hash = "sha256-KtNMKRRcqAxfLn2OyQ4FiWl7GTOLK0WoPJGNSQekz5Y=";
  };

  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
    patch -p1 < ${./broker-client.patch}
  '';

  npmDepsHash = "sha256-ChUG2esdl1MuzXhBMpZPp1EaQwxBEpW+QnwXBVhPNM4=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    install -Dm644 ${./broker.mjs} $out/lib/node_modules/@browsermcp/mcp/broker.mjs
    makeWrapper ${nodejs}/bin/node $out/bin/browser-mcp-broker \
      --add-flags $out/lib/node_modules/@browsermcp/mcp/broker.mjs
  '';

  meta = {
    description = "MCP server for browser automation using Browser MCP";
    homepage = "https://browsermcp.io";
    license = lib.licenses.mit;
    mainProgram = "mcp-server-browsermcp";
    platforms = lib.platforms.linux;
  };
})
