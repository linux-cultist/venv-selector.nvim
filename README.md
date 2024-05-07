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
  - `:VenvSelect fd 'venv/bin/python$' . --full-path -I`

- Support [Pyright](https://github.com/microsoft/pyright), [Pylance](https://github.com/microsoft/pylance-release) and [Pylsp](https://github.com/python-lsp/python-lsp-server) lsp servers with ability to config hooks for others.
- Cached virtual environment that ties to your current working directory for quick activation
- Requires [fd](https://github.com/sharkdp/fd) and [Telescope](https://github.com/nvim-telescope/telescope.nvim) for fast searches, and visual pickers.
- Requires [nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python), [debugpy](https://github.com/microsoft/debugpy) and [nvim-dap](https://github.com/mfussenegger/nvim-dap) for debugger support


#### **NOTE:** This regexp branch of the plugin is a rewrite that works differently under the hood to support more advanced features. Its under development and not ready for public use yet.

## Quick introduction and example

Your old configuration should be removed since its not used anymore.

The new configuration looks like this:

```
      require("venv-selector").setup {
        settings = {
          search = {
            my_venvs = {
              command = "fd 'python$' ~/.venv",
            },
          },
        },
      }

```
The example command above launches a search for any path ending with `/bin/python` in the `~/Code` folder. Here are the results:

```
/home/cado/Code/Personal/databricks-cli/venv/bin/python
/home/cado/Code/Personal/dbt/venv/bin/python
/home/cado/Code/Personal/fastapi_learning/venv/bin/python
/home/cado/Code/Personal/helix/venv/bin/python
```

These results will be shown in the telescope viewer and if they are a python virtual environment, they can be activated by pressing enter.

## Adding your own searches

The best way to craft a search is to run `fd` with your desired parameters on the command line before you put it into the plugin config.

Naturally you want to use your own paths and your own flags to `fd` to make it pick up exactly what you want to see in the telescope viewer.

```
      require("venv-selector").setup {
        settings = {
          search = {
            name_for_your_search_here = {
              command = "fd '/bin/python$' ~/Code --full-path",
            },
            name_for_your_other_search_here = {
              command = "fd '/bin/python$' ~/Programming/Python --full-path -IHL -E /proc",
            },
          },
        },
      }

```

This example above has added a secondary search where some extra fd flags are used. They are important to add sometimes, depending on how your file system looks like.


| Fd option             | Description |
|-----------------------|-------------|
| `-I` or `--no-ignore` | Ignore files and directories specified in `.gitignore`, `.fdignore`, and other ignore files. This option forces `fd` to include files it would normally ignore. |
| `-L` or `--follow`    | Follow symbolic links while searching. This option makes `fd` consider the targets of symbolic links as potential search results. |
| `-H` or `--hidden`    | Include hidden directories and files in the search results. Hidden files are those starting with a dot (`.`) on Unix-like systems. |
| `-E` or `--exclude`   | Exclude files and directories that match the specified pattern. This can be used multiple times to exclude various patterns. |

So if you dont add `-I`, paths that are in a `.gitignore` file will be ignored. Its common to have venv folders in that file, so thats why this flag can be important.

However, some flags slows down the search significantly and should not be used if not needed (like `-H` to look for hidden files). If your venvs are not starting with a dot in their name, you dont need to use this flag.


## Preconfigured searches

There are a few predefined searches that comes with the plugin, designed to find venvs from different venv managers like Poetry, Anaconda and so on.
https://github.com/linux-cultist/venv-selector.nvim/blob/regexp/lua/venv-selector/config.lua

The `cwd` search will search your current working directory. The `$CWD` variable will have your actual neovim working directory when the search is being run.

The `workspace` search is using the `$WORKSPACE_PATH` variable. This variable gets the actual workspace path when your LSP is activated by opening a python file.

If these searches dont work for you, you can write your own as shown above.

## More docs

More docs coming up soon!




