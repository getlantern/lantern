function tsv(url) {
  var tsv = {},
      key,
      value;

  tsv.key = function(x) {
    if (!arguments.length) return key;
    key = x;
    return tsv;
  };

  tsv.value = function(x) {
    if (!arguments.length) return value;
    value = x;
    return tsv;
  };

  tsv.map = function(x) {
    var map = {}, req = new XMLHttpRequest();
    req.overrideMimeType("text/plain");
    req.open("GET", url, false);
    req.send(null);
    var lines = req.responseText.split(/\n/g);
    for (var i = 0; i < lines.length; i++) {
      var columns = lines[i].split(/\t/g),
          k = key(columns);
      if (k != null) map[k] = value(columns);
    }
    return map;
  };

  return tsv;
}
