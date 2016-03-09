# DiveLogSync-Lightroom-Plugin

### About
DiveLogSync is a plugin for Adobe Lightroom to get metadata from dive computer log files and add to the Lightroom catalog

The plugin currently tries to extract
- runtime
- depth
- temperature
- dive number
- dive identifier
- dive site (site name, city/province, country)
- location

from the dive log files and saves as metadata to matching photos/videos by comparing the capture time of the photo/video to the time in
the dive log. Location and altitude (depth) data is saved to built in Lightroom fields while the others are saved to the plugin's custom metadata fields.
The user can configure which fields should be transferred over.


### Supported formats

It currently supports XML files exported from:
- MacDive
- Diving Log (Tested with exports from 6.0)
- Shearwater Desktop

In development:
- UDDF (not properly tested yet)
- UDCF

For other formats, please add a feature request and supply a sample file and I will see about implementing it.

The parser is not yet robust to versioning of these formats, so old versions of those may not work as expected.


### Installation

The plugin requires Lightroom 5.0 or newer, but is currently only tested on the following platforms:
- OS X, Lightroom CC 2015.4
- Windows 8.1, Lightroom CC 2015.4

Add the plugin to Lightroom via the Plugin Manager. To run the plugin, in Library mode,
go to Library->Plug-in Extras->Dive Log Sync and select the XML files you want to process.

If you encounter an error after updating the plugin, try to exit Lightroom and start it again and go to the plugin manager and try to reload the plugin.

### Usage notes

Since the plugin uses timestamps to match photos to dive profiles, it is up to the user to make sure that the clocks in the dive log and the capture time
of the photos match up. If either the camera clock or dive computer clock was wrong,
it is easy to adjust. To adjust the camera clock after the fact, in Lightroom, select the photos and go to Metadata->Edit Capture Time.

Note that at least for some cameras, the date for videos may have a timezone offset.

To adjust the dive computer clock after the fact, use your dive log software to edit the start times of the dives.


### Problems?

If you get errors while importing, please file an issue on Github.

In order to debug, I'll need a debug log file from the plugin: Go to the plugin manager and set the plugin to write a debug log. Then run the import again. The log file, "Lr_DiveSyncLog.log" should be saved to your Documents directory. Please attach that file to the issue you create.
