-- UI / 편집 경험 현대화 (filetype 무관 공통 설정)
-- neovim.nix 의 extraLuaConfig 에서 require("ui") 로 로드됨

-- 클립보드: 헤드리스 서버 → OSC52 로 SSH 클라이언트 클립보드에 복사 (neovim 내장)
local ok_osc52, osc52 = pcall(require, "vim.ui.clipboard.osc52")
if ok_osc52 then
  vim.g.clipboard = {
    name = "OSC52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
  }
end

-- 컬러스킴: tokyonight
require("tokyonight").setup({
  style = "night",
  on_highlights = function(hl, c)
    hl.LspInlayHint = { fg = c.comment, bg = "NONE" }
  end,
})
vim.cmd.colorscheme("tokyonight-night")

-- 아이콘
require("nvim-web-devicons").setup({})

-- 상태바 (vim-airline 대체)
require("lualine").setup({
  options = {
    theme = "tokyonight",
    icons_enabled = true,
    section_separators = { left = "", right = "" },
    component_separators = { left = "", right = "" },
    globalstatus = true,
  },
  sections = {
    lualine_c = { { "filename", path = 1 } },
    lualine_x = { "diagnostics", "encoding", "filetype" },
  },
})

-- Treesitter (nvim-treesitter main 브랜치): 하이라이팅은 neovim 이 담당.
-- parser/쿼리는 nix(withPlugins)가 제공하므로 FileType 에서 켜기만 하면 됨.
local ts_filetypes = { "nix", "lua", "json", "yaml", "bash", "sh", "markdown", "vimdoc" }
vim.api.nvim_create_autocmd("FileType", {
  pattern = ts_filetypes,
  callback = function()
    pcall(vim.treesitter.start)
    -- treesitter 기반 들여쓰기(실험적)
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

-- Git 변경사항 거터 표시
require("gitsigns").setup()

-- 괄호/따옴표 자동 짝맞춤
require("nvim-autopairs").setup({})

-- 들여쓰기 가이드 라인
require("ibl").setup()

-- 코드 접기 (nvim-ufo)
-- foldcolumn=0: 접기 기능(zc/zo/zR/zM)은 유지하되 왼쪽 fold 표시 열은 끔.
-- (markdown 등에서 중첩 fold 깊이가 숫자로 떠 라인번호처럼 헷갈리는 것 방지. ufo 도 "0 is not bad" 명시)
vim.o.foldcolumn = "0"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.opt.fillchars:append({ foldopen = "-", foldclose = "+", foldsep = " " })

require("ufo").setup({
  provider_selector = function(_, _, _)
    return { "treesitter", "indent" }
  end,
})

local ufo = require("ufo")
local fmap = vim.keymap.set
fmap("n", "zR", ufo.openAllFolds, { desc = "모든 폴드 펼치기" })
fmap("n", "zM", ufo.closeAllFolds, { desc = "모든 폴드 접기" })
fmap("n", "zr", ufo.openFoldsExceptKinds, { desc = "한 단계 펼치기" })
fmap("n", "zm", ufo.closeFoldsWith, { desc = "한 단계 접기" })
fmap("n", "zp", function()
  if not ufo.peekFoldedLinesUnderCursor() then
    vim.lsp.buf.hover()
  end
end, { desc = "접힌 내용 미리보기" })

-- Telescope: 퍼지 파인더
local telescope = require("telescope")
telescope.setup({
  defaults = {
    layout_strategy = "horizontal",
    layout_config = { prompt_position = "top" },
    sorting_strategy = "ascending",
  },
})

-- 기존 fzf 키맵(<esc>b/f/h)은 그대로 두고, telescope 는 <leader>f* 네임스페이스 사용
local builtin = require("telescope.builtin")
local map = vim.keymap.set
map("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
map("n", "<leader>fg", builtin.live_grep, { desc = "Live grep (프로젝트 전체 검색)" })
map("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
map("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
map("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics 목록" })
