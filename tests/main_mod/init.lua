local pipe = require('main_mod.middleware')

local function test()
  local module = require('main_mod.module_route')
  local res, _ = pcall(module, 'Hello!!!')
  return res
end

return pipe(test)
