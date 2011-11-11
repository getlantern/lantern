var po = org.polymaps;

var googremovereqs = dsv('google-content-removal-requests.csv', ',', 1)
    .key(function(l) { return l[1]; })
    .value(function(l) { return l[4]; })
    .map();

var map = po.map()
    .container(document.getElementById('map').appendChild(po.svg('svg')))
    .center({lat: 40, lon: 0})
    .zoomRange([1, 4])
    .zoom(2)
    .add(po.interact());

map.add(po.image()
    .url('http://s3.amazonaws.com/com.modestmaps.bluemarble/{Z}-r{Y}-c{X}.jpg'));

map.add(po.geoJson()
    .url('world.json')
    .tile(false)
    .zoom(3)
    .on('load', load));

map.add(po.compass()
    .pan('none'));

map.container().setAttribute('class', 'Blues');

/** Set feature class and add tooltip on tile load. */
function load(e) {
  for (var i = 0, ln = e.features.length; i < ln; i++) {
    var feature = e.features[i],
        n = feature.data.properties.name,
        v = googremovereqs[n];
    n$(feature.element)
        .attr('class', isNaN(v) ? null : 'q' + bin(v) + '-9')
      .add('svg:title')
        .text(n + (isNaN(v) ? '' : ':  ' + v));
  }
}

function bin(v) {
  return parseInt(v / 14); // XXX don't hard-code
}
