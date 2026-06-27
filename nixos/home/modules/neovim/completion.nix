{ config
, lib
, ...
}:
let
  cfg = config.custom.neovim;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim.plugins = {
      friendly-snippets.enable = true;

      blink-cmp = {
        enable = true;
        settings = {
          keymap = {
            preset = "default";
            "<C-s>" = [
              "show"
              "fallback"
            ];
            "<A-s>" = [
              {
                __raw = ''
                  function(cmp)
                    if require("blink.cmp.signature").is_open() then
                      cmp.hide_signature()
                    else
                      cmp.show_signature()
                    end
                  end
                '';
              }
            ];
            "<C-k>" = [
              "scroll_documentation_up"
              "fallback"
            ];
            "<C-j>" = [
              "scroll_documentation_down"
              "fallback"
            ];
            "<C-e>" = [
              "cancel"
              "fallback"
            ];
            "<Tab>" = [
              "accept"
              "fallback"
            ];
            "<C-n>" = [
              {
                __raw = ''
                  function(cmp)
                    if cmp.snippet_active() then
                      return cmp.snippet_forward()
                    else
                      return cmp.select_next()
                    end
                  end
                '';
              }
              "fallback"
            ];
            "<C-p>" = [
              {
                __raw = ''
                  function(cmp)
                    if cmp.snippet_active() then
                      return cmp.snippet_backward()
                    else
                      return cmp.select_prev()
                    end
                  end
                '';
              }
              "fallback"
            ];
          };
          appearance = {
            use_nvim_cmp_as_default = true;
            nerd_font_variant = "mono";
          };
          sources = {
            default = [
              "lazydev"
              "lsp"
              "path"
              "buffer"
              "snippets"
            ];
            per_filetype.toggleterm = [
              "buffer"
              "path"
            ];
            providers.lazydev = {
              name = "LazyDev";
              module = "lazydev.integrations.blink";
              score_offset = 100;
            };
          };
          completion = {
            list.selection = {
              preselect = true;
              auto_insert = true;
            };
            accept.auto_brackets.enabled = true;
            menu = {
              border = "rounded";
              draw.columns = [
                [ "kind_icon" ]
                [
                  "label"
                  "label_description"
                  { gap = 1; }
                ]
                [ "source_name" ]
              ];
            };
            documentation = {
              auto_show = true;
              auto_show_delay_ms = 200;
              window.border = "rounded";
            };
          };
          signature = {
            enabled = true;
            window.border = "rounded";
          };
        };
      };
    };
  };
}
