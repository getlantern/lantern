/* URL template for loading Crimespotting data. */
function crimespotting(template) {
  return function(c) {
    var max = 1 << c.zoom, column = c.column % max;
    if (column < 0) column += max;
    return template.replace(/{(.)}/g, function(s, v) {
      switch (v) {
        case "B": {
          var nw = map.coordinateLocation({row: c.row, column: column, zoom: c.zoom}),
              se = map.coordinateLocation({row: c.row + 1, column: column + 1, zoom: c.zoom}),
              pn = Math.ceil(Math.log(c.zoom) / Math.LN2);
          return nw.lon.toFixed(pn)
              + "," + se.lat.toFixed(pn)
              + "," + se.lon.toFixed(pn)
              + "," + nw.lat.toFixed(pn);
        }
      }
      return v;
    });
  };
}

crimespotting.categorize = (function() {
  var categories = {
    "aggravated assault": "violent",
    "murder": "violent",
    "robbery": "violent",
    "simple assault": "violent",
    "arson": "property",
    "burglary": "property",
    "theft": "property",
    "vandalism": "property",
    "vehicle theft": "property",
    "alcohol": "quality",
    "disturbing the peace": "quality",
    "narcotics": "quality",
    "prostitution": "quality"
  };
  return function(d) {
    return categories[d.properties.crime_type.toLowerCase()];
  };
})();
