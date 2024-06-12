const { describe, it } = require('node:test');
const assert = require('node:assert');
const path = require('node:path');

const ExtendedConfigParser = require('../hooks/lib/ExtendedConfigParser');

describe('ExtendedConfigParser test', async () => {
  it('should return undefined when <universal-links> is missing', () => {
    const mockConfig = path.join(__dirname, 'mock/no-configs.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.strictEqual(actual, undefined);
  });

  it('should return empty config block when <universal-links> exists but empty', () => {
    const mockConfig = path.join(__dirname, 'mock/empty-universal-links.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.deepStrictEqual(actual, { hosts: [], iosTeamId: null });
  });

  it('should set iosTeamID when <ios-team-id> has value', () => {
    const mockConfig = path.join(__dirname, 'mock/ios-team-id.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.deepStrictEqual(actual, { hosts: [], iosTeamId: 'foobar' });
  });

  it('should use default scheme & wildcard path when missing on <host>', () => {
    const mockConfig = path.join(__dirname, 'mock/host-missing-scheme.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.deepStrictEqual(actual, {
      hosts: [
        {name: '*.users.example.com', paths: ['*'], scheme: 'http'}
      ],
      iosTeamId: null
    });
  });

  it('should use set scheme to https when set on <host>', () => {
    const mockConfig = path.join(__dirname, 'mock/host-https-scheme.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.deepStrictEqual(actual, {
      hosts: [
        {name: '*.users.example.com', paths: ['*'], scheme: 'https'}
      ],
      iosTeamId: null
    });
  });

  it('should ... when event is set on <host>', { skip: true }, () => {
    const mockConfig = path.join(__dirname, 'mock/host-event.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.deepStrictEqual(actual, {
      hosts: [
        {name: '*.users.example.com', paths: ['*'], scheme: 'https'}
      ],
      iosTeamId: null
    });
  });

  it('should set path when <path> is defined inside <host>', () => {
    const mockConfig = path.join(__dirname, 'mock/host-defined-path.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.deepStrictEqual(actual, {
      hosts: [
        {name: '*.users.example.com', paths: ['/some/path1'], scheme: 'https'}
      ],
      iosTeamId: null
    });
  });

  it('should set path to wildcard and and ignore other paths when wildcard exists', () => {
    const mockConfig = path.join(__dirname, 'mock/host-defined-path-with-wildcard.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.deepStrictEqual(actual, {
      hosts: [
        {name: '*.users.example.com', paths: ['*'], scheme: 'https'}
      ],
      iosTeamId: null
    });
  });

  it('should remove empty paths when url is missing.', () => {
    const mockConfig = path.join(__dirname, 'mock/host-defined-path-missing-url.xml');
    const configParser = new ExtendedConfigParser(mockConfig);

    const actual = configParser.getUniversalLinks();
    assert.deepStrictEqual(actual, {
      hosts: [
        {name: '*.users.example.com', paths: ['/some/path1', '/some/path3'], scheme: 'https'}
      ],
      iosTeamId: null
    });
  });
});
