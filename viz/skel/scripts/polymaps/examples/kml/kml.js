(function() {
  var po = org.polymaps;

  po.kml = function() {
    var kml = po.geoJson(fetch);

    function fetch(url, update) {
      return po.queue.xml(url, function(xml) {
        update(geoJson(xml));
      });
    }

    var types = {

      Point: function(e) {
        return {
          type: "Point",
          coordinates: e.getElementsByTagName("coordinates")[0]
            .textContent
            .split(",")
            .map(Number)
        };
      },

      LineString: function(e) {
        return {
          type: "LineString",
          coordinates: e.getElementsByTagName("coordinates")[0]
            .textContent
            .trim()
            .split(/\s+/)
            .map(function(a) { return a.split(",").slice(0, 2).map(Number); })
        };
      }

    };

    function geometry(e) {
      return e && e.tagName in types && types[e.tagName](e);
    }

    function geoJson(xml) {
      var features = [],
      placemarks = xml.getElementsByTagName("Placemark");
      for (var i = 0; i < placemarks.length; i++) {
        var e = placemarks[i],
        f = {id: e.getAttribute("id"), properties: {}};
        for (var c = e.firstChild; c; c = c.nextSibling) {
          switch (c.tagName) {
          case "name": f.properties.name = c.textContent; continue;
          case "description": f.properties.description = c.textContent; continue;
          }
          var g = geometry(c);
          if (g) f.geometry = g;
        }
        if (f.geometry) features.push(f);
      }
      return {type: "FeatureCollection", features: features};
    }

    return kml;
  };
})();
