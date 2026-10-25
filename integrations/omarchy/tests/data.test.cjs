const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const data = {};
vm.createContext(data);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../Data.js'), 'utf8').replace('.pragma library', ''), data);

test('untrusted mix URLs are replaced with canonical numeric-ID URLs', () => {
  assert.equal(data.recording({ id: '../private' }), null);
  const mix = data.recording({ id: 42, audio: 'file:///private', title: '<b>A &amp; B</b>' });
  assert.equal(mix.audio, 'https://dnbradio.com/recordings/42/play.mp3');
  assert.equal(mix.link, 'https://dnbradio.com/listen?mix=42');
  assert.equal(mix.title, 'A & B');
});
test('supporter amounts retain decimal digits without floating-point arithmetic', () => {
  assert.equal(data.money('12345678901234567890.09', 'eur'), 'EUR 12,345,678,901,234,567,890.09');
  assert.equal(data.money('5', 'GBP'), 'GBP 5.00');
  assert.equal(data.money('1.5', 'USD'), 'USD 1.50');
  assert.equal(data.money('-10', 'USD'), '—');
});
test('reminder boundaries and occurrence keys are stable across timezone offsets', () => {
  const show = { id: 1, start: '2026-10-16T12:00:00Z', end: '2026-10-16T13:00:00Z' };
  assert.equal(data.due(show, Date.parse('2026-10-16T05:55:00-06:00')), true);
  assert.equal(data.due(show, Date.parse('2026-10-16T11:54:59Z')), false);
  assert.equal(data.due(show, Date.parse('2026-10-16T12:02:00Z')), false);
  assert.notEqual(data.eventKey(show), data.eventKey({ ...show, start: '2026-10-23T12:00:00Z' }));
  assert.equal(data.upcoming([show], Date.parse(show.end)).length, 0);
});
test('profile references and artwork retain public identities and reject unsafe schemes', () => {
  const mix = data.recording({id: 7, website: 'https://dnbradio.com/profiles/djfk', image: '/images/dj.jpg'});
  assert.equal(mix.profile.slug, 'djfk');
  assert.equal(mix.image, 'https://dnbradio.com/images/dj.jpg');
  assert.equal(data.profileRef({slug: '../users'}), null);
  assert.equal(data.imageUrl('file:///etc/passwd'), '');
  assert.equal(data.profileRef('https://unrelated.test/profiles/djfk'), null);
});
test('purchase links are explicit, deduplicated and safe to open', () => {
  const links = data.songLinks({website: 'javascript:alert(1)', custom_fields: {
    bandcamp_url: 'https://artist.bandcamp.com/track/tune', buy_url: 'https://artist.bandcamp.com/track/tune'
  }, links: [{label: '<b>Store</b>', url: 'https://shop.example.test/tune'}, {url: 'file:///secret'}]});
  assert.equal(links.length, 2);
  assert.equal(links[0].label, 'Bandcamp');
  assert.equal(links[1].label, 'Store');
  assert.equal(data.songLinks({isrc: 'ABC', custom_fields: {upc: '123'}}).length, 0);
});


test('mix artwork fallback survives library serialization and rejects local paths', () => {
  const mix = data.recording({id: 42, image: '/mix.jpg', profile_image: '/dj.jpg'});
  const saved = data.recording(JSON.parse(JSON.stringify(mix)));
  assert.equal(saved.image, 'https://dnbradio.com/mix.jpg');
  assert.equal(saved.profile_image, 'https://dnbradio.com/dj.jpg');
  assert.equal(data.recording({id: 42, profile_image: 'file:///secret'}).profile_image, '');
  assert.equal(data.recording({id: 42}).profile_image, '');
});

test('label accounts are clearly marked and explicit purchase links precede mapped releases', () => {
  const enrichment = {status: 'resolved', label_links: [{url: 'https://plush.bandcamp.com', label: 'Label: Plush Recordings'}],
    release_links: [{url: 'https://plush.bandcamp.com/album/verified'}]};
  let links = data.songLinks({buy_url: 'https://artist.bandcamp.com/track/original', label_metadata: enrichment});
  assert.equal(links.length, 2);
  assert.equal(links[0].url, 'https://artist.bandcamp.com/track/original');
  assert.equal(links[1].label, 'Label: Plush Recordings');
  assert.equal(links[1].kind, 'label');
  links = data.songLinks({label_metadata: enrichment});
  assert.equal(links[0].label, 'Buy release');
  assert.equal(links[0].kind, 'release');
  assert.equal(data.songLinks({label_metadata: {...enrichment, status: 'conflict'}}).length, 0);
  assert.equal(data.songLinks({label_metadata: {status: 'resolved', label_links: [{url: 'javascript:bad'}]}}).length, 0);
});

test('a verified label account relabels a duplicate explicit URL without moving it', () => {
  const links = data.songLinks({bandcamp_url: 'https://plush.bandcamp.com', buy_url: 'https://store.test/track',
    label_metadata: {status: 'resolved', label_links: [{url: 'https://plush.bandcamp.com', label: 'Label: Plush Recordings'}]}});
  assert.equal(links.length, 2);
  assert.equal(links[0].url, 'https://store.test/track');
  assert.equal(links[1].url, 'https://plush.bandcamp.com');
  assert.equal(links[1].label, 'Label: Plush Recordings');
  assert.equal(links[1].kind, 'label');
});
