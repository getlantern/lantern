/** delimiter-separated values.
 *    delimiter defaults to '\t'
 *    startline defaults to 0
 */

function dsv(url, delimiter, startline) {
  var re = delimiter ? new RegExp(delimiter, 'g') : /\t/g,
      startline = startline ? startline : 0,
      dsv = {},
      key,
      value;

  dsv.key = function(x) {
    if (!arguments.length) return key;
    key = x;
    return dsv;
  };

  dsv.value = function(x) {
    if (!arguments.length) return value;
    value = x;
    return dsv;
  };

  dsv.map = function(x) {
    var map = {}, req = new XMLHttpRequest();
    req.overrideMimeType('text/plain');
    req.open('GET', url, false);
    req.send(null);
    var lines = req.responseText.split(/\n/g);
    for (var i = startline, ln = lines.length; i < ln; i++) {
      var columns = lines[i].split(re),
          k = key(columns);
      if (k != null) map[k] = value(columns);
    }
    return map;
  };

  return dsv;
}
