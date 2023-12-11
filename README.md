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

Browse existing python virtual environments on your computer and select one to activate inside neovim.

- Plug and play, no configuration required
- Switch back and forth between virtual environments without restarting neovim
- Support [Pyright](https://github.com/microsoft/pyright), [Pylance](https://github.com/microsoft/pylance-release) and [Pylsp](https://github.com/python-lsp/python-lsp-server) lsp servers with ability to config hooks for others.
- Currently supports virtual environments created in:
  - [Python](https://www.python.org/) (`python3 -m venv venv`)
  - [Poetry](https://python-poetry.org)
  - [PDM](https://github.com/pdm-project/pdm)
  - [Pipenv](https://pipenv.pypa.io/en/latest/)
  - [Anaconda](https://www.anaconda.com)
  - [Pyenv](https://github.com/pyenv/pyenv)
  - [Virtualenvwrapper](https://virtualenvwrapper.readthedocs.io/en/latest/)
  - [Hatch](https://hatch.pypa.io/latest/)
- Cached virtual environment that ties to your workspace for easy activation subsequently
- Requires [fd](https://github.com/sharkdp/fd) and [Telescope](https://github.com/nvim-telescope/telescope.nvim) for fast searches, and visual pickers.
- Requires [nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python), [debugpy](https://github.com/microsoft/debugpy) and [nvim-dap](https://github.com/mfussenegger/nvim-dap) for debugger support

## 📋 Installation and Configuration

The plugin works with **pyright**, **pylance**, or **pylsp** lsp servers. If you want to take advantage of this plugin's default behaviour, you need to have either of them installed
and configured using [lspconfig](https://github.com/neovim/nvim-lspconfig). If you want to use custom integration, see [hooks section](#hooks)
before using this plugin. You can see example setup instructions here: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#pyright

You configure `VenvSelect` by sending in a lua table to the setup() function.

Easiest way if you use [Lazy.nvim](https://github.com/folke/lazy.nvim) is to use the opts function like this:

```lua
return {
  'linux-cultist/venv-selector.nvim',
  dependencies = { 'neovim/nvim-lspconfig', 'nvim-telescope/telescope.nvim', 'mfussenegger/nvim-dap-python' },
  opts = {
    -- Your options go here
    -- name = "venv",
    -- auto_refresh = false
  },
  event = 'VeryLazy', -- Optional: needed only if you want to type `:VenvSelect` without a keymapping
  keys = {
    -- Keymap to open VenvSelector to pick a venv.
    { '<leader>vs', '<cmd>VenvSelect<cr>' },
    -- Keymap to retrieve the venv from a cache (the one previously used for the same project directory).
    { '<leader>vc', '<cmd>VenvSelectCached<cr>' },
  },
}
```

But if you want, you can also manually call the setup function like this:

```lua
return {
  'linux-cultist/venv-selector.nvim',
  dependencies = { 'neovim/nvim-lspconfig', 'nvim-telescope/telescope.nvim', 'mfussenegger/nvim-dap-python' },
  config = function()
    require('venv-selector').setup {
      -- Your options go here
      -- name = "venv",
      -- auto_refresh = false
    }
  end,
  event = 'VeryLazy', -- Optional: needed only if you want to type `:VenvSelect` without a keymapping
  keys = {
    -- Keymap to open VenvSelector to pick a venv.
    { '<leader>vs', '<cmd>VenvSelect<cr>' },
    -- Keymap to retrieve the venv from a cache (the one previously used for the same project directory).
    { '<leader>vc', '<cmd>VenvSelectCached<cr>' },
  },
}
```

### Configuration Options

Important: `VenvSelect` has several different types of searching mentioned in the options description below, so its good to
understand the differences.

**Parental Search**

`VenvSelect` goes up a number of parent directories and then searches downwards in all directories under that one. This is
used when searching for venv folders matching a certain name (like `venv` or `.venv`) relative to your opened file.

Example: You have read the file `/home/cado/Code/Python/Projects/MachineLearning/Tutorial/main.py` into the current neovim buffer.

`VenvSelect` would by default go up to `/home/cado/Python/Projects` and search downwards in all folders under that directory for directories matching the name `venv`.

Look into options like `parents` and `name` to change the specifics of this kind of search.

**Venv Manager Search**

`VenvSelect` looks for virtual environments managed by Poetry, PDM, Pipenv, Anaconda etc in specific locations where they normally are. This kind of search
does not go up to parent directories - it just looks in the specific default folders on your machine.

Look into options like `poetry_path`, `pipenv_path` etc to change where the plugin will look. The options `name` or `parents` has no effect on this search.

**Workspace Search**

`VenvSelect` looks in the workspace (your project directory) that your LSP server has determined. You can typically see this directory with the `LspInfo` command inside
Neovim when you have a file opened and your LSP has started. `VenvSelect` looks in that directory for virtual environments.

| Property                             | Default                                                                                                  | Description                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| auto_refresh                         | false                                                                                                    | Weather or not `VenvSelect` should automatically refresh its search every time its opened. You can manually refresh it with `Ctrl-r` otherwise.                                                                                                                                                                                                                                                           |
| search_venv_managers                 | true                                                                                                     | Weather or not the plugin will look for Venv Manager venvs or skip that search. You can set it to false if you dont use any Venv Managers.                                                                                                                                                                                                                                                                |
| search_workspace                     | true                                                                                                     | Weather or not the plugin will look for venvs in the currently active LSP workspace.                                                                                                                                                                                                                                                                                                                      |
| path                                 | nil                                                                                                      | A fixed path on the disk where VenvSelect should start its search for venvs. If set, it will use this path instead of the path for the currently opened file in the buffer. It will still go up `parents` number of steps before it searches, so set `parents` option to 0 if you want this specific path to be searched and nothing else. Can be useful if all your projects are in a specific location. |
| search                               | true                                                                                                     | This is the Parental Search talked about above. It tries to find venvs in parent paths and below. Use the `parents` option to control how many parents to search.                                                                                                                                                                                                                                         |
| dap_enabled                          | false                                                                                                    | When set to true, uses the selected virtual environment with the debugger. Requires extra dependencies to be added to `VenvSelect` dependencies: [nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python), [debugpy](https://github.com/microsoft/debugpy), [nvim-dap](https://github.com/mfussenegger/nvim-dap)                                                                                |
| parents                              | 2                                                                                                        | The number of parent directories to go up, before searching all directories below for venvs.                                                                                                                                                                                                                                                                                                              |
| name                                 | venv                                                                                                     | The name of the venvs to look for. Can be set to a lua table to search for multiple names (name = {"venv", ".venv"})                                                                                                                                                                                                                                                                                      |
| fd_binary_name                       | fd                                                                                                       | `VenvSelect` also tries to find other names for the same program, like `fdfind` and `fd-find` and will use those if found. But you can set something specific here if you need to.                                                                                                                                                                                                                        |
| notify_user_on_activate              | true                                                                                                     | `VenvSelect` will notify you with a message when a venv is selected in the user interface.                                                                                                                                                                                                                                                                                                                |
| poetry_path                          | [system.lua](https://github.com/linux-cultist/venv-selector.nvim/blob/main/lua/venv-selector/system.lua) | The default path on your system where the plugin looks for Poetry venvs.                                                                                                                                                                                                                                                                                                                                  |
| pdm_path                             | [system.lua](https://github.com/linux-cultist/venv-selector.nvim/blob/main/lua/venv-selector/system.lua) | The default path on your system where the plugin looks for PDM venvs.                                                                                                                                                                                                                                                                                                                                     |
| pipenv_path                          | [system.lua](https://github.com/linux-cultist/venv-selector.nvim/blob/main/lua/venv-selector/system.lua) | The default path on your system where the plugin looks for Pipenv venvs.                                                                                                                                                                                                                                                                                                                                  |
| pyenv_path                           | [system.lua](https://github.com/linux-cultist/venv-selector.nvim/blob/main/lua/venv-selector/system.lua) | The default path on your system where the plugin looks for Pyenv venvs.                                                                                                                                                                                                                                                                                                                                   |
| hatch_path                           | [system.lua](https://github.com/linux-cultist/venv-selector.nvim/blob/main/lua/venv-selector/system.lua) | The default path on your system where the plugin looks for Hatch venvs.                                                                                                                                                                                                                                                                                                                                   |
| venvwrapper_path                     | [system.lua](https://github.com/linux-cultist/venv-selector.nvim/blob/main/lua/venv-selector/system.lua) | The default path on your system where the plugin looks for VenvWrapper venvs.                                                                                                                                                                                                                                                                                                                             |
| anaconda_base_path                   | [system.lua](https://github.com/linux-cultist/venv-selector.nvim/blob/main/lua/venv-selector/system.lua) | The default path on your system where the plugin looks for Anaconda venvs.                                                                                                                                                                                                                                                                                                                                |
| anaconda_envs_path                   | [system.lua](https://github.com/linux-cultist/venv-selector.nvim/blob/main/lua/venv-selector/system.lua) | The default path on your system where the plugin looks for Anaconda venvs.                                                                                                                                                                                                                                                                                                                                |
| anaconda { python_executable = nil } | 'python' or 'python3'                                                                                    | The name of the anaconda python executable                                                                                                                                                                                                                                                                                                                                                                |
| anaconda { python_parent_dir = nil } | 'bin' or 'Scripts'                                                                                       | The name of the anaconda python parent directory                                                                                                                                                                                                                                                                                                                                                          |

## ☄ Getting started

Once the plugin has been installed, the `:VenvSelect` command is available.

This plugin will look for python virtual environments located close to your code.

It will start looking in the same directory as your currently opened file. Usually the venv is located in a parent
directory. By default it will go up 2 levels in the directory tree (relative to your currently open file), and then go back down into all the directories under that
directory. Finally it will give you a list of found virtual environments so you can pick one to activate.

There is also the `:VenvSelectCurrent` command to get a message saying which venv is active.

### Hooks

By default, the plugin tries to setup `pyright`, `pylance`, and `pylsp` automatically using hooks. If you want to add a custom integration, you need to write
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
require('venv-selector').setup {
  --- other configuration
  changed_venv_hooks = { your_hook_name },
}
```

The plugin-provided hooks are exposed for convenience in case you want to use them alongside your custom one:

```lua
local venv_selector = require 'venv-selector'

venv_selector.setup {
  --- other configuration
  changed_venv_hooks = { your_hook_name, venv_selector.hooks.pyright },
}
```

Currently provided hooks are:

- `require("venv-selector").hooks.pyright`
- `require("venv-selector").hooks.pylance`
- `require("venv-selector").hooks.pylsp`

### Helpful functions

The selected virtual environment and path to the python executable is available from these two functions:

```lua
require('venv-selector').get_active_path() -- Gives path to the python executable inside the activated virtual environment
require('venv-selector').get_active_venv() -- Gives path to the activated virtual environment folder
require('venv-selector').retrieve_from_cache() -- To activate the last virtual environment set in the current working directory
```

This can be used to print out the virtual environment in a status bar, or make the plugin work with other plugins that
want this information.

## 🤖 Automate

After choosing your virtual environment, the path to the virtual environment will be cached under the current working directory. To activate the same virtual environment
the next time, simply use `:VenvSelectCached` to reactivate your virtual environment.

This can also be automated to run whenever you enter into a python project, for example.

```lua
vim.api.nvim_create_autocmd('VimEnter', {
  desc = 'Auto select virtualenv Nvim open',
  pattern = '*',
  callback = function()
    local venv = vim.fn.findfile('pyproject.toml', vim.fn.getcwd() .. ';')
    if venv ~= '' then
      require('venv-selector').retrieve_from_cache()
    end
  end,
  once = true,
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
require('venv-selector').setup {
  poetry_path = '/home/cado/.cache/pypoetry/virtualenvs',
}
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
require('venv-selector').setup {
  pipenv_path = '/home/cado/.local/share/virtualenvs',
}
```

#### Pyenv-virtualenv

First run `pyenv root` to get the rootfolder for pyenv versions and shims are kept. You should get some output similar to this:

`/home/cado/.pyenv`

The virtualenvs are stored under the `versions` folder inside that directory. In this case it would be `/home/cado/.pyenv/versions`.

Copy the virtualenv path and set it as a parameter to the `VenvSelector` setup function:

```lua
require('venv-selector').setup {
  pyenv_path = '/home/cado/.pyenv/versions',
}
```

#### Anaconda

Once you have your anaconda environment activated in a shell, you can use the `conda env list` command to list
both the base environment and the other environments:

```
# conda environments:
#
conda1                   /home/cado/.conda/envs/conda1
conda2                   /home/cado/.conda/envs/conda2
base                  *  /opt/anaconda
```

Configure `VenvSelect` like this in this example:

```lua
require('venv-selector').setup {
  anaconda_base_path = '/opt/anaconda',
  anaconda_envs_path = '/home/cado/.conda/envs',
}
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
  local venv_name = require('venv-selector').get_active_venv()
  if venv_name ~= nil then
    return string.gsub(venv_name, '.*/pypoetry/virtualenvs/', '(poetry) ')
  else
    return 'venv'
  end
end

local venv = {
  {
    provider = function()
      return '  ' .. actived_venv()
    end,
  },
  on_click = {
    callback = function()
      vim.cmd.VenvSelect()
    end,
    name = 'heirline_statusline_venv_selector',
  },
}
```
