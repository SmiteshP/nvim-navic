local navic = require("nvim-navic")

local M = require("lualine.component"):extend()

local default_options = {
	cond = function()
		return navic.is_available()
	end
}

M.init = function(self, options)
	M.super.init(self, options)
	self.options = vim.tbl_deep_extend("keep", self.options or {}, default_options)
end

M.update_status = function(self)
	return navic.get_location()
end

return M
