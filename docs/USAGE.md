# 🧰 Usage — venv-selector.nvim

## ⚙️ Configuration structure

Top-level plugin configuration has two primary tables:

- `options` — global behavior & callbacks (picker choice, misc flags, integrations)
- `search` — your own custom searches if venvs are not found automatically

Refer to `docs/OPTIONS.md` for the complete reference.

---

## 🔎 Creating your own searches

- Start in the terminal and create your fd command.
- Prefer narrow, explicit commands that target known locations.
- Only search hidden files/directories (like `$HOME/Code`) in a specific location, not your home directory.
- Template variables available in command:
  - `$CWD` — current working directory
  - `$WORKSPACE_PATH` — workspace root
  - `$FILE_DIR` — directory of current file
  - `$CURRENT_FILE` — currently open file


### 🧪 Search examples

When creating a new search, make sure it gives the expected results in your terminal first.

<details>
<summary>🐧 Linux and macOS — fd in terminal</summary>


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
<summary>🪟 Windows — fd in terminal</summary>


Here we search for all pythons under the home directory. We want to match on all paths ending in `Scripts\\python.exe` since those are the venvs on Windows.

```
tameb@WIN11 C:\Users\tameb>fd Scripts\\python.exe$ %USERPROFILE%\Code --full-path -I -a  
C:\Users\tameb\Code\another_project\venv\Scripts\python.exe
C:\Users\tameb\Code\manual\venv\Scripts\python.exe
C:\Users\tameb\Code\sample_project\venv\Scripts\python.exe
```

</details>

### ➕ Adding the fd search to VenvSelect config

The docs are split into two different sections.

<details>
<summary>🐧 Linux and macOS config example</summary>

You can use relative paths here to specify search location, but make sure to use `--full-path` so `fd` always gives you back an absolute path to the results.

```lua
search = {
  my_project_venvs = {
    command = "fd '/bin/python$' ~/Code --full-path --color never",
  }
}
```

If it's a search for a conda-type environment, set the type to `\"anaconda\"` so the plugin sets the environment variable `CONDA_PREFIX` and not `VIRTUAL_ENV`:

```lua
search = {
  my_conda_base = {
    command = "fd '/bin/python$' /opt/anaconda3 --full-path --color never -E pkgs", -- exclude path with pkgs
    type = "anaconda" -- it's anaconda-style environment (also for miniconda)
  }
}
```

Have a look at [config.lua](../lua/venv-selector/config.lua) to see the built-in searches and how they look.
</details>

<details>
<summary>🪟 Windows config example</summary>

VenvSelect doesn't understand Windows shell variables like `%USERPROFILE%`, but you can use `$HOME`. Its also important to escape backslashes on windows, see below.

NOTE:
- You *have to* escape each backslash in the regexp with another backslash. So 'Scripts\\python.exe` from the fd example becomes `Scripts\\\\python.exe` in the plugin config.
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

When you open a python file with this metadata, you will see this in the `VenvSelectLog` (if `log_level` is set to `TRACE` or `DEBUG`):

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

Your uv environment is activated and will use the dependencies you have specified. If you add or remove dependencies, or change python version, the plugin will again update the active uv environment for you.

NOTE: You *don't use the picker* to select a venv for uv environments. The plugin activates the venv when you open a file with metadata automatically.