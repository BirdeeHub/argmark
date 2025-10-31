---@class ArgmarkEditKeymap
---key to cycle to the next arglist (default "<leader><leader>n")
---@field cycle_right? string
---key to cycle to the previous arglist (default "<leader><leader>p")
---@field cycle_left?  string
---key to open file under cursor (default "<CR>")
---@field go?          string
---key to save and quit (default "Q")
---@field quit?        string
---key to quit without saving (default "q")
---@field exit?        string

---@class ArgmarkEditDisplay
---Argument used as the second argument to argmark.get_arglist_display_text
---Allows customization of display of edit window title.
---@field arglist_display_func? fun(id: integer, focused: boolean): string
---See :h nvim_open_win()
---@field border? string|string[]
---See :h nvim_open_win()
---@field footer? string
---See :h nvim_open_win()
---@field footer_pos? string
---See :h nvim_open_win()
---@field title_pos? string

---@class ArgmarkEditOpts
---override keybindings for the floating arglist editor
---@field keys? ArgmarkEditKeymap
---@field display? ArgmarkEditDisplay

---@class ArgmarkKeymap
---remove buffer at count/current (<leader><leader>x)
---@field rm?           string|false
---add buffer at count/current (<leader><leader>a)
---@field add?          string|false
---go to buffer at count (<leader><leader><leader>)
---@field go?           string|false
---open floating editor (<leader><leader>e)
---@field edit?         string|false
---clear arglist (<leader><leader>X)
---@field clear?        string|false
---add all window buffers (<leader><leader>A)
---@field add_windows?  string|false
---copy arglist by id (default global) into new local arglist (<leader><leader>c)
---@field copy?  string|false

---@class ArgmarkOpts
---normal-mode mappings
---@field keys? ArgmarkKeymap
---passed to M.edit
---@field edit_opts? ArgmarkEditOpts

---@class Argmark
---@field get_display_text fun(tar_win_id?: integer, format_name?: (fun(name: string, focused: boolean, idx: integer): string), format_list_id?: (fun(id: integer): string)): string
---@field get_arglist_display_text fun(tar_win_id?: integer, format_list_id?: (fun(id: integer, focused: boolean): string)): string
---@field add fun(num_or_name_s?: integer|string|string[], tar_win_id?: integer)
---@field go fun(num?: integer, tar_win_id?: integer)
---@field copy fun(arglist_id?: integer, tar_win_id?: integer)
---@field rm fun(num_or_name?: integer|string|string[], num?: integer, tar_win_id?: integer)
---@field add_windows fun(tar_win_id?: integer)
---@field edit fun(opts?: ArgmarkEditOpts, tar_win_id?: integer)
---@field setup fun(opts?: ArgmarkOpts)

local M = {}

do
  local function default_format_name(name, focused, idx)
    name = vim.fn.fnamemodify(name, ":t")
    if name == "" then name = vim.fn.fnamemodify(name .. ".", ":h:t") end
    if name == "" then name = "~No~Name~" end
    if focused then name = "["..name.."]" end
    return name
  end
  local function default_format_id(id)
    return id == 0 and "" or "L"..id..":"
  end
  ---@param tar_win_id? number
  ---@param format_name? fun(name: string, focused: boolean, idx: integer): string
  ---@param format_list_id? fun(id: integer): string
  ---@return string
  function M.get_display_text(tar_win_id, format_name, format_list_id)
    if type(format_name) ~= "function" then format_name = default_format_name end
    if type(format_list_id) ~= "function" then format_list_id = default_format_id end
    local curwin = vim.api.nvim_get_current_win()
    local lid = type(tar_win_id) ~= "number" and vim.fn.arglistid(curwin) or tar_win_id >= 0 and vim.fn.arglistid(tar_win_id) or 0
    tar_win_id = type(tar_win_id) == "number" and tar_win_id or curwin
    local needs_force_global = tar_win_id < 0 and vim.fn.arglistid(curwin) ~= 0
    local arglist = vim.fn.argv(-1, tar_win_id < 0 and -1 or tar_win_id)
    if tar_win_id < 0 then tar_win_id = curwin end

    local res = format_list_id(lid)
    if type(res) ~= "string" then
      error("parameter 3 of argmark.get_display_text: format_list_id?: (fun(id: integer): string) must return a string!")
    end

    local focused_idx = vim.api.nvim_win_call(tar_win_id, function()
      if needs_force_global then vim.cmd.argglobal() end
      local idx = vim.fn.argidx() + 1
      if needs_force_global then vim.cmd.arglocal() end
      return idx
    end)

    for i = 1, #arglist do
      local name = format_name(arglist[i], focused_idx == i, i)
      if type(name) ~= "string" then
        error("parameter 2 of argmark.get_display_text: format_name?: (fun(name: string, focused: boolean, idx: integer): string) must return a string!")
      end
      res = res .. " " .. name
    end
    return res
  end
end

do
  local function default_format_id(id, focused)
    if id == 0 then
      if focused then
        return "[Global]"
      else
        return "Global"
      end
    elseif focused then
      return "[L:" .. id .. "]"
    else
      return "L:" .. id
    end
  end
  ---@param tar_win_id? number
  ---@param format_list_id? fun(id: integer, focused: boolean): string
  ---@return string
  function M.get_arglist_display_text(tar_win_id, format_list_id)
    if type(format_list_id) ~= "function" then format_list_id = default_format_id end
    tar_win_id = type(tar_win_id) == "number" and tar_win_id or vim.api.nvim_get_current_win()
    local temp = {}
    local focused_idx = tar_win_id < 0 and 0 or vim.fn.arglistid(tar_win_id)
    local titlelist = { format_list_id(0, focused_idx == 0) }
    if type(titlelist[1]) ~= "string" then
      error("parameter 2 of argmark.get_arglist_display_text: format_list_id?: (fun(id: integer, focused: boolean): string) must return a string!")
    end
    local wins = vim.api.nvim_list_wins()
    for i = 1, #wins do
      local c = wins[i]
      local lid = vim.fn.arglistid(c)
      if lid ~= 0 and not temp[lid] then
        local newstr = format_list_id(lid, focused_idx == lid)
        if type(newstr) ~= "string" then
          error("parameter 2 of argmark.get_arglist_display_text: format_list_id?: (fun(id: integer, focused: boolean): string) must return a string!")
        end
        temp[lid] = newstr
      end
    end
    local lids = {}
    for lid, _ in pairs(temp) do
        table.insert(lids, lid)
    end
    table.sort(lids)
    for _, lid in ipairs(lids) do
      table.insert(titlelist, temp[lid])
    end
    return table.concat(titlelist, " ")
  end
end

---@param num_or_name_s? number|string|string[]
---@param tar_win_id? number
function M.add(num_or_name_s, tar_win_id)
  tar_win_id = type(tar_win_id) == "number" and tar_win_id or vim.api.nvim_get_current_win()
  local arglen = vim.fn.argc(tar_win_id)
  local argtype = type(num_or_name_s)
  local to_add = {}
  if argtype == "number" and num_or_name_s > 0 and arglen >= num_or_name_s then
    to_add[1] = vim.fn.bufname(num_or_name_s)
    if to_add[1] == "" then to_add[1] = "%" end
  elseif argtype == "table" then
    to_add = num_or_name_s
  elseif argtype ~= "string" then
    to_add[1] = "%"
  end
  vim.api.nvim_win_call(tar_win_id < 0 and vim.api.nvim_get_current_win() or tar_win_id, function()
    local needs_force_global = tar_win_id < 0 and vim.fn.arglistid() ~= 0
    if needs_force_global then vim.cmd.argglobal() end
    vim.cmd.argadd {
      args = to_add,
      range = { arglen, arglen },
    }
    vim.cmd.argdedupe()
    if needs_force_global then vim.cmd.arglocal() end
  end)
end

---@param num? number
---@param tar_win_id? number
function M.go(num, tar_win_id)
  tar_win_id = type(tar_win_id) == "number" and tar_win_id or vim.api.nvim_get_current_win()
  local needs_force_global = tar_win_id < 0 and vim.fn.arglistid() ~= 0
  local arglen = vim.fn.argc(tar_win_id)
  if num > 0 and arglen >= num then
    vim.api.nvim_win_call(tar_win_id < 0 and vim.api.nvim_get_current_win() or tar_win_id, function()
      if needs_force_global then vim.cmd.argglobal() end
      vim.cmd.argument(num)
      if needs_force_global then vim.cmd.arglocal() end
    end)
  elseif arglen > 0 then
    vim.api.nvim_win_call(tar_win_id < 0 and vim.api.nvim_get_current_win() or tar_win_id, function()
      if needs_force_global then vim.cmd.argglobal() end
      vim.cmd.argument(vim.fn.argidx() + 1)
      if needs_force_global then vim.cmd.arglocal() end
    end)
  else
    error("No args to go to!")
  end
end

---@param num_or_name? number|string|string[]
---@param num? number
---@param tar_win_id? number
function M.rm(num_or_name, num, tar_win_id)
  tar_win_id = type(tar_win_id) == "number" and tar_win_id or vim.api.nvim_get_current_win()
  local atype = type(num_or_name)
  local arglen = vim.fn.argc(tar_win_id)
  vim.api.nvim_win_call(tar_win_id < 0 and vim.api.nvim_get_current_win() or tar_win_id, function()
    local needs_force_global = tar_win_id < 0 and vim.fn.arglistid() ~= 0
    if needs_force_global then vim.cmd.argglobal() end
    if atype == "number" and num_or_name > 0 and arglen >= num_or_name then
      if type(num) == "number" and num > 0 and arglen >= num then
        vim.cmd.argdelete { range = { num_or_name, num } }
      else
        vim.cmd.argdelete { range = { num_or_name, num_or_name } }
      end
    elseif atype == "string" then
      vim.cmd.argdelete(num_or_name)
    elseif atype == "table" then
      vim.cmd.argdelete { args = num_or_name }
    else
      vim.cmd.argdelete "%"
    end
    if needs_force_global then vim.cmd.arglocal() end
  end)
end

do
  local function get_arglist(arglist_id)
    if arglist_id == 0 then
      return vim.fn.argv(-1, -1)
    else
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.fn.arglistid(w) == arglist_id then
          return vim.fn.argv(-1, w)
        end
      end
      return {}
    end
  end
  ---@param arglist_id number
  ---@param tar_win_id? number
  function M.copy(arglist_id, tar_win_id)
    tar_win_id = type(tar_win_id) == "number" and tar_win_id or vim.api.nvim_get_current_win()
    if type(arglist_id) ~= "number" or arglist_id < 0 then
      arglist_id = 0
    end
    local needs_force_global = tar_win_id < 0 and vim.fn.arglistid() ~= 0
    vim.api.nvim_win_call(needs_force_global and vim.api.nvim_get_current_win() or tar_win_id, function()
      if needs_force_global then vim.cmd.argglobal() -- if not setting into global list,
      else vim.cmd.arglocal() end  -- make a window-local list
      vim.cmd.argdelete "*"
      vim.cmd.argadd({ args = get_arglist(arglist_id) })
      if needs_force_global then vim.cmd.arglocal() end
    end)
  end
end

---@param tar_win_id? number
function M.add_windows(tar_win_id)
  tar_win_id = (type(tar_win_id) == "number" and tar_win_id >= 0) and tar_win_id or vim.api.nvim_get_current_win()
  vim.api.nvim_win_call(tar_win_id or vim.api.nvim_get_current_win(), function()
    local needs_force_global = tar_win_id < 0 and vim.fn.arglistid() ~= 0
    if needs_force_global then vim.cmd.argglobal() end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      vim.cmd.argadd(vim.fn.bufname(vim.api.nvim_win_get_buf(win)))
    end
    vim.cmd.argdedupe()
    if needs_force_global then vim.cmd.arglocal() end
  end)
end

do
  ---@param bufnr number
  ---@param winid? number
  ---@param tar_win_id? number
  ---@param title? string
  ---@param opts ArgmarkEditDisplay
  ---@return number bufnr
  ---@return number winid
  local function setup_window(bufnr, winid, tar_win_id, title, opts)
    tar_win_id = (type(tar_win_id) == "number") and tar_win_id or vim.api.nvim_get_current_win()
    local rel_height, rel_width = 0.7, 0.7
    local rows, cols = vim.opt.lines._value, vim.opt.columns._value
    local lid = tar_win_id >= 0 and vim.fn.arglistid(tar_win_id) or 0
    local filetype = "ArglistEditor"
    vim.api.nvim_buf_set_name(bufnr, "ArglistEditor")
    vim.api.nvim_set_option_value("filetype", filetype, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
    local height = math.min(vim.fn.argc(lid == 0 and -1 or tar_win_id) + 3, math.ceil(rows * rel_height))
    local winconfig = {
      relative = "editor",
      height = height,
      width = math.ceil(cols * rel_width),
      row = math.ceil(rows / 2 - height / 2),
      col = math.ceil(cols / 2 - cols * rel_width / 2),
      border = opts.border or "single",
      style = "minimal",
      footer = opts.footer or "Arglist Editor",
      footer_pos = opts.footer_pos or "center",
      title_pos = opts.title_pos or "center",
      title = title or "",
    }
    if type(winid) == "number" and vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_set_config(winid, winconfig)
    else
      winid = vim.api.nvim_open_win(bufnr, true, winconfig)
    end
    -- argv(-1) is always a list
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.argv(-1, lid == 0 and -1 or tar_win_id))
    return bufnr, winid
  end

  ---@param bufnr number
  ---@param tar_win_id? number
  local function overwrite_argslist(bufnr, tar_win_id)
    tar_win_id = type(tar_win_id) == "number" and tar_win_id or vim.api.nvim_get_current_win()
    vim.api.nvim_win_call(tar_win_id >= 0 and tar_win_id or vim.api.nvim_get_current_win(), function()
      local to_write = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true) or {}
      for i = #to_write, 1, -1 do
        if to_write[i]:match("^%s*$") then
          table.remove(to_write, i)
        end
      end
      local needs_force_global = tar_win_id < 0 and vim.fn.arglistid() ~= 0
      if needs_force_global then vim.cmd.argglobal() end
      pcall(vim.cmd.argdelete, "*")
      if #to_write > 0 then
        local ok, err = pcall(vim.cmd.argadd, { args = to_write })
        if not ok then vim.notify(err, vim.log.levels.ERROR) end
        vim.cmd.argdedupe()
      end
      if needs_force_global then vim.cmd.arglocal() end
    end)
  end

  local function get_arglist_list()
    local result = {}
    local temp = {}
    local wins = vim.api.nvim_list_wins()
    for i = 1, #wins do
      local c = wins[i]
      local lid = vim.fn.arglistid(c)
      temp[lid] = temp[lid] or { id = lid, wins = {} }
      table.insert(temp[lid].wins, c)
    end
    local lids = {}
    for lid, _ in pairs(temp) do
      table.insert(lids, lid)
    end
    table.sort(lids)
    for i = 1, #lids do
      table.insert(result, temp[lids[i]])
    end
    if result[1].id ~= 0 then
      table.insert(result, 1, { id = 0, wins = { -1 } })
    end
    return result
  end

  ---@param opts? ArgmarkEditOpts
  ---@param tar_win_id? number
  function M.edit(opts, tar_win_id)
    opts = opts or {}
    local keys = opts.keys or {}
    local display_opts = opts.display or {}
    local argseditor, winid = setup_window(vim.api.nvim_create_buf(false, true), nil, tar_win_id, M.get_arglist_display_text(tar_win_id, display_opts.arglist_display_func), display_opts)
    local arglist_list = get_arglist_list()

    vim.keymap.set("n", keys.cycle_right or "<leader><leader>n", function()
      local lid = (type(tar_win_id) == "number" and tar_win_id >= 0) and vim.fn.arglistid(tar_win_id) or 0
      local found = nil
      for i = 1, #arglist_list do
        if arglist_list[i].id == lid then
          found = i
        end
      end
      if found == nil then
        tar_win_id = arglist_list[#arglist_list > 1 and 2 or 1].wins[1]
      elseif found >= #arglist_list then
        tar_win_id = arglist_list[1].wins[1]
      else
        tar_win_id = arglist_list[found + 1].wins[1]
      end
      setup_window(argseditor, winid, tar_win_id, M.get_arglist_display_text(tar_win_id, display_opts.arglist_display_func), display_opts)
    end, {
      buffer = argseditor,
      desc = "Cycle right through arglist choices",
    })
    vim.keymap.set("n", keys.cycle_left or "<leader><leader>p", function()
      local lid = (type(tar_win_id) == "number" and tar_win_id >= 0) and vim.fn.arglistid(tar_win_id) or 0
      local found = nil
      for i = #arglist_list, 1, -1 do
        if arglist_list[i].id == lid then
          found = i
        end
      end
      if found == nil then
        tar_win_id = arglist_list[#arglist_list].wins[1]
      elseif found <= 1 then
        tar_win_id = arglist_list[#arglist_list].wins[1]
      else
        tar_win_id = arglist_list[found - 1].wins[1]
      end
      setup_window(argseditor, winid, tar_win_id, M.get_arglist_display_text(tar_win_id, display_opts.arglist_display_func), display_opts)
    end, {
      buffer = argseditor,
      desc = "Cycle left through arglist choices",
    })

    vim.keymap.set("n", keys.go or "<CR>", function()
      local f = vim.fn.getline(".")
      vim.api.nvim_win_close(winid, true)
      vim.cmd.edit(f)
    end, {
      buffer = argseditor,
      desc = "Go to file under cursor",
    })
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer = argseditor,
      callback = function() overwrite_argslist(argseditor, tar_win_id) end,
    })
    vim.keymap.set("n", keys.quit or "Q", function()
      overwrite_argslist(argseditor, tar_win_id)
      pcall(vim.api.nvim_win_close, winid, true)
    end, {
      buffer = argseditor,
      desc = "Update arglist and exit",
    })
    vim.api.nvim_create_autocmd({ "WinLeave", "BufWinLeave", "BufLeave" } ,{
      buffer = argseditor,
      callback = function()
        pcall(vim.api.nvim_win_close, winid, true)
      end
    })
    vim.keymap.set("n", keys.exit or "q", function()
      pcall(vim.api.nvim_win_close, winid, true)
    end, {
      buffer = argseditor,
      desc = "Exit without updating arglist",
    })
  end
end

---@param opts? ArgmarkOpts
function M.setup(opts)
  opts = opts or {}
  local keys = opts.keys or {}
  if keys.rm ~= false then
    vim.keymap.set("n", keys.rm or "<leader><leader>x", function()
      local ok, err = pcall(M.rm, vim.v.count)
      if not ok then vim.notify(err or "Failed to remove buffer", vim.log.levels.WARN) end
    end, { silent = true, desc = "Remove buffer at count (or current) from arglist"})
  end
  if keys.add ~= false then
    vim.keymap.set("n", keys.add or "<leader><leader>a", function()
      local ok, err = pcall(M.add, vim.v.count)
      if not ok then vim.notify(err or "Failed to add buffer", vim.log.levels.ERROR) end
    end, { silent = true, desc = "Add buffer (count or current) to arglist" })
  end
  if keys.go ~= false then
    vim.keymap.set("n", keys.go or "<leader><leader><leader>", function()
      local ok, err = pcall(M.go, vim.v.count)
      if not ok then vim.notify(err or "Failed to go to buffer", vim.log.levels.WARN) end
    end, { silent = true, desc = "Go to buffer at count in arglist" })
  end
  if keys.copy ~= false then
    vim.keymap.set("n", keys.copy or "<leader><leader>c", function()
      local ok, err = pcall(M.copy, vim.v.count)
      if not ok then vim.notify(err or "Failed to copy target arglist into local arglist", vim.log.levels.ERROR) end
    end, { silent = true, desc = "Copy (count or global) arglist to current (or new) local arglist"})
  end
  if keys.edit ~= false then
    vim.keymap.set("n", keys.edit or "<leader><leader>e", function()
      M.edit(opts.edit_opts)
    end, { silent = true, desc = "edit arglist in floating window"})
  end
  if keys.clear ~= false then
    vim.keymap.set("n", keys.clear or "<leader><leader>X", function()
      local ok, err = pcall(M.rm, "*")
      if not ok then vim.notify(err or "Failed to clear arglist", vim.log.levels.WARN) end
    end, { desc = "Clear arglist" })
  end
  if keys.add_windows ~= false then
    vim.keymap.set("n", keys.add_windows or "<leader><leader>A", M.add_windows, { desc = "Add current buffers for all windows to arglist" })
  end
end

---@type Argmark
return M
