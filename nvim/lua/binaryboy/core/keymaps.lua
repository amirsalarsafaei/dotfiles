vim.g.mapleader = ' '

function Map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend('force', options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end


Map('n', '<leader>c', ':nohl<CR>', { desc = "Clears search highlights" })

Map('n', '<leader>r', ':so %<CR>', { desc = "Reload configuration without restart nvim" })

Map('n', '<leader>s', ':w<CR>', { desc = "Fast saving with <leader> and s"})

Map('n', '<leader>sv', '<C-w>sv', { desc = "Split window vertically" })
Map('n', '<leader>sh', '<C-w>sh', { desc = "Split window horizontally" })
Map('n', '<leader>se', '<C-w>=', { desc = "Make splits equal size" })
Map('n', '<leader>sx', '<cmd>close<CR>', { desc = "Closes active pane" })

Map('n', '<leader>v', '<C-v>', { desc = "Enters visual block mode" })

