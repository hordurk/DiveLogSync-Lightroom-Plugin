local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrLogger = import 'LrLogger'
local LrFileUtils = import 'LrFileUtils'
local LrStringUtils = import 'LrStringUtils'
local LrXml = import 'LrXml'
local LrDate = import 'LrDate'
local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrProgressScope = import 'LrProgressScope'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'

local logger = LrLogger( 'Lr_DiveLogSync' )
logger:enable( "logfile" ) -- Pass either a string or a table of actions

-- Write trace information to the logger.
function outputToLog( message )
    logger:trace( message )
end

-- Borrowed from https://github.com/philipbl/Day-One-Lightroom-Plugin/blob/35407a33e549855032abbd09709ce047cd17ae7c/dayone.lrdevplugin/ExportTask.lua
local function split( str, delimiter )
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
local function print_r ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            outputToLog(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
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




local mainProgress = {}


local function parseDate( dateString )
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

local function toLrDate( d )
    return LrDate.timeFromComponents( d.year, d.month, d.day, d.hour, d.minute, d.second, true )
end

local function parseXmlFile(filename)
  -- Using method from Flickr plugin from Lightroom SDK Samples, convert XML to Lua script and execute that code
  -- xml_to_lua.xslt defines the import for the different formats.

  local xml = LrFileUtils.readFile(filename)
  local xslt = LrFileUtils.readFile(LrPathUtils.child(_PLUGIN.path, 'xml_to_lua.xslt'))
  local xmlRoot = LrXml.parseXml(xml)
  local luaTableString = xmlRoot and xmlRoot:transform( xslt )

  outputToLog('XSL Transform result:')
  outputToLog(luaTableString)
  outputToLog('=====================')

  local luaTableFunction = luaTableString and loadstring( luaTableString )
  outputToLog('loadstring() result:')
  print_r(luaTableFunction)
  outputToLog('====================')
  if luaTableFunction then
    local diveListTable = LrFunctionContext.callWithEmptyEnvironment( luaTableFunction )
    outputToLog('Dive list table:')
    print_r(diveListTable)
    outputToLog('================')
    if diveListTable then
      for k, dive in pairs(diveListTable) do -- do some date conversions, convert to lightroom format and figure out missing variables
        -- Maybe need to do type conversions here?

        dive.start_date = toLrDate(parseDate(dive.start_date))
        if dive.end_date ~= '' then
          dive.end_date = toLrDate(parseDate(dive.end_date))
        elseif dive.duration ~= '' then
            dive.end_date = dive.start_date + dive.duration
        else
          dive.end_date = dive.start_date + dive.profile[#dive.profile].runtime
        end
        if dive.duration == '' then
          dive.duration = dive.end_date - dive.start_date
        end
        -- Maybe need to loop through dive.profile and do type conversions?
      end

      return diveListTable

    end

  end

  return nil

end




local function processFile(context, filename )

    local divesData = parseXmlFile(filename)

    outputToLog('Parsed from dive log:')
    print_r(divesData)

    if divesData == nil then
        LrDialogs.message( "Unable to parse file: " .. filename )
        return 0
    end

    local count = 0
    local updated = 0

    local fileProgress = LrProgressScope({
        caption = "Processing file",
        functionContext = context,
        parent = mainProgress,
    })
    fileProgress:setCancelable(true)

    fileProgress:setPortionComplete( 0, #divesData )

    for diveNo, diveData in pairs(divesData) do
        if fileProgress:isCanceled() then break end

        local dateFrom = diveData.start_date
        local dateTo = diveData.end_date
        local depths = diveData.profile

            outputToLog("Finding photos between " .. LrDate.timeToUserFormat( dateFrom, "%Y-%m-%d %H:%M:%S" ) .. " and " .. LrDate.timeToUserFormat( dateTo, "%Y-%m-%d %H:%M:%S" ))

            local progress = LrProgressScope({
            caption = "Matching photos with dive profile",
            functionContext = context,
            parent = fileProgress,
          })
            progress:setCancelable(true)

            local catalog = LrApplication.activeCatalog()

            local foundPhotos = catalog:findPhotos {
              sort = "captureTime",
              ascending = true,
              searchDesc = {
                            {
                      criteria = "fileFormat",
                      operation = "!=",
                      value = "VIDEO",
                  },
                  {
                      criteria = "captureTime",
                      operation = "in",
                      value = LrDate.timeToUserFormat( dateFrom, "%Y-%m-%d" ),
                      value2 = LrDate.timeToUserFormat( dateTo, "%Y-%m-%d" ),
                  },
                  combine = "intersect",
              }
          }

            progress:setPortionComplete( 0, #foundPhotos )

            -- print_r(depths)
            local dIndex = 2
            local i = 0
            for k, photo in pairs( foundPhotos) do
                if progress:isCanceled() then break end
                i = i + 1
                outputToLog(photo:getFormattedMetadata("fileName"))
                local dateTime = photo:getRawMetadata("dateTimeOriginal")
                -- Only consider photos taken during the dive
                if dateTime >= dateFrom and dateTime <= dateTo then
                    count = count + 1
                    -- This photo timestamp relative to the start of the dive profile
                    local relTime = dateTime - dateFrom
                    -- Search the dive profile until we reach this photos timestatmp
                    while relTime > depths[dIndex].runtime do
                        dIndex = dIndex + 1
                    end

                    -- Linear interpolation of the depth
                    local depth = (depths[dIndex-1].depth + (depths[dIndex].depth-depths[dIndex-1].depth) * (relTime-depths[dIndex-1].runtime)/(depths[dIndex].runtime-depths[dIndex-1].runtime))
                    local temperature = (depths[dIndex-1].temperature + (depths[dIndex].temperature-depths[dIndex-1].temperature) * (relTime-depths[dIndex-1].runtime)/(depths[dIndex].runtime-depths[dIndex-1].runtime))

                    local newDepth = depth
                    local currentDepth = -(photo:getRawMetadata("gpsAltitude") or 0)

                    outputToLog("Current depth: " .. currentDepth .. ". New depth: " .. newDepth)

                    if true then --math.abs(currentDepth-newDepth) > 0.01 then
                        updated = updated + 1
                        catalog:withWriteAccessDo("Change " .. photo:getFormattedMetadata("fileName") .. " depth to " .. newDepth,
                            function()
                                photo:setPropertyForPlugin( _PLUGIN, 'depth', newDepth )
                                photo:setPropertyForPlugin( _PLUGIN, 'waterTemp', temperature )
                                photo:setPropertyForPlugin( _PLUGIN, 'runTime', relTime )
                                photo:setPropertyForPlugin( _PLUGIN, 'diveNo', diveData.number )

                                photo:setRawMetadata("gpsAltitude", -newDepth) -- Convert depth to meters
                            end
                        )
                    end



                    -- outputToLog(photo:getFormattedMetadata("fileName") .. " depth=" .. depth .. " d0=" .. depths[dIndex-1].depth .. ",d1=" .. depths[dIndex].depth .. " t=" .. relTime .. " ti=" .. depths[dIndex-1].time .. "-" .. depths[dIndex].time)
                end

                progress:setPortionComplete( i, #foundPhotos )

            end
            progress:done()
            fileProgress:setPortionComplete( diveNo, #divesData )

        end

        fileProgress:done()

        outputToLog("Number of photos: " .. count .. ". Updated: " .. updated)

        return updated
        -- print_r(foundPhotos)

end


local function showFileDialog()


      local files = LrDialogs.runOpenPanel(
        {
          title = "Select Petrel XML",
          canChooseFiles = true,
          allowsMultipleSelection = true,
          canChooseDirectories = false,
          canCreateDirectories = false,
          fileTypes = {
            'xml', 'udcf', 'uddf',
          },
        })

        -- abort if no file was selected
        if not files then
          return
        end


        LrTasks.startAsyncTask( function()

        LrFunctionContext.callWithContext( "mainTask", function( context )

          print_r(files)

            local mainProgress = LrProgressScope {
                title = 'Parsing dive profiles',
                functionContext = context,
            }
            mainProgress:setCancelable(true)

            mainProgress:setPortionComplete(0,#files)

            local totalUpdated = 0

          for k,file in pairs(files) do
                if mainProgress:isCanceled() then break end
            outputToLog("Reading file " .. file)
                totalUpdated = totalUpdated + LrFunctionContext.callWithContext("processFile", processFile, file)
                mainProgress:setPortionComplete(k,#files)
          end

            mainProgress:done()

            LrDialogs.message( "Updated depth for " .. totalUpdated .. " photos." )

        end)

    end)


end


showFileDialog()
