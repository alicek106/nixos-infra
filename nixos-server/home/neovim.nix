{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # neovim 이 직접 호출하는 바이너리를 wrapper에 직접 bundling
    extraPackages = with pkgs; [ nixd fzf ripgrep ];

    plugins = with pkgs.vimPlugins; [
      nerdtree
      vim-mundo
      vim-lastplace
      vim-sensible
      fzf-vim
      nvim-scrollbar

      lualine-nvim
      nvim-web-devicons
      tokyonight-nvim
      gitsigns-nvim
      nvim-autopairs
      indent-blankline-nvim
      nvim-ufo
      promise-async
      (nvim-treesitter.withPlugins (p: with p; [
        nix
        lua
        json
        yaml
        bash
        markdown
        markdown_inline
        vimdoc
      ]))

      nvim-lspconfig
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip
      friendly-snippets

      telescope-nvim
      plenary-nvim
    ];

    initLua = ''
      require("scrollbar").setup()
      require("ui")
      require("lsp")
    '';

    extraConfig = ''
      " === 기본 설정 ===
      let mapleader = ","
      set hlsearch
      set ignorecase
      set incsearch
      set noswapfile
      set termguicolors
      set bg=dark
      set nu
      set smartindent
      set shiftwidth=4
      set tabstop=4
      set softtabstop=4
      set expandtab
      syntax on
      filetype indent plugin on

      " === 키맵 ===
      nnoremap <esc>t :tabnew<CR>
      nnoremap <esc>T :-tabnew<CR>
      nnoremap <esc>1 1gt
      nnoremap <esc>2 2gt
      nnoremap <esc>3 3gt
      nnoremap <esc>4 4gt
      nnoremap <esc>5 5gt
      nnoremap <esc>6 6gt
      nnoremap <esc>7 7gt
      nnoremap <esc>8 8gt
      nnoremap <esc>9 9gt

      nnoremap <esc>b :Files<CR>
      nnoremap <esc>f :Rg<CR>
      nnoremap <esc>h :History<CR>

      " Ctrl + s = save
      nnoremap <silent> <C-s>      :update<CR>
      inoremap <silent> <C-s> <ESC>:update<CR>
      vnoremap <silent> <C-s> <ESC>:update<CR>

      " Mundo shortcut
      nnoremap <silent> <Leader>h :MundoToggle<CR>

      set undodir=~/.vim/undodir
      set undofile
      set mouse=
    '';
  };

  home.file.".vim/undodir/.keep".text = "";

  # extraLuaConfig 에서 require("ui")/require("lsp") 로 로딩하는 lua 모듈
  home.file.".config/nvim/lua/ui.lua".source = ./nvim/ui.lua;
  home.file.".config/nvim/lua/lsp.lua".source = ./nvim/lsp.lua;
}
