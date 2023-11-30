local lib = require("nvim-navic.lib")

---@class LspOptions
---@field auto_attach boolean
---@field preference table | nil

---@class Options
---@field icons table | nil
---@field highlight boolean | nil
---@field format_text function | nil
---@field depth_limit number | nil
---@field depth_limit_indicator string | nil
---@field lazy_update_context boolean | nil
---@field safe_output boolean | nil
---@field click boolean | nil
---@field lsp LspOptions | nil

-- @Public Methods

local M = {}

---@type Options
local config = {
	icons = {
		[1] = "󰈙 ", -- File
		[2] = " ", -- Module
		[3] = "󰌗 ", -- Namespace
		[4] = " ", -- Package
		[5] = "󰌗 ", -- Class
		[6] = "󰆧 ", -- Method
		[7] = " ", -- Property
		[8] = " ", -- Field
		[9] = " ", -- Constructor
		[10] = "󰕘 ", -- Enum
		[11] = "󰕘 ", -- Interface
		[12] = "󰊕 ", -- Function
		[13] = "󰆧 ", -- Variable
		[14] = "󰏿 ", -- Constant
		[15] = "󰀬 ", -- String
		[16] = "󰎠 ", -- Number
		[17] = "◩ ", -- Boolean
		[18] = "󰅪 ", -- Array
		[19] = "󰅩 ", -- Object
		[20] = "󰌋 ", -- Key
		[21] = "󰟢 ", -- Null
		[22] = " ", -- EnumMember
		[23] = "󰌗 ", -- Struct
		[24] = " ", -- Event
		[25] = "󰆕 ", -- Operator
		[26] = "󰊄 ", -- TypeParameter
		[255] = "󰉨 ", -- Macro
	},
	highlight = false,
	separator = " > ",
	depth_limit = 0,
	depth_limit_indicator = "..",
	safe_output = true,
	lazy_update_context = false,
	click = false,
	lsp = {
		auto_attach = false,
		preference = nil
	},
	format_text = function(a) return a end,
}

setmetatable(config.icons, {
	__index = function()
		return "? "
	end,
})

local function setup_auto_attach(opts)
	vim.api.nvim_create_autocmd("LspAttach", {
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if not client.server_capabilities.documentSymbolProvider then
				return
			end

			local prev_client = vim.b[args.buf].navic_client_name
			if not prev_client or prev_client == client.name then
				return M.attach(client, args.buf)
			end

			if not opts.lsp.preference then
				return vim.notify(
					"nvim-navic: Trying to attach "
						.. client.name
						.. " for current buffer. Already attached to "
						.. prev_client
						.. ". Please use the preference option to set a higher preference for one of the servers",
					vim.log.levels.WARN
				)
			end

			for _, preferred_lsp in ipairs(opts.lsp.preference) do
				-- If new client comes first, then remove the previous
				-- attached server and attatch the new one
				if preferred_lsp == client.name then
					vim.b[args.buf].navic_client_id = nil
					vim.b[args.buf].navic_client_name = nil
					return M.attach(client, args.buf)
				elseif preferred_lsp == prev_client then
					-- If the previous attached server comes first, it
					-- has higher priority over the one trying to attach
					return
				end
			end
		end,
	})
end

---@param opts Options
function M.setup(opts)
	if opts == nil then
		return
	end

	if opts.lsp ~= nil and opts.lsp.auto_attach then
		setup_auto_attach(opts)
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
	if opts.lazy_update_context then
		config.lazy_update_context = opts.lazy_update_context
	end
	if opts.click then
		config.click = opts.click
	end
	if opts.format_text then
		vim.validate({ format_text = { opts.format_text, "f" } })
		config.format_text = opts.format_text
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

	for i, v in ipairs(context_data) do
		if i ~= 1 then
			table.insert(ret, {
				kind = v.kind,
				type = lib.adapt_lsp_num_to_str(v.kind),
				name = v.name,
				icon = config.icons[v.kind],
				scope = v.scope,
			})
		end
	end

	return ret
end

function M.is_available(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	return vim.b[bufnr].navic_client_id ~= nil
end

function M.format_data(data, opts)
	if data == nil then
		return ""
	end

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
		if opts.click ~= nil then
			local_config.click = opts.click
		end
	else
		local_config = config
	end


	local location = {}

	local function add_hl(kind, name)
		return "%#NavicIcons"
			.. lib.adapt_lsp_num_to_str(kind)
			.. "#"
			.. local_config.icons[kind]
			.. "%*%#NavicText#"
			.. config.format_text(name)
			.. "%*"
	end

	if local_config.click then
		_G.navic_click_handler = function(minwid, cnt, _, _)
			vim.cmd("normal! m'")
			vim.api.nvim_win_set_cursor(0, {
				data[minwid].scope["start"].line,
				data[minwid].scope["start"].character
			})
			if cnt > 1 then
				local ok, navbuddy = pcall(require, "nvim-navbuddy")
				if ok then
					navbuddy.open(bufnr)
				else
					vim.notify("nvim-navic: Double click requires nvim-navbuddy to be installed.", vim.log.levels.WARN)
				end
			end
		end
	end

	local function add_click(level, component)
		return "%"
			.. level
			.. "@v:lua.navic_click_handler@"
			.. component
			.. "%X"
	end

	for i, v in ipairs(data) do
		local name = ""

		if local_config.safe_output then
			name = string.gsub(v.name, "%%", "%%%%")
			name = string.gsub(name, "\n", " ")
		else
			name = v.name
		end

		local component

		if local_config.highlight then
			component = add_hl(v.kind, name)
		else
			component = v.icon .. name
		end

		if local_config.click then
			component = add_click(i, component)
		end

		table.insert(location, component)
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

function M.get_location(opts, bufnr)
	local data = M.get_data(bufnr)
	return M.format_data(data, opts)
end

local awaiting_lsp_response = {}
local function lsp_callback(for_buf, symbols)
	awaiting_lsp_response[for_buf] = false
	lib.update_data(for_buf, symbols)
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
		local prev_client = vim.b[bufnr].navic_client_name
		if not vim.g.navic_silence then
			vim.notify(
				"nvim-navic: Failed to attach to "
					.. client.name
					.. " for current buffer. Already attached to "
					.. prev_client,
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
			if not awaiting_lsp_response[bufnr] and changedtick < vim.b[bufnr].changedtick then
				awaiting_lsp_response[bufnr] = true
				changedtick = vim.b[bufnr].changedtick
				lib.request_symbol(bufnr, lsp_callback, client)
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
	if not config.lazy_update_context then
		vim.api.nvim_create_autocmd("CursorMoved", {
			callback = function()
				if vim.b.navic_lazy_update_context ~= true then
					lib.update_context(bufnr)
				end
			end,
			group = navic_augroup,
			buffer = bufnr,
		})
	end
	vim.api.nvim_create_autocmd("BufDelete", {
		callback = function()
			lib.clear_buffer_data(bufnr)
		end,
		group = navic_augroup,
		buffer = bufnr,
	})

	-- First call
	vim.b[bufnr].navic_awaiting_lsp_response = true
	lib.request_symbol(bufnr, lsp_callback, client)
end

return M
