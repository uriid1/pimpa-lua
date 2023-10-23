---
-- Pimp Module
-- @module p
local pp = require 'pimp.pretty-print'
local type_constructor = require 'pimp.type_constructor'
local color = require 'pimp.color'
local tocolor = color.tocolor

local pimp = {
  prefix = nil,
  module_name = 'p',
  output = true,
  full_path = true,
}

--- Find the arguments passed to the function
-- @local
-- @param filepath string The path to the file
-- @param call_line number The line number of the function call
-- @return string The found arguments
local function find_call(filepath, call_line)
  local buff = ''
  local i = 0

  for line in io.lines(filepath) do
    i = i + 1
    -- Start capture
    if i == call_line then
      buff = buff .. line
      if buff:sub(-1, -1) ~= ')' then
        call_line = call_line + 1
      else
        break
      end
    end
  end

  -- Capture function and format buffer
  buff = buff
   :match(pimp.module_name .. '%((.+)%)?')
   :gsub('%s*', '')
   :gsub('[\n\t]', '')
   :gsub('{ ', '{')
   :gsub(' }', '}')

  return buff
end

---
-- Output debugging information
-- @param ... any Arguments to be printed
-- @return ... The passed arguments
function pimp:debug(...)
  if not self.output then
    return ...
  end

  local args = {...}
  local args_count = #args

  -- Set the prefix based on the loaded module's name
  if not self.prefix then
    local info = debug.getinfo(1, 'n')
    self.prefix = info.name .. '| '
    self.module_name = info.name
  end

  -- Get information about the calling location
  -- S - source, short_src, what, linedefined, lastlinedefined
  -- L - currentline
  local info = debug.getinfo(2, 'Sl')

  local linepos = info.currentline
  local filename = info.short_src
  if self.full_path == false then
    filename = filename:match('.+/(.-)$')
  end

  local filepath = info.source:match('@(.+)')
  local callpos = filename .. ':' .. linepos

  -- No arguments were passed
  if args_count == 0 then
    io.write(self.prefix .. callpos, '\n')
    io.flush()
    return ...
  end

  -- Handling the 'C' type (for C functions)
  if info.what == 'C' then
    io.write(self.prefix .. table.concat(args, ', '), '\n')
    io.flush()
    return ...
  end

  -- Find the function call
  local callname = find_call(filepath, linepos)
  local is_func = callname:match('.+%(.*%)') ~= nil

  -- Handling a variable number of arguments
  local data = {}
  for i = 1, args_count do
    local arg = args[i]
    local arg_type = type(arg)
    -- Handle table type
    if arg_type == 'table' then
      table.insert(data, pp:wrap(arg))
    else
      --
      local res = type_constructor(arg)
      table.insert(data, res)
    end
  end

  if is_func then
    local fmt_str = '%s%s: %s: %s\n'
    callname = tocolor(callname, 'custom_func')
    io.write(fmt_str:format(self.prefix, callpos, callname, table.concat(data, ', ')))
  else
    local fmt_str = '%s%s: %s\n'
    io.write(fmt_str:format(self.prefix, callpos, table.concat(data, ', ')))
  end

  io.flush()
  return ...
end

--- Set prefix
-- @param pref_str Pimp prefix
function pimp:setPrefix(pref_str)
  self.prefix = tostring(pref_str)
end

--- Enable debug output
function pimp:disable()
  self.output = false
end

--- Disable debug output
function pimp:enable()
  self.output = true
end

--- Disable full path output
function pimp:disableFullPath()
  self.full_path = false
end

--- Enable full path output
function pimp:enableFullPath()
  self.full_path = true
end

--- Enable or disable colors
-- @param val boolean
pimp.setUseColors = color.setUseColors

---
-- Set up the 'debug' function to be called
-- when attempting to invoke the table as a function
setmetatable(pimp, { __call = pimp.debug })

return pimp
