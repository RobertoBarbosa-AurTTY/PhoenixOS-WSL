-- Extras de editor: chat do Copilot e painel de erros (como "Problems" do VSCode).
-- Para desfazer: apague este arquivo.

---@type LazySpec
return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = { "zbirenbaum/copilot.lua", "nvim-lua/plenary.nvim" },
    cmd = { "CopilotChat", "CopilotChatToggle", "CopilotChatExplain", "CopilotChatFix", "CopilotChatTests", "CopilotChatReview", "CopilotChatOptimize" },
    opts = {
      window = { layout = "vertical", width = 0.4 },
      prompts = {
        Explain = { prompt = "Explique o código selecionado em português, de forma direta." },
        Fix = { prompt = "Há um problema neste código. Reescreva-o corrigindo o bug e explique em português." },
        Tests = { prompt = "Escreva testes para o código selecionado. Explicações em português." },
        Review = { prompt = "Revise o código selecionado e aponte problemas em português." },
        Optimize = { prompt = "Otimize o código selecionado e explique as mudanças em português." },
      },
    },
    keys = {
      { "<Leader>a", nil, desc = "AI / Copilot Chat", mode = { "n", "v" } },
      { "<Leader>ac", "<cmd>CopilotChatToggle<cr>", desc = "Abrir/fechar chat", mode = { "n", "v" } },
      { "<Leader>ae", "<cmd>CopilotChatExplain<cr>", desc = "Explicar", mode = { "n", "v" } },
      { "<Leader>af", "<cmd>CopilotChatFix<cr>", desc = "Corrigir", mode = { "n", "v" } },
      { "<Leader>at", "<cmd>CopilotChatTests<cr>", desc = "Gerar testes", mode = { "n", "v" } },
      { "<Leader>ar", "<cmd>CopilotChatReview<cr>", desc = "Revisar", mode = { "n", "v" } },
      { "<Leader>ao", "<cmd>CopilotChatOptimize<cr>", desc = "Otimizar", mode = { "n", "v" } },
    },
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    keys = {
      { "<Leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Erros do projeto" },
      { "<Leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Erros do arquivo" },
      { "<Leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Símbolos do arquivo" },
    },
  },
}
