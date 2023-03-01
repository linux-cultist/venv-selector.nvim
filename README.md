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

## 📋 Installation and Configuration

**IMPORTANT**: The plugin works by using **pyright** lsp server, so pyright needs to be installed and pre-configured with nvim-lspconfig
before using this plugin. You can see example setup instructions here: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#pyright

### Using [folke/lazy.nvim](https://github.com/folke/lazy.nvim)

A minimal config looks like this and would typically go into your folder where you have plugins:

```lua
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
	config = true,
	event = "VeryLazy", -- Optional: needed only if you want to type `:VenvSelect` without a keymapping
}
```

Feel free to add a nice keymapping here as well:

```lua
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
	config = true,
	event = "VeryLazy", -- Optional: needed only if you want to type `:VenvSelect` without a keymapping
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
		-- path (optional) - Absolute path on the file system where the plugin will look for venvs.
		-- If you have venv folders in one specific path, you can set it here to look only in that path.
		-- If you have many venv folders spread out across the file system, dont set this at all, and the
		-- plugin will search for your venvs relative to what file is open in the current buffer.
		path = "/home/username/your_venvs"

		-- parents (optional) - How many parent directories the plugin will go up, before traversing down
		-- into all children directories to look for venvs. Set this to 0 if you use an absolute path above.
		parents = 2,

		-- name (optional) - The name of the venv directories to look for. Can for example be set to ".venv".
		name = "venv"
	}
	event = "VeryLazy", -- Optional: needed only if you want to type `:VenvSelect` without a keymapping
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
			-- path (optional) - Absolute path on the file system where the plugin will look for venvs.
			-- If you have venv folders in one specific path, you can set it here to look only in that path.
			-- If you have many venv folders spread out across the file system, dont set this at all, and the
			-- plugin will search for your venvs relative to what file is open in the current buffer.
			path = "/home/username/your_venvs"

			-- parents (optional) - How many parent directories the plugin will go up, before traversing down
			-- into all children directories to look for venvs. Set this to 0 if you use an absolute path above.
			parents = 2,

			-- name (optional) - The name of the venv directories to look for. Can for example be set to ".venv".
			name = "venv"
		})
	end
	event = "VeryLazy", -- Optional: needed only if you want to type `:VenvSelect` without a keymapping
}
```






## ☄ Getting started

Once the plugin has been installed, the `:VenvSelect` command is available.

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

