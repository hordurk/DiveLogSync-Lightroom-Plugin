local LrLogger = import "LrLogger"
local LrStringUtils = import "LrStringUtils"
local LrPrefs 		= import 'LrPrefs'
local LrDate = import 'LrDate'


local logger = LrLogger( 'Lr_DiveLogSync' )
logger:enable( "logfile" ) -- Pass either a string or a table of actions

-- Write trace information to the logger.
function outputToLog( message )
  local prefs = LrPrefs.prefsForPlugin()
  if prefs.writeDebugLog then
    logger:trace( message )
  end
end

function outputToLogVar( message, v )
  if type(v) == "table" then
    outputToLog(string.format("%s:",message))
    print_r(v)
  else
    outputToLog(string.format("%s: %s", message, v))
  end
end

-- Borrowed from https://github.com/philipbl/Day-One-Lightroom-Plugin/blob/35407a33e549855032abbd09709ce047cd17ae7c/dayone.lrdevplugin/ExportTask.lua
function split( str, delimiter )
    local result = { }
    local from  = 1
    local delim_from, delim_to = string.find( str, delimiter, from  )
    while delim_from do
        table.insert( result, LrStringUtils.trimWhitespace( string.sub( str, from , delim_from-1 ) ) )
        from  = delim_to + 1
        delim_from, delim_to = string.find( str, delimiter, from  )
    end
    table.insert( result, LrStringUtils.trimWhitespace( string.sub( str, from  ) ) )
    return result
end

-- Modified from https://github.com/robmiracle/print_r/blob/master/print_r.lua to output to log instead of print
function print_r ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            outputToLog(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                  if(type(pos)=="table") then
                    pos = "table"
                  end
                    if (type(val)=="table") then


                        outputToLog(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        outputToLog(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        outputToLog(indent.."["..pos..'] => "'..val..'"')
                    else
                        outputToLog(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                outputToLog(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        outputToLog(tostring(t).." {")
        sub_print_r(t,"  ")
        outputToLog("}")
    else
        sub_print_r(t,"  ")
    end
    outputToLog()
end

function parseDate( dateString )
    local parts = split(dateString,' ')
    local dateParts = split(parts[1],'-')
    local timeParts = split(parts[2],':')
    local res = {}
    res.year = tonumber(dateParts[1])
    res.month = tonumber(dateParts[2])
    res.day = tonumber(dateParts[3])
    res.hour = tonumber(timeParts[1])
    res.minute = tonumber(timeParts[2])
    res.second = tonumber(timeParts[3])
    return res
end

function toLrDate( d )
    return LrDate.timeFromComponents( d.year, d.month, d.day, d.hour, d.minute, d.second, true )
end

function iif(test, res_true, res_false)
  if test then
    return res_true
  else
    return res_false
  end
end

function interpolate(x, x0, x1, y0, y1)
  return (y0 + (y1-y0) * (x-x0)/(x1-x0))
end

function compare(val1,val2)
  if type(val1)~=type(val2) then
    return false
  end

  if type(val1)=="table" then
    if val1==val2 then
      return true
    end
    for k,v in pairs(val1) do
      if val2[k] == nil or not compare(v,val2[k]) then
        return false
      end
    end
    for k,v in pairs(val2) do
      if val1[k] == nil or not compare(v,val1[k]) then
        return false
      end
    end
    return true
  elseif type(val1)=="number" then
    if math.abs(val1-val2) < 0.0001 then
      return true
    else
      return false
    end
  else
    if val1==val2 then
      return true
    else
      return false
    end
  end
end

local function convertDepth(val)
  local prefs = LrPrefs.prefsForPlugin()
  if val == nil then
    return 0
  end

  if prefs.units ~= nil and prefs.units ~= 'm' then
    val = val * 3.28084
  end

  return val
end

local function convertAltitude(val)
  if val == nil then
    return 0
  end
  return -val
end

local function convertTemperature(val)
  local prefs = LrPrefs.prefsForPlugin()
  if val == nil then
    return 0
  end

  if prefs.units ~= nil and prefs.units ~= 'm' then
    val = val * 1.8 + 32
  end

  return val
end

local function getLatLon(vals,i)
  if vals.lat ~= nil and vals.lat ~= '' and vals.lat ~= 0 and vals.lon ~= nil and vals.lon ~= '' and vals.lon ~= 0 then
    local lat = tonumber(vals.lat)
    local lon = tonumber(vals.lon)
    if lat ~= nil and lon ~= nil then
      return { latitude = lat, longitude = lon }
    end
  end
  return nil
end

DLSpropertyDefinitions =
{
    {
      title = 'Altitude',
      id = 'gpsAltitude',
      plugin = nil,
      interpolate = true,
      func = convertAltitude,
      c_id  = 'depth',
      type = 'number',
    },
    {
      title = 'GPS lat/lon',
      id = 'gps',
      plugin = nil,
      get_func = getLatLon,
    },
    {
      title = 'Location',
      id = 'location',
      plugin = nil,
      type = 'string',
    },
    {
      title = 'City',
      id = 'city',
      plugin = nil,
      type = 'string',
    },
    {
      title = 'State/province',
      id = 'stateProvince',
      plugin = nil,
      type = 'string',
    },
    {
      title = 'Country',
      id = 'country',
      plugin = nil,
      type = 'string',
    },
    {
      title = 'Run time',
      id = 'run_time',
      plugin = _PLUGIN,
      type = 'number',
    },
    {
      title = 'Depth',
      id = 'depth',
      plugin = _PLUGIN,
      interpolate = true,
      func = convertDepth,
      type = 'number',
    },
    {
      title = 'Water temperature',
      id = 'water_temperature',
      plugin = _PLUGIN,
      interpolate = true,
      func = convertTemperature,
      type = 'number',
    },
    {
      title = 'Dive number',
      id = 'dive_number',
      plugin = _PLUGIN,
      interpolate = false,
      type = 'number',
    },
    {
      title = 'Dive site',
      id = 'dive_site',
      plugin = _PLUGIN,
      interpolate = false,
      c_id = 'location',
      type = 'string',
    },
    {
      title = 'Dive ID',
      id = 'id',
      plugin = _PLUGIN,
      type = 'string',
    },
}
