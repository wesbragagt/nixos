-- minimal neovim 0.12+ config: vim.pack + built-in LSP + Nix-managed tools

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.undofile = true
opt.swapfile = false
opt.scrolloff = 8
opt.splitright = true
opt.splitbelow = true

-- vim.pack: built-in package manager (neovim 0.12+)
vim.pack.add({
  { src = "https://github.com/rebelot/kanagawa.nvim" },
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
  { src = "https://github.com/supermaven-inc/supermaven-nvim" },
  { src = "https://github.com/christoomey/vim-tmux-navigator" },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/stevearc/oil.nvim" },
  { src = "https://github.com/nvim-tree/nvim-tree.lua" },
  { src = "https://github.com/tpope/vim-fugitive" },
  { src = "https://github.com/norcalli/nvim-colorizer.lua" },
  { src = "https://github.com/folke/zen-mode.nvim" },
})

vim.pack.add({
  { src = "https://github.com/windwp/nvim-autopairs" },
}, { load = false })

require("fzf-lua").setup({})
require("blink.cmp").setup({
  keymap = { preset = "default" },
  appearance = { nerd_font_variant = "mono" },
  completion = { documentation = { auto_show = true, auto_show_delay_ms = 200 } },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  fuzzy = { implementation = "prefer_rust_with_warning" },
})

require("supermaven-nvim").setup({
  keymaps = {
    accept_suggestion = "<C-y>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = {
    gitcommit = true,
    gitrebase = true,
    help = true,
    oil = true,
  },
})

require("nvim-web-devicons").setup({})
require("colorizer").setup({
  "*",
}, {
  RGB = true,
  RRGGBB = true,
  RRGGBBAA = true,
  names = false,
  rgb_fn = true,
  hsl_fn = true,
  css = true,
  css_fn = true,
  mode = "background",
})
require("oil").setup({
  columns = { "icon" },
})
require("nvim-tree").setup({
  view = { width = 35 },
  filters = { dotfiles = false },
  git = { ignore = false },
})
require("zen-mode").setup({
  window = {
    backdrop = 0.95,
    width = 90,
    options = {
      colorcolumn = "",
      cursorline = false,
      foldcolumn = "0",
      list = false,
      number = false,
      relativenumber = false,
      signcolumn = "no",
    },
  },
  plugins = {
    options = {
      enabled = true,
      laststatus = 0,
      ruler = false,
      showcmd = false,
    },
  },
})

vim.api.nvim_create_autocmd("InsertEnter", {
  once = true,
  callback = function()
    vim.cmd.packadd("nvim-autopairs")
    require("nvim-autopairs").setup({})
  end,
})

local default_laststatus = vim.opt.laststatus:get()

local function markdown_mode()
  vim.opt_local.wrap = true
  vim.opt_local.linebreak = true
  vim.opt_local.breakindent = true
  vim.opt_local.conceallevel = 2
  vim.opt_local.concealcursor = "nc"
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
  vim.opt_local.signcolumn = "no"
  vim.opt_local.foldcolumn = "0"
  vim.opt_local.statuscolumn = ""
  vim.opt_local.colorcolumn = ""
  vim.opt_local.cursorline = false
  vim.opt_local.list = false
  vim.opt.laststatus = 0

end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = markdown_mode,
})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.md",
  callback = markdown_mode,
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = "*.md",
  callback = function()
    vim.opt.laststatus = default_laststatus
  end,
})

require("kanagawa").setup({
  transparent = true,
  dimInactive = true,
  colors = {
    theme = {
      all = {
        ui = {
          bg_gutter = "none",
        },
      },
    },
  },
  overrides = function(colors)
    local theme = colors.theme
    return {
      NormalFloat = { bg = "none" },
      FloatBorder = { bg = "none" },
      SignColumn = { bg = "none" },
      LineNr = { fg = theme.ui.nontext, bg = "none" },
      StatusLine = { bg = "none" },
      StatusLineNC = { bg = "none" },
    }
  end,
})

vim.cmd.colorscheme("kanagawa")

local fzf = require("fzf-lua")
vim.keymap.set("n", "<leader>sf", fzf.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>sg", fzf.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>gs", function()
  vim.cmd("Git")
end, { desc = "Git status" })
vim.keymap.set("n", "<leader><Space>", fzf.buffers, { desc = "Buffers" })
vim.keymap.set("n", "<leader>di", vim.diagnostic.setqflist, { desc = "Diagnostics quickfix" })
vim.keymap.set("n", "<leader>pt", function()
  vim.cmd("Oil")
end, { desc = "Open Oil" })
vim.keymap.set("n", "<leader>E", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })
vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<cr>", { desc = "Toggle Zen Mode" })

vim.keymap.set("x", "<leader>y", '"+y', { desc = "Yank selection to system clipboard" })
vim.keymap.set("n", "<leader>p", '"+p', { desc = "Paste below from system clipboard" })
vim.keymap.set("x", "<leader>p", '"+p', { desc = "Paste below from system clipboard" })
vim.keymap.set("n", "<leader>P", '"+P', { desc = "Paste above from system clipboard" })
vim.keymap.set("x", "<leader>P", '"+P', { desc = "Paste above from system clipboard" })

require("lsp").setup(require("blink.cmp").get_lsp_capabilities())

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gr", vim.lsp.buf.references, "References")
    map("n", "K", vim.lsp.buf.hover, "Hover")
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
    map("n", "<leader>ca", vim.lsp.buf.code_action, "Code action")
    map("n", "[d", function()
      vim.diagnostic.jump({
        count = -1,
        on_jump = function(_, bufnr)
          vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
        end,
      })
    end, "Prev diagnostic")
    map("n", "]d", function()
      vim.diagnostic.jump({
        count = 1,
        on_jump = function(_, bufnr)
          vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
        end,
      })
    end, "Next diagnostic")
  end,
})
