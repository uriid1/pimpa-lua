---
-- @module pimp
local pp = require 'pimp.pretty-print'
local type_constructor = require 'pimp.type_constructor'
local color = require 'pimp.color'
local tocolor = color.tocolor

local pimp = {
  prefix = nil,
  module_name = 'p',
  output = true,
  full_path = true,
  use_colors = true,
}

--
local function char_count(str, char)
  local count = 0
  for i = 1, #str do
    if char == str:sub(i, i) then
      count = count + 1
    end
  end

  return count
end

--- Find the arguments passed to the function
-- @local
-- @param filepath string The path to the file
-- @param call_line number The line number of the function call
-- @return string The found arguments
local stack_find_call = {}
local function find_call(filepath, call_line, curfunc)
  local buff = ''
  local i = 0
  local call_line_non_modify = call_line

  local open_brackets_count = 0 -- (
  local close_brackets_count = 0 -- )

  if not stack_find_call[filepath] then
    stack_find_call[filepath] = {
      [call_line_non_modify] = {
        filepath = filepath,
        call_line = call_line_non_modify,
        curfunc = curfunc,
        buff = buff,
        is_func = nil,
      }
    }
  elseif not stack_find_call[filepath][call_line_non_modify] then
    stack_find_call[filepath] = {
      [call_line_non_modify] = {
        filepath = filepath,
        call_line = call_line_non_modify,
        curfunc = curfunc,
        buff = buff,
        is_func = nil,
      }
    }
  elseif stack_find_call[filepath][call_line_non_modify] then
    local current = stack_find_call[filepath][call_line_non_modify]
    if curfunc then
      return current.buff:match(curfunc..'%((.+)%)'), true
    end

    return current.buff, current.is_func
  end

  for line in io.lines(filepath) do
    i = i + 1
    -- Start capture
    if i == call_line then
      buff = buff .. line

      open_brackets_count = open_brackets_count + char_count(line, '(')
      close_brackets_count = close_brackets_count + char_count(line, ')')

      if open_brackets_count == close_brackets_count then
        break
      end

      call_line = call_line + 1
    end
  end

  -- Remove spaces
  buff = buff:gsub('  ', '')

  if curfunc then
    return buff:match(curfunc..'%((.+)%)'), true
  end

  -- Capture function and format buffer
  buff = buff:sub(#pimp.module_name+2, -2)
  --  :gsub('[\n\t]', '')

  -- Add to stack
  local current = stack_find_call[filepath][call_line_non_modify]
  current.buff = buff
  current.is_func = buff:match('.+%(.*%)') ~= nil

  return buff, current.is_func
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
    local info = debug.getinfo(1)
    if not info.name then
      info.name = self.module_name
    end

    self.prefix = info.name .. '| '
    self.module_name = info.name
  end

  -- Get information about the calling location
  -- S - source, short_src, what, linedefined, lastlinedefined
  -- L - currentline
  local info = debug.getinfo(2)

  local infunc = ''
  if info.namewhat ~= '' then
    if info.isvararg and info.nparams == 1 then
      info.name = info.name .. '(...)'
    elseif info.linedefined > 0 then
      local filepath = info.source:match('@(.+)')
      local args, _ = find_call(filepath, info.linedefined, info.name)
      info.name = info.name .. '('..args..')'
    else
      info.name = info.name .. '(?)'
    end

    infunc = infunc ..' in '..tocolor(info.name, 'custom_func')
  end

  local linepos = info.currentline
  local filename = info.short_src
  if self.full_path == false then
    filename = filename:match('.+/(.-)$')
  end

  local filepath = info.source:match('@(.+)')
  local callpos = filename .. ':' .. linepos

  -- No arguments were passed
  if args_count == 0 then
    io.write(self.prefix .. callpos .. infunc, '\n')
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
  local callname, is_func = find_call(filepath, linepos)

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
    callname = callname .. ' return'
    io.write(fmt_str:format(self.prefix, callpos, callname, table.concat(data, ', ')))
  else
    local fmt_str = '%s%s: %s\n'
    io.write(fmt_str:format(self.prefix, callpos..infunc, table.concat(data, ', ')))
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

--- Disable colour output
function pimp:disableColor()
  color.setUseColors(false)
end

--- Enable colour output
function pimp:enableColor()
  color.setUseColors(true)
end

---
-- Set up the 'debug' function to be called
-- when attempting to invoke the table as a function
setmetatable(pimp, { __call = pimp.debug })

return pimp
