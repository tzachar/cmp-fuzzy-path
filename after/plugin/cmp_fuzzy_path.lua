local source = require('cmp_fuzzy_path').new()
require('cmp').register_source('fuzzy_path', source)

if vim.api.nvim_create_user_command ~= nil then
  vim.api.nvim_create_user_command('CmpFuzzyStats', function()
   vim.api.nvim_echo({{source:stats()}}, false, {})
  end, { force = true })
end
