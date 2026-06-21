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

-- Ensure uv-installed tools (ruff, yamllint) are on PATH
-- regardless of how nvim was launched (non-interactive shells, tmux,
-- desktop entries skip ~/.bashrc which normally adds ~/.local/bin).
vim.env.PATH = vim.fn.expand("~/.local/bin") .. ":" .. vim.env.PATH

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

-- Detect systemd unit files that live outside a /systemd/ path. Stock nvim
-- only maps *.service etc. to the "systemd" filetype when the path contains
-- "/systemd/", so bare files (project dirs, dotfile overrides, /etc/foo/)
-- would otherwise get no filetype — no syntax, no K man-page lookup, no
-- commentstring. Map the systemd-specific extensions globally.
vim.filetype.add({
	extension = {
		service = "systemd",
		socket = "systemd",
		timer = "systemd",
		target = "systemd",
		mount = "systemd",
		automount = "systemd",
		scope = "systemd",
		slice = "systemd",
		path = "systemd",
		swap = "systemd",
		dnssd = "systemd",
		nspawn = "systemd",
		netdev = "systemd",
	},
	-- *.conf inside a "*.service.d/" (or "*.unit.d/") drop-in dir is a systemd
	-- override, not a generic ini file.
	pattern = {
		[".*%.d/.+%.conf$"] = "systemd",
	},
})

-- =============================================================================
-- VisiData: open data files (csv/json/parquet/sqlite/xlsx/...) in `vd` inside
-- a new tmux tab instead of as plain text. uv-installed tools are already on
-- PATH (see PATH prepend above); install with `uv tool install visidata`.
-- Escape hatch: <leader>ev (or :EditRaw) on a matching buffer loads it as text.
-- =============================================================================
do
	local data_exts = {
		"csv", "tsv",
		"json", "jsonl", "geojson",
		"parquet", "arrow", "arrows",
		"sqlite", "sqlite3", "db",
		"xlsx", "xls", "ods",
		"hdf5", "h5",
		-- (yaml/yml removed — open as plain text; use :VisiData or vd manually if needed)
		"xml", "toml", "npy",
		"vcf", "vds",
		"dta", "sav", "sas7bdat", "xpt",
		"pcap",
		"shp", "pbf", "mbtiles",
		"png", "ttf",
		"eml", "mailbox", "mbox",
	}

	-- Build a single comma-separated pattern: *.{csv,tsv,...}
	local pattern = "*.{" .. table.concat(data_exts, ",") .. "}"

	-- BufReadCmd takes over the entire read for matching files, so nvim never
	-- loads the file content — important for large parquet/sqlite/xlsx. vd
	-- reads the file in its own process (in a new tmux tab); the empty stub
	-- buffer nvim creates for the read is deleted synchronously before nvim
	-- ever renders it.
	vim.api.nvim_create_autocmd("BufReadCmd", {
		group = vim.api.nvim_create_augroup("UserVisiData", {}),
		pattern = pattern,
		nested = true,
		callback = function(args)
			local path = args.match
			local buf = args.buf

			-- Escape hatch: buffer flagged, or :EditRaw one-shot flag → read
			-- the file as plain text ourselves (BufReadCmd owns the read, so
			-- returning without populating would leave an empty buffer).
			if vim.b[buf].skip_visidata or vim.g.skip_visidata_next then
				vim.g.skip_visidata_next = false
				local lines = vim.fn.readfile(path)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.bo[buf].modified = false
				vim.b[buf].skip_visidata = true
				return
			end

			-- No vd on PATH → fall back to a plain text read.
			if vim.fn.executable("vd") == 0 then
				local lines = vim.fn.readfile(path)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.bo[buf].modified = false
				return
			end

			-- Not in tmux → fall back to plain text read. You're "always in
			-- tmux", but this keeps a bare `nvim foo.csv` from breaking.
			if vim.env.TMUX == nil or vim.env.TMUX == "" then
				local lines = vim.fn.readfile(path)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.bo[buf].modified = false
				return
			end

			-- Launch vd in a new tmux tab (window). The call is synchronous:
			-- tmux creates the tab and steals focus to it while nvim is
			-- blocked, so the empty stub buffer is never rendered. When vd
			-- exits (press q) the tab closes and focus returns to nvim. vd
			-- runs in its own process — never inside any nvim buffer — and
			-- the file is read by vd, not nvim (safe for arbitrarily large
			-- files).
			vim.fn.system({
				"tmux", "new-window", "-n", vim.fn.fnamemodify(path, ":t"),
				"vd " .. vim.fn.shellescape(path),
			})
			-- Delete the empty stub buffer nvim created for this read.
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end,
	})

	-- :EditRaw — load a file as plain text in the current window, bypassing
	-- the vd tmux handoff.   :EditRaw          → current file
	--   :EditRaw foo.csv  → specific path
	vim.api.nvim_create_user_command("EditRaw", function(opts)
		local target = opts.args ~= "" and opts.args or vim.fn.expand("%:p")
		-- One-shot flag consumed by the BufReadCmd callback above.
		vim.g.skip_visidata_next = true
		vim.cmd("edit " .. vim.fn.fnameescape(target))
	end, { nargs = "*", bang = true })
end

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

-- -----------------------------------------------------------------------------
-- Plugins
-- -----------------------------------------------------------------------------
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
				integrations = {
					cmp = true,
					gitsigns = true,
					nvimtree = true,
					treesitter = true,
					telescope = { enabled = true },
					mason = true,
					which_key = true,
					native_lsp = { enabled = true, inlay_hints = { background = true } },
					bufferline = true,
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
					-- ruff is installed via `uv tool install ruff` (Python packaging on
					-- this host is broken — no pip + PEP 668 EXTERNALLY-MANAGED). The
					-- ruff LSP is enabled explicitly below; lspconfig finds the binary
					-- on PATH.
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
					-- systemd unit files (*.service, *.timer, *.socket, etc.).
					-- Requires ft=systemd (see vim.filetype.add below).
					"systemd_lsp",
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
					-- yamllint is a Python package installed via `uv tool install`
					-- (Mason's pip installer is broken on this host). nvim-lint
					-- finds it on PATH.
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
				-- Installed via `uv tool install ruff` (not Mason) — hence the
				-- explicit enable() rather than relying on mason-lspconfig auto-enable.
				vim.lsp.config("ruff", {
					capabilities = capabilities,
					on_attach = function(client, _)
						client.server_capabilities.hoverProvider = false
					end,
				})
				vim.lsp.enable("ruff")

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

				-- Load VSCode-style snippets from friendly-snippets
				require("luasnip.loaders.from_vscode").lazy_load()

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
						-- Tab/S-Tab: pure cmp menu cycling (no snippet logic).
						["<Tab>"] = cmp.mapping(function(fallback)
							if cmp.visible() then
								cmp.select_next_item()
							else
								fallback()
							end
						end, { "i", "s" }),
						["<S-Tab>"] = cmp.mapping(function(fallback)
							if cmp.visible() then
								cmp.select_prev_item()
							else
								fallback()
							end
						end, { "i", "s" }),
						-- Dedicated snippet keys (insert + select modes).
						-- <C-l>: expand snippet at trigger, or jump to next placeholder.
						-- <C-k>: jump to previous placeholder.
						-- Chosen to avoid all conflicts: vim-tmux-navigator binds
						-- <C-l>/<C-k> in NORMAL mode only; in insert mode <C-l> is
						-- unbound and <C-k>'s only default use is digraph entry
						-- (rarely needed). <C-h> is backspace (untouchable) and
						-- <C-j> is reserved per user request.
						["<C-l>"] = cmp.mapping(function(fallback)
							if luasnip.expandable() then
								luasnip.expand()
							elseif luasnip.locally_jumpable() then
								luasnip.jump(1)
							else
								fallback()
							end
						end, { "i", "s" }),
						["<C-k>"] = cmp.mapping(function(fallback)
							if luasnip.locally_jumpable(-1) then
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
				on_attach = function(bufnr)
					local api = require("nvim-tree.api")
					api.config.mappings.default_on_attach(bufnr)
					-- E: open the cursor's file as plain text, bypassing the
					-- VisiData tmux handoff (see BufReadCmd autocmd above).
					-- Uses node.open.edit() so the file opens in the main edit
					-- pane, not as a split inside the tree window.
				vim.keymap.set("n", "<leader>E", function()
					vim.g.skip_visidata_next = true
					api.node.open.edit()
				end, { buffer = bufnr, desc = "Open as text (skip visidata)" })

				-- Yank paths from the node under the cursor (clipboard via
				-- 'unnamedplus'); works across tmux/other apps.
				vim.keymap.set("n", "yp", api.fs.copy.absolute_path, { buffer = bufnr, desc = "Yank absolute path" })
				vim.keymap.set("n", "yr", api.fs.copy.relative_path, { buffer = bufnr, desc = "Yank repo-relative path" })
				vim.keymap.set("n", "yf", api.fs.copy.filename, { buffer = bufnr, desc = "Yank filename" })
				vim.keymap.set("n", "yb", api.fs.copy.basename, { buffer = bufnr, desc = "Yank basename (no ext)" })
			end,
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
					pickers = {
						live_grep = { additional_args = { "--hidden" } },
						find_files = { hidden = true },
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

		-- Comment.nvim — full default mappings (line + block)
		{
			"numToStr/Comment.nvim",
			event = { "BufReadPost", "BufNewFile" },
			opts = {},
		},

		-- tmux navigator: seamless <C-h/j/k/l> across nvim splits AND tmux panes
		{ "christoomey/vim-tmux-navigator", lazy = false },

		-- VS Code-style buffer tabline
		{
			"akinsho/bufferline.nvim",
			version = "*",
			dependencies = { "nvim-tree/nvim-web-devicons" },
			opts = {
				options = {
					diagnostics = "nvim_lsp",
					offsets = { { filetype = "NvimTree", text = "File Explorer", padding = 1 } },
				},
			},
		},

		-- Snippet library for LuaSnip (Python/Go/TS/Svelte/etc.)
		{ "rafamadriz/friendly-snippets" },

		-- Auto-close/rename tags in Svelte/HTML/TSX
		{ "windwp/nvim-ts-autotag", opts = {} },

		-- Show CSS colors + tailwind classes with their actual color in buffer
		{
			"NvChad/nvim-colorizer.lua",
			opts = { user_default_options = { tailwind = true, names = true } },
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
keymap("n", "<leader>pf", "<cmd>NvimTreeFindFile<CR>", { desc = "Reveal current file in tree" })

-- Yank current buffer's path from any window (tree has its own yp/yf/yb/yd)
keymap("n", "yp", function() vim.fn.setreg("+", vim.fn.expand("%:p")) end, { desc = "Yank cur buf abs path" })
keymap("n", "yP", function() vim.fn.setreg("+", vim.fn.expand("%:.")) end, { desc = "Yank cur buf rel path" })

-- Undotree
keymap("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle Undotree" })

-- Telescope
keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
keymap("v", "<leader>fg", function()
	-- Yank visual selection into register x, then pre-fill live_grep with it
	vim.cmd('noautocmd normal! "xy')
	local text = vim.fn.getreg("x")
	require("telescope.builtin").live_grep({ default_text = text })
end, { desc = "Live grep (selection)" })
keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
keymap("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Find help" })
keymap("n", "<leader>fr", "<cmd>Telescope resume<CR>", { desc = "Resume last picker" })
keymap("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Doc symbols" })
keymap("n", "<leader>fS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", { desc = "Workspace symbols" })

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

-- Buffer cycling (VS Code-style gt/gT + Shift-h/l)
-- <C-h/j/k/l> are provided by vim-tmux-navigator (cross nvim splits + tmux panes)
keymap("n", "gt", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
keymap("n", "gT", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev buffer" })
keymap("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })
keymap("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Prev buffer" })
keymap("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Close buffer" })

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
