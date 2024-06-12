/**
Hook is executed at the end of the 'prepare' stage. Usually, when you call 'cordova build'.

It will inject required preferences in the platform-specific projects, based on <universal-links>
data you have specified in the projects config.xml file.
*/

const path = require('node:path');

var androidManifestWriter = require('./lib/android/manifestWriter.js');
var androidWebHook = require('./lib/android/webSiteHook.js');
var iosProjectEntitlements = require('./lib/ios/projectEntitlements.js');
var iosAppSiteAssociationFile = require('./lib/ios/appleAppSiteAssociationFile.js');
const ExtendedConfigParser = require('./lib/ExtendedConfigParser.js');
const { CONFIG_FILE_NAME, PLATFORM_ANDROID, PLATFORM_IOS } = require('./lib/constants.js')

module.exports = function(ctx) {
  run(ctx);
};

/**
 * Execute hook.
 *
 * @param {Object} cordovaContext - cordova context object
 */
function run(cordovaContext) {
  const configFilePath = path.join(cordovaContext.opts.projectRoot, CONFIG_FILE_NAME);
  const configFile = new ExtendedConfigParser(configFilePath);
  const pluginPreferences = configFile.getUniversalLinks();
  var platformsList = cordovaContext.opts.platforms;

  // if no preferences are found - exit
  if (!pluginPreferences) {
    return;
  }

  // if no host is defined - exit
  if (pluginPreferences.hosts === null || pluginPreferences.hosts.length === 0) {
    console.warn('No host is specified in the config.xml. Universal Links plugin is not going to work.');
    return;
  }

  platformsList.forEach(function(platform) {
    switch (platform) {
      case PLATFORM_ANDROID:
          activateUniversalLinksInAndroid(cordovaContext, pluginPreferences);
          break;
      case PLATFORM_IOS:
          activateUniversalLinksInIos(cordovaContext, pluginPreferences);
          break;
    }
  });
}

/**
 * Activate Deep Links for Android application.
 *
 * @param {Object} cordovaContext - cordova context object
 * @param {Object} pluginPreferences - plugin preferences from the config.xml file. Basically, content from <universal-links> tag.
 */
function activateUniversalLinksInAndroid(cordovaContext, pluginPreferences) {
  // inject preferenes into AndroidManifest.xml
  androidManifestWriter.writePreferences(cordovaContext, pluginPreferences);

  // generate html file with the <link> tags that you should inject on the website.
  androidWebHook.generate(cordovaContext, pluginPreferences);
}

/**
 * Activate Universal Links for iOS application.
 *
 * @param {Object} cordovaContext - cordova context object
 * @param {Object} pluginPreferences - plugin preferences from the config.xml file. Basically, content from <universal-links> tag.
 */
function activateUniversalLinksInIos(cordovaContext, pluginPreferences) {
  // generate entitlements file
  iosProjectEntitlements.generateAssociatedDomainsEntitlements(cordovaContext, pluginPreferences);

  // generate apple-site-association-file
  iosAppSiteAssociationFile.generate(cordovaContext, pluginPreferences);
}
