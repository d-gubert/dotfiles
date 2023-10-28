vim.api.nvim_command([[ autocmd BufWritePre * :%s/\s\+$//e ]])

vim.api.nvim_create_user_command('DisableEslintDiagnostics', function()
	for id, namespace in pairs(vim.diagnostic.get_namespaces()) do
		-- for some reason this is the name of the `eslint` namespace
		if namespace.name == 'NULL_LS_SOURCE_3' then
			vim.diagnostic.disable(nil, id)
		end
	end
end, {})

