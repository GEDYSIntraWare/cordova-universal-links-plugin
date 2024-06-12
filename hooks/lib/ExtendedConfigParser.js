const { ConfigParser } = require('cordova-common');

const { DEFAULT_SCHEME, PLATFORM_ANDROID, PLATFORM_IOS } = require('./constants.js')

class ExtendedConfigParser extends ConfigParser {
  getPackageName (platform) {
    let packageName;

    switch (platform) {
      case PLATFORM_ANDROID:
        packageName = this.android_packageName();
        break;
      case PLATFORM_IOS:
        packageName = this.ios_CFBundleIdentifier();
        break;
    }

    if (packageName === undefined || packageName.length == 0) {
      packageName = this.packageName();
    }

    return packageName;
  }

  /**
  * Returns the privacy manifest node, if available.
  * Otherwise `null` is returned.
  */
  getUniversalLinks () {
    const universalLinks = this.doc.find('./universal-links');

    if (!universalLinks) {
      console.warn('<universal-links> tag is not set in the config.xml. Universal Links plugin is not going to work.');
      return;
    }

    const iosTeamIdEl = universalLinks.find('./ios-team-id');
    const iosTeamId = iosTeamIdEl && iosTeamIdEl.attrib.value || null;

    const hosts = universalLinks.findall('./host').map(host => ({
      scheme: host.attrib.scheme || DEFAULT_SCHEME,
      name: host.attrib.name || '',
      paths: extractPathUrlsFromHost(host)
    }));

    return { hosts, iosTeamId }
  }
}

function extractPathUrlsFromHost(host) {
  const paths = host.findall('./path');

  if (paths.length === 0) {
    return ['*'];
  }

  const urls = paths.map(path => path.attrib.url)
    .filter(path => !!path);

  if (urls.includes('*')) {
    return ['*'];
  }

  return urls;
}

module.exports = ExtendedConfigParser;
