-- vim.api.nvim_command([[ autocmd BufWritePre * :%s/\s\+$//e ]])
vim.api.nvim_create_autocmd('BufWritePre', {
	pattern = '*',
	command = [[ %s/\s\+$//e ]]
})

vim.api.nvim_create_user_command('DisableEslintDiagnostics', function()
	for id, namespace in pairs(vim.diagnostic.get_namespaces()) do
		-- for some reason this is the name of the `eslint` namespace
		if namespace.name == 'NULL_LS_SOURCE_3' then
			vim.diagnostic.disable(nil, id)
		end
	end
end, {})

vim.api.nvim_create_user_command('DisableTSServer', function()
	for _, client in pairs(vim.lsp.get_active_clients()) do
		-- for some reason this is the name of the `tsserver` namespace
		if client.config.name == 'tsserver' then
			vim.lsp.stop_client(client.id)
		end
	end
end, {})

-- Project specific command
vim.api.nvim_create_user_command('DenoRuntimeDisable', function()
	vim.cmd.DisableTSServer()
	vim.cmd.DisableEslintDiagnostics()
end, {})
