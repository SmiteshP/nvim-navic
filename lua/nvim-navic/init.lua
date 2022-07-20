local M = {}

-- @Private Methods

-- Make request to lsp server
local function request_symbol(for_buf, handler, client_id)
	vim.lsp.buf_request_all(
		for_buf,
		"textDocument/documentSymbol",
		{ textDocument = vim.lsp.util.make_text_document_params() },
		function(symbols)
			if symbols[client_id] == nil then
				return
			elseif symbols[client_id].error then
				vim.defer_fn(function()
					request_symbol(for_buf, handler, client_id)
				end, 750)
			elseif symbols[client_id].result ~= nil then
				if vim.api.nvim_buf_is_valid(for_buf) then
					vim.b[for_buf].navic_awaiting_lsp_response = false
					handler(for_buf, symbols[client_id].result)
				end
			end
		end
	)
end

-- Return the relation of `other` to `symbol`
--
-- Possible values are:
--   before
--   around
--   within
--   after
local function symbol_relation(symbol, other)
	local s = symbol.scope
	local o = other.scope

	if
		o["end"].line < s["start"].line
		or (o["end"].line == s["start"].line and o["end"].character < s["start"].character)
	then
		return "before"
	end

	if
		o["start"].line > s["end"].line
		or (o["start"].line == s["end"].line and o["start"].character > s["end"].character)
	then
		return "after"
	end

	if
		(
			o["start"].line < s["start"].line
			or (o["start"].line == s["start"].line and o["start"].character <= s["start"].character)
		)
		and (
			o["end"].line > s["end"].line
			or (o["end"].line == s["end"].line and o["end"].character >= s["end"].character)
		)
	then
		return "around"
	end

	return "within"
end

-- Derive the hierarchy in a symbol list. Add all direct descendents of a
-- symbol to a `children` property on the symbol.
local function derive_hierarchy(symbols)
	for _, sym in ipairs(symbols) do
		local children = sym.children or {}

		for _, other in ipairs(symbols) do
			if other ~= sym then
				local r = symbol_relation(sym, other)

				-- other is after sym, so there's no point in looking further
				if r == "after" then
					break
				end

				-- other is within sym
				if r == "within" then
					local should_add = true

					-- Check to see if other is contained by one of sym's
					-- children. If it is, don't add it to sym's children
					-- list as this list should only contain direct
					-- children of sym.
					if #children > 0 then
						for _, child in ipairs(children) do
							if symbol_relation(child, other) == "within" then
								should_add = false
								break
							end
						end
					end

					if should_add then
						table.insert(children, other)
					end
				end
			end
		end

		if #children > 0 then
			sym.children = children
		end
	end
end

-- Process raw data from lsp server
local function parse(symbols)
	local parsed_symbols = {}

	local function dfs(curr_symbol)
		local ret = {}

		for index, val in ipairs(curr_symbol) do
			local curr_parsed_symbol = {}
			local scope = val.range

			-- SymbolInformation objects store the range in a `location`
			-- property
			if scope == nil then
				scope = val.location.range
			end

			scope["start"].line = scope["start"].line + 1
			scope["end"].line = scope["end"].line + 1

			curr_parsed_symbol = {
				name = val.name or "<???>",
				scope = scope,
				kind = val.kind or 0,
				index = index,
			}

			if val.children then
				curr_parsed_symbol.children = dfs(val.children)
			end

			ret[#ret + 1] = curr_parsed_symbol
		end

		if ret then
			table.sort(ret, function(a, b)
				if b.scope["start"].line == a.scope["start"].line then
					return b.scope["start"].character > a.scope["start"].character
				end
				return b.scope["start"].line > a.scope["start"].line
			end)
		end

		return ret
	end

	parsed_symbols = dfs(symbols)

	-- Check if the symbol list contains SymbolInformation objects. If so, add
	-- the symbol hierarchy to the parsed symbols.
	if #symbols > 0 and symbols[1].range == nil then
		derive_hierarchy(parsed_symbols)
	end

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

-- Walk a symbol tree. Any symbols that contain the current cursor position are
-- added to a context list. The symbols must be sorted by start position (line
-- and character).
local function walk_symbols(syms, context, cursor_pos)
	if syms == nil then
		return
	end

	for _, sym in ipairs(syms) do
		if in_range(cursor_pos, sym.scope) == 0 then
			table.insert(context, sym)
			walk_symbols(sym.children, context, cursor_pos)
			return
		end
	end
end

local function update_context(for_buf)
	local symbols = navic_symbols[for_buf]
	if symbols == nil then
		return
	end

	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local old_context = navic_context_data[for_buf] or {}
	local new_context = {}

	-- Check if the cursor is still within the previous context; if it is, this
	-- will be faster than walking the entire symbol tree
	walk_symbols(old_context, new_context, cursor_pos)

	-- If the new context is empty, the cursor wasn't in the previous context,
	-- so walk the tree again
	if #new_context == 0 then
		walk_symbols(symbols, new_context, cursor_pos)
	end

	navic_context_data[for_buf] = new_context
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

setmetatable(config.icons, {
	__index = function()
		return "? "
	end,
})

-- @Public Methods

function M.setup(opts)
	if opts == nil then
		return
	end

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
	local changedtick = 0

	local navic_augroup = vim.api.nvim_create_augroup("navic", { clear = false })
	vim.api.nvim_clear_autocmds({
		buffer = bufnr,
		group = navic_augroup,
	})
	vim.api.nvim_create_autocmd({ "InsertLeave", "BufEnter", "CursorHold" }, {
		callback = function()
			if not vim.b.navic_awaiting_lsp_response and changedtick < vim.b.changedtick then
				vim.b.navic_awaiting_lsp_response = true
				changedtick = vim.b.changedtick
				request_symbol(bufnr, update_data, client.id)
			end
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

	-- First call
	vim.b.navic_awaiting_lsp_response = true
	request_symbol(bufnr, update_data, client.id)
end

return M
