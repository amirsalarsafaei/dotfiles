# Reusable development environments

The Home Manager dev profile registers this configuration as `dev`. After activating
that profile, these commands work from any directory:

```sh
nix develop dev#python
nix develop dev#python-data
```

The `python` shell contains pandas, Pillow (`from PIL import Image`), NumPy,
SciPy, Matplotlib, Seaborn, requests, httpx, Beautiful Soup, lxml, openpyxl,
PyArrow, PyYAML, Rich, tabulate, pypdf, PyMuPDF, python-docx, python-pptx,
IPython, and pytest. Add common packages in `pkgs/python-environment.nix`.
It also provides uv, Ruff, Pyright, a compiler, pkg-config, and common native
libraries. `python-data` adds JupyterLab, Notebook, ipykernel, and scikit-learn.
Run `python`, `ipython`, or `jupyter lab` directly inside the shell to use the
curated packages. Exiting the shell restores your usual environment; your base
Python installation and global Python packages are unchanged.
Both environments support x86_64-linux and aarch64-linux. The existing x86_64
CUDA environment remains `nix develop dev`.

For your usual Zsh configuration, use `nix develop dev#python -c zsh`.
For a single command, use `nix develop dev#python -c python script.py`.
Before the registry is activated, use the checkout path instead of `dev`, for
example `nix develop ~/personal/dotfiles/nixos#python`.

Entering either Python shell creates and activates a persistent writable virtualenv
under `${XDG_STATE_HOME:-$HOME/.local/state}/nix-dev/`, outside the current project.
A venv-local `.pth` file exposes the curated Nix packages. Install an extra package
and run a script with:

```sh
nix develop dev#python -c bash -c 'uv pip install --python "$VIRTUAL_ENV/bin/python" package-name && python script.py'
```

Additions persist between entries. The venv path includes the pinned Python
package environment's store identity, so changing that environment starts a fresh
venv; old ones are retained. The mutable additions are not covered by `flake.lock`.
The base OS Python is unchanged. Use a project's own environment and lockfile for
project dependency management; do not run `uv sync --active` against this toolbox.

For native Rust development:

```sh
nix develop dev#rust -c cargo check
nix develop dev#rust -c pkg-config --modversion openssl
```

The Rust shell supplies Cargo, rustc, rustfmt, Clippy, pkg-config, and OpenSSL.
Nix's pkg-config setup locates the OpenSSL headers and libraries without a global
`OPENSSL_DIR`. The Python shells also provide Cargo and rustc for native extensions.

The Python shells disable uv interpreter downloads and select system interpreters.
If a project requires another Python minor version, supply it explicitly through
Nix. The native library search path is scoped to these shells, not your desktop;
packages needing additional system libraries may require extending the list in
`python-shell.nix`. These are CPU Python environments; entering the data shell
does not configure CUDA or install a GPU framework.

`dev` points to the configuration snapshot from your latest Home Manager activation.
Use the checkout path to try subsequent edits. New files must be tracked by Git
before Git-backed flake commands include them. The existing flake lock pins the
Nix packages; a project's uv lock pins its Python dependencies separately.

`uv run` may select a separate project environment. Use direct `python` / `python3`
inside the reusable shell for the shared toolbox. Entering the shell selects its
own venv even if another was active; existing project venvs are not modified.
