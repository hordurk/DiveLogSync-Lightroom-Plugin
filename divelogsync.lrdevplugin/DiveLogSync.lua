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
local LrBinding		= import 'LrBinding'
local LrPrefs 		= import 'LrPrefs'


require "Utils"
require "DLSDialogs"

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

local function interpolate(x, x0, x1, y0, y1)
  return (y0 + (y1-y0) * (x-x0)/(x1-x0))
end

local function compare(val1,val2)
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

local function shouldWrite(id, prefs, current_val, new_val)
  if compare(current_val,new_val) then
    return false
  end

  if (current_val == nil or current_val == '') then
    if prefs[id .. '_populate'] then
      return true
    end
  else
    if prefs[id .. '_overwrite'] then
      return true
    end
  end

  return false
end

local function extractValue(diveData, prop_desc, relTime, i)
  local id = prop_desc.id
  local val

  if prop_desc.c_id ~= nil then
    id = prop_desc.c_id
  end

  if diveData[id] ~= nil then
    val = diveData[id]
    if prop_desc.type == 'string' then
      val = LrStringUtils.trimWhitespace(val)
    end
    return val
  end

  if prop_desc.get_func then
    val = prop_desc.get_func(diveData,i)
  else
    val = diveData.profile[i][id]
  end

  if val ~= nil then
    if prop_desc.interpolate then
      val = interpolate(relTime, diveData.profile[i-1].run_time, diveData.profile[i].run_time, diveData.profile[i-1][id], diveData.profile[i][id])
    end
    if prop_desc.func then
      val = prop_desc.func(val)
    end
    if prop_desc.type == 'string' then
      val = LrStringUtils.trimWhitespace(val)
    end
    return val
  end

  return nil
end

local function iif(test, res_true, res_false)
  if test then
    return res_true
  else
    return res_false
  end
end

local function processFile(context, filename )
  local prefs = LrPrefs.prefsForPlugin()

    local divesData = parseXmlFile(filename)

    if divesData == nil then
        LrDialogs.message( "Unable to parse file: " .. filename )
        return 0
    end

    outputToLog('Parsed from dive log:')
    print_r(divesData)
    outputToLog("/Parsed from dive log")

    local count = 0
    local updated = 0

    local fileProgress = LrProgressScope({
        caption = "Processing file",
        functionContext = context,
        parent = mainProgress,
    })
    fileProgress:setCancelable(true)

    fileProgress:setPortionComplete( 0, #divesData )

    local catalog = LrApplication.activeCatalog()


    for diveNo, diveData in pairs(divesData) do
        if fileProgress:isCanceled() then break end

            outputToLog("Finding photos between " .. LrDate.timeToUserFormat( diveData.start_date, "%Y-%m-%d %H:%M:%S" ) .. " and " .. LrDate.timeToUserFormat( diveData.end_date, "%Y-%m-%d %H:%M:%S" ))

            local progress = LrProgressScope({
              caption = "Matching photos with dive profile",
              functionContext = context,
              parent = fileProgress,
            })
            progress:setCancelable(true)

            local captureTimeSearchDesc = {
              criteria = "captureTime",
              operation = "in",
              value = LrDate.timeToUserFormat( diveData.start_date, "%Y-%m-%d" ),
              value2 = LrDate.timeToUserFormat( diveData.end_date, "%Y-%m-%d" ),
            }
            local searchDesc = {
              captureTimeSearchDesc,
              {
                  criteria = "fileFormat",
                  operation = "!=",
                  value = "VIDEO",
              },
              combine = "intersect",
            }

            if(prefs.doVideos) then
              searchDesc = captureTimeSearchDesc
            end

            local foundPhotos = catalog:findPhotos {
              sort = "captureTime",
              ascending = true,
              searchDesc = searchDesc,
            }

            progress:setPortionComplete( 0, #foundPhotos )

            -- print_r(depths)
            local dIndex = 2
            local i = 0
            for k, photo in pairs( foundPhotos) do
                if progress:isCanceled() then break end
                i = i + 1
                local photoName = photo:getFormattedMetadata("fileName")
                outputToLog("Processing photo: " .. photoName)

                -- Lightroom has multiple datetimes for a photo. Fetch them all for debug output.
                local dateTimeOriginal = photo:getRawMetadata("dateTimeOriginal")
                local dateTimeDigitized = photo:getRawMetadata("dateTimeDigitized")
                local dateTime = photo:getRawMetadata("dateTime")

                outputToLog(string.format("dateTimeOriginal: %s %s", dateTimeOriginal,LrDate.timeToUserFormat( dateTimeOriginal or 0, "%Y-%m-%d %H:%M:%S" )))
                outputToLog(string.format("dateTimeDigitized: %s %s", dateTimeDigitized,LrDate.timeToUserFormat( dateTimeDigitized or 0, "%Y-%m-%d %H:%M:%S" )))
                outputToLog(string.format("dateTime: %s %s",dateTime,LrDate.timeToUserFormat( dateTime or 0, "%Y-%m-%d %H:%M:%S" )))

                -- Prefer original timestamp. If that is missing, use dateTime or lastly digitized timestamp. original seems to get edited when one edits a photo.
                dateTime = dateTimeOriginal or dateTime or dateTimeDigitized or 0 -- last resort, use 0 instead of nil to not fail on the comparison

                outputToLog(string.format("dateTime: %s %s",dateTime,LrDate.timeToUserFormat( dateTime or 0, "%Y-%m-%d %H:%M:%S" )))

                -- Only consider photos taken during the dive
                if dateTime >= diveData.start_date and dateTime <= diveData.end_date then
                  outputToLog("Photo is within dive profile bounds.")
                    count = count + 1
                    -- This photo timestamp relative to the start of the dive profile
                    local relTime = dateTime - diveData.start_date
                    outputToLog(string.format("Photo runtime: %f", relTime))
                    -- Search the dive profile until we reach this photos timestatmp
                    while dIndex < #diveData.profile and relTime > diveData.profile[dIndex].run_time do
                        dIndex = dIndex + 1
                    end

                    catalog:withWriteAccessDo("metadata update for " .. LrPathUtils.leafName(photoName),
                        function(context)
                          outputToLog("start write access for " .. photoName)

                          local u = false
                          for k,v in pairs(DLSpropertyDefinitions) do
                            outputToLog(string.format("Property: %s.", v.id))
                            local val = extractValue(diveData, v, relTime, dIndex)
                            outputToLog(string.format("Value: %s", val))
                            if val ~= nil and val ~= '' then
                              local current_val
                              if v.plugin ~= nil then
                                current_val = photo:getPropertyForPlugin(v.plugin, v.id)
                              elseif v.type ~= nil and v.type == 'string' then
                                current_val = photo:getFormattedMetadata(v.id)
                              else
                                current_val = photo:getRawMetadata(v.id)
                              end
                              outputToLog(string.format("Current value: %s", current_val))
                              if shouldWrite(v.id, prefs, current_val, val) then
                                  outputToLog("Writing new property value to catalog.")
                                  if v.plugin ~= nil then
                                    photo:setPropertyForPlugin(v.plugin, v.id, val)
                                  else
                                    photo:setRawMetadata(v.id, val)
                                  end
                                  u = true
                              end
                            end
                            outputToLog("/Property")
                          end

                          if u then
                            outputToLog("Metadata updated.")
                            updated = updated + 1
                          else
                            outputToLog("Metadata up to date.")
                          end
                          outputToLog("end write access for " .. photoName)
                    end)

                end
                outputToLog("Done processing " .. photo:getFormattedMetadata("fileName"))

                progress:setPortionComplete( i, #foundPhotos )
                outputToLog("Portion complete")

            end
            progress:done()
            fileProgress:setPortionComplete( diveNo, #divesData )

        end



        fileProgress:done()

        outputToLog("Number of photos: " .. count .. ". Updated: " .. updated)

        return updated
        -- print_r(foundPhotos)

end

local function showMetadataSelectDialog( context )
  local prefs = LrPrefs.prefsForPlugin()
  local f = LrView.osFactory()
  local pt = LrBinding.makePropertyTable(context)
  for k,v in prefs:pairs() do
    outputToLog(k)
    outputToLog(v)
    pt[k] = v
  end
  local res = LrDialogs.presentModalDialog(
    {
      title = "Select metadata",
      contents = DLSDialogs.metadataSelectView(f, pt),
      actionVerb = "Select files",
    }
  )



  if res == "ok" then
    for k,v in pt:pairs() do
      prefs[k] = v
      outputToLog(k)
      outputToLog(v)
    end
    -- prefs.showMetadataDialog = pt.showMetadataDialog
    return true
  end

  return false
end

local function showFileDialog()
  local prefs = LrPrefs.prefsForPlugin()

  outputToLog("\n\n\n===============================\n\n\n")
  outputToLog("Starting Dive Log Sync")
  local info = require "Info"
  local currentVersion = info["VERSION"]
  outputToLog(string.format("Version: %d.%d.%d.%d", currentVersion.major, currentVersion.minor, currentVersion.revision, currentVersion.build))


  outputToLog("Preferences:")
  for k,v in prefs:pairs() do
    outputToLog(string.format("%s = %s", k, v))
  end
  outputToLog("/Preferences")

  if prefs.showMetadataDialog then
    outputToLog("Showing Metadata dialog")
    local d = LrFunctionContext.callWithContext( 'metadataSelectDialog', showMetadataSelectDialog)

    if not d then
      outputToLog("User hit cancel, aborting.")
      return
    end
  end

  outputToLog("Showing file dialog")

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
          outputToLog("No files selected, aborting.")
          return
        end

        outputToLog("File selection:")
        print_r(files)
        outputToLog("/File selection")


        LrTasks.startAsyncTask( function()

        LrFunctionContext.callWithContext( "mainTask", function( context )

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

            outputToLog("Done processing files.")

            mainProgress:done()

            LrDialogs.message( "Updated metadata for " .. totalUpdated .. " photos/videos." )

            outputToLog("Updated metadata for " .. totalUpdated .. " photos/videos.")

        end)

    end)


end


showFileDialog()
