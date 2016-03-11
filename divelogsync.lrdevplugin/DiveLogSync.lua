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
    if diveListTable then
      for k, dive in pairs(diveListTable) do -- do some date conversions, convert to lightroom format and figure out missing variables
        -- Maybe need to do type conversions here?

        dive.start_date = toLrDate(parseDate(dive.start_date))
        if dive.end_date ~= nil and dive.end_date ~= '' then
          dive.end_date = toLrDate(parseDate(dive.end_date))
        elseif dive.duration ~= nil and dive.duration ~= '' then
            dive.end_date = dive.start_date + dive.duration
        else
          dive.end_date = dive.start_date + dive.profile[#dive.profile].runtime
        end
        if dive.duration == nil or dive.duration == '' then
          dive.duration = dive.end_date - dive.start_date
        end
        -- Maybe should loop through dive.profile and do type conversions?
      end

      return diveListTable

    end

  end

  return nil

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
  if diveData == nil or prop_desc == nil or diveData.profile == nil then
    return nil
  end

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
    if diveData.profile[i] == nil then return nil end
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

local function parseCsv(data, header_mapping, delimiter)
  outputToLog("parseCsv. delimiter: " .. delimiter)
  print_r(data)
  outputToLog("Header mapping:")
  print_r(header_mapping)


  local lines = split(data,"\n")
  print_r(lines)
  -- process 1st line, check header mapping
  local headers = {}
  local headerParts = split(lines[1],delimiter)
  for k,v in pairs(headerParts) do
    if header_mapping[v] ~= nil then
      headers[k] = header_mapping[v]
    end
  end
  print_r(headers)

  local res = {}
  for i=2,#lines do
    local entry = {}
    local p = split(lines[i],delimiter)
    for k,v in pairs(headers) do
      if p[k] ~= nil then
        entry[v.id] = v.func(p[k])
      end
    end
    res[#res+1] = entry
  end

  print_r(res)

  return res

end


local function parseZXUFile(filename)
  local data = LrFileUtils.readFile(filename)
  outputToLog("Parsing ZXU file")

  if string.sub(data, 1, 4) ~= "FSH|" then
    outputToLog("Invalid file header")
    return nil
  end

  local headers = {'ZRH','ZAR','ZDH','ZDP'}
  local segments = {}
  for k,h in pairs(headers) do
    local pos = string.find(data, h)
    local f = string.sub(data, pos+string.len(h), pos+string.len(h))
    if f == '|' then
      segments[h] = string.sub(data, pos+string.len(h)+1, string.find(data, "\n", pos)-1)
    elseif f == '{' then
      segments[h] = string.sub(data, pos+string.len(h)+1, string.find(data, "}", pos)-1)
    else
      -- ?
    end
  end

  outputToLog("Segments:")
  print_r(segments)

  local res = {}
  local depthFunc = tonumber
  local tempFunc = tonumber

  if segments['ZRH'] ~= nil then
    local parts = split(segments['ZRH'],"|")

    local depthUnit = parts[5-1]
    if depthUnit == "FFWG" or depthUnit == "FSWG" then
      depthFunc = fromFeet
    end

    local tempUnit = parts[7-1]
    if tempUnit == "F" then
      tempFunc = fromFahrenheit
    elseif tempUnit == "K" then
      tempFunc = fromKelvin
    end
  end

  if segments['ZAR'] ~= nil then
    -- Parse some strings from known formats.

    -- DiverLog
    local id = string.match(segments['ZAR'],"<DUID>(.*)</DUID>")
    if id ~= nil and id ~= "" then
      res.id = id
    end
    local location = string.match(segments['ZAR'],"DIVESITE=%[([^%].]*)%]")
    if location ~= nil and location ~= "" then
      res.location = location
    end
    local country = string.match(segments['ZAR'],"LOCNAME=%[([^%].]*)%]")
    if country ~= nil and country ~= "" then
      res.country = country
    end


  end

  if segments['ZDH'] ~= nil then
    local parts = split(segments['ZDH'],"|")
    res.dive_number = tonumber(parts[2])
    res.start_date = toLrDate(parseDateStamp(parts[5]))
  else
    outputToLog("ZDH section missing")
    return nil
  end

  if segments['ZDP'] ~= nil then
    res.profile = {}
    local lastTemp = 0
    local lines = split(segments['ZDP'],"\n")
    for k,line in pairs(lines) do
      local parts = split(line,"|")
      if #parts >= 3 then
        if parts[8 +1] ~= "" then
          lastTemp = tempFunc(parts[8 +1])
        end
        local sample = {
          run_time = fromMinutes(parts[1 +1]),
          depth = depthFunc(parts[2 +1]),
          temperature = lastTemp,
        }
        res.profile[#res.profile+1] = sample
      end
    end
    res.duration = res.profile[#res.profile].run_time
    res.end_date = res.start_date + res.duration
  else
    outputToLog("ZDP section missing")
    return nil
  end

  return res
end

local function parseTxtFile(filename)
  local res = nil

  local data = LrFileUtils.readFile(filename)

  local header_mapping = {}
  header_mapping["Elapsed Dive Time (hr:min)"] = {id="run_time",func=timeToSeconds}
  header_mapping["Depth(FT)"] = {id="depth",func=fromFeet}
  header_mapping["Depth(m)"] = {id="depth",func=tonumber}
  header_mapping["Temperature(FT)"] = {id="water_temperature",func=fromFahrenheit}
  header_mapping["Temperature(m)"] = {id="water_temperature",func=tonumber}

  if string.sub(data,1,string.len("Life Time Dive")) == "Life Time Dive" then
    res = {}
    res.id = LrPathUtils.leafName(LrPathUtils.removeExtension(filename))
    outputToLog("Detected DiverLog format")
    local dive_date
    local dive_time
    data = string.gsub( data, "[-]+[-]+[-]*", "===" ) -- replace 2 or more - with triple =
    local parts = split( data, "\n\n" )
    for k,v in pairs(split(parts[1], "\n")) do
      local p = split(v, ": ")
      if p[1] == "Life Time Dive #" then
        res.dive_number = tonumber(p[2])
      elseif p[1] == "Dive Date" then
        dive_date = string.gsub(p[2],"/","-")
      elseif p[1] == "Dive Time" then
        dive_time = p[2]
      end
    end

    local lastParts = split(parts[#parts], "===")
    local csvPart = lastParts[#lastParts]

    res.profile = parseCsv(csvPart, header_mapping, "[;,\t]")
    res.duration = res.profile[#res.profile].run_time
    res.start_date = toLrDate(parseDate(dive_date .. " " .. dive_time))
    res.end_date = res.start_date + res.duration
  end
  return res
end


local function processFile(context, filename )
  local prefs = LrPrefs.prefsForPlugin()

  local ext = LrPathUtils.extension(filename)
  local divesData

  if string.lower(ext) == "xml" then
    divesData = parseXmlFile(filename)
  elseif string.lower(ext) == "txt" then
    divesData = parseTxtFile(filename)
  elseif string.lower(ext) == "zxu" then
    divesData = parseZXUFile(filename)
  else
    LrDialogs.message("Unsupported format: " .. filename)
  end

    if divesData == nil then
        LrDialogs.message( "Unable to parse file: " .. filename )
        return 0
    end

    outputToLog('Parsed from dive log:')
    print_r(divesData)
    outputToLog("/Parsed from dive log")

    local count = 0
    local numUpdated = 0

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

        if diveData == nil or diveData.start_date == nil or diveData.end_date == nil then
          outputToLog("Problem with diveData")
          break
        end

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
                          outputToLogVar("Start write access for",photoName)

                          local updated = false
                          for k,v in pairs(DLSpropertyDefinitions) do
                            outputToLogVar("Property",v.id)
                            local val = extractValue(diveData, v, relTime, dIndex)
                            outputToLogVar("Value", val)
                            if val ~= nil and val ~= '' then
                              local current_val
                              if v.plugin ~= nil then
                                current_val = photo:getPropertyForPlugin(v.plugin, v.id)
                              elseif v.type ~= nil and v.type == 'string' then
                                current_val = photo:getFormattedMetadata(v.id)
                              else
                                current_val = photo:getRawMetadata(v.id)
                              end
                              outputToLogVar("Current value", current_val)
                              if shouldWrite(v.id, prefs, current_val, val) then
                                  outputToLog("Writing new property value to catalog.")
                                  if v.plugin ~= nil then
                                    photo:setPropertyForPlugin(v.plugin, v.id, val)
                                  else
                                    photo:setRawMetadata(v.id, val)
                                  end
                                  updated = true
                              end
                            end
                            outputToLog("/Property")
                          end

                          if updated then
                            outputToLog("Metadata updated.")
                            numUpdated = numUpdated + 1
                          else
                            outputToLog("Metadata up to date.")
                          end
                          outputToLogVar("end write access for", photoName)
                    end)

                end
                outputToLogVar("Done processing photo/video",photo:getFormattedMetadata("fileName"))

                progress:setPortionComplete( i, #foundPhotos )
                outputToLog("Portion complete")

            end
            progress:done()
            fileProgress:setPortionComplete( diveNo, #divesData )

        end



        fileProgress:done()

        outputToLog("Number of photos: " .. count .. ". Updated: " .. numUpdated)

        return numUpdated
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
          title = "Select dive logs",
          canChooseFiles = true,
          allowsMultipleSelection = true,
          canChooseDirectories = false,
          canCreateDirectories = false,
          fileTypes = {
            'xml', 'uddf', 'txt', 'zxu'
          },
        })

        -- abort if no file was selected
        if files == nil or not files then
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
                if file == nil then break end
                outputToLogVar("Reading file", file)
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
