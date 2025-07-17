module github.com/getlantern/lantern-outline

go 1.24

toolchain go1.24.1

replace github.com/getlantern/radiance => ../radiance

// replace github.com/getlantern/lantern-server-provisioner => ../lantern-server-provisioner

replace github.com/sagernet/sing-box => github.com/getlantern/sing-box-minimal v1.11.12-0.20250616155750-74188abad925

replace github.com/sagernet/wireguard-go => github.com/getlantern/wireguard-go v0.0.1-beta.5.0.20250310145906-45220d8aec77

replace github.com/tetratelabs/wazero => github.com/refraction-networking/wazero v1.7.1-w

require (
	github.com/getlantern/golog v0.0.0-20230503153817-8e72de7e0a65
	github.com/getlantern/lantern-server-provisioner v0.0.0-20250617134205-a652cb0cef27
	github.com/getlantern/radiance v0.0.0-20250626212255-c51611b432be
	github.com/golang-jwt/jwt/v5 v5.2.2
	github.com/sagernet/sing-box v1.11.5
	golang.org/x/mobile v0.0.0-20240520174638-fa72addaaa1b
	google.golang.org/protobuf v1.36.6
	howett.net/plist v1.0.1
)

require (
	github.com/ajg/form v1.5.1 // indirect
	github.com/andybalholm/brotli v1.1.1 // indirect
	github.com/caddyserver/certmagic v0.22.0 // indirect
	github.com/caddyserver/zerossl v0.1.3 // indirect
	github.com/cloudflare/circl v1.6.0 // indirect
	github.com/davecgh/go-spew v1.1.2-0.20180830191138-d8f796af33cc // indirect
	github.com/fsnotify/fsnotify v1.8.0
	github.com/getlantern/context v0.0.0-20220418194847-3d5e7a086201 // indirect
	github.com/getlantern/errors v1.0.4 // indirect
	github.com/getlantern/hex v0.0.0-20220104173244-ad7e4b9194dc // indirect
	github.com/getlantern/hidden v0.0.0-20220104173330-f221c5a24770 // indirect
	github.com/getlantern/ops v0.0.0-20231025133620-f368ab734534 // indirect
	github.com/go-chi/chi/v5 v5.2.1 // indirect
	github.com/go-chi/render v1.0.3 // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/go-ole/go-ole v1.3.0 // indirect
	github.com/go-stack/stack v1.8.1 // indirect
	github.com/gobwas/httphead v0.1.0 // indirect
	github.com/gobwas/pool v0.2.1 // indirect
	github.com/gofrs/uuid/v5 v5.3.2 // indirect
	github.com/google/btree v1.1.3 // indirect
	github.com/google/go-cmp v0.7.0 // indirect
	github.com/hashicorp/yamux v0.1.2 // indirect
	github.com/insomniacslk/dhcp v0.0.0-20250109001534-8abf58130905 // indirect
	github.com/josharian/native v1.1.1-0.20230202152459-5c7d0dd6ab86 // indirect
	github.com/klauspost/compress v1.18.0 // indirect
	github.com/klauspost/cpuid/v2 v2.2.11 // indirect
	github.com/libdns/alidns v1.0.3 // indirect
	github.com/libdns/cloudflare v0.1.3 // indirect
	github.com/libdns/libdns v0.2.3 // indirect
	github.com/logrusorgru/aurora v2.0.3+incompatible // indirect
	github.com/mdlayher/netlink v1.7.2 // indirect
	github.com/mdlayher/socket v0.5.1 // indirect
	github.com/metacubex/tfo-go v0.0.0-20241231083714-66613d49c422 // indirect
	github.com/mholt/acmez v1.2.0 // indirect
	github.com/mholt/acmez/v3 v3.1.0 // indirect
	github.com/miekg/dns v1.1.63 // indirect
	github.com/oschwald/maxminddb-golang v1.13.1 // indirect
	github.com/oxtoacart/bpool v0.0.0-20190530202638-03653db5a59c // indirect
	github.com/pierrec/lz4/v4 v4.1.22 // indirect
	github.com/quic-go/qpack v0.5.1 // indirect
	github.com/quic-go/qtls-go1-20 v0.4.1 // indirect
	github.com/sagernet/bbolt v0.0.0-20231014093535-ea5cb2fe9f0a // indirect
	github.com/sagernet/cloudflare-tls v0.0.0-20231208171750-a4483c1b7cd1 // indirect
	github.com/sagernet/cors v1.2.1 // indirect
	github.com/sagernet/fswatch v0.1.1 // indirect
	github.com/sagernet/gvisor v0.0.0-20250217052116-ed66b6946f72 // indirect
	github.com/sagernet/netlink v0.0.0-20240916134442-83396419aa8b // indirect
	github.com/sagernet/nftables v0.3.0-beta.4 // indirect
	github.com/sagernet/quic-go v0.49.0-beta.1 // indirect
	github.com/sagernet/reality v0.0.0-20230406110435-ee17307e7691 // indirect
	github.com/sagernet/sing-dns v0.4.5 // indirect
	github.com/sagernet/sing-mux v0.3.2 // indirect
	github.com/sagernet/sing-quic v0.4.3 // indirect
	github.com/sagernet/sing-shadowsocks v0.2.8 // indirect
	github.com/sagernet/sing-shadowsocks2 v0.2.1 // indirect
	github.com/sagernet/sing-shadowtls v0.2.0 // indirect
	github.com/sagernet/sing-vmess v0.2.3 // indirect
	github.com/sagernet/smux v1.5.34-mod.2 // indirect
	github.com/sagernet/utls v1.6.7 // indirect
	github.com/sagernet/wireguard-go v0.0.1-beta.7 // indirect
	github.com/sagernet/ws v0.0.0-20231204124109-acfe8907c854 // indirect
	github.com/u-root/uio v0.0.0-20240224005618-d2acac8f3701 // indirect
	github.com/vishvananda/netns v0.0.5 // indirect
	github.com/zeebo/blake3 v0.2.4 // indirect
	go.opentelemetry.io/auto/sdk v1.1.0 // indirect
	go.opentelemetry.io/otel v1.37.0 // indirect
	go.opentelemetry.io/otel/metric v1.37.0 // indirect
	go.opentelemetry.io/otel/trace v1.37.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	go.uber.org/zap v1.27.0 // indirect
	go.uber.org/zap/exp v0.3.0 // indirect
	go4.org/netipx v0.0.0-20231129151722-fdeea329fbba // indirect
	golang.org/x/exp v0.0.0-20250305212735-054e65f0b394 // indirect
	golang.org/x/mod v0.25.0 // indirect
	golang.org/x/net v0.41.0 // indirect
	golang.org/x/sync v0.15.0 // indirect
	golang.org/x/text v0.26.0 // indirect
	golang.org/x/time v0.11.0 // indirect
	golang.org/x/tools v0.33.0 // indirect
	golang.zx2c4.com/wintun v0.0.0-20230126152724-0fa3db229ce2 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20250715232539-7130f93afb79 // indirect
	google.golang.org/grpc v1.73.0 // indirect
	lukechampine.com/blake3 v1.4.1 // indirect
)

require (
	dario.cat/mergo v1.0.1 // indirect
	github.com/1Password/srp v0.2.0 // indirect
	github.com/Jigsaw-Code/outline-sdk v0.0.19 // indirect
	github.com/Jigsaw-Code/outline-sdk/x v0.0.2 // indirect
	github.com/RoaringBitmap/roaring v1.2.3 // indirect
	github.com/Xuanwo/go-locale v1.1.3 // indirect
	github.com/ajwerner/btree v0.0.0-20211221152037-f427b3e689c0 // indirect
	github.com/alecthomas/atomic v0.1.0-alpha2 // indirect
	github.com/alitto/pond/v2 v2.1.5 // indirect
	github.com/anacrolix/chansync v0.3.0 // indirect
	github.com/anacrolix/dht/v2 v2.19.2-0.20221121215055-066ad8494444 // indirect
	github.com/anacrolix/envpprof v1.3.0 // indirect
	github.com/anacrolix/generics v0.0.0-20230816105729-c755655aee45 // indirect
	github.com/anacrolix/go-libutp v1.3.1 // indirect
	github.com/anacrolix/log v0.14.6-0.20231202035202-ed7a02cad0b4 // indirect
	github.com/anacrolix/missinggo v1.3.0 // indirect
	github.com/anacrolix/missinggo/perf v1.0.0 // indirect
	github.com/anacrolix/missinggo/v2 v2.7.2-0.20230527121029-a582b4f397b9 // indirect
	github.com/anacrolix/mmsg v1.0.0 // indirect
	github.com/anacrolix/multiless v0.3.0 // indirect
	github.com/anacrolix/stm v0.4.0 // indirect
	github.com/anacrolix/sync v0.5.1 // indirect
	github.com/anacrolix/torrent v1.53.3 // indirect
	github.com/anacrolix/upnp v0.1.3-0.20220123035249-922794e51c96 // indirect
	github.com/anacrolix/utp v0.1.0 // indirect
	github.com/bahlo/generic-list-go v0.2.0 // indirect
	github.com/benbjohnson/immutable v0.3.0 // indirect
	github.com/bits-and-blooms/bitset v1.2.2 // indirect
	github.com/blang/semver v3.5.1+incompatible // indirect
	github.com/blang/vfs v1.0.0 // indirect
	github.com/bradfitz/iter v0.0.0-20191230175014-e8f45d346db8 // indirect
	github.com/cenkalti/backoff/v5 v5.0.2 // indirect
	github.com/cretz/bine v0.2.0 // indirect
	github.com/dsnet/compress v0.0.2-0.20210315054119-f66993602bf5 // indirect
	github.com/dustin/go-humanize v1.0.0 // indirect
	github.com/edsrzf/mmap-go v1.1.0 // indirect
	github.com/gaukas/wazerofs v0.1.0 // indirect
	github.com/getlantern/algeneva v0.0.0-20250307163401-1824e7b54f52 // indirect
	github.com/getlantern/appdir v0.0.0-20250324200952-507a0625eb01 // indirect
	github.com/getlantern/byteexec v0.0.0-20220903142956-e6ed20032cfd // indirect
	github.com/getlantern/common v1.2.1-0.20250711182004-51a659011c7a // indirect
	github.com/getlantern/elevate v0.0.0-20220903142053-479ab992b264 // indirect
	github.com/getlantern/filepersist v0.0.0-20210901195658-ed29a1cb0b7c // indirect
	github.com/getlantern/fronted v0.0.0-20250619212426-1120fc75a5e4 // indirect
	github.com/getlantern/iptool v0.0.0-20230112135223-c00e863b2696 // indirect
	github.com/getlantern/jibber_jabber v0.0.0-20210901195950-68955124cc42 // indirect
	github.com/getlantern/keepcurrent v0.0.0-20240126172110-2e0264ca385d // indirect
	github.com/getlantern/keyman v0.0.0-20230503155501-4e864ca2175b // indirect
	github.com/getlantern/kindling v0.0.0-20250506175908-d622fb5c9990 // indirect
	github.com/getlantern/lantern-water v0.0.0-20250331153903-07abebe611e8 // indirect
	github.com/getlantern/mtime v0.0.0-20200417132445-23682092d1f7 // indirect
	github.com/getlantern/netx v0.0.0-20240830183145-c257516187f0 // indirect
	github.com/getlantern/osversion v0.0.0-20240418205916-2e84a4a4e175 // indirect
	github.com/getlantern/sing-box-extensions v0.0.5-0.20250620193835-ad2cc4d65801 // indirect
	github.com/getlantern/timezone v0.0.0-20210901200113-3f9de9d360c9 // indirect
	github.com/getlantern/tlsdialer/v3 v3.0.3 // indirect
	github.com/getsentry/sentry-go v0.31.1 // indirect
	github.com/go-llsqlite/adapter v0.0.0-20230927005056-7f5ce7f0c916 // indirect
	github.com/go-llsqlite/crawshaw v0.4.0 // indirect
	github.com/go-resty/resty/v2 v2.16.5 // indirect
	github.com/gobwas/ws v1.4.0 // indirect
	github.com/goccy/go-yaml v1.15.13 // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/gorilla/websocket v1.5.3 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.27.1 // indirect
	github.com/huandu/xstrings v1.3.2 // indirect
	github.com/klauspost/pgzip v1.2.5 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/mholt/archiver/v3 v3.5.1 // indirect
	github.com/mschoch/smat v0.2.0 // indirect
	github.com/nwaples/rardecode v1.1.0 // indirect
	github.com/pion/datachannel v1.5.2 // indirect
	github.com/pion/dtls/v2 v2.2.7 // indirect
	github.com/pion/ice/v2 v2.2.6 // indirect
	github.com/pion/interceptor v0.1.11 // indirect
	github.com/pion/logging v0.2.2 // indirect
	github.com/pion/mdns v0.0.5 // indirect
	github.com/pion/randutil v0.1.0 // indirect
	github.com/pion/rtcp v1.2.9 // indirect
	github.com/pion/rtp v1.7.13 // indirect
	github.com/pion/sctp v1.8.8 // indirect
	github.com/pion/sdp/v3 v3.0.5 // indirect
	github.com/pion/srtp/v2 v2.0.9 // indirect
	github.com/pion/stun v0.6.1 // indirect
	github.com/pion/transport v0.13.1 // indirect
	github.com/pion/transport/v2 v2.2.3 // indirect
	github.com/pion/turn/v2 v2.0.8 // indirect
	github.com/pion/webrtc/v3 v3.1.42 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/qdm12/reprint v0.0.0-20200326205758-722754a53494 // indirect
	github.com/refraction-networking/utls v1.7.1 // indirect
	github.com/refraction-networking/water v0.7.0-alpha // indirect
	github.com/remyoudompheng/bigfft v0.0.0-20230129092748-24d4a6f8daec // indirect
	github.com/rs/dnscache v0.0.0-20211102005908-e0241e321417 // indirect
	github.com/sagernet/sing v0.6.10 // indirect
	github.com/sagernet/sing-tun v0.6.5 // indirect
	github.com/shadowsocks/go-shadowsocks2 v0.1.5 // indirect
	github.com/tetratelabs/wazero v1.7.1 // indirect
	github.com/tevino/abool/v2 v2.1.0 // indirect
	github.com/tidwall/btree v1.6.0 // indirect
	github.com/tkuchiki/go-timezone v0.2.0 // indirect
	github.com/ulikunitz/xz v0.5.10 // indirect
	github.com/xi2/xz v0.0.0-20171230120015-48954b6210f8 // indirect
	github.com/zeebo/assert v1.3.0 // indirect
	go.etcd.io/bbolt v1.3.6 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc v1.37.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace v1.37.0 // indirect
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.37.0 // indirect
	go.opentelemetry.io/otel/sdk v1.37.0 // indirect
	go.opentelemetry.io/otel/sdk/metric v1.37.0 // indirect
	go.opentelemetry.io/proto/otlp v1.7.0 // indirect
	go.uber.org/mock v0.5.0 // indirect
	golang.org/x/crypto v0.39.0 // indirect
	golang.org/x/sys v0.33.0 // indirect
	golang.zx2c4.com/wireguard/wgctrl v0.0.0-20241231184526-a9ab2273dd10 // indirect
	google.golang.org/genproto v0.0.0-20250715232539-7130f93afb79 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20250715232539-7130f93afb79 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	modernc.org/libc v1.22.3 // indirect
	modernc.org/mathutil v1.5.0 // indirect
	modernc.org/memory v1.5.0 // indirect
	modernc.org/sqlite v1.21.1 // indirect
	zombiezen.com/go/sqlite v0.13.1 // indirect
)
