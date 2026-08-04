return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			setup = {
				vtsls = function ()
					-- When working with the Apps-Engine's deno-runtime, I need a specific version of Deno, pointing to the correct cache
					local overrideCmdIfMatchesDenoRuntime = function (basePath)
						if basePath:match('deno%-runtime') == nil then
							return false
						end

						local newOpt = {
							cmd = { vim.fs.abspath('~/.dvm/bin/deno'), 'lsp' },
							cmd_env = {
								NO_COLOR = true,
								DENO_DIR = vim.fs.joinpath(vim.fs.dirname(basePath), ".deno-cache"),
							}
						}

						vim.print(newOpt)

						vim.lsp.config('denols', newOpt)

						return true;
					end

					overrideCmdIfMatchesDenoRuntime(vim.env.PWD)

					for dir in vim.fs.parents(vim.env.PWD) do
						if overrideCmdIfMatchesDenoRuntime(dir) then
							return
						end
					end
				end
			},
			servers = {
				vtsls = {
					experimental = {
						enableServerSideFuzzyMatch = true,
					},
					settings = {
						["js/ts.hover.maximumLength"] = 10000,
						typescript = {
							preferences = {
								preferTypeOnlyAutoImports = true,
								importModuleSpecifier = "relative",
							},
							-- preferGoToSourceDefinition = true,
							tsserver = {
								-- From docs: To use a memory limit greater than 4 GB, use `#typescript.tsserver.nodePath#` to run TS Server with a custom Node installation.
								maxTsServerMemory = 8192,
								nodePath = 'node',
							}
						},
						javascript = {
							preferences = {
								importModuleSpecifier = "relative",
							},
							-- preferGoToSourceDefinition = true,
						}
					}
				}
			}
		}
	}
}
