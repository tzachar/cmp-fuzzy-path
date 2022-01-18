local cmp = require('cmp')
local matcher = require('fuzzy_nvim')
local fn = vim.fn

local source = {}

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

source.get_trigger_characters = function()
  return { '.', '/', '~' }
end

source.get_keyword_pattern = function(_, params)
  if vim.api.nvim_get_mode().mode == 'c' then
    return [[\S\+]]
  else
    return [[[.~/]\+\S\+]]
  end
end

local PATH_PREFIX_REGEX = vim.regex([[\~\?[./]\+]])
-- return new_pattern, cwd, prefix
local function find_cwd(pattern)
  local s, e = PATH_PREFIX_REGEX:match_str(pattern)
  if s == nil then
    return pattern, vim.fn.getcwd(), ''
  else
    local prefix = pattern:sub(s, e)
    if prefix:byte(#prefix) ~= string.byte('/') then
      prefix = prefix .. '/'
    end
    return pattern:sub(e + 1), vim.fn.resolve(vim.fn.expand(prefix)), prefix
  end
end

source.stat = function(_, path)
  local stat = vim.loop.fs_stat(path)
  if stat then
    return stat
  end
  return nil
end

source.complete = function(self, params, callback)
  params.option = vim.tbl_deep_extend('keep', params.option, defaults)
  local is_cmd = (vim.api.nvim_get_mode().mode == 'c')
  if is_cmd then
    if params.option.allowed_cmd_context[params.context.cursor_line:byte(1)] == nil then
      callback()
      return
    elseif params.context.cursor_line:find('%s') == nil then
      -- we should have a space between, e.g., `edit` and a path
      callback({ items = {}, isIncomplete = true })
      return
    end
  end
  local pattern = params.context.cursor_before_line:sub(params.offset)
  if #pattern == 0 then
    callback({ items = {}, isIncomplete = true })
    return
  end

  local new_pattern, cwd, prefix = find_cwd(pattern)
  -- check if cwd is valid
  if not self:stat(cwd) then
    return callback()
  end

  if #new_pattern == 0 then
    callback({ items = {}, isIncomplete = true })
    return
  end

  -- keep items here, as we reference it in the job's callback
  local items = {}
  local path_regex = string.gsub(new_pattern, '(.)', '%1.*')
  local cmd = { unpack(params.option.fd_cmd) }
  table.insert(cmd, path_regex)
  local job
  job = fn.jobstart(cmd, {
    stdout_buffered = false,
    cwd = cwd,
    on_stdout = function(_, lines, _)
      if #lines == 0 or (#lines == 1 and lines[1] == '') then
        vim.fn.jobstop(job)
        callback({ items = items, isIncomplete = true })
        return
      end
      for _, item in ipairs(lines) do
        if #item > 0 then
          -- first check if prefix..item matches new_pattern
          local matches = matcher:filter(new_pattern, { prefix .. item })
          if #matches > 0 then
            local score = matches[1][3]
            local stat, kind = self:kind(cwd .. '/' .. item)
            table.insert(items, {
              label = prefix .. item,
              kind = kind,
              -- data is for cmp-path
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
    return { 'binary file' }
  end
  local lines = { '```' }
  for line in first_k:gmatch('[^\r\n]+') do
    lines[#lines + 1] = line
    if count ~= nil and #lines >= count then
      break
    end
  end
  lines[#lines + 1] = '```'
  return lines
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
