return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-python",
  },
  keys = {
    { "<leader>tr", function() require("neotest").run.run() end, desc = "Run Nearest Test" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run File Test" },
    { "<leader>to", function() require("neotest").output_panel.toggle() end, desc = "Toggle Output Panel" },
    { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Summary" },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-python")({
          runner = "pytest", -- Cambia a "unittest" si no usas pytest
        }),
      },
    })
  end,
}
