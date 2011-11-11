// Default map controls.
po.interact = function() {
  var interact = {},
      drag = po.drag(),
      wheel = po.wheel(),
      dblclick = po.dblclick(),
      touch = po.touch(),
      arrow = po.arrow();

  interact.map = function(x) {
    drag.map(x);
    wheel.map(x);
    dblclick.map(x);
    touch.map(x);
    arrow.map(x);
    return interact;
  };

  return interact;
};
