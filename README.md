# DiveLogSync-Lightroom-Plugin
Lightroom plugin to get metadata from dive computer log files and add to the Lightroom catalog

Currently supports XML files exported from:
- Shearwater Desktop
- MacDive
- Diving Log
- UDDF (not properly tested yet)

For other formats, please add a feature request and supply a sample file and I will see about implementing it.

The plugin has been tested on the following platforms:
- OS X, Lightroom CC 2015.4
- Windows 8.1, Lightroom CC 2015.4

The parser is not yet robust to versioning of these formats, so old versions of those may not work as expected.

The plugin currently grabs the runtime, depth, temperature, dive number, dive identifier, dive site and location from the dive log files
and saves as metadata to matching photos/videos by comparing the capture time of the photo/video to the time in
the dive log. Location data is saved to built in Lightroom fields while the others are saved to the plugin's custom metadata fields.
The user configure which fields should be transferred over.

It is up to the user to make sure that the clocks in the dive log and the capture time
of the photos match up. If either the camera clock or dive computer clock was wrong,
it is easy to adjust. To adjust the camera clock after the fact, in Lightroom, select the photos and go to Metadata->Edit Capture Time.
To adjust the dive computer clock after the fact, use your dive log software to edit the start times of the dives. Note that at least for some cameras, the date for videos has a timezone offset.

Add plugin to Lightroom via the Plugin Manager. To run the plugin, in Library mode,
go to Library->Plug-in Extras->Dive Log Sync and select the XML files you want to process.

If you encounter an error after updating the plugin, try to exit Lightroom and start it again and go to the plugin manager and try to reload the plugin.
