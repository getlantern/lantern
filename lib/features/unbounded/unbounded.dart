import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/app_event_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

@RoutePage(name: 'UnboundedScreen')
class UnboundedScreen extends HookConsumerWidget {
  const UnboundedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSetting = ref.watch(appSettingProvider);
    final notifier = ref.read(appSettingProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BaseScreen(
      title: 'unbounded'.i18n,
      padded: false,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _GlobeView(isDark: isDark),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: AppTile(
                      label: 'share_bandwidth'.i18n,
                      subtitle: Text(
                        'help_fight_global_internet_censorship'.i18n,
                        style: textTheme.labelMedium!.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                      icon: AppImagePaths.lanternLogoRounded,
                      iconUseThemeColor: false,
                      trailing: SwitchButton(
                        value: appSetting.unboundedEnabled,
                        onChanged: (bool? value) {
                          notifier.setUnboundedEnabled(value ?? false);
                        },
                      ),
                      onPressed: () {
                        notifier
                            .setUnboundedEnabled(!appSetting.unboundedEnabled);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'unbounded_description'.i18n,
                      style: textTheme.bodySmall!.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        UrlUtils.openUrl(AppUrls.unbounded);
                      },
                      child: Text(
                        'learn_more'.i18n,
                        style: textTheme.labelLarge!.copyWith(
                          color: context.textLink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobeView extends ConsumerStatefulWidget {
  final bool isDark;

  const _GlobeView({required this.isDark});

  @override
  ConsumerState<_GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends ConsumerState<_GlobeView> {
  InAppWebViewController? _controller;
  bool _isLoading = true;

  void _handleConnectionEvent(UnboundedConnectionEvent event) {
    if (_controller == null) return;

    _controller?.evaluateJavascript(
      source:
          "window.unboundedGlobe.handleMessage({type:'connectionEvent',state:${event.state},workerIdx:${event.workerIdx},addr:'${event.addr}'});",
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(unboundedConnectionProvider, (prev, next) {
      next.whenData((event) {
        _handleConnectionEvent(event);
      });
    });

    return Stack(
      children: [
        InAppWebView(
          initialData: InAppWebViewInitialData(
            data: _globeHtml,
            baseUrl: WebUri('https://unpkg.com'),
            mimeType: 'text/html',
            encoding: 'utf-8',
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: true,
            hardwareAcceleration: true,
            mediaPlaybackRequiresUserGesture: false,
            supportZoom: false,
            disableHorizontalScroll: true,
            disableVerticalScroll: true,
            allowUniversalAccessFromFileURLs: true,
            allowFileAccessFromFileURLs: true,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onLoadStop: (controller, url) {
            setState(() => _isLoading = false);
            _sendTheme();
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint('Globe JS: ${consoleMessage.message}');
          },
          onReceivedError: (controller, request, error) {
            debugPrint('Globe load error: ${error.description} for ${request.url}');
          },
        ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00BCD4),
            ),
          ),
      ],
    );
  }

  void _sendTheme() {
    final theme = widget.isDark ? 'dark' : 'light';
    _controller?.evaluateJavascript(
      source:
          "window.unboundedGlobe.handleMessage({type:'setTheme',theme:'$theme'});",
    );
  }

  @override
  void didUpdateWidget(covariant _GlobeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      _sendTheme();
    }
  }
}

// Globe HTML with built-in geo lookup and connection event handling
const _globeHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%; height: 100%;
    overflow: hidden;
    background: transparent;
  }
  #globe-container {
    width: 100%; height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }
  #globe-container canvas { touch-action: none; }
</style>
</head>
<body>
<div id="globe-container"></div>

<script>
window.onerror = function(msg, url, line, col, err) {
  console.error('Globe error: ' + msg + ' at ' + url + ':' + line);
  return false;
};
</script>
<script src="https://unpkg.com/three@0.160.0/build/three.min.js" onerror="console.error('Failed to load three.js')"></script>
<script src="https://unpkg.com/three-globe@2.27.4/dist/three-globe.min.js" onerror="console.error('Failed to load three-globe.js')"></script>
<script>
(function() {
  if (typeof THREE === 'undefined') { console.error('THREE not loaded'); return; }
  if (typeof ThreeGlobe === 'undefined') { console.error('ThreeGlobe not loaded'); return; }
  console.log('Globe: all libraries loaded successfully');

  // Minimal orbit controls (auto-rotate + drag)
  function SimpleOrbitControls(camera, domElement) {
    var spherical = new THREE.Spherical().setFromVector3(camera.position);
    var isDragging = false;
    var prevMouse = { x: 0, y: 0 };
    this.autoRotate = true;
    this.autoRotateSpeed = 1.5;
    this.enableDamping = true;
    this.dampingFactor = 0.1;
    var rotVel = { theta: 0, phi: 0 };

    domElement.addEventListener('pointerdown', function(e) {
      isDragging = true;
      prevMouse.x = e.clientX;
      prevMouse.y = e.clientY;
      domElement.setPointerCapture(e.pointerId);
    });
    domElement.addEventListener('pointermove', function(e) {
      if (!isDragging) return;
      var dx = e.clientX - prevMouse.x;
      var dy = e.clientY - prevMouse.y;
      prevMouse.x = e.clientX;
      prevMouse.y = e.clientY;
      rotVel.theta -= dx * 0.005;
      rotVel.phi -= dy * 0.005;
    });
    domElement.addEventListener('pointerup', function(e) {
      isDragging = false;
      domElement.releasePointerCapture(e.pointerId);
    });

    this.update = function() {
      if (this.autoRotate && !isDragging) {
        rotVel.theta += this.autoRotateSpeed * 0.0002;
      }
      spherical.theta += rotVel.theta;
      spherical.phi += rotVel.phi;
      spherical.phi = Math.max(0.3, Math.min(Math.PI - 0.3, spherical.phi));
      if (this.enableDamping) {
        rotVel.theta *= (1 - this.dampingFactor);
        rotVel.phi *= (1 - this.dampingFactor);
      }
      camera.position.setFromSpherical(spherical);
      camera.lookAt(0, 0, 0);
    };
  }

  // Country ISO -> lat/lng lookup (subset of most common countries)
  var countries = {"AF":{"lat":33,"lng":65},"AL":{"lat":41,"lng":20},"DZ":{"lat":28,"lng":3},"AD":{"lat":42.5,"lng":1.6},"AO":{"lat":-12.5,"lng":18.5},"AR":{"lat":-34,"lng":-64},"AM":{"lat":40,"lng":45},"AU":{"lat":-27,"lng":133},"AT":{"lat":47.33,"lng":13.33},"AZ":{"lat":40.5,"lng":47.5},"BD":{"lat":24,"lng":90},"BY":{"lat":53,"lng":28},"BE":{"lat":50.83,"lng":4},"BJ":{"lat":9.5,"lng":2.25},"BO":{"lat":-17,"lng":-65},"BA":{"lat":44,"lng":18},"BR":{"lat":-10,"lng":-55},"BG":{"lat":43,"lng":25},"KH":{"lat":13,"lng":105},"CM":{"lat":6,"lng":12},"CA":{"lat":60,"lng":-95},"CL":{"lat":-30,"lng":-71},"CN":{"lat":35,"lng":105},"CO":{"lat":4,"lng":-72},"CD":{"lat":0,"lng":25},"CR":{"lat":10,"lng":-84},"HR":{"lat":45.17,"lng":15.5},"CU":{"lat":21.5,"lng":-80},"CZ":{"lat":49.75,"lng":15.5},"DK":{"lat":56,"lng":10},"DO":{"lat":19,"lng":-70.67},"EC":{"lat":-2,"lng":-77.5},"EG":{"lat":27,"lng":30},"SV":{"lat":13.83,"lng":-88.92},"EE":{"lat":59,"lng":26},"ET":{"lat":8,"lng":38},"FI":{"lat":64,"lng":26},"FR":{"lat":46,"lng":2},"GE":{"lat":42,"lng":43.5},"DE":{"lat":51,"lng":9},"GH":{"lat":8,"lng":-2},"GR":{"lat":39,"lng":22},"GT":{"lat":15.5,"lng":-90.25},"HN":{"lat":15,"lng":-86.5},"HK":{"lat":22.25,"lng":114.17},"HU":{"lat":47,"lng":20},"IS":{"lat":65,"lng":-18},"IN":{"lat":20,"lng":77},"ID":{"lat":-5,"lng":120},"IR":{"lat":32,"lng":53},"IQ":{"lat":33,"lng":44},"IE":{"lat":53,"lng":-8},"IL":{"lat":31.5,"lng":34.75},"IT":{"lat":42.83,"lng":12.83},"CI":{"lat":8,"lng":-5},"JP":{"lat":36,"lng":138},"JO":{"lat":31,"lng":36},"KZ":{"lat":48,"lng":68},"KE":{"lat":1,"lng":38},"KR":{"lat":37,"lng":127.5},"KW":{"lat":29.34,"lng":47.66},"KG":{"lat":41,"lng":75},"LA":{"lat":18,"lng":105},"LV":{"lat":57,"lng":25},"LB":{"lat":33.83,"lng":35.83},"LT":{"lat":56,"lng":24},"MG":{"lat":-20,"lng":47},"MY":{"lat":2.5,"lng":112.5},"ML":{"lat":17,"lng":-4},"MX":{"lat":23,"lng":-102},"MD":{"lat":47,"lng":29},"MN":{"lat":46,"lng":105},"MA":{"lat":32,"lng":-5},"MZ":{"lat":-18.25,"lng":35},"MM":{"lat":22,"lng":98},"NP":{"lat":28,"lng":84},"NL":{"lat":52.5,"lng":5.75},"NZ":{"lat":-41,"lng":174},"NI":{"lat":13,"lng":-85},"NG":{"lat":10,"lng":8},"NO":{"lat":62,"lng":10},"OM":{"lat":21,"lng":57},"PK":{"lat":30,"lng":70},"PA":{"lat":9,"lng":-80},"PY":{"lat":-23,"lng":-58},"PE":{"lat":-10,"lng":-76},"PH":{"lat":13,"lng":122},"PL":{"lat":52,"lng":20},"PT":{"lat":39.5,"lng":-8},"QA":{"lat":25.5,"lng":51.25},"RO":{"lat":46,"lng":25},"RU":{"lat":60,"lng":100},"SA":{"lat":25,"lng":45},"SN":{"lat":14,"lng":-14},"RS":{"lat":44,"lng":21},"SG":{"lat":1.37,"lng":103.8},"SK":{"lat":48.67,"lng":19.5},"SI":{"lat":46,"lng":15},"ZA":{"lat":-29,"lng":24},"ES":{"lat":40,"lng":-4},"LK":{"lat":7,"lng":81},"SE":{"lat":62,"lng":15},"CH":{"lat":47,"lng":8},"SY":{"lat":35,"lng":38},"TW":{"lat":23.5,"lng":121},"TJ":{"lat":39,"lng":71},"TZ":{"lat":-6,"lng":35},"TH":{"lat":15,"lng":100},"TN":{"lat":34,"lng":9},"TR":{"lat":39,"lng":35},"TM":{"lat":40,"lng":60},"UA":{"lat":49,"lng":32},"AE":{"lat":24,"lng":54},"GB":{"lat":54,"lng":-2},"US":{"lat":38,"lng":-97},"UY":{"lat":-33,"lng":-56},"UZ":{"lat":41,"lng":64},"VE":{"lat":8,"lng":-66},"VN":{"lat":16,"lng":106},"YE":{"lat":15,"lng":48},"ZM":{"lat":-15,"lng":30},"ZW":{"lat":-20,"lng":30}};

  var GEO_LOOKUP_URL = 'https://geo.getiantem.org';

  var COLORS = {
    arcOrigin: 'rgba(0, 188, 212, 0.75)',
    arcPeer: 'rgba(255, 193, 7, 0.75)',
    pointOrigin: 'rgba(0, 188, 212, 0.15)',
    pointPeer: 'rgba(255, 193, 7, 0.15)',
    atmosphere: 'rgba(0, 188, 212, 1)',
  };
  var ARCH_ALTITUDE_MIN = 0.3;
  var ARCH_ALTITUDE_GAP = 0.05;

  var arcs = [];
  var points = [];
  var originLat = null;
  var originLng = null;
  var countryPeerCounts = {};
  var pendingLookups = {};

  var container = document.getElementById('globe-container');
  var width = function() { return container.clientWidth; };
  var height = function() { return container.clientHeight; };

  var globe = new ThreeGlobe()
    .globeImageUrl('https://embed.lantern.io/uv-map-dark.png')
    .showAtmosphere(true)
    .atmosphereColor(COLORS.atmosphere)
    .atmosphereAltitude(0.25)
    .arcColor('color')
    .arcDashLength(1)
    .arcDashGap(0.5)
    .arcDashInitialGap(1)
    .arcDashAnimateTime(1000)
    .arcStroke(function(d) { return d.ghost ? 10 : 2; })
    .arcsTransitionDuration(0)
    .pointColor('color')
    .pointRadius(4)
    .pointAltitude(0)
    .pointsTransitionDuration(500);

  var renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: true,
    powerPreference: 'high-performance',
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(width(), height());
  renderer.setClearColor(0x000000, 0);
  container.appendChild(renderer.domElement);

  var scene = new THREE.Scene();
  var camera = new THREE.PerspectiveCamera(50, width() / height(), 1, 5000);
  camera.position.z = 400;

  var ambient = new THREE.AmbientLight(0xffffff, 0.6);
  scene.add(ambient);
  var dirLight = new THREE.DirectionalLight(0xffffff, 0.25);
  dirLight.position.set(0, 500, 0);
  camera.add(dirLight);
  scene.add(camera);
  scene.add(globe);

  var controls = new SimpleOrbitControls(camera, renderer.domElement);
  controls.autoRotate = true;
  controls.autoRotateSpeed = 1.5;
  controls.enableDamping = true;
  controls.dampingFactor = 0.1;

  function animate() {
    requestAnimationFrame(animate);
    controls.update();
    renderer.render(scene, camera);
  }
  animate();

  var ro = new ResizeObserver(function() {
    camera.aspect = width() / height();
    camera.updateProjectionMatrix();
    renderer.setSize(width(), height());
  });
  ro.observe(container);

  function updateGlobe() {
    globe.arcsData(arcs);
    globe.pointsData(points);
  }

  function rebuildPoints() {
    var pts = [];
    if (originLat !== null) {
      pts.push({ lat: originLat, lng: originLng, color: COLORS.pointOrigin, id: -1 });
    }
    arcs.forEach(function(a) {
      if (!a.ghost) {
        pts.push({ lat: a.endLat, lng: a.endLng, color: COLORS.pointPeer, id: a.workerIdx });
      }
    });
    points = pts;
  }

  function calcAltitude(count) {
    return ARCH_ALTITUDE_MIN + (count - 1) * ARCH_ALTITUDE_GAP;
  }

  // Geo lookup: IP -> ISO country code
  function geoLookup(ip) {
    return fetch(GEO_LOOKUP_URL + '/' + ip)
      .then(function(res) { return res.json(); })
      .then(function(data) { return data.Country ? data.Country.IsoCode : 'IR'; })
      .catch(function() { return 'IR'; });
  }

  // Self geo lookup for origin
  function selfGeoLookup() {
    return fetch(GEO_LOOKUP_URL + '/')
      .then(function(res) { return res.json(); })
      .then(function(data) { return data.Country ? data.Country.IsoCode : 'US'; })
      .catch(function() { return 'US'; });
  }

  // Initialize origin from self-lookup
  selfGeoLookup().then(function(iso) {
    var c = countries[iso] || countries['US'];
    originLat = c.lat;
    originLng = c.lng;
    rebuildPoints();
    updateGlobe();
  });

  function handleConnectionEvent(state, workerIdx, addr) {
    if (state === 1 && addr) {
      // Connected: geo lookup the peer IP, then add arc
      geoLookup(addr).then(function(iso) {
        var c = countries[iso] || countries['IR'];
        countryPeerCounts[iso] = (countryPeerCounts[iso] || 0) + 1;
        arcs = arcs.filter(function(a) { return a.workerIdx !== workerIdx; });
        arcs.push({
          startLat: originLat || 0, startLng: originLng || 0,
          endLat: c.lat, endLng: c.lng,
          country: '', iso: iso,
          workerIdx: workerIdx,
          count: countryPeerCounts[iso],
          altitude: calcAltitude(countryPeerCounts[iso]),
          ghost: false,
          color: [COLORS.arcOrigin, COLORS.arcPeer],
        });
        rebuildPoints();
        updateGlobe();
      });
    } else if (state === -1) {
      // Disconnected: remove arc
      var removed = arcs.find(function(a) { return a.workerIdx === workerIdx; });
      arcs = arcs.filter(function(a) { return a.workerIdx !== workerIdx; });
      if (removed) {
        var riso = removed.iso;
        countryPeerCounts[riso] = Math.max(0, (countryPeerCounts[riso] || 1) - 1);
      }
      rebuildPoints();
      updateGlobe();
    }
  }

  function handleMessage(data) {
    switch (data.type) {
      case 'setOrigin':
        originLat = data.lat;
        originLng = data.lng;
        arcs.forEach(function(a) { a.startLat = originLat; a.startLng = originLng; });
        rebuildPoints();
        updateGlobe();
        break;
      case 'connectionEvent':
        handleConnectionEvent(data.state, data.workerIdx, data.addr);
        break;
      case 'addArc':
        arcs = arcs.filter(function(a) { return a.workerIdx !== data.workerIdx; });
        var iso = data.iso || 'XX';
        countryPeerCounts[iso] = (countryPeerCounts[iso] || 0) + 1;
        arcs.push({
          startLat: originLat || 0, startLng: originLng || 0,
          endLat: data.endLat, endLng: data.endLng,
          country: data.country || '', iso: iso,
          workerIdx: data.workerIdx,
          count: countryPeerCounts[iso],
          altitude: calcAltitude(countryPeerCounts[iso]),
          ghost: false,
          color: [COLORS.arcOrigin, COLORS.arcPeer],
        });
        rebuildPoints();
        updateGlobe();
        break;
      case 'removeArc':
        var removed = arcs.find(function(a) { return a.workerIdx === data.workerIdx; });
        arcs = arcs.filter(function(a) { return a.workerIdx !== data.workerIdx; });
        if (removed) {
          var riso = removed.iso;
          countryPeerCounts[riso] = Math.max(0, (countryPeerCounts[riso] || 1) - 1);
        }
        rebuildPoints();
        updateGlobe();
        break;
      case 'clear':
        arcs = [];
        points = [];
        countryPeerCounts = {};
        updateGlobe();
        break;
      case 'setTheme':
        var dark = data.theme !== 'light';
        globe.globeImageUrl(dark
          ? 'https://embed.lantern.io/uv-map-dark.png'
          : 'https://embed.lantern.io/uv-map.png');
        globe.atmosphereColor(dark
          ? 'rgba(0, 188, 212, 1)'
          : 'rgba(0, 122, 124, 1)');
        globe.atmosphereAltitude(dark ? 0.25 : 0.2);
        break;
    }
  }

  window.addEventListener('message', function(e) {
    if (e.data && typeof e.data === 'object' && e.data.type) {
      handleMessage(e.data);
    } else if (typeof e.data === 'string') {
      try { handleMessage(JSON.parse(e.data)); } catch(x) {}
    }
  });

  window.unboundedGlobe = { handleMessage: handleMessage };
})();
</script>
</body>
</html>
''';
