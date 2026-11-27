# Profiles and development environments

## Configuration ownership

`hosts/default.nix` explicitly selects every host's profiles. The builders in
`flake/default.nix` resolve those names and compose modules; they do not silently
assign a desktop profile to a new host. Unknown profile names fail with the host
and profile name in the error. Package policy is shared between NixOS and the
standalone Home Manager builder without evaluating unrelated inputs.

| Host | NixOS profiles | Home Manager profiles | SOPS |
| --- | --- | --- | --- |
| `g14` | `base`, `desktop` | `full` | System and home |
| `t14` | `base`, `desktop` | `full` | System and home |
| `franksalar` | `base`, `server` | `base`, `dev`, `franksalar` | System only |
| `orangepi` | Standalone Home Manager | `base`, `dev`, `theme` | Home only |

Home Manager `full` composes `base`, `dev`, `theme`, and `desktop`. The base
profile owns home paths, state version, XDG support, and shared policy options.
The dev profile adds shell/editor tooling and `home/modules/dev-environment.nix`,
which owns Go paths, compiler paths, YAML tool configuration, and tmuxinator files.
The `franksalar` home profile disables the optional agents and editor debugger.

NixOS profiles select features; reusable service definitions live in `modules/`.
Host-specific settings and specialisations remain under `hosts/<host>/`.

| Feature | Owner | Desktop default |
| --- | --- | --- |
| NetworkManager, iwd, resolver, firewall, local hosts file | `modules/desktop-networking.nix` | Imported by desktop |
| Docker networking and user group | `modules/docker.nix` | `virtualisation.docker.enable = true` |
| Local Kubernetes | `modules/local-kubernetes.nix` | `custom.localKubernetes.enable = true` |
| PostgreSQL 16 development database | `modules/local-postgresql.nix` | `custom.localPostgresql.enable = true` |
| Prometheus, exporters, Grafana | `modules/local-monitoring.nix` | `custom.localMonitoring.enable = true` |
| Shared Ubuntu VM | `modules/ubuntu-vm.nix` | `custom.ubuntuVm.enable = true` |

These enable defaults use `lib.mkDefault`, so a host can disable a feature with a
normal `false` definition. Importing Docker policy alone does not enable its
daemon or grant Docker group membership. Disable local Kubernetes too when
disabling Docker; its existing assertion checks that dependency. Disabling
PostgreSQL leaves its existing database directory intact.

Monitoring binds Prometheus, its exporters, and Grafana to `127.0.0.1`. It is
disabled on `t14` and in `g14`'s `on-the-go` specialisation, including exporters
and target-directory provisioning. The default `g14` profile retains monitoring;
its `low-power` specialisation omits the NVIDIA exporter.

The existing Grafana signing key and Google credential environment settings still
need a separate runtime-secret migration. Changing Grafana's key requires
re-encoding existing data-source credentials. This refactor preserves those values
and does not rotate credentials or change database versions, state versions,
package outputs, or input pins.

## Reusable development environments

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

## Local Kubernetes playground

The NixOS desktop profile enables `custom.localKubernetes` on `g14` and `t14`.
`modules/docker.nix` owns the shared Docker configuration;
`modules/local-kubernetes.nix` owns Minikube and its defaults. The Home Manager
infra package list owns the existing Kubernetes, Helm, and Istio tools. The server
and standalone Home Manager profiles do not enable a local cluster runtime.

After applying the configuration and logging in again, Minikube defaults to the
Docker driver, containerd, 4 CPUs, and 8192 MiB RAM per node. These defaults use
Minikube's native `MINIKUBE_*` environment variables and apply to all profiles;
command-line flags take precedence. Hosts can override
`custom.localKubernetes.cpus` and `custom.localKubernetes.memory`.
No cluster is created or started by activation or a boot service. Docker keeps its
existing startup policy, including socket activation on `t14`.

Open a dedicated terminal for the playground and give it a separate kubeconfig:

```sh
install -d -m 700 "$HOME/.kube"
export KUBECONFIG="$HOME/.kube/playground"
export DOCKER_CONTEXT=default
minikube start -p playground --listen-address=127.0.0.1
kubectl --context=playground get nodes
```

Use these exports in each playground terminal; leave them out of global shell
configuration. This keeps Minikube from merging into your usual kubeconfig or
changing its current context. The explicit Docker context selects the local
daemon. Run Minikube as your normal user with the existing Docker group access.
The API's published port binds to loopback; this setup adds no host firewall ports
or host-directory mounts. Minikube's Docker nodes are privileged containers sharing
the host kernel, so this is a trusted development playground, not a VM boundary.

The first start downloads node images and Kubernetes components. The Minikube
binary is pinned by Nixpkgs; cluster images and workloads are downloaded at runtime.
The pinned Minikube currently defaults to Kubernetes v1.35.1. For a different
version, pass `--kubernetes-version=vX.Y.Z` when creating a new profile and check
compatibility with the installed `istioctl version --remote=false` first.
Increase resources with `--cpus=6 --memory=12288` for larger experiments.

For a small Istio sidecar lab, in that same terminal:

```sh
istioctl x precheck --context=playground
istioctl install --context=playground --set profile=demo -y
kubectl --context=playground create namespace mesh-demo
kubectl --context=playground label namespace mesh-demo istio-injection=enabled --overwrite
kubectl --context=playground -n istio-system get pods
istioctl analyze --context=playground -A
```

Deploy test workloads in `mesh-demo` after applying the injection label. The demo
profile is for experiments. For ambient mesh, use a fresh profile and follow the
matching Istio release's ambient installation instructions rather than installing
both modes into the same example namespace.

Access the demo ingress gateway locally in a second playground terminal:

```sh
kubectl --context=playground -n istio-system port-forward --address=127.0.0.1 service/istio-ingressgateway 8080:80
```

Configure an Istio Gateway and VirtualService for your workload before testing
traffic through `localhost:8080`. A service of type LoadBalancer can instead use
`minikube tunnel -p playground` while needed; it may request sudo to add routes.

Stop and resume the cluster without deleting workloads or stored data:

```sh
minikube stop -p playground
minikube start -p playground --listen-address=127.0.0.1
minikube status -p playground
```

Stopping releases the node's running resources and retains disk data. It does not
stop Docker or affect the shared Ubuntu VM. Stop the playground when finished;
closing its terminal does not stop it. To deliberately discard the entire lab,
including its persistent volumes, run `minikube delete -p playground` with the
playground kubeconfig still selected.

References: [Minikube Docker driver](https://minikube.sigs.k8s.io/docs/drivers/docker/),
[Minikube configuration](https://minikube.sigs.k8s.io/docs/handbook/config/),
[Istio platform setup](https://istio.io/latest/docs/setup/platform-setup/minikube/),
[Istio supported releases](https://istio.io/latest/docs/releases/supported-releases/).
