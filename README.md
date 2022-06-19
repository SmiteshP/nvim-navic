# 🛰️ nvim-navic

A simple statusline/winbar component that uses LSP to show your current code context.
Named after the Indian satellite navigation system.

![2022-06-11 17-02-33](https://user-images.githubusercontent.com/43147494/173186210-c8d689ad-1f8a-43cf-8125-127c7bd5be35.gif)

## ⚡️ Requirements

* Neovim >= 0.7.0
* [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

## 📦 Installation

Install the plugin with your preferred package manager:

### [packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "SmiteshP/nvim-navic",
    requires = "neovim/nvim-lspconfig"
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug "neovim/nvim-lspconfig"
Plug "SmiteshP/nvim-navic"
```

## ⚙️ Setup

For nvim-navic to work, it needs attach to the lsp server. You can pass the nvim-navic's `attach` function as `on_attach` while setting up the lsp server.

Note: nvim-navic can attach to only one server per buffer.

Example:
```lua
local navic = require("nvim-navic")

require("lspconfig").clangd.setup {
    on_attach = function(client, bufnr)
        navic.attach(client, bufnr)
    end
}
```

## 🪄 Customise

Use the `setup` function to modify default parameters.

* `icons` : Indicate the type of symbol captured. Default icons assume you have nerd-fonts.
* `highlight` : If set to true, will add colors to icons and text as defined by highlight groups `NavicIcons*` (`NavicIconsFile`, `NavicIconsModule`.. etc.), `NavicText` and `NavicSeparator`.
* `depth_limit` : Maximum depth of context to be shown. If the context hits this depth limit, it is truncated.
* `depth_limit_indicatior` : Icon to indicate that `depth_limit` was hit and the shown context is truncated.

```lua
navic.setup {
    icons = {
        File          = " ",
        Module        = " ",
        Namespace     = " ",
        Package       = " ",
        Class         = " ",
        Method        = " ",
        Property      = " ",
        Field         = " ",
        Constructor   = " ",
        Enum          = "練",
        Interface     = "練",
        Function      = " ",
        Variable      = " ",
        Constant      = " ",
        String        = " ",
        Number        = " ",
        Boolean       = "◩ ",
        Array         = " ",
        Object        = " ",
        Key           = " ",
        Null          = "ﳠ ",
        EnumMember    = " ",
        Struct        = " ",
        Event         = " ",
        Operator      = " ",
        TypeParameter = " ",
    },
    highlight = false,
    separator = " > ",
    depth_limit = 0,
    depth_limit_indicator = "..",
}

```

For highlights to work, highlight groups must be defined. These may be defined in your colourscheme, if not you can define them yourself too as shown in below code snippet.

<details>
<summary>Example highlight definitions</summary>
	
```lua
vim.api.nvim_set_hl(0, "NavicFile",          {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicModule",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicNamespace",     {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicPackage",       {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicClass",         {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicMethod",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicProperty",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicField",         {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicConstructor",   {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicEnum",          {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicInterface",     {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicFunction",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicVariable",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicConstant",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicString",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicNumber",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicBoolean",       {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicArray",         {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicObject",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicKey",           {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicNull",          {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicEnumMember",    {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicStruct",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicEvent",         {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicOperator",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicTypeParameter", {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicText",          {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicSeparator",     {default = true, bg = "#000000", fg = "#ffffff"})
```
</details>


## 🚀 Usage

nvim-navic does not alter your statusline or winbar on its own. Instead, you are provided with these two functions and its left up to you how you want to incorporate this into your setup.

* `is_available()`     : Returns boolean value indicating whether output can be provided.
* `get_location(opts)` : Returns a pretty string with context information. Using `opts` table you can override any of the options, format same as the table for `setup` function.

<details>
<summary>Examples</summary>

### [feline](https://github.com/feline-nvim/feline.nvim)

<details>
<summary>An example feline setup </summary>

```lua
local navic = require("nvim-navic")

table.insert(components.active[1], {
    provider = function()
        return navic.get_location()
    end,
    enabled = function()
        return navic.is_available()
    end
})

require("feline").setup({components = components})
--  OR
require("feline").winbar.setup({components = components})
```
</details>

### [lualine](https://github.com/nvim-lualine/lualine.nvim)

<details>
<summary>An example lualine setup </summary>

```lua
local navic = require("nvim-navic")

require("lualine").setup({
    sections = {
        lualine_c = {
            { navic.get_location, cond = navic.is_available },
        }
    }
})
```

</details>
	
### [galaxyline](https://github.com/glepnir/galaxyline.nvim)

<details>
<summary>An example galaxyline setup </summary>

```lua
local navic = require("nvim-navic")
local gl = require("galaxyline")
local condition = require("galaxyline.condition")

gl.section.right[1]= {
    nvimNavic = {
        provider = function()
            return navic.get_location()
        end,
        condition = function()
            return navic.is_available()
        end
    }
}
```
</details>

</details>

If you have a creative use case and want the raw context data to work with, you can use the following function

* `get_data()` : Returns a table of intermediate representation of data. Table of tables that contain 'kind', 'name' and 'icon' for each context.

<details>
<summary>An example output of <code>get_data</code> function: </summary>

```lua
 {
    {
        name = "myclass",
        type = "Class",
        icon = " ",
        kind = 5
    },
    {
        name = "mymethod",
        type = "Method",
        icon = " ",
        kind = 6
    }
 }
```
</details>
