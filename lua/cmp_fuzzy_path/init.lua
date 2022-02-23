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
    return basename, vim.fn.resolve(vim.fn.expand(dname)), dname
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

  -- dump({cwd = cwd, prefix = prefix, new_pattern = new_pattern, pattern = pattern})

  -- check if cwd is valid
  if self:stat(cwd) == nil then
    callback({ items = {}, isIncomplete = true })
    return
  end

  -- keep items here, as we reference it in the job's callback
  local items = {}
  local path_regex = '.*'
  if #new_pattern > 0 then
    path_regex = string.gsub(new_pattern, '(.)', '%1.*')
  end
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
          -- if new_pattern is empty, we will get no matches
          local score = nil
          if #new_pattern == 0 then
            score = 10
          else
            local matches = matcher:filter(new_pattern, { prefix .. item })
            if #matches > 0 then
              score = matches[1][3]
            end
          end
          if score ~= nil then
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
            -- dump(item, string.sub(params.context.cursor_before_line, params.offset))
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
