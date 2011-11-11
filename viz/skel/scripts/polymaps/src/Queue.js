po.queue = (function() {
  var queued = [], active = 0, size = 6;

  function process() {
    if ((active >= size) || !queued.length) return;
    active++;
    queued.pop()();
  }

  function dequeue(send) {
    for (var i = 0; i < queued.length; i++) {
      if (queued[i] == send) {
        queued.splice(i, 1);
        return true;
      }
    }
    return false;
  }

  function request(url, callback, mimeType) {
    var req;

    function send() {
      req = new XMLHttpRequest();
      if (mimeType && req.overrideMimeType) {
        req.overrideMimeType(mimeType);
      }
      req.open("GET", url, true);
      req.onreadystatechange = function(e) {
        if (req.readyState == 4) {
          active--;
          if (req.status < 300) callback(req);
          process();
        }
      };
      req.send(null);
    }

    function abort(hard) {
      if (dequeue(send)) return true;
      if (hard && req) { req.abort(); return true; }
      return false;
    }

    queued.push(send);
    process();
    return {abort: abort};
  }

  function text(url, callback, mimeType) {
    return request(url, function(req) {
      if (req.responseText) callback(req.responseText);
    }, mimeType);
  }

  /*
   * We the override MIME type here so that you can load local files; some
   * browsers don't assign a proper MIME type for local files.
   */

  function json(url, callback) {
    return request(url, function(req) {
      if (req.responseText) callback(JSON.parse(req.responseText));
    }, "application/json");
  }

  function xml(url, callback) {
    return request(url, function(req) {
      if (req.responseXML) callback(req.responseXML);
    }, "application/xml");
  }

  function image(image, src, callback) {
    var img;

    function send() {
      img = document.createElement("img");
      img.onerror = function() {
        active--;
        process();
      };
      img.onload = function() {
        active--;
        callback(img);
        process();
      };
      img.src = src;
      image.setAttributeNS(po.ns.xlink, "href", src);
    }

    function abort(hard) {
      if (dequeue(send)) return true;
      if (hard && img) { img.src = "about:"; return true; } // cancels request
      return false;
    }

    queued.push(send);
    process();
    return {abort: abort};
  }

  return {text: text, xml: xml, json: json, image: image};
})();
