{ config
, lib
, ...
}:
let
  cfg = config.custom.neovim;
  helpers = import ./lib.nix { inherit lib config; };
  inherit (helpers) mkKeymap normalKeymap;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim.keymaps = [
      (normalKeymap "<leader>w" "<cmd>w<CR>" { desc = "Save file"; })
      (normalKeymap "<Esc>" "<cmd>nohl<CR><Esc>" { desc = "Clear highlights on escape"; })
      (normalKeymap "j" "v:count == 0 ? 'gj' : 'j'" {
        expr = true;
        desc = "Move down wrapped";
      })
      (normalKeymap "k" "v:count == 0 ? 'gk' : 'k'" {
        expr = true;
        desc = "Move up wrapped";
      })
      (normalKeymap "<leader>sv" "<cmd>vsplit<CR>" { desc = "Split vertical"; })
      (normalKeymap "<leader>sh" "<cmd>split<CR>" { desc = "Split horizontal"; })
      (normalKeymap "<leader>se" "<C-w>=" { desc = "Equalize splits"; })
      (normalKeymap "<leader>sx" "<cmd>close<CR>" { desc = "Close split"; })
      (normalKeymap "<leader>so" "<C-w>o" { desc = "Close other splits"; })
      (normalKeymap "<C-Up>" "<cmd>resize +2<CR>" { desc = "Increase height"; })
      (normalKeymap "<C-Down>" "<cmd>resize -2<CR>" { desc = "Decrease height"; })
      (normalKeymap "<C-Left>" "<cmd>vertical resize -2<CR>" { desc = "Decrease width"; })
      (normalKeymap "<C-Right>" "<cmd>vertical resize +2<CR>" { desc = "Increase width"; })
      (normalKeymap "<leader>sr" "<C-w>r" { desc = "Rotate splits"; })
      (normalKeymap "<leader>sH" "<C-w>H" { desc = "Move split left"; })
      (normalKeymap "<leader>sJ" "<C-w>J" { desc = "Move split down"; })
      (normalKeymap "<leader>sK" "<C-w>K" { desc = "Move split up"; })
      (normalKeymap "<leader>sL" "<C-w>L" { desc = "Move split right"; })
      (normalKeymap "<leader>tn" "<cmd>tabnew<CR>" { desc = "Tab new"; })
      (normalKeymap "<leader>tc" "<cmd>tabclose<CR>" { desc = "Tab close"; })
      (normalKeymap "<leader>to" "<cmd>tabonly<CR>" { desc = "Tab only"; })
      (normalKeymap "<leader>t]" "<cmd>tabnext<CR>" { desc = "Tab next"; })
      (normalKeymap "<leader>t[" "<cmd>tabprevious<CR>" { desc = "Tab previous"; })
      (mkKeymap "v" "<" "<gv" { desc = "Indent left and reselect"; })
      (mkKeymap "v" ">" ">gv" { desc = "Indent right and reselect"; })
      (mkKeymap "v" "J" ":m '>+1<CR>gv=gv" { desc = "Move selection down"; })
      (mkKeymap "v" "K" ":m '<-2<CR>gv=gv" { desc = "Move selection up"; })
      (normalKeymap "J" "mzJ`z" { desc = "Join lines keep cursor"; })
      (normalKeymap "<C-d>" "<C-d>zz" { desc = "Page down centered"; })
      (normalKeymap "<C-u>" "<C-u>zz" { desc = "Page up centered"; })
      (normalKeymap "n" "nzzzv" { desc = "Next search centered"; })
      (normalKeymap "N" "Nzzzv" { desc = "Prev search centered"; })
      (mkKeymap "x" "<leader>p" ''"_dP'' { desc = "Paste without yanking"; })
      (mkKeymap [ "n" "v" ] "<leader>d" ''"_d'' { desc = "Delete without yanking"; })
      (normalKeymap "<leader>bn" "<cmd>bnext<CR>" { desc = "Next buffer"; })
      (normalKeymap "<leader>bp" "<cmd>bprevious<CR>" { desc = "Previous buffer"; })
      (normalKeymap "[q" "<cmd>cprev<CR>zz" { desc = "Previous quickfix"; })
      (normalKeymap "]q" "<cmd>cnext<CR>zz" { desc = "Next quickfix"; })
      (normalKeymap "[l" "<cmd>lprev<CR>zz" { desc = "Previous loclist"; })
      (normalKeymap "]l" "<cmd>lnext<CR>zz" { desc = "Next loclist"; })
      (normalKeymap "Q" "@q" { desc = "Replay macro q"; })
      (mkKeymap "i" "<C-c>" "<Esc>" { desc = "Exit insert mode"; })
    ];
  };
}
