# tealdeer — the `tldr` client: concise, example-first cheatsheets for CLI
# tools (`tldr tar`, `tldr ssh`, …). Pages are crowd-sourced and maintained
# upstream, so there's nothing here to keep current by hand — auto_update
# refreshes the local cache on its own.
{ ... }:
{
  programs.tealdeer = {
    enable = true;
    settings = {
      updates.auto_update = true;
      display = {
        compact = false;
        use_pager = false;
      };
    };
  };
}
