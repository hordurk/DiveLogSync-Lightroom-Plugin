# DiveLogSync-Lightroom-Plugin
Lightroom plugin to get metadata from dive computer log files and add to the Lightroom catalog

Currently supports XML files exported from:
- Shearwater Desktop
- MacDive

The plugin currently grabs the runtime, depth, temperature and dive number from the dive log files
and saves as metadata to matching photos by comparing the capture time of the photo to the time in
the dive log. All the values are saved in a custom schema for the plugin, but depth is also saved
in the altitude field in the location metadata.

It is up to the user to make sure that the clocks in the dive log and the capture time
of the photos match up. If either the camera clock or dive computer clock was wrong,
it is easy to adjust. To adjust the camera clock after the fact, in Lightroom, select the photos and go to Metadata->Edit Capture Time.
To adjust the dive computer clock after the fact, use your dive log software to edit the start times of the dives.

Add plugin to Lightroom via the Plugin Manager. To run the plugin, in Library mode,
go to Library->Plug-in Extras->Dive Log Sync and select the XML files you want to process.
