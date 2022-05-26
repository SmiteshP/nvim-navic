local M = {}

local function request_symbol(for_buf, handler)
	vim.lsp.buf_request_all(
		for_buf,
		"textDocument/documentSymbol",
		{ textDocument = vim.lsp.util.make_text_document_params() },
		function(symbols)
			handler(for_buf, symbols[vim.b.gps_client_id].result)
		end
	)
end

local function parse(symbols, for_buf)
	local parsed_symbols = {}

	local function dfs(curr_symbol)
		local ret = {}

		for _, val in ipairs(curr_symbol) do
			local curr_parsed_symbol = {}

			local name_range = val.selectionRange
			local scope = val.range

			name_range["start"].line = name_range["start"].line + 1
			name_range["end"].line = name_range["end"].line + 1

			scope["start"].line = scope["start"].line + 1
			scope["end"].line = scope["end"].line + 1

			local name = ""
			if val.name ~= "<Anonymous>" then
				name = table.concat(
					vim.api.nvim_buf_get_text(
						for_buf,
						name_range["start"].line - 1,
						name_range["start"].character,
						name_range["end"].line - 1,
						name_range["end"].character,
						{}
					)
				)
			else
				name = "Anon"
			end

			curr_parsed_symbol = {
				name = name,
				name_range = name_range,
				scope = scope,
				kind = val.kind,
			}

			if val.children then
				curr_parsed_symbol.children = dfs(val.children)
			end

			ret[#ret + 1] = curr_parsed_symbol
		end

		return ret
	end

	parsed_symbols = dfs(symbols)

	return parsed_symbols
end

local function update_data(for_buf, symbols)
	vim.b.gps_symbols = parse(symbols, for_buf)
end

function M.get_data()
	-- request_symbol(vim.api.nvim_get_current_buf(), handler)
	vim.pretty_print(vim.b.gps_symbols)
end

function M.attach(client, bufnr)
	if not client.server_capabilites.documentSymbolProvider then
		vim.notify("nvim-gps-2: Server "..client.name.." does not support documentSymbols", vim.log.levels.ERROR)
		return
	end

	if vim.b.gps_client_id ~= nil then
		local prev_client = vim.lsp.get_client_by_id(vim.b.gps_client_id)
		vim.notify("nvim-gps-2: Failed to attach to "..client.name.." for current buffer. Already attached to "..prev_client.name)
		return
	end

	vim.b.gps_client_id = client.id

	local gps_augroup = vim.api.nvim_create_augroup("gps", { clear = false })
	vim.api.nvim_clear_autocmds({
		buffer = bufnr,
		group = gps_augroup
	})
	vim.api.nvim_create_autocmd(
		{"InsertLeave", "BufEnter"},
		{
			callback = function()
				request_symbol(bufnr, update_data)
			end,
			group = gps_augroup,
			buffer = bufnr
		}
	)
end

return M
