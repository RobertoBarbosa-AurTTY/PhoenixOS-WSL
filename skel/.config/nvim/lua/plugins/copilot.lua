-- GitHub Copilot: sugestão em texto cinza enquanto digita (como no VSCode).
-- Login uma vez: :Copilot auth   ·   Status: :Copilot status
-- Tab aceita a sugestão do Copilot quando ela está visível; senão, Tab segue no menu do blink.cmp.
-- Para desfazer: apague este arquivo.

---@type LazySpec
return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      panel = { enabled = false },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        hide_during_completion = false,
        keymap = {
          accept = false, -- Tab é tratado no blink.cmp abaixo
          accept_word = "<M-Right>",
          accept_line = "<M-Down>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      filetypes = { yaml = true, markdown = true, gitcommit = true, ["*"] = true },
    },
  },
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.keymap = opts.keymap or {}
      local tab = opts.keymap["<Tab>"] or { "fallback" }
      table.insert(tab, 1, function()
        local ok, suggestion = pcall(require, "copilot.suggestion")
        if ok and suggestion.is_visible() then
          suggestion.accept()
          return true
        end
      end)
      opts.keymap["<Tab>"] = tab
    end,
  },
}
