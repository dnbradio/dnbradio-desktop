.pragma library

var stations = [
  {id: "dnbradio", name: "DNBRADIO", description: "Live DJs · every flavor of drum & bass", streams: [
    {label: "320K MP3", url: "https://azura.drmnbss.org/listen/dnbradio/radio.mp3", macPrebufferMs: 2500},
    {label: "128K AAC", url: "https://azura.drmnbss.org/listen/dnbradio/radio.aac"}]},
  {id: "plushrecs", name: "Atmospheric", description: "Plush Recordings · deep & atmospheric", streams: [
    {label: "320K MP3", url: "https://azura.drmnbss.org/listen/plushrecs/radio.mp3"}]},
  {id: "jungletrain.net", name: "JungleTrain", description: "Jungle & breakbeats · JungleTrain.net", streams: [
    {label: "256K MP3", url: "https://a7.asurahosting.com:7880/woodsiaalpina"}]},
  {id: "section8recs", name: "Section 8", description: "Section 8 Recordings · dark drum & bass", streams: [
    {label: "128K MP3", url: "https://azura.drmnbss.org/listen/section8recs/radio.mp3"}]},
  {id: "darkstep", name: "Darkstep", description: "Darkstep, techstep & neuro", streams: [
    {label: "128K AAC", url: "https://azura.drmnbss.org/listen/darkstep/radio.mp3"}]},
  {id: "bassdrive", name: "Bassdrive", description: "Worldwide drum & bass radio", streams: [
    {label: "128K MP3", url: "https://ice.bassdrive.net/stream"},
    {label: "32K AAC", url: "https://ice.bassdrive.net/stream32"}]}
];

function time(milliseconds) {
  var seconds = Math.max(0, Math.floor(milliseconds / 1000));
  var minutes = Math.floor(seconds / 60);
  return minutes + ":" + (seconds % 60 < 10 ? "0" : "") + seconds % 60;
}
