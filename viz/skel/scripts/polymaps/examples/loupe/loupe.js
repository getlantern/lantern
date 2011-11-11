(function(po) {
  po.loupe = function() {
    var loupe = po.map(),
        container = po.svg("g"),
        clipId = "org.polymaps." + po.id(),
        clipHref = "url(#" + clipId + ")",
        clipPath = container.appendChild(po.svg("clipPath")),
        clipCircle = clipPath.appendChild(po.svg("circle")),
        back = po.svg("circle"),
        tab = po.svg("path"),
        fore = po.svg("circle"),
        centerPoint = null,
        zoomDelta = 0,
        tabPosition = "bottom-right",
        tabAngles = {"top-left": 180, "top-right": 270, "bottom-left": 90},
        visible = true,
        r = 128,
        rr = [64, 384],
        k = 1,
        map,
        f0,
        m0,
        p0,
        repeatInterval,
        repeatRate = 30,
        repeatPan = {x: 0, y: 0};

    loupe
        .size({x: r * 2, y: r * 2})
        .container(container)
        .centerRange(null)
        .zoomRange(null)
        .on("move", loupemove);

    container.appendChild(back).setAttribute("class", "back");
    container.appendChild(tab).setAttribute("class", "tab");
    container.appendChild(fore).setAttribute("class", "fore");
    clipPath.setAttribute("id", clipId);
    container.setAttribute("class", "map loupe");

    back.addEventListener("mousedown", mousedown, false);
    tab.addEventListener("mousedown", mousedown, false);
    fore.addEventListener("mousedown", foredown, false);
    fore.setAttribute("fill", "none");
    fore.setAttribute("cursor", "ew-resize");
    window.addEventListener("mouseup", mouseup, false);
    window.addEventListener("mousemove", mousemove, false);

    // update the center point if the center is set explicitly
    function loupemove() {
      if (!map) return;
      loupe.centerPoint(map.locationPoint(loupe.center()));
    }

    // update the center and zoom level if the underlying map moves
    function mapmove() {
      if (!map) return;
      var z0 = map.zoom() + zoomDelta,
          z1 = loupe.zoom();
      loupe.off("move", loupemove)
        .zoomBy(z0 - z1, {x: r, y: r}, map.pointLocation(centerPoint))
        .on("move", loupemove);
      clipCircle.setAttribute("r", r * (k = Math.pow(2, Math.round(z0) - z0)));
      container.setAttribute("transform", "translate(" + (centerPoint.x - r) + "," + (centerPoint.y - r) + ")");
    }

    function foredown(e) {
      f0 = true;
      document.body.style.setProperty("cursor", "ew-resize", null);
      map.focusableParent().focus();
      return cancel(e);
    }

    function foremove(e) {
      var p0 = map.mouse(e),
          p1 = loupe.centerPoint(),
          dx = p1.x - p0.x,
          dy = p1.y - p0.y,
           r = Math.sqrt(dx * dx + dy * dy);
      loupe.radius(r ^ (r & 1));
      return cancel(e);
    }

    function mousedown(e) {
      m0 = map.mouse(e);
      p0 = loupe.centerPoint();
      map.focusableParent().focus();
      return cancel(e);
    }

    function mousemove(e) {
      if (f0) return foremove(e);
      if (!m0) return;
      var m1 = map.mouse(e),
          size = map.size(),
          x = p0.x - m0.x + m1.x,
          y = p0.y - m0.y + m1.y;

      // determine whether we're offscreen
      repeatPan.x = x < 0 ? -x : x > size.x ? size.x - x : 0;
      repeatPan.y = y < 0 ? -y : y > size.y ? size.y - y : 0;

      // if the loupe is offscreen, start a new pan interval
      if (repeatPan.x || repeatPan.y) {
        repeatPan.x /= 10;
        repeatPan.y /= 10;
        if (!repeatInterval) repeatInterval = setInterval(mouserepeat, repeatRate);
      } else if (repeatInterval) {
        repeatInterval = clearInterval(repeatInterval);
      }

      centerPoint = {x: Math.round(x), y: Math.round(y)};
      mapmove();
      return cancel(e);
    }

    function mouserepeat() {
      map.panBy(repeatPan);
    }

    function mouseup(e) {
      if (f0) {
        f0 = null;
        document.body.style.removeProperty("cursor");
      }
      if (m0) {
        if (repeatInterval) repeatInterval = clearInterval(repeatInterval);
        m0 = p0 = null;
      }
      return cancel(e);
    }

    function cancel(e) {
      e.stopPropagation();
      e.preventDefault();
      return false;
    }

    loupe.map = function(x) {
      if (!arguments.length) return map;
      if (map) {
        map.container().removeChild(loupe.container());
        map.off("move", move).off("resize", move);
      }
      if (map = x) {
        if (!centerPoint) {
          var size = map.size();
          centerPoint = {x: size.x >> 1, y: size.y >> 1};
        }
        map.on("move", mapmove).on("resize", mapmove);
        map.container().appendChild(loupe.container());
        mapmove();
      }
      return loupe;
    };

    var __add__ = loupe.add;
    loupe.add = function(x) {
      __add__(x);
      if (x.container) {
        x = x.container();
        x.setAttribute("clip-path", clipHref);
        x.setAttribute("pointer-events", "none");
      }
      container.appendChild(fore); // move to end
      return loupe;
    };

    loupe.centerPoint = function(x) {
      if (!arguments.length) return centerPoint;
      centerPoint = {x: Math.round(x.x), y: Math.round(x.y)};
      if (map) mapmove();
      return loupe;
    };

    loupe.radiusRange = function(x) {
      if (!arguments.length) return rr;
      rr = x;
      return loupe.radius(r);
    };

    loupe.radius = function(x) {
      if (!arguments.length) return r;
      r = rr ? Math.max(rr[0], Math.min(rr[1], x)) : x;

      // update back, fore and clip
      back.setAttribute("cx", r);
      back.setAttribute("cy", r);
      back.setAttribute("r", r);
      fore.setAttribute("cx", r);
      fore.setAttribute("cy", r);
      fore.setAttribute("r", r);
      clipCircle.setAttribute("r", r * k);

      // update the tab path
      tab.setAttribute("d", "M" + r + "," + 2 * r
          + "H" + 1.9 * r
          + "A" + r * .1 + "," + r * .1 + " 0 0,0 " + 2 * r + "," + 1.9 * r
          + "V" + r
          + "A" + r + "," + r + " 0 0,1 " + r + "," + 2 * r
          + "Z");

      // update the tab position
      if (tabPosition == "none") tab.setAttribute("display", "none");
      else {
        tab.removeAttribute("display");
        var a = tabAngles[tabPosition];
        if (a) tab.setAttribute("transform", "rotate(" + a + " " + r + "," + r + ")");
        else tab.removeAttribute("transform");
      }

      // update map size
      loupe.size({x: r * 2, y: r * 2})

      if (map) mapmove();
      return loupe;
    };

    loupe.tab = function(x) {
      if (!arguments.length) return tabPosition;
      tabPosition = x;
      return loupe.radius(r);
    };

    loupe.zoomDelta = function(x) {
      if (!arguments.length) return zoomDelta;
      zoomDelta = x;
      if (map) mapmove();
      return loupe;
    };

    loupe.visible = function(x) {
      if (!arguments.length) return visible;
      visible = x;
      if (x) g.removeAttribute("visibility");
      else g.setAttribute("visibility", "hidden");
      return loupe;
    };

    loupe.radius(r); // initialize circles

    return loupe;
  };
})(org.polymaps);
