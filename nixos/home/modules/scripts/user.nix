{
  pkgs,
  lib,
  config,
  currentHostname,
  ...
}:
let
  cfg = config.custom.userScripts;

  filesDir = ./files;

  extLang =
    ext:
    if ext == "sh" || ext == "bash" then
      "bash"
    else if ext == "zsh" then
      "zsh"
    else if ext == "py" then
      "python3"
    else
      null;

  splitExt =
    name:
    let
      parts = lib.splitString "." name;
    in
    if builtins.length parts > 1 then
      {
        base = lib.concatStringsSep "." (lib.init parts);
        ext = lib.last parts;
      }
    else
      null;

  discovered = lib.pipe filesDir [
    builtins.readDir
    (lib.mapAttrsToList (
      n: _:
      let
        parts = splitExt n;
      in
      if parts != null && extLang parts.ext != null then
        {
          name = parts.base;
          lang = extLang parts.ext;
          source = filesDir + "/${n}";
        }
      else
        null
    ))
    (builtins.filter (x: x != null))
  ];

  mkBin =
    name: spec:
    let
      lang = spec.lang or "bash";
      runtimeInputs = spec.runtimeInputs or [ ];
      text = builtins.readFile spec.source;
      pathExport = lib.optionalString (
        runtimeInputs != [ ]
      ) ''export PATH="${lib.makeBinPath runtimeInputs}''${PATH:+:$PATH}"'';
    in
    if lang == "bash" then
      pkgs.writeShellApplication { inherit name runtimeInputs text; }
    else if lang == "zsh" then
      pkgs.writeTextFile {
        inherit name;
        executable = true;
        destination = "/bin/${name}";
        text = ''
          #!${pkgs.zsh}/bin/zsh
          ${pathExport}
          ${text}
        '';
      }
    else if lang == "python3" then
      pkgs.writers.writePython3Bin name { libraries = spec.libraries or [ ]; } text
    else
      throw "custom.userScripts.bins.${name}: unknown lang '${lang}' (use 'bash', 'zsh', or 'python3')";

  mkGroupBins =
    group: spec:
    let
      lang = spec.lang or "bash";
      runtimeInputs = spec.runtimeInputs or [ ];
      libFile = pkgs.writeText "user-scripts-${group}.sh" (builtins.readFile spec.source);
      pathExport = lib.optionalString (
        runtimeInputs != [ ]
      ) ''export PATH="${lib.makeBinPath runtimeInputs}''${PATH:+:$PATH}"'';
      mkOne =
        cmd:
        if lang == "bash" then
          pkgs.writeShellApplication {
            name = cmd;
            inherit runtimeInputs;
            checkPhase = ":";
            text = ''
              source ${libFile}
              ${cmd} "$@"
            '';
          }
        else if lang == "zsh" then
          pkgs.writeTextFile {
            name = cmd;
            executable = true;
            destination = "/bin/${cmd}";
            text = ''
              #!${pkgs.zsh}/bin/zsh
              ${pathExport}
              source ${libFile}
              ${cmd} "$@"
            '';
          }
        else
          throw "custom.userScripts.group.${group}: lang '${lang}' not supported (use 'bash' or 'zsh')";
    in
    map mkOne spec.commands;

  discoveredBins =
    let
      grouped = lib.groupBy (d: d.name) discovered;
      dups = lib.attrNames (lib.filterAttrs (_: ds: builtins.length ds > 1) grouped);
    in
    if dups != [ ] then
      throw "custom.userScripts: duplicate script names in files/: ${lib.concatStringsSep ", " dups} (name = filename without extension)"
    else
      map (d: mkBin d.name { inherit (d) source lang; }) discovered;

  declaredBins = lib.mapAttrsToList mkBin cfg.bins;
  groupBins = lib.concatLists (lib.mapAttrsToList mkGroupBins cfg.group);

  addScript = pkgs.writeShellApplication {
    name = "add-script";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
    ];
    text = builtins.replaceStrings [ "@REPO_DIR@" "@HOST@" ] [ cfg.repoDir currentHostname ] (
      builtins.readFile ./add-script.sh
    );
  };
in
{
  options.custom.userScripts = {
    repoDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/personal/dotfiles/nixos";
      description = ''
        Absolute path to the dotfiles flake checkout. `add-script` copies new
        scripts into <repoDir>/home/modules/scripts/files/ and rebuilds
        <repoDir>#<host>.
      '';
    };

    bins = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            source = lib.mkOption {
              type = lib.types.path;
              description = ''
                Path to the committed script file. Its contents become the bin's
                body (omit the shebang — the writer adds one). For the common
                case prefer dropping a file in ./files/ (auto-discovered) instead.
              '';
            };
            lang = lib.mkOption {
              type = lib.types.enum [
                "bash"
                "zsh"
                "python3"
              ];
              default = "bash";
              description = "Interpreter for the script.";
            };
            runtimeInputs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Packages placed on PATH (bash via writeShellApplication; zsh via PATH export).";
            };
            libraries = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Python packages (lang = \"python3\" only).";
            };
          };
        }
      );
      default = { };
      description = ''
        Nix-declared standalone scripts (escape hatch for when you need
        runtimeInputs or a non-default lang). Most scripts should instead go in
        ./files/ and be auto-discovered — no Nix edit needed.
      '';
    };

    group = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            source = lib.mkOption {
              type = lib.types.path;
              description = "Path to a shell file defining functions (one per entry in `commands`).";
            };
            commands = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Function names to export as bins. Each becomes a wrapper that does
                `source <file>; <name> "$@"`.
              '';
            };
            lang = lib.mkOption {
              type = lib.types.enum [
                "bash"
                "zsh"
              ];
              default = "bash";
              description = "Shell for both the library file and the generated wrappers.";
            };
            runtimeInputs = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [ ];
              description = "Packages placed on PATH in every wrapper.";
            };
          };
        }
      );
      default = { };
      description = ''
        Nix-declared grouped scripts (escape hatch for one-file-many-commands
        clutter grouping). The file must only define functions (no top-level
        side effects), since every wrapper sources it.
      '';
    };
  };

  config = {
    home.packages = [ addScript ] ++ discoveredBins ++ declaredBins ++ groupBins;
  };
}
