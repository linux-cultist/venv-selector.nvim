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

#### **NOTE:** This regexp branch of the plugin is a rewrite that works differently under the hood to support more advanced features. Its under development and not ready for public use yet.

- Switch back and forth between virtual environments without restarting neovim
- New and much more flexible configuration to support finding the exact venvs you want.
- Browse existing python virtual environments on your computer and select one to activate inside neovim.
- Supports **all** virtual environments using configurable **regular expressions expressions**, such as:
  - [Python](https://www.python.org/) (`python3 -m venv venv`)
  - [Poetry](https://python-poetry.org)
  - [PDM](https://github.com/pdm-project/pdm)
  - [Pipenv](https://pipenv.pypa.io/en/latest/)
  - [Anaconda](https://www.anaconda.com)
  - [Pyenv](https://github.com/pyenv/pyenv)
  - [Virtualenvwrapper](https://virtualenvwrapper.readthedocs.io/en/latest/)
  - [Hatch](https://hatch.pypa.io/latest/)
- Supports callbacks to further filter or rename telescope results as they are found.
- Supports using any program to find virtual environments (`fd`, `find`, `ls`, `dir` etc)
- Supports running any interactive command to populate the telescope viewer:
  - `:VenvSelect ls -1 /tmp`
  - `:VenvSelect fd 'venv/bin/python$' . --full-path -I`

- Support [Pyright](https://github.com/microsoft/pyright), [Pylance](https://github.com/microsoft/pylance-release) and [Pylsp](https://github.com/python-lsp/python-lsp-server) lsp servers with ability to config hooks for others.
- Cached virtual environment that ties to your current working directory for quick activation
- Requires [fd](https://github.com/sharkdp/fd) and [Telescope](https://github.com/nvim-telescope/telescope.nvim) for fast searches, and visual pickers.
- Requires [nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python), [debugpy](https://github.com/microsoft/debugpy) and [nvim-dap](https://github.com/mfussenegger/nvim-dap) for debugger support

## 📋 Installation and Configuration

The plugin works with **pyright**, **pylance**, or **pylsp** lsp servers. If you want to take advantage of this plugin's default behaviour, you need to have either of them installed
and configured using [lspconfig](https://github.com/neovim/nvim-lspconfig). If you want to use custom integration, see [hooks section](#hooks)
before using this plugin. You can see example setup instructions here: https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#pyright

You configure `VenvSelect` by sending in a lua table to the setup() function.

Here is an example of how it can be set up with [Lazy.nvim](https://github.com/folke/lazy.nvim):


```lua
return {
  'linux-cultist/venv-selector.nvim',
  dependencies = { 'neovim/nvim-lspconfig', 'nvim-telescope/telescope.nvim', 'mfussenegger/nvim-dap-python' },
  config = function()
     -- Optional callback function if you want to alter how the results from `mycode` command look like in telescope viewer
     local c = require "venv-selector.config"
     local function my_callback(filename)
        return filename 
     end

    require('venv-selector').setup {
        search = {
          -- You can add any number of searches just like the one named `mycode` below.
          mycode = {
            command = "fd '/bin/python$' ~/Code --full-path --color never -E /proc -L -H -I",
            callback = my_callback -- Optional, not needed.
          },
          -- Another example of a search, here without the optional callback
          search_home_for_pythons = {
            command = "fd '/bin/python$' ~ --full-path --color never",
          },
        },
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

TODO: Describe new configuration

## ☄ Getting started

TODO: Describe new getting started

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
