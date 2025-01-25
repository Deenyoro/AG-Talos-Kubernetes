RADARR_API_KEY = process.env.RADARR_API_KEY
SONARR_API_KEY = process.env.SONARR_API_KEY
PROWLARR_API_KEY = process.env.PROWLARR_API_KEY


module.exports = {
  action: "inject",
  apiKey: process.env.CROSS_SEED_API_KEY,
  delay: 30,
  includeNonVideos: true,
  includeSingleEpisodes: true,
  linkCategory: "cross-seed",
  linkDirs: [
    "/mnt/QuadSquad/EC/Downloads/Torrents/cross-seed"
  ],
  linkType: "hardlink",
  matchMode: "partial",
  outputDir: "/tmp",
  port: Number(process.env.CROSS_SEED_PORT),
  qbittorrentUrl: String(process.env.CROSS_SEED_QBITURL),
  sonarr: ["http://sonarr.media.svc.cluster.local/?apikey=$SONARR_API_KEY"],
  radarr: ["http://radarr.media.svc.cluster.local/?apikey=$RADARR_API_KEY"],
  torznab: [
    1,
    2,
    5,
  ].map(i => `http://prowlarr.media.svc.cluster.local/$${i}/api?apikey=$PROWLARR_API_KEY`),
  dataDirs: [
    "/mnt/QuadSquad/EC/Downloads/SABnzbd/Completed"
  ],
};
