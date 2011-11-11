po.drag = function() {
  var drag = {},
      map,
      container,
      dragging;

  function mousedown(e) {
    if (e.shiftKey) return;
    dragging = {
      x: e.clientX,
      y: e.clientY
    };
    map.focusableParent().focus();
    e.preventDefault();
    document.body.style.setProperty("cursor", "move", null);
  }

  function mousemove(e) {
    if (!dragging) return;
    map.panBy({x: e.clientX - dragging.x, y: e.clientY - dragging.y});
    dragging.x = e.clientX;
    dragging.y = e.clientY;
  }

  function mouseup(e) {
    if (!dragging) return;
    mousemove(e);
    dragging = null;
    document.body.style.removeProperty("cursor");
  }

  drag.map = function(x) {
    if (!arguments.length) return map;
    if (map) {
      container.removeEventListener("mousedown", mousedown, false);
      container = null;
    }
    if (map = x) {
      container = map.container();
      container.addEventListener("mousedown", mousedown, false);
    }
    return drag;
  };

  window.addEventListener("mousemove", mousemove, false);
  window.addEventListener("mouseup", mouseup, false);

  return drag;
};
