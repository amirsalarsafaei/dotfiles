{ pkgs, ... }:
[
  pkgs.fd
  pkgs.bubblewrap
  pkgs.ripgrep
  pkgs.jq
  pkgs.yq-go
  pkgs.fzf
  pkgs.zoxide
  pkgs.coreutils-full
  pkgs.ncdu
  pkgs.zip
  pkgs.p7zip
  pkgs.gzip
  pkgs.bzip2
  pkgs.xz
  pkgs.tree
  pkgs.bat
  pkgs.fastfetch
  pkgs.acpi
  pkgs.htop
  pkgs.w3m
  pkgs.television
  pkgs.aichat
  pkgs.jcal
  pkgs.hyperfine
  pkgs.valgrind
  pkgs.minio-client # mc: S3/MinIO object storage CLI

  # modern-unix staples
  # tealdeer (tldr) is configured via programs.tealdeer in
  # programs/development/tealdeer.nix so its cache auto-updates.
  pkgs.btop # prettier htop with GPU/net graphs
  pkgs.dust # du replacement: a tree of what's eating disk
  pkgs.duf # df replacement: readable mountpoint usage
  pkgs.procs # ps replacement: colored, tree, searchable
  pkgs.jless # pager/TUI for exploring large JSON
  pkgs.sd # sed replacement for simple find/replace (sd 'foo' 'bar')
  pkgs.doggo # dig replacement: friendly DNS lookups
]
