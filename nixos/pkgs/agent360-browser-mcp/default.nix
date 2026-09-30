{
  lib,
  buildNpmPackage,
  fetchurl,
  procps,
}:

buildNpmPackage (finalAttrs: {
  pname = "agent360-browser-mcp";
  version = "1.30.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@agent360/browser-mcp/-/browser-mcp-${finalAttrs.version}.tgz";
    hash = "sha256-g2ApPyllSR+EokesPBOdzGqViZxqcPj0V3pVwdYG+k8=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-Zn9wC28KnmPimLhZjshyQcwY/x96aI6acQGO+72q+y8=";

  dontNpmBuild = true;

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ procps ])
  ];

  meta = {
    description = "MCP server and Chrome extension that drive your logged-in Chrome, one isolated tab group per session";
    homepage = "https://github.com/Agent360dk/browser-mcp";
    license = lib.licenses.mit;
    mainProgram = "browser-mcp";
    platforms = lib.platforms.linux;
  };
})
