.pragma library

function plain(value) {
  return String(value || "").replace(/<br\s*\/?\s*>/gi, "\n").replace(/<[^>]*>/g, "")
    .replace(/&(?:amp|lt|gt|quot|apos|nbsp|#39);/g, function(s) {
      return {"&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&apos;": "'", "&#39;": "'", "&nbsp;": " "}[s];
    });
}
function recording(row) {
  var id = String(row.id || ((row.audio || "").match(/\/recordings\/(\d+)\//) || [])[1] || "");
  if (!/^\d+$/.test(id)) return null;
  return {id: id, title: plain(row.title), artist: plain(row.artist || "DNBRADIO archive"),
    description: plain(row.description), tracklist: plain(row.tracklist), genre: plain(row.genre),
    plays: Number(row.plays || 0), image: imageUrl(row.image), profile_image: imageUrl(row.profile_image), profile: profileRef(row.profile || row.website),
    date: row.timestamp || row.date || "", audio: "https://dnbradio.com/recordings/" + id + "/play.mp3",
    link: "https://dnbradio.com/listen?mix=" + id};
}
function webUrl(value) {
  var url = String(value || "").trim();
  return /^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/i.test(url) ? url : "";
}
function imageUrl(value) {
  var url = String(value || "");
  if (url.charAt(0) === "/" && url.charAt(1) !== "/") url = "https://dnbradio.com" + url;
  return webUrl(url);
}
function profileRef(value) {
  if (!value) return null;
  var slug = typeof value === "object" ? value.slug : (String(value).match(/^https:\/\/dnbradio\.com\/profiles\/([a-z0-9_-]+)\/?$/i) || [])[1];
  if (!/^[a-z0-9_-]+$/i.test(slug || "")) return null;
  return {slug: slug, name: plain(value.name || slug), url: "https://dnbradio.com/profiles/" + slug};
}
function songLinks(song) {
  if (!song) return [];
  var links = [], seen = {};
  function add(value, label) {
    var url = webUrl(value);
    if (!url || seen[url]) return;
    seen[url] = true;
    var host = url.replace(/^https?:\/\//i, "").split("/")[0].toLowerCase();
    links.push({url: url, label: /(^|\.)bandcamp\.com$/.test(host) ? "Bandcamp" : /(^|\.)beatport\.com$/.test(host) ? "Beatport" : plain(label || "Track website")});
  }
  [song, song.custom_fields || {}].forEach(function(fields) {
    ["purchase_url", "buy_url", "bandcamp_url", "bandcamp", "website", "url"].forEach(function(key) {
      add(fields[key], /buy|purchase/.test(key) ? "Buy track" : "Track website");
    });
  });
  if (Array.isArray(song.links)) song.links.forEach(function(link) { add(link.url, link.label); });
  return links;
}
function relativeTime(timestamp, now) {
  var seconds = Math.floor((now - Number(timestamp) * 1000) / 1000);
  if (!isFinite(seconds) || seconds < 0) return "";
  if (seconds < 60) return "Just now";
  if (seconds < 3600) return Math.floor(seconds / 60) + " min ago";
  return Math.floor(seconds / 3600) + " hr ago";
}
function startsIn(event, now) {
  var minutes = Math.ceil((Date.parse(event.start) - now) / 60000);
  if (minutes <= 0) return "On air now";
  return minutes < 60 ? "In " + minutes + " min" : "In " + Math.floor(minutes / 60) + "h " + (minutes % 60) + "m";
}
function money(amount, currency) {
  var match = String(amount).match(/^(\d+)(?:\.(\d+))?$/);
  if (!match) return "—";
  return String(currency || "USD").toUpperCase() + " " + match[1].replace(/\B(?=(\d{3})+(?!\d))/g, ",") + "." + ((match[2] || "") + "00").slice(0, 2);
}
function eventKey(event) { return String(event.id) + ":" + event.start; }
function upcoming(rows, now) {
  return rows.filter(function(r) { return isFinite(Date.parse(r.start)) && Date.parse(r.end) > now; })
    .sort(function(a, b) { return Date.parse(a.start) - Date.parse(b.start); });
}
function due(event, now) {
  var start = Date.parse(event.start);
  return isFinite(start) && start - now <= 300000 && now - start < 120000;
}
