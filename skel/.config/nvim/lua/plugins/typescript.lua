-- TypeScript/JavaScript: erros na linha (diagnósticos) + autocomplete (blink.cmp) via LSP.
-- Projetos com deno.json usam o denols (`deno lsp`, do deno do sistema).
-- Projetos Node sem deno.json usam o vtsls (mesmo motor do VSCode), instalado pelo Mason.
-- ESLint (eslint-lsp) só liga onde houver config do eslint; Prettier (prettierd) só onde houver config do prettier.
-- Formatar ao salvar está DESLIGADO (evita reformatar arquivos inteiros nos commits): use <Space>lf.
-- Para desfazer: apague este arquivo.

local deno_markers = { "deno.json", "deno.jsonc" }
local prettier_markers = {
  ".prettierrc", ".prettierrc.json", ".prettierrc.js", ".prettierrc.cjs", ".prettierrc.mjs",
  ".prettierrc.yaml", ".prettierrc.yml", "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs",
}

local ts_inlay = {
  parameterNames = { enabled = "literals" },
  parameterTypes = { enabled = true },
  variableTypes = { enabled = false },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts_extend = { "ensure_installed" },
    opts = { ensure_installed = { "vtsls", "json-lsp", "eslint-lsp", "prettierd" } },
  },
  {
    "AstroNvim/astrolsp",
    ---@type AstroLSPOpts
    opts = {
      features = { inlay_hints = true }, -- tipos em cinza no código; alternar com <Space>uH
      formatting = { format_on_save = { enabled = false } },
      servers = { "denols" }, -- deno já está instalado fora do Mason
      config = {
        denols = {
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, deno_markers)
            if root then on_dir(root) end
          end,
          settings = {
            deno = { enable = true, lint = true, unstable = true, inlayHints = ts_inlay },
          },
        },
        vtsls = {
          root_dir = function(bufnr, on_dir)
            if vim.fs.root(bufnr, deno_markers) then return end -- deixa projetos Deno para o denols
            local root = vim.fs.root(bufnr, { "tsconfig.json", "jsconfig.json", "package.json", ".git" })
            if root then on_dir(root) end
          end,
          settings = {
            typescript = { inlayHints = ts_inlay, updateImportsOnFileMove = { enabled = "always" } },
            javascript = { inlayHints = ts_inlay, updateImportsOnFileMove = { enabled = "always" } },
            vtsls = { autoUseWorkspaceTsdk = true },
          },
        },
      },
    },
  },
  {
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
      local null_ls = require "null-ls"
      opts.sources = require("astrocore").list_insert_unique(opts.sources, {
        null_ls.builtins.formatting.prettierd.with {
          condition = function(utils)
            return utils.root_has_file(prettier_markers) and not utils.root_has_file(deno_markers)
          end,
        },
      })
    end,
  },
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = function(_, opts)
      opts.treesitter = opts.treesitter or {}
      opts.treesitter.ensure_installed = require("astrocore").list_insert_unique(
        opts.treesitter.ensure_installed or {},
        { "typescript", "tsx", "javascript", "json", "jsdoc" }
      )
    end,
  },
}
