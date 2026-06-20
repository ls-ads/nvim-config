-- =============================================================================
-- Neovim 0.11.5 config — Python (ruff + ty) / Go / SvelteKit / Docker / Bash
-- =============================================================================

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- -----------------------------------------------------------------------------
-- Leader + base options
-- -----------------------------------------------------------------------------
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
vim.opt.undofile = true

vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.updatetime = 250 -- faster CursorHold (gitsigns, diagnostics)
vim.opt.timeoutlen = 400 -- which-key feels snappier

-- Disable unused providers (silences :checkhealth warnings for remote plugins
-- we don't use; not related to LSP/treesitter/etc.)
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0

-- Filetype overrides — Go uses tabs, web/yaml use 2 spaces
vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function()
		vim.bo.expandtab = false
		vim.bo.tabstop = 4
		vim.bo.shiftwidth = 4
	end,
})
vim.api.nvim_create_autocmd("FileType", {
	pattern = {
		"svelte",
		"javascript",
		"typescript",
		"javascriptreact",
		"typescriptreact",
		"html",
		"css",
		"json",
		"jsonc",
		"yaml",
		"lua",
		"markdown",
	},
	callback = function()
		vim.bo.tabstop = 2
		vim.bo.softtabstop = 2
		vim.bo.shiftwidth = 2
	end,
})

-- Flash on yank (0.11 renamed vim.highlight -> vim.hl)
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.on_yank({ timeout = 150 })
	end,
})

-- -----------------------------------------------------------------------------
-- Diagnostics config (0.11+ API)
-- -----------------------------------------------------------------------------
vim.diagnostic.config({
	virtual_text = { spacing = 2, prefix = "●" },
	virtual_lines = false, -- toggled via <leader>dl below
	severity_sort = true,
	update_in_insert = false,
	float = { border = "rounded", source = true },
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "",
			[vim.diagnostic.severity.WARN] = "",
			[vim.diagnostic.severity.INFO] = "",
			[vim.diagnostic.severity.HINT] = "",
		},
	},
})

-- vim-visual-multi config must be set before plugin loads
vim.g.VM_maps = {
	["Find Under"] = "gb",
	["Find Subword Under"] = "gb",
}

-- -----------------------------------------------------------------------------
-- Plugins
-- -----------------------------------------------------------------------------
require("lazy").setup({
	spec = {
		-- Multi-cursor (VS Code "gb" style)
		{ "mg979/vim-visual-multi", branch = "master" },

		-- Colorscheme
		{
			"catppuccin/nvim",
			lazy = false,
			name = "catppuccin",
			priority = 1000,
			opts = {
				flavour = "mocha",
				integrations = {
					cmp = true,
					gitsigns = true,
					nvimtree = true,
					treesitter = true,
					telescope = { enabled = true },
					mason = true,
					which_key = true,
					native_lsp = { enabled = true, inlay_hints = { background = true } },
				},
			},
			config = function(_, opts)
				require("catppuccin").setup(opts)
				vim.cmd.colorscheme("catppuccin")
			end,
		},

		-- Treesitter
		{
			"nvim-treesitter/nvim-treesitter",
			branch = "master",
			build = ":TSUpdate",
			config = function()
				require("nvim-treesitter.configs").setup({
					ensure_installed = {
						"python",
						"javascript",
						"typescript",
						"tsx",
						"svelte",
						"css",
						"html",
						"lua",
						"vim",
						"vimdoc",
						"dockerfile",
						"yaml",
						"jinja",
						"json",
						"jsonc",
						"bash",
						"markdown",
						"markdown_inline",
						"go",
						"gomod",
						"gosum",
						"gowork",
						"toml",
						"git_config",
						"gitignore",
						"diff",
					},
					highlight = { enable = true },
					indent = { enable = true },
				})
			end,
		},

		-- Mason
		{ "mason-org/mason.nvim", config = true },

		{
			"mason-org/mason-lspconfig.nvim",
			dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
			opts = {
				ensure_installed = {
					"pyright", -- kept as a fallback; primary type checker is ty (configured below)
					"ruff", -- Astral linter/formatter LSP
					"ts_ls",
					"svelte", -- SvelteKit support
					"cssls",
					"tailwindcss",
					"dockerls",
					"docker_compose_language_service",
					"yamlls",
					"emmet_language_server",
					"bashls",
					"marksman",
					"gopls",
					"lua_ls",
				},
			},
		},

		-- Auto-install formatters/linters/extra tools via Mason (Mason itself only
		-- handles LSP servers; this fills the gap).
		{
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			dependencies = { "mason-org/mason.nvim" },
			config = function()
				require("mason-tool-installer").setup({
					ensure_installed = {
						-- Formatters
						"prettierd", -- svelte/ts/js/css/html/json/yaml/md
						"stylua", -- lua
						"shfmt", -- bash
						"goimports", -- go
						"gofumpt", -- go (stricter than gofmt)
						-- Linters
						"shellcheck", -- bash
						"hadolint", -- dockerfile
						"yamllint", -- yaml
						-- Go extras
						"golangci-lint",
					},
					auto_update = false,
					run_on_start = true,
				})
			end,
		},

		-- LSP configuration (uses 0.11+ vim.lsp.config API)
		{
			"neovim/nvim-lspconfig",
			dependencies = { "hrsh7th/cmp-nvim-lsp" },
			config = function()
				local capabilities = require("cmp_nvim_lsp").default_capabilities()

				----------------------------------------------------------------------
				-- Python: ty (Astral type checker) + ruff (lint/format)
				----------------------------------------------------------------------
				-- ty is pre-release. It's not yet in mason-lspconfig's known servers
				-- on all versions, so we configure it manually. Install ty via:
				--   uv tool install ty       (recommended)
				--   pipx install ty
				-- If `ty` isn't on PATH, this block silently no-ops and pyright (also
				-- configured below) handles types.
				if vim.fn.executable("ty") == 1 then
					vim.lsp.config("ty", {
						cmd = { "ty", "server" },
						filetypes = { "python" },
						root_markers = {
							"pyproject.toml",
							"ty.toml",
							"setup.py",
							"setup.cfg",
							"requirements.txt",
							".git",
						},
						capabilities = capabilities,
					})
					vim.lsp.enable("ty")
				end

				-- Ruff: linting, formatting, organize-imports, autofixes.
				-- Disable Ruff's hover so pyright/ty own hover documentation.
				vim.lsp.config("ruff", {
					capabilities = capabilities,
					on_attach = function(client, _)
						client.server_capabilities.hoverProvider = false
					end,
				})

				-- Pyright: kept as a secondary/fallback type checker.
				-- Disable its linting (analysis) since Ruff handles that — prevents
				-- duplicate diagnostics. If you want ty to be the SOLE type checker
				-- and never see pyright, remove "pyright" from ensure_installed above.
				vim.lsp.config("pyright", {
					capabilities = capabilities,
					settings = {
						pyright = {
							-- Use Ruff for import organization
							disableOrganizeImports = true,
						},
						python = {
							analysis = {
								-- If ty is running, let it own diagnostics
								ignore = vim.fn.executable("ty") == 1 and { "*" } or {},
								typeCheckingMode = "basic",
								diagnosticMode = "openFilesOnly",
								useLibraryCodeForTypes = true,
							},
						},
					},
				})

				----------------------------------------------------------------------
				-- Go: gopls with inlay hints + analyses
				----------------------------------------------------------------------
				vim.lsp.config("gopls", {
					capabilities = capabilities,
					settings = {
						gopls = {
							gofumpt = true,
							staticcheck = true,
							usePlaceholders = true,
							completeUnimported = true,
							analyses = {
								unusedparams = true,
								shadow = true,
								nilness = true,
								unusedwrite = true,
								useany = true,
							},
							hints = {
								assignVariableTypes = true,
								compositeLiteralFields = true,
								compositeLiteralTypes = true,
								constantValues = true,
								functionTypeParameters = true,
								parameterNames = true,
								rangeVariableTypes = true,
							},
						},
					},
				})

				----------------------------------------------------------------------
				-- SvelteKit
				----------------------------------------------------------------------
				vim.lsp.config("svelte", {
					capabilities = capabilities,
					on_attach = function(client, bufnr)
						-- Notify svelte LSP when companion .ts/.js files change so it
						-- re-checks the .svelte files that reference them.
						vim.api.nvim_create_autocmd("BufWritePost", {
							buffer = bufnr,
							pattern = { "*.js", "*.ts" },
							callback = function(ctx)
								client:notify("$/onDidChangeTsOrJsFile", { uri = vim.uri_from_fname(ctx.match) })
							end,
						})
					end,
				})

				-- ts_ls: enable Svelte plugin so .svelte <script> blocks get TS smarts
				vim.lsp.config("ts_ls", {
					capabilities = capabilities,
					init_options = {
						plugins = {
							{
								name = "typescript-svelte-plugin",
								location = vim.fn.stdpath("data")
									.. "/mason/packages/svelte-language-server/node_modules/typescript-svelte-plugin",
								languages = { "svelte" },
							},
						},
					},
					filetypes = {
						"javascript",
						"typescript",
						"javascriptreact",
						"typescriptreact",
						"svelte",
					},
				})

				----------------------------------------------------------------------
				-- Emmet
				----------------------------------------------------------------------
				vim.lsp.config("emmet_language_server", {
					capabilities = capabilities,
					filetypes = {
						"html",
						"css",
						"scss",
						"javascriptreact",
						"typescriptreact",
						"htmldjango",
						"jinja",
						"svelte",
					},
				})

				----------------------------------------------------------------------
				-- YAML — schema-aware
				----------------------------------------------------------------------
				vim.lsp.config("yamlls", {
					capabilities = capabilities,
					settings = {
						yaml = {
							keyOrdering = false,
							schemas = {
								["https://json.schemastore.org/github-workflow.json"] = ".github/workflows/*",
								["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = {
									"docker-compose*.y*ml",
									"compose*.y*ml",
								},
								["https://json.schemastore.org/kustomization.json"] = "kustomization.y*ml",
							},
						},
					},
				})

				----------------------------------------------------------------------
				-- Lua (for editing this config)
				----------------------------------------------------------------------
				vim.lsp.config("lua_ls", {
					capabilities = capabilities,
					settings = {
						Lua = {
							workspace = { checkThirdParty = false },
							telemetry = { enable = false },
							diagnostics = { globals = { "vim" } },
						},
					},
				})

				----------------------------------------------------------------------
				-- Remaining servers — plain config with capabilities
				----------------------------------------------------------------------
				for _, server in ipairs({
					"cssls",
					"tailwindcss",
					"dockerls",
					"docker_compose_language_service",
					"bashls",
					"marksman",
				}) do
					vim.lsp.config(server, { capabilities = capabilities })
				end
			end,
		},

		-- Tailwind colorizer in cmp menu
		{ "roobert/tailwindcss-colorizer-cmp.nvim", config = true },

		-- Autocompletion
		{
			"hrsh7th/nvim-cmp",
			dependencies = {
				"hrsh7th/cmp-nvim-lsp",
				"hrsh7th/cmp-buffer",
				"hrsh7th/cmp-path",
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
						{ name = "path" },
					}, {
						{ name = "buffer", keyword_length = 3 },
					}),
					formatting = {
						format = function(entry, item)
							local fmt = lspkind.cmp_format({
								mode = "symbol_text",
								maxwidth = 50,
							})(entry, item)
							return tailwind_formatter(entry, fmt)
						end,
					},
				})
			end,
		},

		-- Snippets
		{ "L3MON4D3/LuaSnip", version = "v2.*", build = "make install_jsregexp" },

		-- Icons
		{ "onsails/lspkind.nvim" },
		{ "nvim-tree/nvim-web-devicons", lazy = true },

		-- File tree
		{
			"nvim-tree/nvim-tree.lua",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			opts = {
				view = { width = 35 },
				renderer = { group_empty = true, highlight_git = true },
				filters = { dotfiles = false, custom = { "^.git$" } },
				git = { enable = true },
			},
		},

		-- Undotree
		{ "mbbill/undotree" },

		-- =========================================================================
		-- Telescope + fzf-native
		-- =========================================================================
		{
			"nvim-telescope/telescope.nvim",
			dependencies = {
				"nvim-lua/plenary.nvim",
				{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
			},
			config = function()
				local telescope = require("telescope")
				telescope.setup({
					defaults = {
						file_ignore_patterns = {
							"node_modules/",
							".git/",
							"%.lock",
							"dist/",
							"build/",
							"__pycache__/",
							"%.pyc",
							".svelte-kit/",
							".next/",
							"vendor/",
						},
						path_display = { "smart" },
					},
					extensions = {
						fzf = {
							fuzzy = true,
							override_generic_sorter = true,
							override_file_sorter = true,
							case_mode = "smart_case",
						},
					},
				})
				pcall(telescope.load_extension, "fzf")
			end,
		},

		-- =========================================================================
		-- conform.nvim — unified formatter with format-on-save
		-- =========================================================================
		{
			"stevearc/conform.nvim",
			event = { "BufWritePre" },
			cmd = { "ConformInfo" },
			config = function()
				require("conform").setup({
					formatters_by_ft = {
						python = { "ruff_organize_imports", "ruff_format" },
						go = { "goimports", "gofumpt" },
						svelte = { "prettierd" },
						javascript = { "prettierd" },
						typescript = { "prettierd" },
						javascriptreact = { "prettierd" },
						typescriptreact = { "prettierd" },
						html = { "prettierd" },
						css = { "prettierd" },
						scss = { "prettierd" },
						json = { "prettierd" },
						jsonc = { "prettierd" },
						yaml = { "prettierd" },
						markdown = { "prettierd" },
						lua = { "stylua" },
						sh = { "shfmt" },
						bash = { "shfmt" },
						-- Dockerfile + tf etc fall through to LSP formatting if available
					},
					format_on_save = function(bufnr)
						-- Bail on huge buffers (paste of generated code, etc.)
						if vim.api.nvim_buf_line_count(bufnr) > 10000 then
							return
						end
						return { timeout_ms = 2000, lsp_format = "fallback" }
					end,
				})
			end,
		},

		-- =========================================================================
		-- nvim-lint — non-LSP linters
		-- =========================================================================
		{
			"mfussenegger/nvim-lint",
			event = { "BufReadPost", "BufWritePost" },
			config = function()
				local lint = require("lint")
				lint.linters_by_ft = {
					sh = { "shellcheck" },
					bash = { "shellcheck" },
					dockerfile = { "hadolint" },
					yaml = { "yamllint" },
				}
				local grp = vim.api.nvim_create_augroup("UserLint", {})
				vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
					group = grp,
					callback = function()
						lint.try_lint()
					end,
				})
			end,
		},

		-- =========================================================================
		-- Quality-of-life
		-- =========================================================================
		{
			"lewis6991/gitsigns.nvim",
			event = { "BufReadPre", "BufNewFile" },
			opts = {
				signs = {
					add = { text = "▎" },
					change = { text = "▎" },
					delete = { text = "" },
					topdelete = { text = "" },
					changedelete = { text = "▎" },
					untracked = { text = "▎" },
				},
				current_line_blame = false,
			},
		},

		{
			"nvim-lualine/lualine.nvim",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			opts = {
				options = {
					theme = "auto",
					globalstatus = true,
					component_separators = { left = "│", right = "│" },
					section_separators = { left = "", right = "" },
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { "branch", "diff", "diagnostics" },
					lualine_c = { { "filename", path = 1 } },
					lualine_x = {
						function()
							local clients = vim.lsp.get_clients({ bufnr = 0 })
							if #clients == 0 then
								return ""
							end
							local names = {}
							for _, c in ipairs(clients) do
								table.insert(names, c.name)
							end
							return " " .. table.concat(names, ",")
						end,
						"encoding",
						"fileformat",
						"filetype",
					},
					lualine_y = { "progress" },
					lualine_z = { "location" },
				},
			},
		},

		{
			"folke/which-key.nvim",
			event = "VeryLazy",
			opts = {
				preset = "modern",
				spec = {
					{ "<leader>f", group = "find / format" },
					{ "<leader>g", group = "git / goto" },
					{ "<leader>c", group = "code" },
					{ "<leader>d", group = "diagnostics" },
					{ "<leader>r", group = "rename / refactor" },
					{ "<leader>t", group = "toggle / trouble" },
					{ "<leader>p", group = "project" },
				},
			},
		},

		{
			"folke/trouble.nvim",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			cmd = "Trouble",
			opts = {},
		},

		{
			"windwp/nvim-autopairs",
			event = "InsertEnter",
			config = function()
				require("nvim-autopairs").setup({})
				-- cmp integration: insert () after function completions
				local ok, cmp = pcall(require, "cmp")
				if ok then
					local cmp_ap = require("nvim-autopairs.completion.cmp")
					cmp.event:on("confirm_done", cmp_ap.on_confirm_done())
				end
			end,
		},

		-- Comment.nvim — auto-mappings disabled; we register only line-comment ones
		-- below so `gb`/`gbc` stay free for vim-visual-multi. This avoids both the
		-- which-key `<Nop>` false-positive and the `block = ""` validation error.
		{
			"numToStr/Comment.nvim",
			event = { "BufReadPost", "BufNewFile" },
			config = function()
				local comment = require("Comment")
				comment.setup({ mappings = false })

				local api = require("Comment.api")
				local esc = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)

				-- Line comments only
				vim.keymap.set("n", "gcc", api.toggle.linewise.current, { desc = "Comment toggle current line" })
				vim.keymap.set("n", "gco", function()
					api.insert.linewise.below()
				end, { desc = "Comment insert below" })
				vim.keymap.set("n", "gcO", function()
					api.insert.linewise.above()
				end, { desc = "Comment insert above" })
				vim.keymap.set("n", "gcA", function()
					api.insert.linewise.eol()
				end, { desc = "Comment insert end of line" })

				-- Operator-pending: gc{motion} (e.g. gcap, gc2j)
				vim.keymap.set("n", "gc", "<Plug>(comment_toggle_linewise)", { desc = "Comment toggle linewise" })
				-- Visual mode: select then gc
				vim.keymap.set("x", "gc", function()
					vim.api.nvim_feedkeys(esc, "nx", false)
					api.toggle.linewise(vim.fn.visualmode())
				end, { desc = "Comment toggle linewise (visual)" })
			end,
		},
	},

	checker = { enabled = true, notify = false },
})

-- =============================================================================
-- Keymaps
-- =============================================================================
local keymap = vim.keymap.set

-- File tree
keymap("n", "<leader>pv", ":NvimTreeToggle<CR>", { desc = "Toggle file explorer" })

-- Undotree
keymap("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle Undotree" })

-- Telescope
keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
keymap("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Find help" })
keymap("n", "<leader>fr", "<cmd>Telescope resume<CR>", { desc = "Resume last picker" })
keymap("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Doc symbols" })

-- Format manually (also runs on save via conform's format_on_save)
keymap({ "n", "v" }, "<leader>fm", function()
	require("conform").format({ lsp_format = "fallback", timeout_ms = 3000 })
end, { desc = "Format buffer/selection" })

-- Diagnostics — 0.11+ APIs (goto_prev/next are deprecated)
keymap("n", "<leader>e", vim.diagnostic.open_float, { desc = "Line diagnostics" })
keymap("n", "[d", function()
	vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Prev diagnostic" })
keymap("n", "]d", function()
	vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
keymap("n", "<leader>dl", function()
	local cfg = vim.diagnostic.config()
	vim.diagnostic.config({
		virtual_lines = not cfg.virtual_lines,
		virtual_text = cfg.virtual_lines,
	})
end, { desc = "Toggle virtual lines vs virtual text" })

-- Trouble
keymap("n", "<leader>tt", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Workspace diagnostics" })
keymap("n", "<leader>tb", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Buffer diagnostics" })
keymap("n", "<leader>tr", "<cmd>Trouble lsp_references toggle<CR>", { desc = "LSP references" })

-- Window navigation
keymap("n", "<C-h>", "<C-w>h", { desc = "Window left" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Window down" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Window up" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Better defaults
keymap("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
keymap("v", "<", "<gv", { desc = "Indent left (stay in visual)" })
keymap("v", ">", ">gv", { desc = "Indent right (stay in visual)" })
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- =============================================================================
-- LSP on-attach: buffer-local keymaps + inlay hints
-- =============================================================================
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(event)
		local bufnr = event.buf
		local client = vim.lsp.get_client_by_id(event.data.client_id)

		local nmap = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { buffer = bufnr, noremap = true, silent = true, desc = "LSP: " .. desc })
		end

		nmap("gd", vim.lsp.buf.definition, "Go to Definition")
		nmap("gD", vim.lsp.buf.declaration, "Go to Declaration")
		nmap("K", vim.lsp.buf.hover, "Hover Documentation")
		nmap("gi", vim.lsp.buf.implementation, "Go to Implementation")
		nmap("<leader>D", vim.lsp.buf.type_definition, "Type Definition")
		nmap("<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
		nmap("<leader>ca", vim.lsp.buf.code_action, "Code Action")
		nmap("<leader>gr", vim.lsp.buf.references, "Find References")
		nmap("<leader>gs", vim.lsp.buf.document_symbol, "Document Symbols")

		-- Inlay hints (Go especially benefits)
		-- 0.11+: method-call syntax (client:supports_method) — the dot form is deprecated.
		if client and client:supports_method("textDocument/inlayHint") then
			vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
			nmap("<leader>th", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
			end, "Toggle Inlay Hints")
		end
	end,
})

-- =============================================================================
-- Go: organize imports on save (gopls code action, not just format)
-- conform handles `goimports` formatting; this triggers gopls's
-- `source.organizeImports` which removes unused imports too.
-- =============================================================================
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*.go",
	callback = function()
		local params = vim.lsp.util.make_range_params(0, "utf-8")
		params.context = { only = { "source.organizeImports" } }
		local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
		for _, res in pairs(result or {}) do
			for _, action in pairs(res.result or {}) do
				if action.edit then
					vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
				end
			end
		end
	end,
})
