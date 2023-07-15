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
local function symbolInfo_treemaker(symbols, root_node)
	-- convert location to scope
	for _, node in ipairs(symbols) do
		node.scope = node.location.range
		node.scope["start"].line = node.scope["start"].line + 1
		node.scope["end"].line = node.scope["end"].line + 1
		node.location = nil

		node.name_range = node.scope

		node.containerName = nil
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
	root_node.children = {}

	local stack = {}

	table.insert(root_node.children, symbols[1])
	symbols[1].parent = root_node
	table.insert(stack, root_node)

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

			symbols[i].parent = symbols[i-1]
		elseif prev_chain_node_relation == "before" and stack_top_node_relation == "around" then
			-- the previous symbol comes before this one and the current node
			-- is child of stack_top node. Add this symbol as child of stack_top
			table.insert(stack[#stack].children, symbols[i])

			symbols[i].parent = stack[#stack]
		elseif stack_top_node_relation == "before" then
			-- the stack_top node comes before this symbol; pop nodes off the stack to
			-- find the parent of this symbol and add this symbol as its child
			while symbol_relation(symbols[i], stack[#stack]) ~= "around" do
				stack[#stack] = nil
			end
			table.insert(stack[#stack].children, symbols[i])

			symbols[i].parent = stack[#stack]
		end
	end

	local function dfs_index(node)
		if node.children == nil then
			return
		end

		for i = 1, #node.children, 1 do
			node.children[i].index = i
			dfs_index(node.children[i])
		end

		-- Set next, prev relations
		for i = 1, #node.children, 1 do
			local curr_node = node.children[i]

			if i ~= 1 then
				local prev_node = node.children[i-1]
				prev_node.next = curr_node
				curr_node.prev = prev_node
			end

			if node.children[i+1] ~= nil then
				local next_node = node.children[i+1]
				next_node.prev = curr_node
				curr_node.next = next_node
			end
		end
	end

	dfs_index(root_node)
end

local function dfs(curr_symbol_layer, parent_node)
	if #curr_symbol_layer == 0 then
		return
	end

	parent_node.children = {}

	for _, val in ipairs(curr_symbol_layer) do
		local scope = val.range
		scope["start"].line = scope["start"].line + 1
		scope["end"].line = scope["end"].line + 1

		local name_range = val.selectionRange
		name_range["start"].line = name_range["start"].line + 1
		name_range["end"].line = name_range["end"].line + 1

		local curr_parsed_symbol = {
			name = val.name or "<???>",
			scope = scope,
			name_range = name_range,
			kind = val.kind or 0,
			parent = parent_node
		}

		if val.children then
			dfs(val.children, curr_parsed_symbol)
		end

		table.insert(parent_node.children, curr_parsed_symbol)
	end

	table.sort(parent_node.children, function(a, b)
		if b.scope.start.line == a.scope.start.line then
			return b.scope.start.character > a.scope.start.character
		end
		return b.scope.start.line > a.scope.start.line
	end)

	for i = 1, #parent_node.children, 1 do
		parent_node.children[i].prev = parent_node.children[i-1]
		parent_node.children[i].next = parent_node.children[i+1]
		parent_node.children[i].index = i
	end
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

-- Process raw data from lsp server into Tree structure
-- Node
-- 	 * is_root    : boolean
-- 	 * name       : string
-- 	 * scope      : table { start = {line = ., character = .}, end = {line = ., character = .}}
-- 	 * name_range : table same as scope
-- 	 * kind       : int [1-26]
-- 	 * index      : int, index among siblings
-- 	 * parent     : pointer to parent node
-- 	 * prev       : pointer to previous sibling node
-- 	 * next       : pointer to next sibling node
function M.parse(symbols)
	local root_node = {
		is_root = true,
		index = 1,
		scope = {
			start = {
				line = -10,
				character = 0,
			},
			["end"] = {
				line = 2147483640,
				character = 0,
			},
		}
	}

	-- detect type
	if #symbols >= 1 and symbols[1].range == nil then
		symbolInfo_treemaker(symbols, root_node)
	else
		dfs(symbols, root_node)
	end

	return root_node
end

-- Make request to lsp server
function M.request_symbol(for_buf, handler, client, file_uri, retry_count)
	local textDocument_argument = vim.lsp.util.make_text_document_params()

	if retry_count == nil then
		retry_count = 10
	elseif retry_count == 0 then
		handler(for_buf, {})
		return
	end

	if file_uri ~= nil then
		textDocument_argument = {
			textDocument = {
				uri = file_uri
			}
		}
	end

	if not vim.api.nvim_buf_is_loaded(for_buf) then
		return
	end

	client.request("textDocument/documentSymbol", { textDocument = textDocument_argument }, function(err, symbols, _)
		if symbols == nil then
			if vim.api.nvim_buf_is_valid(for_buf) then
				handler(for_buf, {})
			end
		elseif err ~= nil then
			if vim.api.nvim_buf_is_valid(for_buf) then
				vim.defer_fn(function()
					M.request_symbol(for_buf, handler, client, file_uri, retry_count-1)
				end, 750)
			end
		elseif symbols ~= nil then
			if vim.api.nvim_buf_is_loaded(for_buf) then
				handler(for_buf, symbols)
			end
		end
	end, for_buf)
end

local navic_symbols = {}
local navic_context_data = {}

function M.get_tree(bufnr)
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
	navic_symbols[for_buf] = M.parse(symbols)
end

function M.update_context(for_buf, arg_cursor_pos)
	local cursor_pos = arg_cursor_pos ~= nil and arg_cursor_pos or vim.api.nvim_win_get_cursor(0)

	if navic_context_data[for_buf] == nil then
		navic_context_data[for_buf] = {}
	end
	local old_context_data = navic_context_data[for_buf]
	local new_context_data = {}

	local curr = navic_symbols[for_buf]

	if curr == nil then
		return
	end

	-- Always keep root node
	if curr.is_root then
		table.insert(new_context_data, curr)
	end

	-- Find larger context that remained same
	for _, context in ipairs(old_context_data) do
		if curr == nil then
			break
		end
		if
			in_range(cursor_pos, context.scope) == 0
			and curr.children ~= nil
			and curr.children[context.index] ~= nil
			and context.name == curr.children[context.index].name
			and context.kind == curr.children[context.index].kind
		then
			table.insert(new_context_data, curr.children[context.index])
			curr = curr.children[context.index]
		else
			break
		end
	end

	-- Fill out context_data
	while curr.children ~= nil do
		local go_deeper = false
		local l = 1
		local h = #curr.children
		while l <= h do
			local m = bit.rshift(l + h, 1)
			local comp = in_range(cursor_pos, curr.children[m].scope)
			if comp == -1 then
				h = m - 1
			elseif comp == 1 then
				l = m + 1
			else
				table.insert(new_context_data, curr.children[m])
				curr = curr.children[m]
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
