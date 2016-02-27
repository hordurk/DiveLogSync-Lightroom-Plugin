--[[----------------------------------------------------------------------------

Info.lua
MyMetadata.lrplugin

--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2008 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 5.0,

	LrToolkitIdentifier = 'us.hordur.divelogsync',
	LrPluginName = "Dive log sync",
	LrPluginInfoUrl = "https://hordur.us",
	LrMetadataProvider = 'DiveLogMetadataDefs.lua',
	LrMetadataTagsetFactory = 'DiveLogTagset.lua',

  LrLibraryMenuItems = {
    {
      title = 'Dive Log Sync',
      file = 'DiveLogSync.lua',
    },
  },



	VERSION = { major=1, minor=0, revision=0, build=1, },

}
