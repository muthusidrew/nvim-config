return {
	{
		"stevearc/overseer.nvim",
		cmd = {
			"OverseerOpen",
			"OverseerClose",
			"OverseerToggle",
			"OverseerSaveBundle",
			"OverseerLoadBundle",
			"OverseerDeleteBundle",
			"OverseerRunCmd",
			"OverseerRun",
			"OverseerInfo",
			"OverseerBuild",
			"OverseerQuickAction",
			"OverseerTaskAction",
			"OverseerClearCache",
		},
		strategy = "terminal",
		opts = {
			dap = false,
			task_list = {
				bindings = {
					["<C-h>"] = false,
					["<C-j>"] = false,
					["<C-k>"] = false,
					["<C-l>"] = false,
				},
			},
			form = { win_opts = { winblend = 0 } },
			confirm = { win_opts = { winblend = 0 } },
			task_win = { win_opts = { winblend = 0 } },
		},
		config = function(_, opts)
			require("overseer").setup(opts)

			local is_win = vim.fn.has("win32") == 1

			local function shell_cmd(command)
				if is_win then
					return { cmd = "cmd", args = { "/c", command } }
				else
					return { cmd = "sh", args = { "-c", command } }
				end
			end

			local function common_components()
				return {
					{ "on_output_quickfix", open = true },
					"on_exit_set_status",
					"default",
				}
			end

			-- C build and run
			require("overseer").register_template({
				name = "Build and Run C File",
				desc = "Compile C file with gcc and run it",
				condition = { filetype = "c" },
				builder = function()
					local file = vim.fn.expand("%:p")
					local output = vim.fn.expand("%:r")

					if is_win then
						output = output .. ".exe"
						-- cmd.exe parses the && chain; quoting is done once, by us.
						-- No outer cmd /c wrapper needed because Overseer will spawn
						-- cmd directly with these args.
						local cmdline =
							string.format('gcc -Wall -Wextra -std=c17 "%s" -o "%s" && "%s"', file, output, output)
						return {
							cmd = "cmd",
							args = { "/c", cmdline },
							components = common_components(),
						}
					end

					local sc = shell_cmd(
						string.format(
							"gcc -Wall -Wextra -std=c17 %s -o %s && %s",
							vim.fn.shellescape(file),
							vim.fn.shellescape(output),
							vim.fn.shellescape("./" .. output)
						)
					)
					return vim.tbl_extend("force", sc, { components = common_components() })
				end,
			})

			-- Python: run directly, no shell at all
			require("overseer").register_template({
				name = "Run Python File",
				desc = "Execute current Python file (auto venv detection)",
				condition = { filetype = "python" },
				builder = function()
					local file = vim.fn.expand("%:p")
					local current_dir = vim.fn.fnamemodify(file, ":h")

					local venv_candidates = is_win and { "venv/Scripts/python.exe", ".venv/Scripts/python.exe" }
						or { "venv/bin/python", ".venv/bin/python" }

					local venv_python = vim.fs.find(venv_candidates, {
						upward = true,
						path = current_dir,
						type = "file",
					})[1]

					local python_cmd = venv_python or (is_win and "python" or "python3")

					return {
						cmd = { python_cmd }, -- table → CreateProcess directly
						args = { file }, -- Overseer quotes each arg itself
						components = {
							{ "on_output_quickfix", open = true },
							"on_exit_set_status",
							"default",
						},
						env = venv_python and {
							VIRTUAL_ENV = vim.fn.fnamemodify(venv_python, ":h:h"),
						} or nil,
					}
				end,
			})

			-- Rust build and run
			require("overseer").register_template({
				name = "Build and Run Rust File",
				desc = "Compile Rust file with cargo and run it",
				condition = { filetype = "rust" },
				builder = function()
					local cargo_toml = vim.fs.find("Cargo.toml", { upward = true })[1]

					if not cargo_toml then
						return {
							cmd = is_win and "cmd" or "echo",
							args = is_win and { "/c", "echo Error: No Cargo.toml found" }
								or { "Error: No Cargo.toml found" },
						}
					end

					return {
						cmd = "cargo",
						args = { "run", "--quiet", "--manifest-path", cargo_toml },
						components = common_components(),
					}
				end,
			})
		end,
		-- stylua: ignore
		keys = {
			{ "<leader>ow", "<cmd>OverseerToggle<cr>",      desc = "Task list" },
			{ "<leader>oo", "<cmd>OverseerRun<cr>",         desc = "Run task" },
			{ "<leader>oq", "<cmd>OverseerQuickAction<cr>", desc = "Action recent task" },
			{ "<leader>oi", "<cmd>OverseerInfo<cr>",        desc = "Overseer Info" },
			{ "<leader>ob", "<cmd>OverseerBuild<cr>",       desc = "Task builder" },
			{ "<leader>ot", "<cmd>OverseerTaskAction<cr>",  desc = "Task action" },
			{ "<leader>oc", "<cmd>OverseerClearCache<cr>",  desc = "Clear cache" },
			{ "<leader>bb", "<cmd>OverseerBuild<cr>",       desc = "Build C File" },
			{ "<leader>pr", "<cmd>OverseerRun Run Python File<cr>", desc = "Run Python File" },
		},
	},
}
