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
- Cached virtual environment that ties to your workspace for easy activation subsequently
- Support pyright and pylsp with ability to config hooks for other LSP
- Requires [fd](https://github.com/sharkdp/fd) and
  [Telescope](https://github.com/nvim-telescope/telescope.nvim) for fast searches, and visual pickers.
- Requires [nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python), [debugpy](https://github.com/microsoft/debugpy) and [nvim-dap](https://github.com/mfussenegger/nvim-dap) for debugger support

## 📋 Installation and Configuration

The plugin works with **pyright** and **pylsp** lsp servers. If you want to take advantage of this plugin's default behaviour, you need to have either of them installed
and configured using [lspconfig](https://github.com/neovim/nvim-lspconfig). If you want to use custom integration, see [hooks section](#hooks)
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
		"<leader>vs", "<cmd>:VenvSelect<cr>",
		-- key mapping for directly retrieve from cache. You may set autocmd if you prefer the no hand approach
		"<leader>vc", "<cmd>:VenvSelectCached<cr>"
	}}
}
```

If you want to change the default options, you can add an opts table like this:

```lua
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = {
		"neovim/nvim-lspconfig",
		"nvim-telescope/telescope.nvim",
		-- for DAP support
		"mfussenegger/nvim-dap-python"
		},
	config = true,
	keys = {{
		"<leader>vs", "<cmd>:VenvSelect<cr>",
		-- optional if you use a autocmd (see #🤖-Automate)
		"<leader>vc", "<cmd>:VenvSelectCached<cr>"
	}},
	opts = {

		-- auto_refresh (default: false). Will automatically start a new search every time VenvSelect is opened.
		-- When its set to false, you can refresh the search manually by pressing ctrl-r. For most users this
		-- is probably the best default setting since it takes time to search and you usually work within the same
		-- directory structure all the time.
		auto_refresh = false,

		-- search_venv_managers (default: true). Will search for Poetry/Pipenv/Anaconda virtual environments in their
		-- default location. If you dont use the default location, you can
		search_venv_managers = true,

		-- search_workspace (default: true). Your lsp has the concept of "workspaces" (project folders), and
		-- with this setting, the plugin will look in those folders for venvs. If you only use venvs located in
		-- project folders, you can set search = false and search_workspace = true.
		search_workspace = true,

		-- path (optional, default not set). Absolute path on the file system where the plugin will look for venvs.
		-- Only set this if your venvs are far away from the code you are working on for some reason. Otherwise its
		-- probably better to let the VenvSelect search for venvs in parent folders (relative to your code). VenvSelect
		-- searchs for your venvs in parent folders relative to what file is open in the current buffer, so you get
		-- different results when searching depending on what file you are looking at.
		-- path = "/home/username/your_venvs",

		-- search (default: true). Search your computer for virtual environments outside of Poetry and Pipenv.
		-- Used in combination with parents setting to decide how it searches.
		-- You can set this to false to speed up the plugin if your virtual envs are in your workspace, or in Poetry
		-- or Pipenv locations. No need to search if you know where they will be.
		search = true,

		-- dap_enabled (default: false). When true, uses the selected virtual environment with the debugger.
		-- require nvim-dap-python from https://github.com/mfussenegger/nvim-dap-python
		-- require debugpy from https://github.com/microsoft/debugpy
		-- require nvim-dap from https://github.com/mfussenegger/nvim-dap
		dap_enabled = false,

		-- parents (default: 2) - Used when search = true only. How many parent directories the plugin will go up
		-- (relative to where your open file is on the file system when you run VenvSelect). Once the parent directory
		-- is found, the plugin will traverse down into all children directories to look for venvs. The higher
		-- you set this number, the slower the plugin will usually be since there is more to search.
		-- You may want to set this to to 0 if you specify a path in the path setting to avoid searching parent
		-- directories.
		parents = 2,

		-- name (default: venv) - The name of the venv directories to look for.
		name = "venv", -- NOTE: You can also use a lua table here for multiple names: {"venv", ".venv"}`

		-- fd_binary_name (default: fd) - The name of the fd binary on your system.
		fd_binary_name = "fd",


		-- notify_user_on_activate (default: true) - Prints a message that the venv has been activated
		notify_user_on_activate = true,

	},
	event = "VeryLazy", -- Optional: needed only if you want to type `:VenvSelect` without a keymapping
}
```

Or you can manually run the setup function with options like this:

```lua
return {
	"linux-cultist/venv-selector.nvim",
	dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
	keys = {{
		"<leader>vs", "<cmd>:VenvSelect<cr>",
		-- optional if you use a autocmd (see #🤖-Automate)
		"<leader>vc", "<cmd>:VenvSelectCached<cr>"
	}},
	config = function()
		require("venv-selector").setup({

		-- auto_refresh (default: false). Will automatically start a new search every time VenvSelect is opened.
		-- When its set to false, you can refresh the search manually by pressing ctrl-r. For most users this
		-- is probably the best default setting since it takes time to search and you usually work within the same
		-- directory structure all the time.
		auto_refresh = false,

		-- search_venv_managers (default: true). Will search for Poetry and Pipenv virtual environments in their
		-- default location. If you dont use the default location, you can
		search_venv_managers = true,

		-- search_workspace (default: true). Your lsp has the concept of "workspaces" (project folders), and
		-- with this setting, the plugin will look in those folders for venvs. If you only use venvs located in
		-- project folders, you can set search = false and search_workspace = true.
		search_workspace = true,

		-- path (optional, default not set). Absolute path on the file system where the plugin will look for venvs.
		-- Only set this if your venvs are far away from the code you are working on for some reason. Otherwise its
		-- probably better to let the VenvSelect search for venvs in parent folders (relative to your code). VenvSelect
		-- searchs for your venvs in parent folders relative to what file is open in the current buffer, so you get
		-- different results when searching depending on what file you are looking at.
		-- path = "/home/username/your_venvs",

		-- search (default: true) - Search your computer for virtual environments outside of Poetry and Pipenv.
		-- Used in combination with parents setting to decide how it searches.
		-- You can set this to false to speed up the plugin if your virtual envs are in your workspace, or in Poetry
		-- or Pipenv locations. No need to search if you know where they will be.
		search = true,

		-- dap_enabled (default: false) Configure Debugger to use virtualvenv to run debugger.
		-- require nvim-dap-python from https://github.com/mfussenegger/nvim-dap-python
		-- require debugpy from https://github.com/microsoft/debugpy
		-- require nvim-dap from https://github.com/mfussenegger/nvim-dap
		dap_enabled = false,

		-- parents (default: 2) - Used when search = true only. How many parent directories the plugin will go up
		-- (relative to where your open file is on the file system when you run VenvSelect). Once the parent directory
		-- is found, the plugin will traverse down into all children directories to look for venvs. The higher
		-- you set this number, the slower the plugin will usually be since there is more to search.
		-- You may want to set this to to 0 if you specify a path in the path setting to avoid searching parent
		-- directories.
		parents = 2,

		-- name (default: venv) - The name of the venv directories to look for.
		name = "venv", -- NOTE: You can also use a lua table here for multiple names: {"venv", ".venv"}`

		-- fd_binary_name (default: fd) - The name of the fd binary on your system. Some Debian based Linux Distributions like Ubuntu use ´fdfind´.
		fd_binary_name = "fd",


		-- notify_user_on_activate (default: true) - Prints a message that the venv has been activated
		notify_user_on_activate = true,

		})
	end;
	event = "VeryLazy", -- Optional: needed only if you want to type `:VenvSelect` without a keymapping
}
```

### Hooks

By default, the plugin tries to setup `pyright` and `pylsp` automatically using hooks. If you want to add a custom integration, you need to write
a hook with following signature:

```lua
--- @param venv_path string A string containing the absolute path to selected virtualenv
--- @param venv_python string A string containing the absolute path to python binary in selected venv
function your_hook_name(venv_path, venv_python)
	--- your custom integration here
end
```

And provide it to a setup function:

```lua
require("venv-selector").setup({
	--- other configuration
	changed_venv_hooks = { your_hook_name }
})
```

The plugin-provided hooks are exposed for convenience in case you want to use them alongside your custom one:

```lua
local venv_selector = require("venv-selector")

venv_selector.setup({
	--- other configuration
	changed_venv_hooks = { your_hook_name, venv_selector.hooks.pyright }
})
```

Currently provided hooks are:

- `require("venv-selector").hooks.pyright`
- `require("venv-selector").hooks.pylsp`

### Helpful functions

The selected virtual environment and path to the python executable is available from these two functions:

```lua
require("venv-selector").get_active_path() -- Gives path to the python executable inside the activated virtual environment
require("venv-selector").get_active_venv() -- Gives path to the activated virtual environment folder
require("venv-selector").retrieve_from_cache() -- To activate the last virtual environment set in the current working directory
require("venv-selector").deactivate_venv() -- Deactivates the virtual environment and unsets VIRTUAL_ENV environment variable.
```

This can be used to print out the virtual environment in a status bar, or make the plugin work with other plugins that
want this information.

## ☄ Getting started

Once the plugin has been installed, the `:VenvSelect` command is available.

This plugin will look for python virtual environments located close to your code.

It will start looking in the same directory as your currently opened file. Usually the venv is located in a parent
directory. By default it will go up 2 levels in the directory tree (relative to your currently open file), and then go back down into all the directories under that
directory. Finally it will give you a list of found virtual environments so you can pick one to activate.

There is also the `:VenvSelectCurrent` command to get a message saying which venv is active.

## 🤖 Automate

After choosing your virtual environment, the path to the virtual environment will be cached under the current working directory. To activate the same virtual environment
the next time, simply use `:VenvSelectCached` to reactivate your virtual environment.

This can also be automated to run whenever you enter into a python project, for example.

```lua
vim.api.nvim_create_autocmd("VimEnter", {
desc = "Auto select virtualenv Nvim open",
pattern = "*",
callback = function()
  local venv = vim.fn.findfile("pyproject.toml", vim.fn.getcwd() .. ";")
  if venv ~= "" then
    require("venv-selector").retrieve_from_cache()
  end
end,
once = true,
})
```

### If you use Poetry, Pipenv, Pyenv-virtualenv or Anaconda

If you use Poetry, Pipenv, Pyenv-virtualenv or Anaconda, you typically have all the virtual environments located in the same path as subfolders.

VenvSelector automatically looks in the default paths for both Poetry, Pipenv, Pyenv-virtualenv and Anaconda virtual environments:

_Mac:_

- Poetry: `$HOME/Library/Caches/pypoetry/virtualenvs`
- Pipenv: `$HOME/.local/share/virtualenvs`
- Pyenv: `$HOME/.pyenv.versions`
- Anaconda: `$CONDA_PREFIX/envs`

_Linux:_

- Poetry: `$HOME/.cache/pypoetry/virtualenvs`
- Pipenv: `$HOME/.local/share/virtualenvs`
- Pyenv: `HOME/.pyenv.versions`
- Anaconda: `$CONDA_PREFIX/envs`

_Windows:_

- Poetry: `%APPDATA%\\pypoetry\\virtualenvs`
- Pipenv: `$HOME\\virtualenvs`
- Pyenv: `%USERPROFILE%\\.pyenv\\versions`
- Anaconda: `%CONDA_PREFIX%\\envs`

You can override the default paths if the virtual environments are not being found by `VenvSelector`:

```lua
require("venv-selector").setup({
	poetry_path = "your_path_here",
	pipenv_path = "your_path_here",
  	pyenv_path = "your_path_here",
  	anaconda_path = "your_path_here",
})
```

#### Find out where your virtual environments are located

##### Poetry

First run `poetry env info` in your project folder where you are using poetry to manage the virtual environments. You
should get some output simular to this:

```bash
Virtualenv
Python:         3.10.10
Implementation: CPython
Path:           /home/cado/.cache/pypoetry/virtualenvs/poetry-demo-EUUW_nAM-py3.10
Executable:     /home/cado/.cache/pypoetry/virtualenvs/poetry-demo-EUUW_nAM-py3.10/bin/python
Valid:          True

System
Platform:   linux
OS:         posix
Python:     3.10.10
Path:       /usr
Executable: /usr/bin/python3.10

```

You can see that the path shows that the virtual environments are located under `/home/cado/.cache/pypoetry/virtualenvs` in this case.

Copy the virtualenv path and set it as a parameter to the `VenvSelector` setup function:

```lua
require("venv-selector").setup({
	poetry_path = "/home/cado/.cache/pypoetry/virtualenvs",
})
```

##### Pipenv

First run `pipenv --venv` in your project folder where you are using pipenv to manage the virtual environments. You
should get some output simular to this:

```bash
/home/cado/.local/share/virtualenvs/pipenv_test-w6BD3kWZ
```

You can see that the path shows that the virtual environments are located under `/home/cado/.local/share/virtualenvs` in this case.

Copy the virtualenv path and set it as a parameter to the `VenvSelector` setup function:

```lua
require("venv-selector").setup({
	pipenv_path = "/home/cado/.local/share/virtualenvs",
})
```

#### Pyenv-virtualenv

First run `pyenv root` to get the rootfolder for pyenv versions and shims are kept. You should get some output similar to this:

`/home/cado/.pyenv`

The virtualenvs are stored under the `versions` folder inside that directory. In this case it would be `/home/cado/.pyenv/versions`.

Copy the virtualenv path and set it as a parameter to the `VenvSelector` setup function:

```lua
require("venv-selector").setup({
    pyenv_path = "/home/cado/.pyenv/versions",
})
```

#### Anaconda

First run `echo $CONDA_PREFIX` to get the rootfolder for Anaconda. You should get some output similar to this:

`/home/cado/anaconda3`

The virtualenvs are stored under the `envs` folder inside that directory. In this case it would be `/home/cado/anaconda3/envs`.

Copy the virtualenv path and set it as a parameter to the `VenvSelector` setup function:

```lua
require("venv-selector").setup({
    anaconda_path = "/home/cado/anaconda/envs",
})
```

## Dependencies

This plugin has been built to be as fast as possible. It will search your computer for virtual environments while you
continue working, and it wont freeze the neovim gui while looking for them. Usually it will give you a result in a few seconds.

Even better, with caching enabled, this plugin instantly activate previously configured virtual environment without having to spend time on searching again.

Note: You need [fd](https://github.com/sharkdp/fd) installed on your system. This plugin uses it to search for
the virtual environments as fast as possible.

Telescope is also needed to let you pick a virtual environment to use.

[nvim-python-dap](https://github.com/mfussenegger/nvim-dap-python) is required for DAP function. Enable DAP at config.

## 💡Tips and Tricks

### VS Code like statusline functionality with [heirline](https://github.com/rebelot/heirline.nvim)

To add a clickable component to your heirline statusline.

```lua
local actived_venv = function()
	local venv_name = require("venv-selector").get_active_venv()
	if venv_name ~= nil then
		return string.gsub(venv_name, ".*/pypoetry/virtualenvs/", "(poetry) ")
	else
		return "venv"
	end
end

local venv = {
	{
		provider = function() return  "  " .. actived_venv() end,
	},
	on_click = {
		callback = function() vim.cmd.VenvSelect() end,
		name = "heirline_statusline_venv_selector",
	},
}
```
