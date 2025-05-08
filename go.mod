module github.com/getlantern/lantern-outline

go 1.24

toolchain go1.24.1

// replace github.com/getlantern/radiance => ../radiance

replace github.com/sagernet/sing-box => github.com/getlantern/sing-box-minimal v1.11.6-0.20250411173055-d82f542dfd3f

require (
	github.com/getlantern/golog v0.0.0-20230503153817-8e72de7e0a65
	github.com/getlantern/radiance v0.0.0-20250507123039-c57a1c93b76e
	github.com/golang-jwt/jwt/v5 v5.2.2
	github.com/sagernet/sing-box v1.11.5
	github.com/stretchr/testify v1.10.0
	github.com/zeebo/assert v1.3.0
	golang.org/x/mobile v0.0.0-20250408133729-978277e7eaf7
	google.golang.org/protobuf v1.36.5
	howett.net/plist v1.0.1
)

require (
	github.com/1Password/srp v0.2.0 // indirect
	github.com/Jigsaw-Code/outline-sdk v0.0.19 // indirect
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
	github.com/getlantern/timezone v0.0.0-20210901200113-3f9de9d360c9 // indirect
	github.com/go-chi/chi/v5 v5.2.1 // indirect
	github.com/go-chi/render v1.0.3 // indirect
	github.com/go-logr/logr v1.4.2 // indirect
	github.com/go-logr/stdr v1.2.2 // indirect
	github.com/go-ole/go-ole v1.3.0 // indirect
	github.com/go-stack/stack v1.8.1 // indirect
	github.com/gobwas/httphead v0.1.0 // indirect
	github.com/gobwas/pool v0.2.1 // indirect
	github.com/gofrs/uuid/v5 v5.3.2 // indirect
	github.com/google/btree v1.1.3 // indirect
	github.com/google/go-cmp v0.7.0 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/hashicorp/yamux v0.1.2 // indirect
	github.com/insomniacslk/dhcp v0.0.0-20250109001534-8abf58130905 // indirect
	github.com/josharian/native v1.1.1-0.20230202152459-5c7d0dd6ab86 // indirect
	github.com/klauspost/compress v1.18.0 // indirect
	github.com/klauspost/cpuid/v2 v2.2.10 // indirect
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
	github.com/pmezard/go-difflib v1.0.1-0.20181226105442-5d4384ee4fb2 // indirect
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
	github.com/sagernet/sing-dns v0.4.1 // indirect
	github.com/sagernet/sing-mux v0.3.1 // indirect
	github.com/sagernet/sing-quic v0.4.1 // indirect
	github.com/sagernet/sing-shadowsocks v0.2.7 // indirect
	github.com/sagernet/sing-shadowsocks2 v0.2.0 // indirect
	github.com/sagernet/sing-shadowtls v0.2.0 // indirect
	github.com/sagernet/sing-vmess v0.2.0 // indirect
	github.com/sagernet/smux v0.0.0-20231208180855-7041f6ea79e7 // indirect
	github.com/sagernet/utls v1.6.7 // indirect
	github.com/sagernet/wireguard-go v0.0.1-beta.5 // indirect
	github.com/sagernet/ws v0.0.0-20231204124109-acfe8907c854 // indirect
	github.com/tkuchiki/go-timezone v0.2.0 // indirect
	github.com/u-root/uio v0.0.0-20240224005618-d2acac8f3701 // indirect
	github.com/vishvananda/netns v0.0.5 // indirect
	github.com/zeebo/blake3 v0.2.4 // indirect
	go.opentelemetry.io/auto/sdk v1.1.0 // indirect
	go.opentelemetry.io/otel v1.35.0 // indirect
	go.opentelemetry.io/otel/metric v1.35.0 // indirect
	go.opentelemetry.io/otel/trace v1.35.0 // indirect
	go.uber.org/multierr v1.11.0 // indirect
	go.uber.org/zap v1.27.0 // indirect
	go.uber.org/zap/exp v0.3.0 // indirect
	go4.org/netipx v0.0.0-20231129151722-fdeea329fbba // indirect
	golang.org/x/exp v0.0.0-20250305212735-054e65f0b394 // indirect
	golang.org/x/mod v0.24.0 // indirect
	golang.org/x/net v0.39.0 // indirect
	golang.org/x/sync v0.13.0 // indirect
	golang.org/x/text v0.24.0 // indirect
	golang.org/x/time v0.11.0 // indirect
	golang.org/x/tools v0.32.0 // indirect
	golang.zx2c4.com/wintun v0.0.0-20230126152724-0fa3db229ce2 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20250311190419-81fb87f6b8bf // indirect
	google.golang.org/grpc v1.71.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
	lukechampine.com/blake3 v1.4.0 // indirect
)

require (
	dario.cat/mergo v1.0.1 // indirect
	github.com/Jigsaw-Code/outline-sdk/x v0.0.2 // indirect
	github.com/Xuanwo/go-locale v1.1.3 // indirect
	github.com/alitto/pond/v2 v2.1.5 // indirect
	github.com/blang/semver v3.5.1+incompatible // indirect
	github.com/cretz/bine v0.2.0 // indirect
	github.com/dsnet/compress v0.0.2-0.20210315054119-f66993602bf5 // indirect
	github.com/getlantern/algeneva v0.0.0-20250307163401-1824e7b54f52 // indirect
	github.com/getlantern/appdir v0.0.0-20250324200952-507a0625eb01 // indirect
	github.com/getlantern/byteexec v0.0.0-20220903142956-e6ed20032cfd // indirect
	github.com/getlantern/common v1.2.1-0.20250428204107-678e5e36cbbf // indirect
	github.com/getlantern/elevate v0.0.0-20220903142053-479ab992b264 // indirect
	github.com/getlantern/filepersist v0.0.0-20210901195658-ed29a1cb0b7c // indirect
	github.com/getlantern/fronted v0.0.0-20250501185902-0f6c04a1b15d // indirect
	github.com/getlantern/iptool v0.0.0-20230112135223-c00e863b2696 // indirect
	github.com/getlantern/jibber_jabber v0.0.0-20210901195950-68955124cc42 // indirect
	github.com/getlantern/keepcurrent v0.0.0-20240126172110-2e0264ca385d // indirect
	github.com/getlantern/keyman v0.0.0-20230503155501-4e864ca2175b // indirect
	github.com/getlantern/kindling v0.0.0-20250501190705-a18e51da1a62 // indirect
	github.com/getlantern/mtime v0.0.0-20200417132445-23682092d1f7 // indirect
	github.com/getlantern/netx v0.0.0-20240830183145-c257516187f0 // indirect
	github.com/getlantern/osversion v0.0.0-20240418205916-2e84a4a4e175 // indirect
	github.com/getlantern/sing-box-extensions v0.0.0-20250417225118-49a27a638120 // indirect
	github.com/getlantern/tlsdialer/v3 v3.0.3 // indirect
	github.com/getsentry/sentry-go v0.31.1 // indirect
	github.com/go-resty/resty/v2 v2.16.5 // indirect
	github.com/gobwas/ws v1.4.0 // indirect
	github.com/goccy/go-yaml v1.15.13 // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/gorilla/websocket v1.5.3 // indirect
	github.com/klauspost/pgzip v1.2.5 // indirect
	github.com/mholt/archiver/v3 v3.5.1 // indirect
	github.com/nwaples/rardecode v1.1.0 // indirect
	github.com/nxadm/tail v1.4.11 // indirect
	github.com/qdm12/reprint v0.0.0-20200326205758-722754a53494 // indirect
	github.com/refraction-networking/utls v1.7.1 // indirect
	github.com/sagernet/sing v0.6.6-0.20250406121928-926a5a1e8bb7 // indirect
	github.com/sagernet/sing-tun v0.6.1 // indirect
	github.com/shadowsocks/go-shadowsocks2 v0.1.5 // indirect
	github.com/ulikunitz/xz v0.5.10 // indirect
	github.com/xi2/xz v0.0.0-20171230120015-48954b6210f8 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdoutlog v0.11.0 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdoutmetric v1.35.0 // indirect
	go.opentelemetry.io/otel/exporters/stdout/stdouttrace v1.35.0 // indirect
	go.opentelemetry.io/otel/log v0.11.0 // indirect
	go.opentelemetry.io/otel/sdk v1.35.0 // indirect
	go.opentelemetry.io/otel/sdk/log v0.11.0 // indirect
	go.opentelemetry.io/otel/sdk/metric v1.35.0 // indirect
	golang.org/x/crypto v0.37.0 // indirect
	golang.org/x/sys v0.32.0 // indirect
	golang.zx2c4.com/wireguard/wgctrl v0.0.0-20241231184526-a9ab2273dd10 // indirect
)
