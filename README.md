# 🛰️ nvim-navic

A simple statusline/winbar component that uses LSP to show your current code context.
Named after the Indian satellite navigation system.

![2022-06-11 17-02-33](https://user-images.githubusercontent.com/43147494/173186210-c8d689ad-1f8a-43cf-8125-127c7bd5be35.gif)

>You might also be interested in [nvim-navbuddy](https://github.com/SmiteshP/nvim-navbuddy). Paired with nvim-navic, it will give you complete breadcrumbs experience like in an IDE!

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

For nvim-navic to work, it needs attach to the lsp server. You can pass the nvim-navic's `attach` function as `on_attach` while setting up the lsp server. You can skip this step if you have enabled auto_attach option during setup.

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

require("lspconfig").clangd.setup {
    on_attach = on_attach
}
```

>NOTE: You can set `vim.g.navic_silence = true` to supress error messages thrown by nvim-navic. However this is not recommended as the error messages indicate that there is problem in your setup. That is, you are attaching nvim-navic to servers that don't support documentSymbol or are attaching navic to multiple servers for a single buffer.

>NOTE: You can set `vim.b.navic_lazy_update_context = true` for specific buffers, where you want the the updates to not occur on every `CursorMoved` event. It should help if you are facing performance issues in large files. Read the docs for example usage of this variable. Alternatively, you can pass `lazy_update_context=true` to the `setup` function to turn off context updates on the `CursorMoved` event completely for all buffers. It's useful when you just want context updates to happen only on `CursorHold` events and not on `CursorMoved`.

## 🪄 Customise

Use the `setup` function to modify default parameters.

* `icons` : Indicate the type of symbol captured. Default icons assume you have nerd-fonts.
* `highlight` : If set to true, will add colors to icons and text as defined by highlight groups `NavicIcons*` (`NavicIconsFile`, `NavicIconsModule`.. etc.), `NavicText` and `NavicSeparator`.
* `depth_limit` : Maximum depth of context to be shown. If the context hits this depth limit, it is truncated.
* `depth_limit_indicator` : Icon to indicate that `depth_limit` was hit and the shown context is truncated.
* `format_text` : A function to customize the text displayed in each segment.
* `lazy_update_context` : If true, turns off context updates for the "CursorMoved" event.
* `safe_output` : Sanitize the output for use in statusline and winbar.
* `click` : Single click to goto element, double click to open nvim-navbuddy on the clicked element.
* `lsp` :
    * `auto_attach` : Enable to have nvim-navic automatically attach to every LSP for current buffer. Its disabled by default.
    * `preference` : Table ranking lsp_servers. Lower the index, higher the priority of the server. If there are more than one server attached to a buffer, nvim-navic will refer to this list to make a decision on which one to use. For example - In case a buffer is attached to clangd and ccls both and the preference list is `{ "clangd", "pyright" }`. Then clangd will be preferred.

```lua
navic.setup {
    icons = {
        File          = "󰈙 ",
        Module        = " ",
        Namespace     = "󰌗 ",
        Package       = " ",
        Class         = "󰌗 ",
        Method        = "󰆧 ",
        Property      = " ",
        Field         = " ",
        Constructor   = " ",
        Enum          = "󰕘",
        Interface     = "󰕘",
        Function      = "󰊕 ",
        Variable      = "󰆧 ",
        Constant      = "󰏿 ",
        String        = "󰀬 ",
        Number        = "󰎠 ",
        Boolean       = "◩ ",
        Array         = "󰅪 ",
        Object        = "󰅩 ",
        Key           = "󰌋 ",
        Null          = "󰟢 ",
        EnumMember    = " ",
        Struct        = "󰌗 ",
        Event         = " ",
        Operator      = "󰆕 ",
        TypeParameter = "󰊄 ",
    },
    lsp = {
        auto_attach = false,
        preference = nil,
    },
    highlight = false,
    separator = " > ",
    depth_limit = 0,
    depth_limit_indicator = "..",
    safe_output = true,
    lazy_update_context = false,
    click = false,
    format_text = function(text)
        return text
    end,
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

* `is_available(bufnr)` : Returns boolean value indicating whether output can be provided. `bufnr` is optional, default is current.
* `get_location(opts, bufnr)`  : Returns a pretty string with context information. Using `opts` table you can override any of the options, format same as the table for `setup` function. You can also provide a `bufnr` value to determine which buffer is used to get the code context information, if not provided the current buffer will be used.

<details>
<summary><h3>Examples</h3></summary>

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
            {
                "navic",
    
                -- Component specific options
                color_correction = nil, -- Can be nil, "static" or "dynamic". This option is useful only when you have highlights enabled.
                                        -- Many colorschemes don't define same backgroud for nvim-navic as their lualine statusline backgroud.
                                        -- Setting it to "static" will perform a adjustment once when the component is being setup. This should
                                        --   be enough when the lualine section isn't changing colors based on the mode.
                                        -- Setting it to "dynamic" will keep updating the highlights according to the current modes colors for
                                        --   the current section.
    
                navic_opts = nil  -- lua table with same format as setup's option. All options except "lsp" options take effect when set here.
            }
        }
    },
    -- OR in winbar
    winbar = {
        lualine_c = {
            {
                "navic",
                color_correction = nil,
                navic_opts = nil
            }
        }
    }
})

-- OR a more hands on approach
require("lualine").setup({
    sections = {
        lualine_c = {
            {
              function()
                  return navic.get_location()
              end,
              cond = function()
                  return navic.is_available()
              end
            },
        }
    },
    -- OR in winbar
    winbar = {
        lualine_c = {
            {
              function()
                  return navic.get_location()
              end,
              cond = function()
                  return navic.is_available()
              end
            },
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

* `get_data(bufnr)` : Returns a table of intermediate representation of data. Table of tables that contain 'kind', 'name' and 'icon' for each context. `bufnr` is optional argument, defaults to current buffer.

<details>
<summary>An example output of <code>get_data</code> function: </summary>

```lua
 {
    {
        name  = "myclass",
        type  = "Class",
        icon  = "󰌗 ",
        kind  = 5,
        scope = {
            start = { line = 1, character = 0 },
            end = { line = 10, character = 0 }
        }
    },
    {
        name  = "mymethod",
        type  = "Method",
        icon  = "󰆧 ",
        kind  = 6,
        scope = {
            start = { line = 2, character = 4 },
            end = { line = 5, character = 4 }
        }
    }
 }
```
</details>

If you work with raw context data, you may want to render a modified version of it. In order to ensure a consistent format with `get_location`, you may use the following function:

* `format_data(data, opts)` : Returns a pretty string (with the same format as `get_location`) with the context information provided in `data`. Using `opts` table you can override any of the options, format same as the table for setup function. If the `opts` parameter is omitted, the globally configured options are used.

<details>
<summary>An example usage of <code>format_data</code>:</summary>

Consider the scenario of working in deeply nested namespaces. Typically, just the namespace names will occupy quite some space in your statusline. With the following snippet, nested namespace names are truncated and combined into a single component:

```lua
-- Customized navic.get_location() that combines namespaces into a single string.
-- Example: `adam::bob::charlie > foo` is transformed into `a::b::charlie > foo`
function()
    local navic = require("nvim-navic")
    local old_data = navic.get_data()
    local new_data = {}
    local cur_ns = nil
    local ns_comps = {}

    for _, comp in ipairs(old_data) do
        if comp.type == "Namespace" then
            cur_ns = comp
            table.insert(ns_comps, comp.name)
        else
            -- On the first non-namespace component $c$, collect
            -- previous NS components into a single one and
            -- insert it in front of $c$.
            if cur_ns ~= nil then
                -- Concatenate name and insert
                local num_comps = #ns_comps
                local comb_name = ""
                for idx = 1, num_comps do
                    local ns_name = ns_comps[idx]

                    -- No "::" in front of first component
                    local join = (idx == 1) and "" or "::"

                    if idx ~= num_comps then
                        comb_name = comb_name .. join .. ns_name:sub(1, 1)
                    else
                        comb_name = comb_name .. join .. ns_name
                    end
                end

                cur_ns.name = comb_name
                table.insert(new_data, cur_ns)
                cur_ns = nil
            end

            table.insert(new_data, comp)
        end
    end

    return navic.format_data(new_data)
end
```
</details>
