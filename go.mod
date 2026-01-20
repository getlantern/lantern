module github.com/getlantern/lantern

go 1.25.4

// replace github.com/getlantern/radiance => ../radiance

// replace github.com/getlantern/lantern-server-provisioner => ../lantern-server-provisioner

// replace github.com/sagernet/sing-box => ../sing-box-minimal

replace github.com/sagernet/sing => github.com/getlantern/sing v0.7.14-0.20251208213946-adbf4abe8692

replace github.com/sagernet/sing-box => github.com/getlantern/sing-box-minimal v1.12.13-0.20251205011046-be268b083378

replace github.com/sagernet/wireguard-go => github.com/getlantern/wireguard-go v0.0.1-beta.7.0.20251208214020-d78e69f1eff4

replace google.golang.org/genproto v0.0.0-20211118181313-81c1377c94b1 => google.golang.org/genproto v0.0.0-20250715232539-7130f93afb79

replace github.com/tetratelabs/wazero => github.com/refraction-networking/wazero v1.7.1-w

require (
	github.com/Microsoft/go-winio v0.6.2
	github.com/alecthomas/assert/v2 v2.3.0
	github.com/getlantern/golog v0.0.0-20230503153817-8e72de7e0a65
	github.com/getlantern/lantern-server-provisioner v0.0.0-20251031121934-8ea031fccfa9
	github.com/getlantern/radiance v0.0.0-20260120014312-1b2faa4d38b5
	github.com/sagernet/sing-box v1.12.13
	golang.org/x/mobile v0.0.0-20250711185624-d5bb5ecc55c0
	golang.org/x/sys v0.40.0
	google.golang.org/protobuf v1.36.11
	howett.net/plist v1.0.1
)

require (
	github.com/ajg/form v1.5.1 // indirect
	github.com/andybalholm/brotli v1.2.0 // indirect
	github.com/caddyserver/certmagic v0.25.1 // indirect
	github.com/caddyserver/zerossl v0.1.4 // indirect
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
	github.com/fsnotify/fsnotify v1.9.0
	github.com/getlantern/context v0.0.0-20220418194847-3d5e7a086201 // indirect
	github.com/getlantern/errors v1.0.4 // indirect
	github.com/getlantern/hex v0.0.0-20220104173244-ad7e4b9194dc // indirect
	github.com/getlantern/hidden v0.0.0-20220104173330-f221c5a24770 // indirect
	github.com/getlantern/ops v0.0.0-20231025133620-f368ab734534 // indirect
	github.com/go-chi/chi/v5 v5.2.4
	github.com/go-chi/render v1.0.3 // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/go-ole/go-ole v1.3.0
	github.com/go-stack/stack v1.8.1 // indirect
	github.com/gobwas/httphead v0.1.0 // indirect
	github.com/gobwas/pool v0.2.1 // indirect
	github.com/gofrs/uuid/v5 v5.4.0 // indirect
	github.com/google/btree v1.1.3 // indirect
	github.com/google/go-cmp v0.7.0 // indirect
	github.com/hashicorp/yamux v0.1.2 // indirect
	github.com/insomniacslk/dhcp v0.0.0-20251020182700-175e84fbb167 // indirect
	github.com/klauspost/compress v1.18.3 // indirect
	github.com/klauspost/cpuid/v2 v2.3.0 // indirect
	github.com/libdns/alidns v1.0.6-beta.3 // indirect
	github.com/libdns/cloudflare v0.2.2 // indirect
	github.com/libdns/libdns v1.1.1 // indirect
	github.com/logrusorgru/aurora v2.0.3+incompatible // indirect
	github.com/mdlayher/netlink v1.8.0 // indirect
	github.com/mdlayher/socket v0.5.1 // indirect
	github.com/metacubex/tfo-go v0.0.0-20251204144243-738de9e3cd15 // indirect
	github.com/mholt/acmez/v3 v3.1.4 // indirect
	github.com/miekg/dns v1.1.70 // indirect
	github.com/oxtoacart/bpool v0.0.0-20190530202638-03653db5a59c // indirect
	github.com/pierrec/lz4/v4 v4.1.25 // indirect
	github.com/quic-go/qpack v0.6.0 // indirect
	github.com/sagernet/bbolt v0.0.0-20231014093535-ea5cb2fe9f0a // indirect
	github.com/sagernet/cors v1.2.1 // indirect
	github.com/sagernet/fswatch v0.1.1 // indirect
	github.com/sagernet/gvisor v0.0.0-20250811-sing-box-mod.1 // indirect
	github.com/sagernet/netlink v0.0.0-20240916134442-83396419aa8b // indirect
	github.com/sagernet/nftables v0.3.0-mod.1 // indirect
	github.com/sagernet/quic-go v0.52.0-sing-box-mod.3 // indirect
	github.com/sagernet/sing-mux v0.3.4 // indirect
	github.com/sagernet/sing-quic v0.5.2 // indirect
	github.com/sagernet/sing-shadowsocks v0.2.9 // indirect
	github.com/sagernet/sing-shadowsocks2 v0.2.2 // indirect
	github.com/sagernet/sing-shadowtls v0.2.1-0.20250503051639-fcd445d33c11 // indirect
	github.com/sagernet/sing-vmess v0.2.7 // indirect
	github.com/sagernet/smux v1.5.50-sing-box-mod.1 // indirect
	github.com/sagernet/wireguard-go v0.0.2-beta.1.0.20250917110311-16510ac47288 // indirect
	github.com/sagernet/ws v0.0.0-20231204124109-acfe8907c854 // indirect
	github.com/u-root/uio v0.0.0-20240224005618-d2acac8f3701 // indirect
	github.com/vishvananda/netns v0.0.5 // indirect
	github.com/zeebo/blake3 v0.2.4 // indirect
	go.opentelemetry.io/auto/sdk v1.2.1 // indirect
	go.opentelemetry.io/otel v1.39.0 // indirect
	go.opentelemetry.io/otel/metric v1.39.0 // indirect
	go.opentelemetry.io/otel/trace v1.39.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	go.uber.org/zap v1.27.1 // indirect
	go.uber.org/zap/exp v0.3.0 // indirect
	go4.org/netipx v0.0.0-20231129151722-fdeea329fbba // indirect
	golang.org/x/exp v0.0.0-20260112195511-716be5621a96 // indirect
	golang.org/x/mod v0.32.0 // indirect
	golang.org/x/net v0.49.0 // indirect
	golang.org/x/sync v0.19.0 // indirect
	golang.org/x/text v0.33.0 // indirect
	golang.org/x/time v0.14.0 // indirect
	golang.org/x/tools v0.41.0 // indirect
	golang.zx2c4.com/wintun v0.0.0-20230126152724-0fa3db229ce2
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260120221211-b8f7ae30c516 // indirect
	google.golang.org/grpc v1.78.0 // indirect
	lukechampine.com/blake3 v1.4.1 // indirect
)

require (
	cloud.google.com/go/compute/metadata v0.9.0 // indirect
	filippo.io/edwards25519 v1.1.0 // indirect
	github.com/1Password/srp v0.2.0 // indirect
	github.com/Jigsaw-Code/outline-sdk v0.0.20 // indirect
	github.com/Jigsaw-Code/outline-sdk/x v0.0.8 // indirect
	github.com/RoaringBitmap/roaring v1.9.4 // indirect
	github.com/Xuanwo/go-locale v1.1.3 // indirect
	github.com/ajwerner/btree v0.1.1 // indirect
	github.com/akutz/memconn v0.1.0 // indirect
	github.com/alecthomas/atomic v0.1.0-alpha2 // indirect
	github.com/alecthomas/repr v0.2.0 // indirect
	github.com/alexbrainman/sspi v0.0.0-20250919150558-7d374ff0d59e // indirect
	github.com/alitto/pond/v2 v2.6.0 // indirect
	github.com/anacrolix/chansync v0.7.0 // indirect
	github.com/anacrolix/dht/v2 v2.23.0 // indirect
	github.com/anacrolix/envpprof v1.5.0 // indirect
	github.com/anacrolix/generics v0.2.0 // indirect
	github.com/anacrolix/go-libutp v1.3.2 // indirect
	github.com/anacrolix/log v0.17.0 // indirect
	github.com/anacrolix/missinggo v1.3.0 // indirect
	github.com/anacrolix/missinggo/perf v1.0.0 // indirect
	github.com/anacrolix/missinggo/v2 v2.10.0 // indirect
	github.com/anacrolix/mmsg v1.1.1 // indirect
	github.com/anacrolix/multiless v0.4.0 // indirect
	github.com/anacrolix/stm v0.5.0 // indirect
	github.com/anacrolix/sync v0.6.0 // indirect
	github.com/anacrolix/torrent v1.60.0 // indirect
	github.com/anacrolix/upnp v0.1.4 // indirect
	github.com/anacrolix/utp v0.2.0 // indirect
	github.com/anytls/sing-anytls v0.0.11 // indirect
	github.com/bahlo/generic-list-go v0.2.0 // indirect
	github.com/benbjohnson/immutable v0.4.3 // indirect
	github.com/bits-and-blooms/bitset v1.24.4 // indirect
	github.com/blang/semver v3.5.1+incompatible // indirect
	github.com/blang/vfs v1.0.0 // indirect
	github.com/bradfitz/iter v0.0.0-20191230175014-e8f45d346db8 // indirect
	github.com/cenkalti/backoff/v5 v5.0.3 // indirect
	github.com/cespare/xxhash v1.1.0 // indirect
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/coder/websocket v1.8.14 // indirect
	github.com/coreos/go-iptables v0.8.0 // indirect
	github.com/cretz/bine v0.2.0 // indirect
	github.com/dblohm7/wingoes v0.0.0-20250822163801-6d8e6105c62d // indirect
	github.com/dsnet/compress v0.0.2-0.20210315054119-f66993602bf5 // indirect
	github.com/dustin/go-humanize v1.0.1 // indirect
	github.com/edsrzf/mmap-go v1.2.0 // indirect
	github.com/felixge/fgprof v0.9.5 // indirect
	github.com/felixge/httpsnoop v1.0.4 // indirect
	github.com/flynn/noise v1.1.0 // indirect
	github.com/fxamacker/cbor/v2 v2.9.0 // indirect
	github.com/gaissmai/bart v0.26.0 // indirect
	github.com/gaukas/wazerofs v0.1.0 // indirect
	github.com/getlantern/algeneva v0.0.0-20250307163401-1824e7b54f52 // indirect
	github.com/getlantern/amp v0.0.0-20260113204224-600f8e8dfe5f // indirect
	github.com/getlantern/appdir v0.0.0-20250324200952-507a0625eb01 // indirect
	github.com/getlantern/common v1.2.1-0.20260113231444-c651c79beddf // indirect
	github.com/getlantern/dnstt v0.0.0-20260112160750-05100563bd0d // indirect
	github.com/getlantern/fronted v0.0.0-20260120003233-f451b84d326e // indirect
	github.com/getlantern/geo v0.0.0-20241129152027-2fc88c10f91e // indirect
	github.com/getlantern/keepcurrent v0.0.0-20240126172110-2e0264ca385d // indirect
	github.com/getlantern/kindling v0.0.0-20260112160127-bea07e410e0b // indirect
	github.com/getlantern/lantern-box v0.0.6-0.20260119210044-0a79ae93ede9 // indirect
	github.com/getlantern/lantern-water v0.0.0-20250331153903-07abebe611e8 // indirect
	github.com/getlantern/mtime v0.0.0-20200417132445-23682092d1f7 // indirect
	github.com/getlantern/netx v0.0.0-20251021221514-279deb2cfd40 // indirect
	github.com/getlantern/osversion v0.0.0-20250424174400-d834340603cf // indirect
	github.com/getlantern/pluriconfig v0.0.0-20251126214241-8cc8bc561535 // indirect
	github.com/getlantern/timezone v0.0.0-20210901200113-3f9de9d360c9 // indirect
	github.com/getlantern/tlsdialer/v3 v3.0.6-0.20260105215053-2a1cd54af4d5 // indirect
	github.com/getsentry/sentry-go v0.41.0 // indirect
	github.com/go-json-experiment/json v0.0.0-20251027170946-4849db3c2f7e // indirect
	github.com/go-llsqlite/adapter v0.2.0 // indirect
	github.com/go-llsqlite/crawshaw v0.6.0 // indirect
	github.com/go-resty/resty/v2 v2.17.1 // indirect
	github.com/go-viper/mapstructure/v2 v2.5.0 // indirect
	github.com/gobwas/ws v1.4.0 // indirect
	github.com/goccy/go-yaml v1.19.2 // indirect
	github.com/godbus/dbus/v5 v5.2.2 // indirect
	github.com/golang-jwt/jwt/v5 v5.3.0 // indirect
	github.com/golang/groupcache v0.0.0-20241129210726-2c02b8208cf8 // indirect
	github.com/golang/snappy v1.0.0 // indirect
	github.com/google/nftables v0.3.0 // indirect
	github.com/google/pprof v0.0.0-20260115054156-294ebfa9ad83 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/gorilla/websocket v1.5.3 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.27.4 // indirect
	github.com/hdevalence/ed25519consensus v0.2.0 // indirect
	github.com/hexops/gotextdiff v1.0.3 // indirect
	github.com/huandu/xstrings v1.5.0 // indirect
	github.com/jsimonetti/rtnetlink v1.4.2 // indirect
	github.com/klauspost/pgzip v1.2.6 // indirect
	github.com/klauspost/reedsolomon v1.13.0 // indirect
	github.com/knadh/koanf/maps v0.1.2 // indirect
	github.com/knadh/koanf/parsers/json v1.0.0 // indirect
	github.com/knadh/koanf/providers/rawbytes v1.0.0 // indirect
	github.com/knadh/koanf/v2 v2.3.0 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/metacubex/utls v1.8.4 // indirect
	github.com/mholt/archiver/v3 v3.5.1 // indirect
	github.com/minio/sha256-simd v1.0.1 // indirect
	github.com/mitchellh/copystructure v1.2.0 // indirect
	github.com/mitchellh/go-ps v1.0.0 // indirect
	github.com/mitchellh/reflectwalk v1.0.2 // indirect
	github.com/mr-tron/base58 v1.2.0 // indirect
	github.com/mschoch/smat v0.2.0 // indirect
	github.com/multiformats/go-multihash v0.2.3 // indirect
	github.com/multiformats/go-varint v0.1.0 // indirect
	github.com/ncruces/go-strftime v1.0.0 // indirect
	github.com/nwaples/rardecode v1.1.3 // indirect
	github.com/oschwald/geoip2-golang v1.13.0 // indirect
	github.com/oschwald/maxminddb-golang v1.13.1 // indirect
	github.com/pion/datachannel v1.6.0 // indirect
	github.com/pion/dtls/v3 v3.0.10 // indirect
	github.com/pion/ice/v4 v4.2.0 // indirect
	github.com/pion/interceptor v0.1.43 // indirect
	github.com/pion/logging v0.2.4 // indirect
	github.com/pion/mdns/v2 v2.1.0 // indirect
	github.com/pion/randutil v0.1.0 // indirect
	github.com/pion/rtcp v1.2.16 // indirect
	github.com/pion/rtp v1.10.0 // indirect
	github.com/pion/sctp v1.9.2 // indirect
	github.com/pion/sdp/v3 v3.0.17 // indirect
	github.com/pion/srtp/v3 v3.0.10 // indirect
	github.com/pion/stun/v3 v3.1.1 // indirect
	github.com/pion/transport/v4 v4.0.1 // indirect
	github.com/pion/turn/v4 v4.1.4 // indirect
	github.com/pion/webrtc/v4 v4.2.3 // indirect
	github.com/pires/go-proxyproto v0.9.0 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/prometheus-community/pro-bing v0.7.0 // indirect
	github.com/protolambda/ctxlock v0.1.0 // indirect
	github.com/refraction-networking/utls v1.8.2 // indirect
	github.com/refraction-networking/water v0.7.1-alpha // indirect
	github.com/remyoudompheng/bigfft v0.0.0-20230129092748-24d4a6f8daec // indirect
	github.com/rs/dnscache v0.0.0-20230804202142-fc85eb664529 // indirect
	github.com/safchain/ethtool v0.7.0 // indirect
	github.com/sagernet/sing v0.7.14 // indirect
	github.com/sagernet/sing-tun v0.7.5 // indirect
	github.com/sagernet/tailscale v1.92.4-sing-box-1.13-mod.6 // indirect
	github.com/shadowsocks/go-shadowsocks2 v0.1.5 // indirect
	github.com/spaolacci/murmur3 v1.1.0 // indirect
	github.com/tailscale/certstore v0.1.1-0.20231202035212-d3fa0460f47e // indirect
	github.com/tailscale/go-winio v0.0.0-20231025203758-c4f33415bf55 // indirect
	github.com/tailscale/goupnp v1.0.1-0.20210804011211-c64d0f06ea05 // indirect
	github.com/tailscale/hujson v0.0.0-20250605163823-992244df8c5a // indirect
	github.com/tailscale/netlink v1.1.1-0.20240822203006-4d49adab4de7 // indirect
	github.com/tailscale/peercred v0.0.0-20250107143737-35a0c7bd7edc // indirect
	github.com/tailscale/web-client-prebuilt v0.0.0-20251127225136-f19339b67368 // indirect
	github.com/tetratelabs/wazero v1.7.3 // indirect
	github.com/tevino/abool/v2 v2.1.0 // indirect
	github.com/tidwall/btree v1.8.1 // indirect
	github.com/tjfoc/gmsm v1.4.1 // indirect
	github.com/tkuchiki/go-timezone v0.2.3 // indirect
	github.com/ulikunitz/xz v0.5.15 // indirect
	github.com/wlynxg/anet v0.0.5 // indirect
	github.com/x448/float16 v0.8.4 // indirect
	github.com/xi2/xz v0.0.0-20171230120015-48954b6210f8 // indirect
	github.com/xtaci/kcp-go/v5 v5.6.61 // indirect
	github.com/xtaci/smux v1.5.50 // indirect
	github.com/zeebo/assert v1.3.0 // indirect
	gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/v2 v2.11.0 // indirect
	go.etcd.io/bbolt v1.4.3 // indirect
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.64.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.39.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace v1.39.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.39.0 // indirect
	go.opentelemetry.io/otel/sdk v1.39.0 // indirect
	go.opentelemetry.io/otel/sdk/metric v1.39.0 // indirect
	go.opentelemetry.io/proto/otlp v1.9.0 // indirect
	go.uber.org/mock v0.6.0 // indirect
	go4.org/mem v0.0.0-20240501181205-ae6ca9944745 // indirect
	golang.org/x/crypto v0.47.0 // indirect
	golang.org/x/oauth2 v0.34.0 // indirect
	golang.org/x/term v0.39.0 // indirect
	golang.zx2c4.com/wireguard/wgctrl v0.0.0-20241231184526-a9ab2273dd10 // indirect
	golang.zx2c4.com/wireguard/windows v0.5.3 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20260120221211-b8f7ae30c516 // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.2.1 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	modernc.org/libc v1.67.6 // indirect
	modernc.org/mathutil v1.7.1 // indirect
	modernc.org/memory v1.11.0 // indirect
	modernc.org/sqlite v1.44.3 // indirect
	www.bamsoftware.com/git/dnstt.git v1.20241021.0 // indirect
	zombiezen.com/go/sqlite v1.4.2 // indirect
)
