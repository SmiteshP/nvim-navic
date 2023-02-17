-- @Private Methods

-- relation of 'other' with repect to 'symbol'
local function symbol_relation(symbol, other)
	local s = symbol.scope
	local o = other.scope

	if
		o["end"].line < s["start"].line
		or (o["end"].line == s["start"].line and o["end"].character <= s["start"].character)
	then
		return "before"
	end

	if
		o["start"].line > s["end"].line
		or (o["start"].line == s["end"].line and o["start"].character >= s["end"].character)
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

-- Construct tree structure based on scope information
-- Could be inaccurate ?? Not intended to be used like this...
local function symbolInfo_treemaker(symbols)
	-- convert location to scope
	for _, node in ipairs(symbols) do
		node.scope = node.location.range
		node.scope["start"].line = node.scope["start"].line + 1
		node.scope["end"].line = node.scope["end"].line + 1
		node.location = nil

		node.name_range = node.scope
	end

	-- sort with repect to node height and location
	-- nodes closer to root node come before others
	-- nodes and same level are arranged according to scope
	table.sort(symbols, function(a, b)
		local loc = symbol_relation(a, b)
		if loc == "after" or loc == "within" then
			return true
		end
		return false
	end)

	-- root node
	local tree = {
		scope = {
			start = {
				line = -10,
				character = 0,
			},
			["end"] = {
				line = 2147483640,
				character = 0,
			},
		},
		children = {},
	}
	local stack = {}

	table.insert(tree.children, symbols[1])
	table.insert(stack, tree)

	-- build tree
	for i = 2, #symbols, 1 do
		local prev_chain_node_relation = symbol_relation(symbols[i], symbols[i - 1])
		local stack_top_node_relation = symbol_relation(symbols[i], stack[#stack])

		if prev_chain_node_relation == "around" then
			-- current node is child node of previous chain node
			table.insert(stack, symbols[i - 1])
			if not symbols[i - 1].children then
				symbols[i - 1].children = {}
			end
			table.insert(symbols[i - 1].children, symbols[i])
		elseif prev_chain_node_relation == "before" and stack_top_node_relation == "around" then
			-- the previous symbol comes before this one and the current node
			-- contains this symbol; add this symbol as a child of the current node
			table.insert(stack[#stack].children, symbols[i])
		elseif stack_top_node_relation == "before" then
			-- the current node comes before this symbol; pop nodes off the stack to
			-- find the parent of this symbol and add this symbol as its child
			while symbol_relation(symbols[i], stack[#stack]) ~= "around" do
				stack[#stack] = nil
			end
			table.insert(stack[#stack].children, symbols[i])
		end
	end

	return tree.children
end

-- Process raw data from lsp server
local function parse(symbols)
	local parsed_symbols = {}

	local function dfs(curr_symbol)
		local ret = {}

		for index, val in ipairs(curr_symbol) do
			local curr_parsed_symbol = {}

			local scope = val.range
			scope["start"].line = scope["start"].line + 1
			scope["end"].line = scope["end"].line + 1

			local name_range = val.selectionRange
			name_range["start"].line = name_range["start"].line + 1
			name_range["end"].line = name_range["end"].line + 1

			curr_parsed_symbol = {
				name = val.name or "<???>",
				scope = scope,
				name_range = name_range,
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
				if b.scope.start.line == a.scope.start.line then
					return b.scope.start.character > a.scope.start.character
				end
				return b.scope.start.line > a.scope.start.line
			end)
		end

		return ret
	end

	-- detect type
	if #symbols >= 1 and symbols[1].range == nil then
		parsed_symbols = symbolInfo_treemaker(symbols)
	else
		parsed_symbols = dfs(symbols)
	end

	return parsed_symbols
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

-- @Public Methods

local M = {}

-- Make request to lsp server
function M.request_symbol(for_buf, handler, client_id)
	vim.lsp.buf_request_all(
		for_buf,
		"textDocument/documentSymbol",
		{ textDocument = vim.lsp.util.make_text_document_params() },
		function(symbols)
			if symbols[client_id] == nil then
				return
			elseif symbols[client_id].error then
				vim.defer_fn(function()
					M.request_symbol(for_buf, handler, client_id)
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

local navic_symbols = {}
local navic_context_data = {}

function M.get_symbols(bufnr)
	return navic_symbols[bufnr]
end

function M.get_context_data(bufnr)
	return navic_context_data[bufnr]
end

function M.clear_buffer_data(bufnr)
	navic_context_data[bufnr] = nil
	navic_symbols[bufnr] = nil
end

function M.update_data(for_buf, symbols)
	navic_symbols[for_buf] = parse(symbols)
end

function M.update_context(for_buf)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)

	if navic_context_data[for_buf] == nil then
		navic_context_data[for_buf] = {}
	end
	local old_context_data = navic_context_data[for_buf]
	local new_context_data = {}

	local curr = navic_symbols[for_buf]

	if curr == nil then
		return
	end

	-- Find larger context that remained same
	for _, context in ipairs(old_context_data) do
		if curr == nil then
			break
		end
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
			local m = bit.rshift(l + h, 1)
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
setmetatable(lsp_str_to_num, {
	__index = function()
		return 0
	end,
})

function M.adapt_lsp_str_to_num(s)
	return lsp_str_to_num[s]
end

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
setmetatable(lsp_num_to_str, {
	__index = function()
		return "Text"
	end,
})

function M.adapt_lsp_num_to_str(n)
	return lsp_num_to_str[n]
end

return M
