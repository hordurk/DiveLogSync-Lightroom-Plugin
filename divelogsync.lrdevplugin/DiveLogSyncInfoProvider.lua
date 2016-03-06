local LrHttp = import "LrHttp"
local LrView = import "LrView"
local LrPrefs = import "LrPrefs"
local LrBinding = import "LrBinding"

require "Utils"
require "DLSDialogs"

local bind = LrView.bind

local pluginInfoProvider = {}

function pluginInfoProvider.startDialog(pt)
  outputToLog('startDialog')
  local prefs = LrPrefs.prefsForPlugin()

  for k,v in prefs:pairs() do
    pt[k]=v
  end

end

function pluginInfoProvider.endDialog(pt)
  local prefs = LrPrefs.prefsForPlugin()
  for k,v in pt:pairs() do
    prefs[k]=v
  end
end

function pluginInfoProvider.sectionsForTopOfDialog(f, pt)
  return {
			-- Section for the top of the dialog.
      {
				title = "Plugin",
				f:row {
					spacing = f:control_spacing(),
          f:static_text {
            fill_horizontal = 1,
            title = "Dive Log Sync"
          },

				},
      },
			{
				title = "Settings",
        bind_to_object = pt,

				f:row {
					spacing = f:control_spacing(),

					f:checkbox {
						title = "Show metadata selection dialog every time",
						value = bind('showMetadataDialog'),
					},
				},

        f:row {
					spacing = f:control_spacing(),

					f:checkbox {
						title = "Write debug log",
						value = bind('writeDebugLog'),
					},
				},

        f:row {
          f:group_box { -- the buttons in this container make a set title = "Radio Buttons",
            fill_horizontal = 1,
            spacing = f:control_spacing(),
            f:static_text {
              fill_horizontal = 1,
              title = "Units: "
            },
            f:radio_button {
              title = "Metric",
              value = bind 'units',
              checked_value = 'm',
            },
            f:radio_button {
              title = "Imperial",
              value = bind 'units',
              checked_value = 'ft',
            },
          },
        },
        DLSDialogs.metadataSelectView(f,pt),

      },

    }

end

return pluginInfoProvider
