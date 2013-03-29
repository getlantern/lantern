;(function(window) {
  'use strict';

  var PKG_URL = 'data/package.json';

  $.ajax({
    url: PKG_URL,
    async: false,
    dataType: 'json',
    success: function(pkg) {
      var version = pkg.version,
          components = version.split('.'),
          major = components[0],
          minor = components[1],
          patch = (components[2] || '').split('-')[0],
          VER = [major, minor, patch];
      window.VER = VER;
    }
  });
}(this));
