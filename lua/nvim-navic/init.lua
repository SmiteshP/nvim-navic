local M = {}

-- @Private Methods

-- Make request to lsp server
local function request_symbol(for_buf, handler, client_id)
	vim.lsp.buf_request_all(
		for_buf,
		"textDocument/documentSymbol",
		{ textDocument = vim.lsp.util.make_text_document_params() },
		function(symbols)
			if symbols[client_id] ~= nil and not symbols[client_id].error and symbols[client_id].result ~= nil then
				handler(for_buf, symbols[client_id].result)
			end
		end
	)
end

-- Process raw data from lsp server
local function parse(symbols)
	local parsed_symbols = {}

	local function dfs(curr_symbol)
		local ret = {}

		for index, val in ipairs(curr_symbol) do
			local curr_parsed_symbol = {}

			-- SymbolInformation detection
			if val.range == nil then
				if not vim.g.navic_silence then
					vim.notify(
						'nvim-navic: Server "'
							.. vim.lsp.get_client_by_id(vim.b.navic_client_id).name
							.. '" does not support documentSymbols, it responds with SymbolInformation format which has been deprecated in latest LSP specification.',
						vim.log.levels.ERROR
					)
				end
				vim.api.nvim_clear_autocmds({
					buffer = vim.api.nvim_win_get_buf(0),
					group = "navic",
				})
				return
			end

			local scope = val.range
			scope["start"].line = scope["start"].line + 1
			scope["end"].line = scope["end"].line + 1

			curr_parsed_symbol = {
				name = val.name,
				scope = scope,
				kind = val.kind,
				index = index,
			}

			if val.children then
				curr_parsed_symbol.children = dfs(val.children)
			end

			ret[#ret + 1] = curr_parsed_symbol
		end

		if ret then
			table.sort(ret, function(a, b)
				if b.scope.start.line == a.scope.start.line then
					return b.scope.start.character > a.scope.start.character
				end
				return b.scope.start.line > a.scope.start.line
			end)
		end

		return ret
	end

	parsed_symbols = dfs(symbols)

	return parsed_symbols
end

local navic_symbols = {}
local navic_context_data = {}

local function update_data(for_buf, symbols)
	navic_symbols[for_buf] = parse(symbols)
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
	local cursor_pos = vim.api.nvim_win_get_cursor(0)

	if navic_context_data[for_buf] == nil then
		navic_context_data[for_buf] = {}
	end
	local old_context_data = navic_context_data[for_buf]
	local new_context_data = {}

	local curr = navic_symbols[for_buf]

	-- Find larger context that remained same
	for _, context in ipairs(old_context_data) do
		if
			in_range(cursor_pos, context.scope) == 0
			and curr[context.index] ~= nil
			and context.name == curr[context.index].name
			and context.kind == curr[context.index].kind
		then
			table.insert(new_context_data, curr[context.index])
			curr = curr[context.index].children
		else
			break
		end
	end

	-- Fill out context_data
	while curr ~= nil do
		local go_deeper = false
		local l = 1
		local h = #curr
		while l <= h do
			local m = ((l + h) - (l + h) % 2) / 2
			local comp = in_range(cursor_pos, curr[m].scope)
			if comp == -1 then
				h = m - 1
			elseif comp == 1 then
				l = m + 1
			else
				table.insert(new_context_data, curr[m])
				curr = curr[m].children
				go_deeper = true
				break
			end
		end
		if not go_deeper then
			break
		end
	end

	navic_context_data[for_buf] = new_context_data
end

-- stylua: ignore
local lsp_str_to_num = {
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

-- stylua: ignore
local lsp_num_to_str = {
	[1]  = "File",
	[2]  = "Module",
	[3]  = "Namespace",
	[4]  = "Package",
	[5]  = "Class",
	[6]  = "Method",
	[7]  = "Property",
	[8]  = "Field",
	[9]  = "Constructor",
	[10] = "Enum",
	[11] = "Interface",
	[12] = "Function",
	[13] = "Variable",
	[14] = "Constant",
	[15] = "String",
	[16] = "Number",
	[17] = "Boolean",
	[18] = "Array",
	[19] = "Object",
	[20] = "Key",
	[21] = "Null",
	[22] = "EnumMember",
	[23] = "Struct",
	[24] = "Event",
	[25] = "Operator",
	[26] = "TypeParameter",
}

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
	highlight = false,
	separator = " > ",
	depth_limit = 0,
	depth_limit_indicator = "..",
}

-- @Public Methods

function M.setup(opts)
	if opts == nil then return end

	if opts.icons ~= nil then
		for k, v in pairs(opts.icons) do
			if lsp_str_to_num[k] then
				config.icons[lsp_str_to_num[k]] = v
			end
		end
	end

	if opts.separator ~= nil then
		config.separator = opts.separator
	end
	if opts.depth_limit ~= nil then
		config.depth_limit = opts.depth_limit
	end
	if opts.depth_limit_indicator ~= nil then
		config.depth_limit_indicator = opts.depth_limit_indicator
	end
	if opts.highlight ~= nil then
		config.highlight = opts.highlight
	end
end

-- returns table of context or nil
function M.get_data()
	local context_data = navic_context_data[vim.api.nvim_get_current_buf()]

	if context_data == nil then
		return nil
	end

	local ret = {}

	for _, v in ipairs(context_data) do
		table.insert(ret, {
			kind = v.kind,
			type = lsp_num_to_str[v.kind],
			name = v.name,
			icon = config.icons[v.kind],
		})
	end

	return ret
end

function M.is_available()
	return vim.b.navic_client_id ~= nil
end

function M.get_location(opts)
	local local_config = {}

	if opts ~= nil then
		local_config = vim.deepcopy(config)

		if opts.icons ~= nil then
			for k, v in pairs(opts.icons) do
				if lsp_str_to_num[k] then
					local_config.icons[lsp_str_to_num[k]] = v
				end
			end
		end

		if opts.separator ~= nil then
			local_config.separator = opts.separator
		end
		if opts.depth_limit ~= nil then
			local_config.depth_limit = opts.depth_limit
		end
		if opts.depth_limit_indicator ~= nil then
			local_config.depth_limit_indicator = opts.depth_limit_indicator
		end
		if opts.highlight ~= nil then
			local_config.highlight = opts.highlight
		end
	else
		local_config = config
	end

	local data = M.get_data()

	if data == nil then
		return ""
	end

	local location = {}

	local function add_hl(kind, name)
		return "%#NavicIcons"
			.. lsp_num_to_str[kind]
			.. "#"
			.. local_config.icons[kind]
			.. "%*%#NavicText#"
			.. name
			.. "%*"
	end

	for _, v in ipairs(data) do
		if local_config.highlight then
			table.insert(location, add_hl(v.kind, v.name))
		else
			table.insert(location, v.icon .. v.name)
		end
	end

	if local_config.depth_limit ~= 0 and #location > local_config.depth_limit then
		location = vim.list_slice(location, #location - local_config.depth_limit + 1, #location)
		if local_config.highlight then
			table.insert(location, 1, "%#NavicSeparator#" .. local_config.depth_limit_indicator .. "%*")
		else
			table.insert(location, 1, local_config.depth_limit_indicator)
		end
	end

	local ret = ""

	if local_config.highlight then
		ret = table.concat(location, "%#NavicSeparator#" .. local_config.separator .. "%*")
	else
		ret = table.concat(location, local_config.separator)
	end

	return ret
end

function M.attach(client, bufnr)
	if not client.server_capabilities.documentSymbolProvider then
		if not vim.g.navic_silence then
			vim.notify(
				'nvim-navic: Server "' .. client.name .. '" does not support documentSymbols.',
				vim.log.levels.ERROR
			)
		end
		return
	end

	if vim.b.navic_client_id ~= nil and vim.b.navic_client_name ~= client.name then
		local prev_client = vim.lsp.get_client_by_id(client.id)
		if not vim.g.navic_silence then
			vim.notify(
				"nvim-navic: Failed to attach to "
					.. client.name
					.. " for current buffer. Already attached to "
					.. prev_client.name,
				vim.log.levels.WARN
			)
		end
		return
	end

	vim.b.navic_client_id = client.id
	vim.b.navic_client_name = client.name

	local navic_augroup = vim.api.nvim_create_augroup("navic", { clear = false })
	vim.api.nvim_clear_autocmds({
		buffer = bufnr,
		group = navic_augroup,
	})
	vim.api.nvim_create_autocmd({ "InsertLeave", "BufEnter", "CursorHold" }, {
		callback = function()
			request_symbol(bufnr, update_data, client.id)
		end,
		group = navic_augroup,
		buffer = bufnr,
	})
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorMoved" }, {
		callback = function()
			update_context(bufnr)
		end,
		group = navic_augroup,
		buffer = bufnr,
	})
	vim.api.nvim_create_autocmd({ "BufDelete" }, {
		callback = function()
			navic_context_data[bufnr] = nil
			navic_symbols[bufnr] = nil
		end,
		group = navic_augroup,
		buffer = bufnr,
	})
end

return M
