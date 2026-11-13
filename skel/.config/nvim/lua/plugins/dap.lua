---@type LazySpec
return {
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = {
      handlers = {
        -- O mason-nvim-dap nao tem mapping pronto para pwa-node/js-debug,
        -- entao registramos o adapter manualmente. Roda quando o pacote
        -- js-debug-adapter (fonte "js") esta/termina de ser instalado.
        ["js"] = function()
          require("dap").adapters["pwa-node"] = {
            type = "server",
            host = "127.0.0.1",
            port = "${port}",
            executable = {
              command = "js-debug-adapter",
              args = { "${port}" },
            },
          }
        end,
      },
    },
  },
}
