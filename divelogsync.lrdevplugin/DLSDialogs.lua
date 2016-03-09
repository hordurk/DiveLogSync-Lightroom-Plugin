-- Lightroom SDK
local LrBinding		= import 'LrBinding'
local LrDialogs		= import 'LrDialogs'
local LrFileUtils	= import 'LrFileUtils'
local LrHttp 		= import 'LrHttp'
local LrPathUtils 	= import 'LrPathUtils'
local LrPrefs 		= import 'LrPrefs'
local LrShell 		= import 'LrShell'
local LrView 		= import 'LrView'

require "Utils"

local bind 				= LrView.bind
local share 			= LrView.share
local negativeOfKey 	= LrBinding.negativeOfKey
local conditionalItem 	= LrView.conditionalItem

DLSDialogs = {}

local function generateCheckboxTable(props, plugin, content, f)
  for k, prop in pairs(props) do
    if (plugin and prop.plugin ~= nil) or (not plugin and prop.plugin == nil) then

      prop_populate = prop.id .. "_populate"
      prop_overwrite = prop.id .. "_overwrite"

      content[#content+1] = f:row {
        fill_horizontal = 1,
        spacing = f:label_spacing(),
        f:static_text {
          title = prop.title,
          width = LrView.share "label_width",
        },
        f:checkbox {
          title = "",
          width = LrView.share("populate_width"),
          value = bind(prop_populate),
        },
        f:checkbox {
          title = "",
          value = bind(prop_overwrite),
        },
      }
    end
  end
end

function DLSDialogs.metadataSelectView(f, pt)
  local content = {
    title = "Select metadata",
    bind_to_object = pt,
  }

  content[#content+1] = f:row {
    fill_horizontal = 1,
    spacing = f:control_spacing(),
    f:static_text {
      title = "Lightroom metadata fields",
    },
  }

  content[#content+1] = f:row {
    fill_horizontal = 1,
    spacing = f:label_spacing(),
    f:static_text {
      title = "",
      width = LrView.share "label_width",
    },
    f:static_text {
      title = "Populate",
      width = LrView.share "populate_width",

    },
    f:static_text {
      title = "Overwrite"
    },
  }


  generateCheckboxTable(DLSpropertyDefinitions, false, content, f)

  content[#content+1] = f:separator {
    margin_top = 100,

    fill_horizontal = 1,
  }

  content[#content+1] = f:row {
    fill_horizontal = 1,
    spacing = f:control_spacing(),
    f:static_text {
      title = "Dive Log Sync metadata fields",
    },
  }

  content[#content+1] = f:row {
    fill_horizontal = 1,
    spacing = f:label_spacing(),
    f:static_text {
      title = "",
      width = LrView.share "label_width",
    },
    f:static_text {
      title = "Populate",
      width = LrView.share "populate_width",

    },
    f:static_text {
      title = "Overwrite"
    },
  }

  generateCheckboxTable(DLSpropertyDefinitions, true, content, f)

  content[#content+1] = f:static_text {
      title = [[When 'Populate' is selected, data from log file for that property will be copied only if the property is empty in Lightroom.
When 'Overwrite' is selected, data from log file for that property will be copied only if the property is not empty in Lightroom.
If the field is empty in the dive log it will never be copied over.]],
      width = 500,
    }


  content[#content+1] = f:separator {
    fill_horizontal = 1,
  }

  content[#content+1] = f:row {
    fill_horizontal = 1,
    spacing = f:label_spacing(),
    f:checkbox {
      title = "Update video metadata?",
      value = bind("doVideos"),
    },
  }

  content[#content+1] = f:row {
    fill_horizontal = 1,
    spacing = f:label_spacing(),
    f:checkbox {
      title = "Always show this dialog?",
      value = bind("showMetadataDialog"),
    },
  }

  return f:view(content)

end
