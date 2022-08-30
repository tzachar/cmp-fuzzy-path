local cmp = require('cmp')
local matcher = require('fuzzy_nvim')
local fn = vim.fn

local source = {
  timing_info = {},
  timeout_count = 0,
  usage_count = 0,
}

local defaults = {
  fd_cmd = { 'fd', '-d', '20', '-p', '-i' },
  allowed_cmd_context = {
    [string.byte('e')] = true,
    [string.byte('w')] = true,
    [string.byte('r')] = true,
  },
  fd_timeout_msec = 500,
}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.stats = function(self)
  local avg_time = 0
  for _, t in ipairs(self.timing_info) do
    avg_time = avg_time + t
  end
  return string.format([[
Total Usage Count   : %d
Timeout Count       : %d
Average Search Time : %f
  ]], self.usage_count, self.timeout_count, avg_time / #self.timing_info)
end

source.get_trigger_characters = function()
  return { '.', '/', '~' }
end

local PATH_REGEX = ([[\%(\k\?[/:\~]\+\|\.\?\.\/\)\S\+]])
local COMPILED_PATH_REGEX = vim.regex(PATH_REGEX)

source.get_keyword_pattern = function(_, params)
  if vim.api.nvim_get_mode().mode == 'c' then
    return [[\S\+]]
  else
    return PATH_REGEX
  end
end

-- return new_pattern, cwd, prefix
local function find_cwd(pattern)
  local dname = string.gsub(pattern, "(.*[/\\])(.*)", "%1")
  local basename = string.gsub(pattern, "(.*[/\\])(.*)", "%2")
  -- dump({pattern = pattern, dname = dname, basename = basename})

  if dname == nil or #dname == 0 or basename == dname then
    return pattern, vim.fn.getcwd(), ''
  else
    if dname:byte(#dname) ~= string.byte('/') then
      dname = dname .. '/'
    end
    local cwd = vim.fn.resolve(vim.fn.expand(dname))
    cwd = cwd:gsub('/+', '/'):gsub('\\+', '\\')
    return basename, cwd, dname
  end
end

source.stat = function(_, path)
  local stat = vim.loop.fs_stat(path)
  if stat and stat.type then
    return stat
  end
  return nil
end

source.complete = function(self, params, callback)
  params.option = vim.tbl_deep_extend('keep', params.option, defaults)
  local is_cmd = (vim.api.nvim_get_mode().mode == 'c')
  local pattern = nil
  if is_cmd then
    if params.option.allowed_cmd_context[params.context.cursor_line:byte(1)] == nil then
      callback()
      return
    elseif params.context.cursor_line:find('%s') == nil then
      -- we should have a space between, e.g., `edit` and a path
      callback({ items = {}, isIncomplete = true })
      return
    end
    pattern = params.context.cursor_before_line:sub(params.offset)
  else
    local match_start, match_end = COMPILED_PATH_REGEX:match_str(params.context.cursor_before_line)
    if not match_start then
      callback({ items = {}, isIncomplete = true })
      return
    end
    pattern = params.context.cursor_before_line:sub(match_start + 1, match_end + 1)
  end

  local new_pattern, cwd, prefix = find_cwd(pattern)
  -- check if cwd is valid
  local stat = self:stat(cwd)
  if (stat == nil or stat.type == nil or stat.type ~= 'directory') then
    callback({ items = {}, isIncomplete = true })
    return
  end

  -- keep items here, as we reference it in the job's callback
  local items = {}
  local cmd = { unpack(params.option.fd_cmd) }
  if #new_pattern > 0 then
    local path_regex = string.gsub(new_pattern, '(.)', '%1.*')
    table.insert(cmd, path_regex)
  end
  local job
  local job_start = vim.fn.reltime()
  job = fn.jobstart(cmd, {
    stdout_buffered = false,
    cwd = cwd,
    on_exit = function(_, _, _)
      callback({ items = items, isIncomplete = true })
      local time_since_start = vim.fn.reltimefloat(vim.fn.reltime(job_start)) * 1000
      table.insert(self.timing_info, time_since_start)
      if time_since_start >= params.option.fd_timeout_msec then
        self.timeout_count = self.timeout_count + 1
      end
    end,
    on_stdout = function(_, lines, _)
      if #lines == 0 or (#lines == 1 and lines[1] == '') then
        vim.fn.jobstop(job)
        return
      end
      for _, item in ipairs(lines) do
        -- remove './' from beginning of line
        item = item:gsub([[^%./]], '')
        if #item > 0 then
          -- if new_pattern is empty, we will get no matches
          local score = nil
          if #new_pattern == 0 then
            score = 10
          else
            local matches = matcher:filter(new_pattern, { prefix .. item })
            if #(matches or {}) > 0 then
              score = matches[1][3]
            end
          end
          if score ~= nil then
            local stat, kind = self:kind(cwd .. '/' .. item)
            table.insert(items, {
              label = prefix .. item,
              kind = kind,
              -- data is for the compare function
              data = { path = cwd .. '/' .. item, stat = stat, score = score },
              -- hack cmp to not filter our fuzzy matches. If we do not use
              -- this, the user has to input the first character of the match
              filterText = string.sub(params.context.cursor_before_line, params.offset),
            })
          end
        end
      end
    end,
  })

  self.usage_count = self.usage_count + 1
  vim.fn.timer_start(params.option.fd_timeout_msec, function()
    vim.fn.jobstop(job)
  end)
end

source.kind = function(self, path)
  local stat = self:stat(path)
  local type = (stat and stat.type) or 'unknown'
  if type == 'directory' then
    return stat, cmp.lsp.CompletionItemKind.Folder
  elseif type == 'file' then
    return stat, cmp.lsp.CompletionItemKind.File
  else
    return nil, nil
  end
end

local function lines_from(file, count)
  local bfile = assert(io.open(file, 'rb'))
  local first_k = bfile:read(1024)
  if first_k:find('\0') then
    return { kind = cmp.lsp.MarkupKind.PlainText, value = 'binary file' }
  end
  local lines = { '```' .. (vim.filetype.match { filename = file } or '') }
  for line in first_k:gmatch('[^\r\n]+') do
    lines[#lines + 1] = line
    if count ~= nil and #lines >= count then
      break
    end
  end
  lines[#lines + 1] = '```'
  return { kind = cmp.lsp.MarkupKind.Markdown, value = table.concat(lines, '\n') }
end

source.resolve = function(self, completion_item, callback)
  local data = completion_item.data
  if data.stat and data.stat.type == 'file' then
    local ok, preview_lines = pcall(lines_from, data.path, defaults.max_lines)
    if ok then
      completion_item.documentation = preview_lines
    end
  end
  callback(completion_item)
end

return source
