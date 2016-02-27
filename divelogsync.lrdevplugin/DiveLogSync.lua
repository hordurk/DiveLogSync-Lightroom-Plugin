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

-- Create the logger and enable the print function.

local myLogger = LrLogger( 'libraryLogger' )
myLogger:enable( "logfile" ) -- Pass either a string or a table of actions

-- Write trace information to the logger.

local function outputToLog( message )
	myLogger:trace( message )
end

local mainProgress = {}

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

Months = {
	Jan=1,
	Feb=2,
	Mar=3,
	Apr=4,
	May=5,
	Jun=6,
	Jul=7,
	Aug=8,
	Sep=9,
	Oct=10,
	Nov=11,
	Dec=12,
}

Days = {
	Mon=1,
	Tue=2,
	Wed=3,
	Thu=4,
	Fri=5,
	Sat=6,
	Sun=7,
}

local function parseShearwaterDate( dateString )
	local parts = split(dateString,' ')
	local timeParts = split(parts[4],':')
	local res = {}
	-- res.weekDayName = parts[1]
	-- res.weekDay = Days[parts[1]]
	-- res.monthName = parts[2]
	res.month = Months[parts[2]]
	res.day = tonumber(parts[3])
	-- res.time = parts[4]
	res.year = tonumber(parts[5])
	-- res.tz = parts[6]
	res.hour = tonumber(timeParts[1])
	res.minute = tonumber(timeParts[2])
	res.second = tonumber(timeParts[3])

	return res
end

local function parseMacdiveDate( dateString )
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

local function parseDepths( depthString )
	local depthLines = split( depthString, ';' )
	print_r(depthLines)
	local res = {}
	for i,l in ipairs( depthLines ) do
		local parts = split( l, ',' )
		if #parts==3 then
			res[ #res + 1 ] = {
				time=tonumber(parts[1]),
				depth=tonumber(parts[2]),
				temperature=tonumber(parts[3]),
			}
		end
	end
	return res
end

local function parseShearwaterXML(xmlRoot)
	local res = {}



	local xsltDates = [[<?xml version="1.0" encoding="UTF-8"?>
	<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"><xsl:output method="text"/><xsl:template match="/"><xsl:value-of select="dive/diveLog/startDate"/>,<xsl:value-of select="dive/diveLog/endDate"/>,<xsl:value-of select="dive/diveLog/number"/></xsl:template></xsl:stylesheet>
	]]

	local xsltProfile = [[<?xml version="1.0" encoding="UTF-8"?>
	<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"><xsl:output method="text"/><xsl:template match="/"><xsl:for-each select="dive/diveLog/diveLogRecords/diveLogRecord"><xsl:value-of select="currentTime"/>,<xsl:value-of select="currentDepth"/>,<xsl:value-of select="waterTemp"/>;</xsl:for-each></xsl:template></xsl:stylesheet>
	]]

	local dateString = xmlRoot:transform( xsltDates )

	if dateString == nil or dateString == "," then
		return nil
	end

	res.dates = split( dateString, ',' )

	res.dateFrom = toLrDate(parseShearwaterDate(res.dates[1]))
	res.dateTo = toLrDate(parseShearwaterDate(res.dates[2]))
	res.diveNo = tonumber(res.dates[3])

	res.depths = parseDepths( xmlRoot:transform( xsltProfile ) )

	return {res}
end

local function parseMacdiveXML(xmlRoot)
	local res = {}

	local xsltProfile = [[<?xml version="1.0" encoding="UTF-8"?>
	<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"><xsl:output method="text"/><xsl:template match="/"><xsl:for-each select="dives/dive"><xsl:value-of select="date"/>,<xsl:value-of select="duration"/>,<xsl:value-of select="diveNumber"/>@<xsl:for-each select="samples/sample"><xsl:value-of select="time"/>,<xsl:value-of select="depth"/>,<xsl:value-of select="temperature"/>;</xsl:for-each>|</xsl:for-each></xsl:template></xsl:stylesheet>
	]]

	local parsedXml = xmlRoot:transform( xsltProfile )

	if parsedXml == nil or parsedXml == "" then
		return nil
	end

	local dives = split( parsedXml, '|' )
	for k, dive in pairs(dives) do
		local d = {}

		if dive ~= '' then

			local diveParts = split( dive, '@' )
			local dateParts = split( diveParts[1] , ',')

			d.dates = dateParts
			d.diveNo = tonumber(dateParts[3])

			d.dateFrom = toLrDate(parseMacdiveDate(dateParts[1]))
			d.dateTo = d.dateFrom + tonumber(dateParts[2])

			d.depths = parseDepths( diveParts[2] )

			res[ #res + 1 ] = d

		end

	end

	return res

end

local function parseXmlFile(filename)
	xml = LrFileUtils.readFile(filename)
	local diveData

	local xmlRoot = LrXml.parseXml(xml)

	-- Try to parse xml as a Macdive XML
	diveData = parseMacdiveXML(xmlRoot)

	-- Check if success
	if diveData ~= nil then
		print_r(diveData)
		outputToLog('Mac dive!')
		return diveData
	end

	-- Add more dive log formats here
	diveData = parseShearwaterXML(xmlRoot)
	return diveData
end

local function processFile(context, filename )

	local divesData = parseXmlFile(filename)

	outputToLog('Parsed from dive log:')
	print_r(divesData)

	if divesData == nil then
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

		local dates = diveData.dates
		local dateFrom = diveData.dateFrom
		local dateTo = diveData.dateTo
		local depths = diveData.depths

			outputToLog("Finding photos between " .. dates[1] .. " and " .. dates[2])

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
					while relTime > depths[dIndex].time do
						dIndex = dIndex + 1
					end

					-- Linear interpolation of the depth
					local depth = (depths[dIndex-1].depth + (depths[dIndex].depth-depths[dIndex-1].depth) * (relTime-depths[dIndex-1].time)/(depths[dIndex].time-depths[dIndex-1].time))
					local temperature = (depths[dIndex-1].temperature + (depths[dIndex].temperature-depths[dIndex-1].temperature) * (relTime-depths[dIndex-1].time)/(depths[dIndex].time-depths[dIndex-1].time))

					local newDepth = 0.3048*depth
					local currentDepth = -(photo:getRawMetadata("gpsAltitude") or 0)

					outputToLog("Current depth: " .. currentDepth .. ". New depth: " .. newDepth)

					if true then --math.abs(currentDepth-newDepth) > 0.01 then
						updated = updated + 1
						catalog:withWriteAccessDo("Change " .. photo:getFormattedMetadata("fileName") .. " depth to " .. newDepth,
							function()
								photo:setPropertyForPlugin( _PLUGIN, 'depth', newDepth )
								photo:setPropertyForPlugin( _PLUGIN, 'waterTemp', temperature )
								photo:setPropertyForPlugin( _PLUGIN, 'runTime', relTime )
								photo:setPropertyForPlugin( _PLUGIN, 'diveNo', diveData.diveNo )

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
	        'xml',
	      },
	    })


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
