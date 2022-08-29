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

If you're sharing your `on-attach` function between lspconfigs, better wrap nvim-navic's `attach` function to make sure `documentSymbolProvider` is enabled:

Example:
```lua
local on_attach = function(client, bufnr)
  ...
  if client.server_capabilities.documentSymbolProvider then
    navic.attach(client, bufnr)
  end
  ...
end
```

>NOTE: You can set `vim.g.navic_silence = true` to supress error messages thrown by nvim-navic. However this is not recommended as the error messages indicate that there is problem in your setup. That is, you are attaching nvim-navic to servers that don't support documentSymbol or are attaching navic to multiple servers for a single buffer.

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
vim.api.nvim_set_hl(0, "NavicIconsFile",          {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsModule",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsNamespace",     {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsPackage",       {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsClass",         {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsMethod",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsProperty",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsField",         {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsConstructor",   {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsEnum",          {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsInterface",     {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsFunction",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsVariable",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsConstant",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsString",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsNumber",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsBoolean",       {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsArray",         {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsObject",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsKey",           {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsNull",          {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsEnumMember",    {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsStruct",        {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsEvent",         {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsOperator",      {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicIconsTypeParameter", {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicText",               {default = true, bg = "#000000", fg = "#ffffff"})
vim.api.nvim_set_hl(0, "NavicSeparator",          {default = true, bg = "#000000", fg = "#ffffff"})
```
</details>

If you have a font patched with [codicon.ttf](https://github.com/microsoft/vscode-codicons/raw/main/dist/codicon.ttf), you can replicate the look of VSCode breadcrumbs using the following icons

<details>
<summary>VSCode like icons</summary>

```lua
navic.setup {
  icons = {
    File = ' ',
    Module = ' ',
    Namespace = ' ',
    Package = ' ',
    Class = ' ',
    Method = ' ',
    Property = ' ',
    Field = ' ',
    Constructor = ' ',
    Enum = ' ',
    Interface = ' ',
    Function = ' ',
    Variable = ' ',
    Constant = ' ',
    String = ' ',
    Number = ' ',
    Boolean = ' ',
    Array = ' ',
    Object = ' ',
    Key = ' ',
    Null = ' ',
    EnumMember = ' ',
    Struct = ' ',
    Event = ' ',
    Operator = ' ',
    TypeParameter = ' '
  }
}
```
</details>

## 🚀 Usage

nvim-navic does not alter your statusline or winbar on its own. Instead, you are provided with these two functions and its left up to you how you want to incorporate this into your setup.

* `is_available()`     : Returns boolean value indicating whether output can be provided.
* `get_location(opts)` : Returns a pretty string with context information. Using `opts` table you can override any of the options, format same as the table for `setup` function.

<details>
<summary>Examples</summary>

### Native method

<details>
<summary>Lua</summary>

```lua
vim.o.statusline = "%{%v:lua.require'nvim-navic'.get_location()%}"
--  OR
vim.o.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"
```
</details>

<details>
<summary>Vimscript</summary>

```vim
set statusline+=%{%v:lua.require'nvim-navic'.get_location()%}
"   OR
set winbar+=%{%v:lua.require'nvim-navic'.get_location()%}
```
</details>

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
