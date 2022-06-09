local M = {}

-- @Private Methods

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
	-- -1 = behind
	--  0 = in range
	--  1 = ahead

	local line = cursor_pos[1]
	local char = cursor_pos[2]

	if line < range["start"].line then
		return -1
	elseif line > range["end"].line then
		return 1
	end

	if line == range["start"].line and char < range["start"].character then
		return -1
	elseif line == range["end"].line and char > range["end"].character then
		return 1
	end

	return 0
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
			if in_range(cursor_pos, context.scope) == 0 then
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
		local l = 1
		local h = #curr
		while l <= h do
			local m = ((l+h) - (l+h)%2)/2
			local comp = in_range(cursor_pos, curr[m].scope)
			if comp == -1 then
				h = m-1
			elseif comp == 1 then
				l = m+1
			else
				table.insert(context_data, curr[m])
				curr = curr[m].children
				go_deeper = true
				break
			end
		end
		if not go_deeper then
			break
		end
	end
end

local config = {
	icons = {
		[1] = " ", -- File
		[2] = " ", -- Module
		[3] = " ", -- Namespace
		[4] = " ", -- Package
		[5] = " ", -- Class
		[6] = " ", -- Method
		[7] = " ", -- Property
		[8] = " ", -- Field
		[9] = " ", -- Constructor
		[10] = "練", -- Enum
		[11] = "練", -- Interface
		[12] = " ", -- Function
		[13] = " ", -- Variable
		[14] = " ", -- Constant
		[15] = " ", -- String
		[16] = " ", -- Number
		[17] = "◩ ", -- Boolean
		[18] = " ", -- Array
		[19] = " ", -- Object
		[20] = " ", -- Key
		[21] = "ﳠ ", -- Null
		[22] = " ", -- EnumMember
		[23] = " ", -- Struct
		[24] = " ", -- Event
		[25] = " ", -- Operator
		[26] = " ", -- TypeParameter
	},
	seperator = " > ",
	depth = 0,
	depth_limit_indicator = ".."
}

-- @Public Methods

function M.setup(opts)
	local lsp_mapping = {
		File          = 1,
		Module        = 2,
		Namespace     = 3,
		Package       = 4,
		Class         = 5,
		Method        = 6,
		Property      = 7,
		Field         = 8,
		Constructor   = 9,
		Enum          = 10,
		Interface     = 11,
		Function      = 12,
		Variable      = 13,
		Constant      = 14,
		String        = 15,
		Number        = 16,
		Boolean       = 17,
		Array         = 18,
		Object        = 19,
		Key           = 20,
		Null          = 21,
		EnumMember    = 22,
		Struct        = 23,
		Event         = 24,
		Operator      = 25,
		TypeParameter = 26,
	}

	if opts.icons ~= nil then
		for k, v in pairs(opts.icons) do
			config[lsp_mapping[k]] = v
		end
	end

	config.seperator = opts.seperator or config.seperator
	config.depth = opts.depth or config.depth
	config.depth_limit_indicator = opts.depth_limit_indicator or config.depth_limit_indicator
end

-- returns table of context or nil
function M.get_data()
	local context_data = gps_context_data[vim.api.nvim_get_current_buf()]

	if context_data == nil then
		return nil
	end

	local ret = {}

	for _, v in ipairs(context_data) do
		table.insert(ret, {
			kind = v.kind,
			name = v.name
		})
	end

	return ret
end

function M.is_available()
	return vim.b.gps_client_id ~= nil
end

function M.get_location()
	local data = M.get_data()

	if data == nil then
		return ""
	end

	local location = {}

	for _, v in ipairs(data) do
		table.insert(location, config.icons[v.kind] .. v.name)
	end

	if config.depth ~= 0 and #location > config.depth then
		location = vim.list_slice(location, #location-config.depth+1, #location)
		table.insert(location, 1, config.depth_limit_indicator)
	end

	return table.concat(location, config.seperator)
end

function M.attach(client, bufnr)
	if not client.server_capabilities.documentSymbolProvider then
		vim.notify("nvim-gps-2: Server "..client.name.." does not support documentSymbols", vim.log.levels.ERROR)
		return
	end

	if vim.b.gps_client_id ~= nil then
		local prev_client = vim.lsp.get_client_by_id(client.id)
		vim.notify("nvim-gps-2: Failed to attach to "..client.name.." for current buffer. Already attached to "..prev_client.name, vim.log.levels.WARN)
		return
	end

	vim.b.gps_client_id = client.id

	local gps_augroup = vim.api.nvim_create_augroup("gps", { clear = false })
	vim.api.nvim_clear_autocmds({
		buffer = bufnr,
		group = gps_augroup
	})
	vim.api.nvim_create_autocmd(
		{"InsertLeave", "BufEnter", "CursorHold"},
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

return M
