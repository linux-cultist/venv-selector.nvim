<p align="center">
  <h1 align="center">:tada: Python Venv Selector</h2>
</p>

<p align="center">
	A simple neovim plugin to let you choose what virtual environment to activate in neovim.
</p>

<p align="center">
    <img src="venv-selector.png" />
</p>

# ⚡️ Features



Browse existing python virtual environments on your computer and select one to activate with pyright inside neovim.

- Plug and play, no configuration required
- Switch back and forth between virtual environments without restarting neovim
- Requires [fd](https://github.com/sharkdp/fd) and
  [Telescope](https://github.com/nvim-telescope/telescope.nvim) for fast searches, and visual pickers.

## 📋 Installation

### Using [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

A minimal config looks like this and would typically go into your folder where you have plugins:

```lua
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
	config = true,
}
```

Feel free to add a nice keymapping here as well:

```lua
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
	config = true,
	keys = {{
		"<leader>vs", "<cmd>:VenvSelect<cr>"
	}}
}
```

If you want to change the default options, you can add an opts table like this:


```lua
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
	config = true,
	keys = {{
		"<leader>vs", "<cmd>:VenvSelect<cr>"
	}},
	opts = {
		-- How many parent directories (relative to the current opened file) the plugin will
		-- go to, before traversing down into all children directories to look for venvs.
		parents = 2,

		-- The name of the venvs to look for
		name = "venv"
	}
}
```

Or you can manually run the setup function with options like this:


```lua
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
	keys = {{
		"<leader>vs", "<cmd>:VenvSelect<cr>"
	}},
	config = function()
		require("venv-selector").setup({
			-- How many parent directories (relative to the current opened file) the plugin will
			-- go to, before traversing down into all children directories to look for venvs.
			parents = 2,

			-- The name of the venvs to look for
			name = "venv"
		})
	end
}
```






## ☄ Getting started

Once the plugin has been installed, the `:VenvActivate` command is available.

This plugin will look for python virtual environments located close to your code.

It will start looking in the same directory as your currently opened file. Usually the venv is located in a parent
directory. By default it will go up 2 levels in the directory tree (relative to your currently open file), and then go back down into all the directories under that
directory. Finally it will give you a list of found virtual environments so you can pick one to activate.

## Dependencies

This plugin has been built to be as fast as possible. It will search your computer for virtual environments while you
continue working, and it wont freeze the neovim gui while looking for them. Usually it will give you a result in a few seconds.

Note: You need [fd](https://github.com/sharkdp/fd) installed on your system. This plugin uses it to search for
the virtual environments as fast as possible.

Telescope is also needed to let you pick a virtual environment to use.

## ⚙ Configuration

```lua
require("venv-selector").setup({
    -- How many steps to go up in the directory tree when looking for virtual environments.
    parents = 2,
    -- The name of the venv to look for
    name = "venv",
})
```






