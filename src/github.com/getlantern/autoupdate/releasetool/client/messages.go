package client

// AssetResponse is the message that arrives after uploading an asset.
type AssetResponse struct {
	URL string `json:"Uri"`
}

// AnnouncementAsset is the part of the Announcement that describes properties
// of an asset.
type AnnouncementAsset struct {
	URL       string            `json:"url"`
	Checksum  string            `json:"checksum"`
	Signature string            `json:"signature"`
	Tags      map[string]string `json:"tags"`
}

// Announcement can be used to publish a release.
type Announcement struct {
	Version string              `json:"version"`
	Tags    map[string]string   `json:"tags"`
	Active  bool                `json:"active"`
	Assets  []AnnouncementAsset `json:"assets"`
}
