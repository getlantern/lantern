po.cache = function(load, unload) {
  var cache = {},
      locks = {},
      map = {},
      head = null,
      tail = null,
      size = 64,
      n = 0;

  function remove(tile) {
    n--;
    if (unload) unload(tile);
    delete map[tile.key];
    if (tile.next) tile.next.prev = tile.prev;
    else if (tail = tile.prev) tail.next = null;
    if (tile.prev) tile.prev.next = tile.next;
    else if (head = tile.next) head.prev = null;
  }

  function flush() {
    for (var tile = tail; n > size; tile = tile.prev) {
      if (!tile) break;
      if (tile.lock) continue;
      remove(tile);
    }
  }

  cache.peek = function(c) {
    return map[[c.zoom, c.column, c.row].join("/")];
  };

  cache.load = function(c, projection) {
    var key = [c.zoom, c.column, c.row].join("/"),
        tile = map[key];
    if (tile) {
      if (tile.prev) {
        tile.prev.next = tile.next;
        if (tile.next) tile.next.prev = tile.prev;
        else tail = tile.prev;
        tile.prev = null;
        tile.next = head;
        head.prev = tile;
        head = tile;
      }
      tile.lock = 1;
      locks[key] = tile;
      return tile;
    }
    tile = {
      key: key,
      column: c.column,
      row: c.row,
      zoom: c.zoom,
      next: head,
      prev: null,
      lock: 1
    };
    load.call(null, tile, projection);
    locks[key] = map[key] = tile;
    if (head) head.prev = tile;
    else tail = tile;
    head = tile;
    n++;
    return tile;
  };

  cache.unload = function(key) {
    if (!(key in locks)) return false;
    var tile = locks[key];
    tile.lock = 0;
    delete locks[key];
    if (tile.request && tile.request.abort(false)) remove(tile);
    return tile;
  };

  cache.locks = function() {
    return locks;
  };

  cache.size = function(x) {
    if (!arguments.length) return size;
    size = x;
    flush();
    return cache;
  };

  cache.flush = function() {
    flush();
    return cache;
  };

  cache.clear = function() {
    for (var key in map) {
      var tile = map[key];
      if (tile.request) tile.request.abort(false);
      if (unload) unload(map[key]);
      if (tile.lock) {
        tile.lock = 0;
        tile.element.parentNode.removeChild(tile.element);
      }
    }
    locks = {};
    map = {};
    head = tail = null;
    n = 0;
    return cache;
  };

  return cache;
};
