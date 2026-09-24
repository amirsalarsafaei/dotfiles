{
  pkgs,
  dataScience ? false,
}:
let
  python = import ../pkgs/python-environment.nix { inherit pkgs dataScience; };
  nativeLibraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    libffi
  ];
in
pkgs.mkShell {
  name = if dataScience then "python-data" else "python";
  packages = [
    python
    pkgs.uv
    pkgs.ruff
    pkgs.pyright
    pkgs.cargo
    pkgs.rustc
  ];
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = nativeLibraries;
  UV_PYTHON_DOWNLOADS = "never";
  UV_PYTHON_PREFERENCE = "only-system";
  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath nativeLibraries}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    dev_venv_root="''${XDG_STATE_HOME:-$HOME/.local/state}/nix-dev"
    dev_venv="$dev_venv_root/${builtins.baseNameOf (toString python)}"
    mkdir -p "$dev_venv_root"
    (
      ${pkgs.util-linux}/bin/flock 9
      if [ ! -x "$dev_venv/bin/python" ]; then
        ${pkgs.python3}/bin/python -m venv --without-pip "$dev_venv" || exit 1
      fi
      printf '%s\n' ${pkgs.lib.escapeShellArg "import site; site.addsitedir(${builtins.toJSON "${python}/${pkgs.python3.sitePackages}"})"} \
        > "$dev_venv/${pkgs.python3.sitePackages}/nix-toolbox.pth"
    ) 9>"$dev_venv.lock" || exit 1
    source "$dev_venv/bin/activate"
    unset dev_venv_root dev_venv
  '';
}
