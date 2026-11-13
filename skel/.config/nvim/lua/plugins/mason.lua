---@type LazySpec
return {
  -- use mason-tool-installer for automatically installing Mason packages
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {
        -- debug adapter (DAP) para pwa-node/Deno usado em .vscode/launch.json
        "js-debug-adapter",
      },
    },
  },
}
