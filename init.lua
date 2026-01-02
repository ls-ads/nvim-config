-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- Set leader key and basic options
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.wrap = false
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true -- Enable persistent undo

-- Disable optional providers you don't use (cleans up :checkhealth)
vim.g.loaded_perl_provider = 0

-- Setup lazy.nvim with plugins
require("lazy").setup({
  spec = {
    -- Colorscheme
    {
      "catppuccin/nvim",
      lazy = false,
      name = "catppuccin",
      priority = 1000,
      opts = {
        flavour = "mocha",
      },
      config = function(_, opts)
        require("catppuccin").setup(opts)
        vim.cmd.colorscheme "catppuccin"
      end,
    },

    -- Syntax Highlighting
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      config = function()
        require("nvim-treesitter.configs").setup({
          ensure_installed = {
            "python", "javascript", "css", "html", "lua",
            "vim", "dockerfile", "yaml", "jinja",
            "bash", "markdown", "markdown_inline",
            "go", "gomod", -- ADDED THIS: Go syntax highlighting
          },
          highlight = { enable = true },
        })
      end,
    },

    -- LSP Setup (Modernized for Nvim 0.11+ and Mason v2+)

    -- Mason installer (config=true calls mason.setup() automatically)
    { "mason-org/mason.nvim", config = true },

    {
      "mason-org/mason-lspconfig.nvim",
      dependencies = {
        "mason-org/mason.nvim",
        "neovim/nvim-lspconfig",
      },
      opts = {
        -- Define the list of servers to install.
        ensure_installed = {
            "pyright",
            "ts_ls", 
            "cssls",
            "tailwindcss",
            "dockerls",
            "yamlls",
            "emmet_language_server",
            "bashls",
            "marksman",
            "gopls", -- ADDED THIS: Go Language Server
        },
      }
    },

    {
      "neovim/nvim-lspconfig",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp", 
      },
      config = function()
        -- Get capabilities for nvim-cmp integration
        local capabilities = require("cmp_nvim_lsp").default_capabilities()

        -- Configure Emmet
        vim.lsp.config("emmet_language_server", {
            capabilities = capabilities,
            filetypes = {
                "html", "css", "scss", "javascriptreact",
                "typescriptreact", "htmldjango", "jinja"
            },
        })

        -- Configure other servers
        local standard_servers = {
            "pyright",
            "ts_ls",
            "cssls",
            "tailwindcss",
            "dockerls",
            "yamlls",
            "bashls",
            "marksman",
            "gopls", -- ADDED THIS: Initialize Go Server
        }

        for _, server in ipairs(standard_servers) do
            vim.lsp.config(server, {
                capabilities = capabilities,
            })
        end
      end
    },

    -- Tailwind Colorizer (Shows colors in the autocomplete menu)
    {
      "roobert/tailwindcss-colorizer-cmp.nvim",
      config = true,
    },

    -- Autocompletion
    {
      "hrsh7th/nvim-cmp",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "onsails/lspkind.nvim",
        "roobert/tailwindcss-colorizer-cmp.nvim",
      },
      config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")
        local lspkind = require("lspkind")
        local tailwind_formatter = require("tailwindcss-colorizer-cmp").formatter

        cmp.setup({
          snippet = {
            expand = function(args)
              luasnip.lsp_expand(args.body)
            end,
          },
          mapping = cmp.mapping.preset.insert({
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<C-e>"] = cmp.mapping.abort(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
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
          }),
          formatting = {
            -- Combine lspkind (icons) with tailwind-colorizer (colors)
            format = function(entry, item)
                -- 1. Generate the standard lspkind icon and text
                local fmt = lspkind.cmp_format({
                    mode = "symbol_text",
                    maxwidth = 50,
                })(entry, item)
                
                -- 2. Pass that result through the tailwind colorizer
                return tailwind_formatter(entry, fmt)
            end
          },
        })
      end,
    },

    -- Snippet Engine
    {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        build = "make install_jsregexp",
    },

    -- Icon packs
    { "onsails/lspkind.nvim" },
    { "nvim-tree/nvim-web-devicons", lazy = true },

    -- File Tree
    {
      "nvim-tree/nvim-tree.lua",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      opts = {},
    },

    -- Undo Tree
    {
      "mbbill/undotree",
    },

    -- Fuzzy Finder
    {
      "nvim-telescope/telescope.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
      config = function()
        require("telescope").setup({})
      end,
    },

  },
  -- lazy.nvim options
  checker = { enabled = true },
})

---
--- General Keymaps
---

local keymap = vim.keymap.set

-- NvimTree (File Explorer)
keymap("n", "<leader>pv", ":NvimTreeToggle<CR>", { desc = "Toggle file explorer" })

-- Undotree
keymap("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle Undotree" })

-- Telescope (Fuzzy Finder)
keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
keymap("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Find help" })

---
--- LSP Keymaps (Uses the LspAttach Autocommand, standard for Nvim 0.11+)
---

local function on_lsp_attach(event)
  local bufnr = event.buf
  local nmap = function(keys, func, desc)
    if desc then
      desc = "LSP: " .. desc
    end
    vim.keymap.set("n", keys, func, { buffer = bufnr, noremap = true, silent = true, desc = desc })
  end

  -- Standard LSP Keymaps
  nmap("gd", vim.lsp.buf.definition, "Go to Definition")
  nmap("K", vim.lsp.buf.hover, "Hover Documentation")
  nmap("gi", vim.lsp.buf.implementation, "Go to Implementation")
  nmap("<leader>D", vim.lsp.buf.type_definition, "Go to Type Definition")
  nmap("<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
  nmap("<leader>ca", vim.lsp.buf.code_action, "Code Action")
  nmap("<leader>gr", vim.lsp.buf.references, "Find References")
  nmap("<leader>e", vim.diagnostic.open_float, "Show Line Diagnostics")
  nmap("[d", vim.diagnostic.goto_prev, "Go to Previous Diagnostic")
  nmap("]d", vim.diagnostic.goto_next, "Go to Next Diagnostic")
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", {}),
  callback = on_lsp_attach,
})
