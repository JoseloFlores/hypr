return {
  { 'scrooloose/nerdtree' },
  { 'christoomey/vim-tmux-navigator' },
  { 'yggdroot/indentline' },
  { 'ryanoasis/vim-devicons' },
  {
    'vim-airline/vim-airline',
    config = function()
      vim.g.airline_powerline_fonts = 1
      vim.g["airline#extensions#tabline#enabled"] = 1
    end,
  },
  { 'jiangmiao/auto-pairs' },
  { 'skywind3000/asyncrun.vim' },
  { 'vim-autoformat/vim-autoformat' },
  { 'nvim-treesitter/nvim-treesitter', build = ':TSUpdate' },
}
