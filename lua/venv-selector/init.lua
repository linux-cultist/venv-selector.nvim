--
--function M.printTable(tbl)
--    for _, part in ipairs(tbl) do
--        print(part)
--    end
--end
--
--function M.splitArgs(args)
--    local t = {}
--    local text = args
--    local spat, epat, buf, quoted = [=[^(['"])]=], [=[(['"])$]=]
--    for str in text:gmatch '%S+' do
--        local squoted = str:match(spat)
--        local equoted = str:match(epat)
--        local escaped = str:match [=[(\*)['"]$]=]
--        if squoted and not quoted and not equoted then
--            buf, quoted = str, squoted
--        elseif buf and equoted == quoted and #escaped % 2 == 0 then
--            str, buf, quoted = buf .. ' ' .. str, nil, nil
--        elseif buf then
--            buf = buf .. ' ' .. str
--        end
--        if not buf then
--            table.insert(t, (str:gsub(spat, ''):gsub(epat, '')))
--        end
--    end
--    if buf then
--        print('Missing matching quote for ' .. buf)
--    end
--
--    return t
--end
--
--function M.filter(results)
--    local filtered = {}
--    for line in results:gmatch '[^\r\n]+' do
--        table.insert(filtered, line)
--    end
--
--    return filtered
--end
--
--function M.search(path)
--    local command = string.format('fd -HItd -E /proc --color never --absolute-path .venv$', path)
--    local result = vim.fn.system(command)
--    print(result)
--    return result
--end
--
--function M.executeSearch(opts, settings)
--    settings.default_path = '/home/cado/Code/Blocket'
--    settings.search_func = M.search -- Let user specify his own search func
--    settings.filter_func = M.filter -- Let user specify his own filter func
--
--    local args = M.splitArgs(opts.args)
--    local path = args[1] or settings.default_path
--    local result = settings.search_func(path)
--    local filtered_result = settings.filter_func(result)
--    M.printTable(filtered_result)
--end

local search = require 'venv-selector.search'

local M = {}

M.callback = function(filename)
    -- return nil or "" to not include it in search results. Alter the filename how you want before returning.
    return filename:gsub("/bin/python", "")
end

M.workspace_callback = function(filename)
    -- return nil or "" to not include it in search results. Alter the filename how you want before returning.
    return filename:gsub("/bin/python", "")
end

M.user_settings = {
    workspace = {
        command = "fd 'venv/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc -I",
        callback = M.workspace_callback
    },
    search = {
        {
            name = "My venvs",
            command = "fd '/venv/bin/python$' ~/Code --full-path --color never -E /proc",
            callback = M.callback
        },
        {
            name = "Virtualenvs",
            command = "fd 'python$' ~/.virtualenvs --color never -E /proc"
        },
        {
            name = "Hatch",
            command = "fd 'python$' ~/.local/share/hatch --color never -E /proc"
        },
        {
            name = "Pypoetry",
            command = "fd 'versions/([0-9.]+)/bin/python$' ~/.pyenv/versions --full-path --color never -E /proc",
        },
        {
            name = "Anaconda Envs",
            command = "fd 'bin/python$' ~/.conda/envs --full-path --color never -E /proc"
        },
        {
            name = "Anaconda Base",
            command = "fd '/python$' /opt/anaconda/bin --full-path --color never -E /proc",
        },
    }
}

function M.setup(settings)
    vim.api.nvim_create_user_command('VenvSelect', function(opts)
        search.New(opts, M.user_settings)
    end, { nargs = '*', desc = 'Activate venv' })
end
return M

