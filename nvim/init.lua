-- 1. DEFINIR LEADER PRIMERO QUE NADA
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 2. OPCIONES GENERALES
vim.opt.background = "dark"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.opt.guifont = "DroidSansMono Nerd Font 11"

-- 3. INSTALACIÓN DE LAZY.NVIM
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 4. CONFIGURACIÓN DE PLUGINS (cada spec vive en lua/plugins/*.lua)
require("lazy").setup({
  { import = "plugins" },
})

-- 5. ATAJOS DE TECLADO (KEYMAPS)
local keymap = vim.keymap.set

-- NERDTree
keymap('n', '<leader>b', ':NERDTreeFind<CR>', { noremap = true, silent = true })
keymap('n', '<leader>w', ':w<CR>', { noremap = true, silent = true })
keymap('n', '<leader>q', ':q<CR>', { noremap = true, silent = true })
keymap('n', '<leader>x', ':x<CR>', { noremap = true, silent = true })

-- Python
keymap('n', '<leader>e', ':!python3 %<CR>', { noremap = true, silent = true })
keymap('n', '<leader>t', ':AsyncRun -mode=term -pos=bottom -rows=12 python3 %<CR>', { noremap = true, silent = true })
