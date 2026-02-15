# 🧰 Usage of venv-selector.nvim

## ⚙️ Configuration structure

Top-level plugin configuration has two primary tables:

- `options` — global behavior & callbacks (picker choice, misc flags, integrations)
- `search` — your own custom searches if venvs are not found automatically

Refer to [docs/OPTIONS.md](OPTIONS.md) for complete reference of options you can set.

<br>



## 🔎 Creating your own searches

- Start in the terminal and create your fd command.
- Prefer narrow, explicit commands that target known locations.
- Only search hidden files/directories (like `$HOME/Code`) in a specific location, not your home directory.
- Template variables available in command:
  - `$CWD` — current working directory
  - `$WORKSPACE_PATH` — workspace root
  - `$FILE_DIR` — directory of current file
  - `$CURRENT_FILE` — currently open file

1. **Creating a fd search**

    When creating a new search, make sure it gives the expected results in your terminal first.

    <details>
    <summary>🐧 Linux/macOS</summary>
    <br>
    Here we search for all pythons under the `~/Code` directory. We need the result to be the full paths to the python interpreters.

    ```
    $ `fd '/bin/python$' ~/Code --no-ignore-vcs --full-path`
    /home/cado/Code/Personal/new_env/infrastructure/venv/bin/python
    /home/cado/Code/Personal/play_with_python/venv/bin/python
    /home/cado/Code/Personal/python_test/venv/bin/python
    /home/cado/Code/Personal/test_venvsel/env/bin/python
    /home/cado/Code/Personal/test_space/my folder/venv/bin/python
    /home/cado/Code/Personal/playing/venv/bin/python
    /home/cado/Code/Personal/parse_manifest/venv/bin/python
    /home/cado/Code/Personal/fastapi_learning/venv/bin/python
    /home/cado/Code/Personal/snowflake-conn/venv/bin/python
    /home/cado/Code/Personal/dbt/venv/bin/python
    /home/cado/Code/Personal/pulse_jinja/venv/bin/python
    /home/cado/Code/Personal/databricks-cli/venv/bin/python
    /home/cado/Code/Personal/exercise/venv/bin/python
    /home/cado/Code/Personal/test_python/venv/bin/python
    /home/cado/Code/Personal/helix/venv/bin/python
    /home/cado/Code/Personal/fleet_python/venv/bin/python
    ```
    
    </details>
    
    <details>
    <summary>🪟 Windows</summary>
    <br>
    Here we search for all pythons under the home directory. We want to match on all paths ending in `Scripts\\python.exe` since those are the venvs on Windows.

    ```
    tameb@WIN11 C:\Users\tameb>fd Scripts\\python.exe$ %USERPROFILE%\Code --full-path -I -a  
    C:\Users\tameb\Code\another_project\venv\Scripts\python.exe
    C:\Users\tameb\Code\manual\venv\Scripts\python.exe
    C:\Users\tameb\Code\sample_project\venv\Scripts\python.exe
    ```
    
    </details>
    
    Its a good idea to experiment with different flags to fd so you get good performance. Dont search hidden files if your venvs are not hidden, and exclude paths you dont need from the search.


2. **Adding the fd search to VenvSelect config**

    Once your fd search is working, you add it to your plugin config.

    <details>
    <summary>🐧 Linux/macOS</summary>
    <br>
    You can use relative paths here to specify search location, but make sure to use `fd --full-path` so `fd` always gives you back an absolute path to the results.
        
    ```lua
    search = {
      my_project_venvs = {
        command = "fd '/bin/python$' ~/Code --full-path --color never",
      },
    -- you can add more searches here
    -- another_search = {
    -- command = ""
    -- }
    }
    ```

    If it's a search for a conda-type environment, set the type to `anaconda` so the plugin sets the environment variable `CONDA_PREFIX` and not `VIRTUAL_ENV`:

    ```lua
    search = {
      my_conda_base = {
        command = "fd '/bin/python$' /opt/anaconda3 --full-path --color never -E pkgs", -- exclude path with pkgs
        type = "anaconda" -- it's anaconda-style environment (also for miniconda)
      }
      -- you can add more searches here
      -- another_search = {
      -- command = ""
      -- }
    }
    ```

    Have a look at [config.lua](../lua/venv-selector/config.lua) to see the built-in searches and how they look.

    </details>

    <details>
    <summary>🪟 Windows</summary>
    <br>
    VenvSelect doesn't understand Windows shell variables like `%USERPROFILE%`, but you can use `$HOME`. Its also important to escape backslashes on windows, see below.
    <br>
        
    NOTE:
    - You *have to* escape each backslash in the regexp with another backslash.
    - 'Scripts\\python.exe' from the fd example becomes 'Scripts\\\\python.exe' in the plugin config.
    - Use single quotes around regexps.

    ```lua
    search = {
      my_project_venvs = {
          command = "fd 'Scripts\\\\python.exe$' $HOME/Code --full-path --color never -a",
      }
    }
    ```

    For conda-style environments on Windows:

    ```lua
    search = {
      my_conda_base = {
        command = "$FD anaconda3\\\\python.exe$ $HOME/anaconda3 --full-path -a",
        type = "anaconda" -- anaconda-style environment
      }
    }
    ```

    Have a look at [config.lua](../lua/venv-selector/config.lua) to see the built-in searches and how they look.
    </details>
<br>
    
## Overriding or disabling a search

If you want to *override* one of the default searches, create a search with the same name. This changes the default cwd (*c*urrent *w*orking *d*irectory) search to not search for hidden files by removing the `-H` flag that is part of the default cwd search. This makes it much faster, but wont find venvs in directories like `.venv/`.

```lua
{
  search = {
    cwd = {
        command =
        "$FD '/bin/python$' '$CWD' --full-path --color never -I -a -L -E /proc -E .git/ -E .wine/ -E .steam/ -E Steam/ -E site-packages/",
    }
  }
}
```
If you want to *disable* one of the default searches, you can simply set it to false. This disables the cwd search.

```lua
{
  search = {
    cwd = false
  }
}

```
---

## 🧾 PEP-723 (`uv`) integration

If you use PEP-723 style scripts, the plugin will read the metadata at the top of the file and create/activate the uv environment for you.

Example of metadata header in your python file:

```
# /// script
# requires-python = "~=3.13.0"
# dependencies = [
#     "click>=7.0.0,<9.0.0", 
#     "colorama>=0.4.0",
#     "urllib3>=1.26.0,<2.0.0",
#     "pip",
#     "requests"
# ]
# ///
```

When you open a python file with this metadata, you will see this in the `VenvSelectLog` (if `log_level` option is set to `TRACE` or `DEBUG`):

```
2026-02-13 10:39:04 [DEBUG]: uv sync: Updating script environment at: /home/cado/.cache/uv/environments-v2/uvtest3-d4fa1d9bee5f848f
2026-02-13 10:39:04 [DEBUG]: uv sync: Resolved 8 packages in 53ms
2026-02-13 10:39:04 [DEBUG]: uv sync: Prepared 1 package in 12ms
2026-02-13 10:39:04 [DEBUG]: uv sync: Installed 8 packages in 11ms
2026-02-13 10:39:04 [DEBUG]: uv sync:  + certifi==2026.1.4
2026-02-13 10:39:04 [DEBUG]: uv sync:  + charset-normalizer==3.4.4
2026-02-13 10:39:04 [DEBUG]: uv sync:  + click==8.3.1
2026-02-13 10:39:04 [DEBUG]: uv sync:  + colorama==0.4.6
2026-02-13 10:39:04 [DEBUG]: uv sync:  + idna==3.11
2026-02-13 10:39:04 [DEBUG]: uv sync:  + pip==26.0.1
2026-02-13 10:39:04 [DEBUG]: uv sync:  + requests==2.32.5
2026-02-13 10:39:04 [DEBUG]: uv sync:  + urllib3==1.26.20
```

Your uv environment is activated and will use the dependencies you have specified.

If you add or remove dependencies, or change python version, the plugin will update the environment for you when you save the file.

You can work with multiple uv files in different neovim buffers and switch between them. New terminals will also use the uv environment.

NOTE: You *don't use the picker* to select a venv for uv environments. The plugin activates the venv when you open a file with metadata automatically.

## Support for lualine and nvchad statusbars

### Lualine

```lua
{
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    -- enabled = false,
    config = function()
      require("lualine").setup {
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = {
            "venv-selector", -- This is what makes lualine call the function in options.statusline_func.lualine
            "encoding",
            "fileformat",
            "filetype",
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    end,
    dependencies = { "nvim-tree/nvim-web-devicons" },
  }
  
```
### Nvchad

Edit your `~/.config/nvim/lua/chadrc.lua` file like this:

```lua
M.ui = {
  statusline = {
    modules = {
      venv = require("venv-selector.statusline.nvchad").render -- this is what makes nvchad call the function in options.statusline.nvchad
    },
    order = { "mode", "file", "git", "%=", "lsp_msg", "diagnostics", "venv", "lsp", "cwd" } -- "venv" is the location of output from the function it calls
  }
}
```
