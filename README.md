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
* `highlight` : If set to true, will add colors to icons and text as defined by highlight groups `NavicIcons*` (`NavicIconsFile`, `NavicIconsModule`.. etc.) and `NavicText`.
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

## 🚀 Usage

nvim-navic does not alter your statusline or winbar on its own. Instead, you are provided with these two functions and its left up to you how you want to incorporate this into your setup.

* `is_available()` : Returns boolean value indicating whether output can be provided.
* `get_location()` : Returns a pretty string with context information.

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
local gps = require("nvim-gps")

require("lualine").setup({
    sections = {
        lualine_c = {
            { gps.get_location, cond = gps.is_available },
        }
    }
})
```

</details>

</details>

If you have a creative use case and want the raw context data to work with, you can use the following function

* `get_data()` : Returns a table of intermediate representation of data. Table of tables that contain 'kind' and 'name' for each context.

<details>
<summary>An example output of <code>get_data</code> function: </summary>

```lua
 {
    {
        name = "myclass",
        kind = 5
    },
    {
        name = "mymethod",
        kind = 6
    }
 }
```
</details>
