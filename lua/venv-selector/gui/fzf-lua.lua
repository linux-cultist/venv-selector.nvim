local gui_utils = require("venv-selector.gui.utils")

local M = {}
M.__index = M

function M.new(search_opts)
    local self = setmetatable({ is_done = false, queue = {}, entries = {} }, M)

    local fzf_lua = require("fzf-lua")
    fzf_lua.fzf_exec(function(fzf_cb)
        self.fzf_cb = fzf_cb
        self:consume_queue()
    end, {
        prompt = "Virtual environments (ctrl-r to refresh) > ",
        winopts = {
            height = 0.4,
            width = 120,
            row = 0.5,
        },
        actions = {
            ["default"] = function(selected, _)
                if selected and #selected > 0 then
                    local result = self.entries[selected[1]]
                    gui_utils.select(result)
                end
            end,
            ["ctrl-r"] = {
                function()
                    self.is_done = false
                    self.fzf_cb = nil
                    self.queue = {}
                    self.entries = {}
                    require("venv-selector.search").run_search(self, search_opts)
                end,
                fzf_lua.actions.resume,
            },
        },
    })

    return self
end

function M:consume_queue()
    if self.fzf_cb then
        for _, result in ipairs(self.queue) do
            local hl = gui_utils.hl_active_venv(result)
            local icon = hl and require("fzf-lua").utils.ansi_from_hl(hl, result.icon) or result.icon
            local entry = gui_utils.format_result_as_string(icon, result.source, result.name)
            self.entries[entry] = result
            self.fzf_cb(entry)
        end
        self.queue = {}

        if self.is_done then
            self.fzf_cb(nil)
        end
    end
end

function M:insert_result(result)
    self.queue[#self.queue + 1] = result

    self:consume_queue()
end

function M:search_done()
    self.is_done = true
    self:consume_queue()

    -- results during the search are not deduplicated or sorted,
    -- so when the search is over, deduplicate and sort the results,
    -- then refresh fzf-lua
    local results = {}
    for _, result in pairs(self.entries) do
        results[#results + 1] = result
    end
    results = gui_utils.remove_dups(results)
    gui_utils.sort_results(results)

    -- the queued results will be consumed in fzf-lua's content function
    self.queue = results
    require("fzf-lua").actions.resume()
end

return M
