vim.g.mapleader = ' '

local function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true, desc = tostring(rhs) }
  if opts then
    options = vim.tbl_extend('force', options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end


map('n', '<leader>c', ':nohl<CR>', { desc = "Clears search highlights" })

map('n', '<leader>r', ':so %<CR>', { desc = "Reload configuration without restart nvim" })

map('n', '<leader>s', ':w<CR>', { desc = "Fast saving with <leader> and s"})

map('n', '<leader>sv', '<C-w>sv', { desc = "Split window vertically" })
map('n', '<leader>sh', '<C-w>sh', { desc = "Split window horizontally" })
map('n', '<leader>se', '<C-w>=', { desc = "Make splits equal size" })
map('n', '<leader>sx', '<cmd>close<CR>', { desc = "Closes active pane" })

map('n', '<leader>v', '<C-v>', { desc = "Enters visual block mode" })

