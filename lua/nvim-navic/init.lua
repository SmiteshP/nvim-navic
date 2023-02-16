local lib = require("nvim-navic.lib")

-- @Public Methods

local M = {}

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
		[255] = " ", -- Macro
	},
	highlight = false,
	separator = " > ",
	depth_limit = 0,
	depth_limit_indicator = "..",
	safe_output = true,
}

setmetatable(config.icons, {
	__index = function()
		return "? "
	end,
})

function M.setup(opts)
	if opts == nil then
		return
	end

	if opts.icons ~= nil then
		for k, v in pairs(opts.icons) do
			if lib.adapt_lsp_str_to_num(k) then
				config.icons[lib.adapt_lsp_str_to_num(k)] = v
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
	if opts.safe_output ~= nil then
		config.safe_output = opts.safe_output
	end
end

-- returns table of context or nil
function M.get_data(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local context_data = lib.get_context_data(bufnr)

	if context_data == nil then
		return nil
	end

	local ret = {}

	for _, v in ipairs(context_data) do
		table.insert(ret, {
			kind = v.kind,
			type = lib.adapt_lsp_num_to_str(v.kind),
			name = v.name,
			icon = config.icons[v.kind],
			scope = v.scope,
		})
	end

	return ret
end

function M.is_available(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	return vim.b[bufnr].navic_client_id ~= nil
end

function M.get_location(opts)
	local local_config = {}

	if opts ~= nil then
		local_config = vim.deepcopy(config)

		if opts.icons ~= nil then
			for k, v in pairs(opts.icons) do
				if lib.adapt_lsp_str_to_num(k) then
					local_config.icons[lib.adapt_lsp_str_to_num(k)] = v
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
		if opts.safe_output ~= nil then
			local_config.safe_output = opts.safe_output
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
			.. lib.adapt_lsp_num_to_str(kind)
			.. "#"
			.. local_config.icons[kind]
			.. "%*%#NavicText#"
			.. name
			.. "%*"
	end

	for _, v in ipairs(data) do
		local name = ""

		if local_config.safe_output then
			name = string.gsub(v.name, "%%", "%%%%")
			name = string.gsub(name, "\n", " ")
		else
			name = v.name
		end

		if local_config.highlight then
			table.insert(location, add_hl(v.kind, name))
		else
			table.insert(location, v.icon .. name)
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

	if vim.b[bufnr].navic_client_id ~= nil and vim.b[bufnr].navic_client_name ~= client.name then
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

	vim.b[bufnr].navic_client_id = client.id
	vim.b[bufnr].navic_client_name = client.name
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
				lib.request_symbol(bufnr, lib.update_data, client.id)
			end
		end,
		group = navic_augroup,
		buffer = bufnr,
	})
	vim.api.nvim_create_autocmd("CursorHold", {
		callback = function()
			lib.update_context(bufnr)
		end,
		group = navic_augroup,
		buffer = bufnr,
	})
	vim.api.nvim_create_autocmd("CursorMoved", {
		callback = function()
			if vim.b.navic_lazy_update_context ~= true then
				lib.update_context(bufnr)
			end
		end,
		group = navic_augroup,
		buffer = bufnr,
	})
	vim.api.nvim_create_autocmd("BufDelete", {
		callback = function()
			lib.clear_buffer_data(bufnr)
		end,
		group = navic_augroup,
		buffer = bufnr,
	})

	-- First call
	vim.b[bufnr].navic_awaiting_lsp_response = true
	lib.request_symbol(bufnr, lib.update_data, client.id)
end

return M
