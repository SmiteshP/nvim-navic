local M = {}

-- Make request to lsp server
local function request_symbol(for_buf, handler, client_id)
	vim.lsp.buf_request_all(
		for_buf,
		"textDocument/documentSymbol",
		{ textDocument = vim.lsp.util.make_text_document_params() },
		function(symbols)
			if not symbols[client_id].error then
				handler(for_buf, symbols[client_id].result)
			end
		end
	)
end

-- Process raw data from lsp server
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

local gps_symbols = {}
local gps_context_data = {}

local function update_data(for_buf, symbols)
	gps_symbols[for_buf] = parse(symbols, for_buf)
end

local function in_range(cursor_pos, range)
	local line = cursor_pos[1]
	local char = cursor_pos[2]

	if line < range["start"].line or line > range["end"].line then
		return false
	end

	if
		line == range["start"].line and char < range["start"].character
		or line == range["end"].line and char > range["end"].character
	then
		return false
	end

	return true
end

local function update_context(for_buf)
	local smallest_unchanged_context = nil
	local unchanged_context_index = 0
	local cursor_pos = vim.api.nvim_win_get_cursor(0)

	if gps_context_data[for_buf] == nil then
		gps_context_data[for_buf] = {}
	end
	local context_data = gps_context_data[for_buf]

	-- Find larger context that remained same
	if context_data ~= nil then
		for i, context in ipairs(context_data) do
			if in_range(cursor_pos, context.scope) then
				unchanged_context_index = i
				smallest_unchanged_context = context
			end
		end

		-- Flush out changed context
		unchanged_context_index = unchanged_context_index+1
		for i = unchanged_context_index, #context_data, 1 do
			context_data[i] = nil
		end
	else
		context_data = {}
	end

	local curr = nil

	if smallest_unchanged_context == nil then
		unchanged_context_index = 0
		curr = gps_symbols[for_buf]
	else
		curr = smallest_unchanged_context.children
	end

	-- Fill out context_data
	while curr ~= nil do
		local go_deeper = false
		for _, v in ipairs(curr) do
			if in_range(cursor_pos, v.scope) then
				print("HERE 1", #context_data)
				table.insert(context_data, v)
				print("HERE 2", #context_data)
				curr = v.children
				go_deeper = true
				break
			end
		end
		if not go_deeper then
			break
		end
	end
	-- vim.pretty_print(vim.b.context_data)
end

function M.get_data()
	-- request_symbol(vim.api.nvim_get_current_buf(), handler)
	vim.pretty_print(vim.b.gps_symbols)
end

function M.attach(client, bufnr)
	if not client.server_capabilities.documentSymbolProvider then
		vim.notify("nvim-gps-2: Server "..client.name.." does not support documentSymbols", vim.log.levels.ERROR)
		return
	end

	if vim.b.gps_client_id ~= nil then
		local prev_client = vim.lsp.get_client_by_id(vim.b.gps_client_id)
		vim.notify("nvim-gps-2: Failed to attach to "..client.name.." for current buffer. Already attached to "..prev_client.name)
		return
	end

	local gps_augroup = vim.api.nvim_create_augroup("gps", { clear = false })
	vim.api.nvim_clear_autocmds({
		buffer = bufnr,
		group = gps_augroup
	})
	vim.api.nvim_create_autocmd(
		{"InsertLeave", "BufEnter"},
		{
			callback = function()
				request_symbol(bufnr, update_data, client.id)
			end,
			group = gps_augroup,
			buffer = bufnr
		}
	)
	vim.api.nvim_create_autocmd(
		{"CursorHold", "CursorMoved"},
		{
			callback = function()
				update_context(bufnr)
			end,
			group = gps_augroup,
			buffer = bufnr
		}
	)
end

function M.test()
	vim.pretty_print(gps_context_data[vim.api.nvim_get_current_buf()])
end

return M
