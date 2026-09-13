-- 자동완성 + LSP (범용, Nix LSP=nixd 대상)
-- neovim.nix 의 extraLuaConfig 에서 require("lsp") 로 로드됨

local map = vim.keymap.set

--------------------------------------------------------------------------------
-- 자동완성 (nvim-cmp + LuaSnip)
--------------------------------------------------------------------------------
local cmp = require("cmp")
local luasnip = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load() -- friendly-snippets

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = false }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
  }, {
    { name = "buffer" },
    { name = "path" },
  }),
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()

--------------------------------------------------------------------------------
-- 진단 표시
--------------------------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

--------------------------------------------------------------------------------
-- LSP 키맵 (LspAttach 시 버퍼 로컬로 적용) — neovim 0.11+ 권장 방식
--------------------------------------------------------------------------------
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf
    if vim.lsp.inlay_hint then
      pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
    end

    local function bmap(lhs, rhs, desc)
      map("n", lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
    end
    local builtin = require("telescope.builtin")

    bmap("gd", vim.lsp.buf.definition, "정의로 이동")
    bmap("gD", vim.lsp.buf.declaration, "선언으로 이동")
    bmap("gi", builtin.lsp_implementations, "구현으로 이동")
    bmap("gr", builtin.lsp_references, "사용처 찾기")
    bmap("K", function() vim.lsp.buf.hover() end, "빠른 문서")
    bmap("<leader>rn", vim.lsp.buf.rename, "이름 변경")
    bmap("<leader>F", function() vim.lsp.buf.format({ async = false }) end, "포맷")
    bmap("<leader>e", vim.diagnostic.open_float, "현재 줄 진단 보기")
    bmap("<leader>fs", builtin.lsp_document_symbols, "문서 심볼")
    bmap("<leader>fw", builtin.lsp_dynamic_workspace_symbols, "워크스페이스 심볼")

    local function diag_jump(count)
      if vim.diagnostic.jump then
        vim.diagnostic.jump({ count = count, float = true })
      elseif count > 0 then
        vim.diagnostic.goto_next()
      else
        vim.diagnostic.goto_prev()
      end
    end
    bmap("]d", function() diag_jump(1) end, "다음 진단")
    bmap("[d", function() diag_jump(-1) end, "이전 진단")
  end,
})

--------------------------------------------------------------------------------
-- Nix LSP (nixd) — neovim 0.11+ 네이티브 API.
-- 서버 base 정의(cmd/filetypes/root)는 nvim-lspconfig 의 lsp/nixd.lua 가 제공하고,
-- 여기서는 capabilities 만 얹어 활성화한다. (nixd 바이너리는 neovim.nix extraPackages)
--------------------------------------------------------------------------------
vim.lsp.config("nixd", { capabilities = capabilities })
vim.lsp.enable("nixd")
