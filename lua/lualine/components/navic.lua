local navic = require("nvim-navic")
local navic_lib = require("nvim-navic.lib")

local M = require("lualine.component"):extend()
local utils = require("lualine.utils.utils")
local highlight = require("lualine.highlight")

local default_options = {
	cond = function()
		return navic.is_available()
	end,
	color_correction = nil,
	navic_opts = nil
}

local function adjust_hl(section)
	local lualine_bg = utils.extract_highlight_colors("lualine_" .. section .. highlight.get_mode_suffix(), "bg")
	local lualine_fg = utils.extract_highlight_colors("lualine_" .. section .. highlight.get_mode_suffix(), "fg")

	local text_hl = utils.extract_highlight_colors("NavicText")
	if text_hl ~= nil and (text_hl.bg ~= lualine_bg or text_hl.fg ~= lualine_fg) then
		highlight.highlight("NavicText", lualine_fg, lualine_bg)
	end

	local sep_hl = utils.extract_highlight_colors("NavicSeparator")
	if sep_hl ~= nil and (sep_hl.bg ~= lualine_bg or sep_hl.fg ~= lualine_fg) then
		highlight.highlight("NavicSeparator", lualine_fg, lualine_bg)
	end

	for i = 1, 26, 1 do
		local hl_name = "NavicIcons"..navic_lib.adapt_lsp_num_to_str(i)
		local hl = utils.extract_highlight_colors(hl_name)
		if hl ~= nil and hl.bg ~= lualine_bg then
			highlight.highlight(hl_name, hl.fg, lualine_bg)
		end
	end
end

M.init = function(self, options)
	M.super.init(self, options)
	self.options = vim.tbl_deep_extend("keep", self.options or {}, default_options)
	if self.options.color_correction == "static" then
		adjust_hl(self.options.self.section)
	end
end

M.update_status = function(self)
	if self.options.color_correction == "dynamic" then
		adjust_hl(self.options.self.section)
	end
	return navic.get_location(self.options.navic_opts)
end

return M
