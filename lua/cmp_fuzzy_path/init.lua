local cmp = require'cmp'
local cmp_path = require'cmp_path'
local fn = vim.fn
local matcher = require('fuzzy_nvim')

local source = vim.deepcopy(cmp_path)

local defaults = {
	fd_cmd = {'fd', '-d', '20'},
	allowed_cmd_context = {
		[string.byte('e')] = true,
		[string.byte('w')] = true,
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
	if (vim.api.nvim_get_mode().mode == 'c') then
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
		return pattern:sub(e+1), vim.fn.resolve(vim.fn.expand(prefix)), prefix
	end
end


source.complete = function(self, params, callback)
	params.option = vim.tbl_deep_extend('keep', params.option, defaults)
	local is_cmd = (vim.api.nvim_get_mode().mode == 'c')
	if is_cmd and params.option.allowed_cmd_context[params.context.cursor_before_line:byte(1)] == nil then
		callback()
		return
	end
	local pattern = params.context.cursor_before_line:sub(params.offset)
	if #pattern == 0 then
		callback()
		return
	end

	local new_pattern, cwd, prefix = find_cwd(pattern)
	-- check if cwd is valid
  if not self:_stat(cwd) then
    return callback()
  end
	-- dump(pattern, 'cd to:', cwd, 'look for:', new_pattern, 'prefix:', prefix)
	local job = fn.jobstart(
		params.option.fd_cmd,
		{
			stdout_buffered=true,
			cwd=cwd,
			on_stdout=function(_, lines, _)
				self:process_fd_results(new_pattern, lines, cwd, prefix, callback)
			end,
		}
	)

	vim.fn.timer_start(params.option.fd_timeout_msec, function()
		vim.fn.jobstop(job)
	end)
end

source.process_fd_results = function(self, pattern, lines, cwd, prefix, callback)
	local matches = matcher:filter(pattern, lines)
	-- local is_cmd = (vim.api.nvim_get_mode().mode == 'c')
	local items = {}
	for _, result in ipairs(matches) do
		local item = result[1]
		table.insert(
			items,
			{
				label = prefix .. item,
				kind = self:kind(cwd .. '/' .. item),
				-- data is for cmp-path
				data = {path = cwd .. '/' .. item},
			})
	end
	-- dump(#items)
	callback({
		items = items,
		isIncomplete = true,
	})
end


source.kind = function(self, path)
	local stat = self:_stat(path)
	local type = (stat and stat.type) or 'unknown'
	if type == 'directory' then
			return cmp.lsp.CompletionItemKind.Folder
	elseif type == 'file' then
			return cmp.lsp.CompletionItemKind.File
	else
		return nil
	end
end

return source
