local LrPrefs 		= import 'LrPrefs'

require "Utils"

local DLSdefaults = {
  showMetadataDialog = true,
  units = 'ft',
}

outputToLog("Plugin loaded.")
local function setDefaultPreferences()
  local prefs = LrPrefs.prefsForPlugin()

  for k,v in pairs(DLSdefaults) do
    if prefs[k] == nil then
      prefs[k] = v
    end
  end

  for k,cat in pairs(DLSpropertyDefinitions) do
    for i,prop in pairs(cat) do
      prop_populate = prop.id .. "_populate"
      prop_overwrite = prop.id .. "_overwrite"
      if prefs[prop_populate] == nil then
        prefs[prop_populate] = true
      end
      if prefs[prop_overwrite] == nil then
        prefs[prop_overwrite] = true
      end
    end
  end
end
setDefaultPreferences()
