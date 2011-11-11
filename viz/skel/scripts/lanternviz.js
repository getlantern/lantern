if (!org) var org = {};
if (!org.lantern) org.lantern = {};
(function(lt){

    var po = org.polymaps;

    // returns "dark" polymaps base layer
    lt.darkBaseLayer = function() {
        return po.image()
            .url(po.url("http://{S}tile.cloudmade.com"
            + "/be8294136a204eed86c4900cdd35448e" 
            + "/47808/256/{Z}/{X}/{Y}.png")
            .hosts(["a.", "b.", "c.", ""]))
    };

    // returns "light" polymaps base layer
    lt.lightBaseLayer = function() {
        return po.image()
            .url(po.url("http://{S}tile.cloudmade.com"
            + "/be8294136a204eed86c4900cdd35448e" 
            + "/47789/256/{Z}/{X}/{Y}.png")
            .hosts(["a.", "b.", "c.", ""])); 
    };

    // returns blue marble polymaps base layer
    lt.blueMarbleBaseLayer = function() {
        // (modest maps hosting)
        return po.image()
                .url("http://s3.amazonaws.com/com.modestmaps.bluemarble/{Z}-r{Y}-c{X}.jpg");
    };


    /** 
     * sets up a full screen toggle button similar to polymaps.org examples
     * but using d3 instead of nns, and defers some work to css classes.
     *
     * map_el - selector for the element that contains the map (container div)
     * map - the polymaps "map" object contained in map_el
     *
     */
    lt.setupFullScreenToggle = function(map_el, map) {

        var body = d3.select(document.body);
        var container = d3.select(map_el).style("visibility", "visible");

        var button = container
              .append("svg:svg")
              .attr("width",32)
              .attr("height",32)
              .style("position","absolute")
              .style("right","-16px")
              .style("top","-16px")
              .style("visibility","visible")
              .on("mousedown",toggleFullScreen);
        var circle = button.append("svg:circle")
            .attr("cx",16)
            .attr("cy",16)
            .attr("r",14)
            .attr("fill","#fff")
            .attr("stroke","#ccc")
            .attr("stroke-width",4)
            .append("svg:title")
                .text("Toggle fullscreen. (ESC)");

        var symbol=button.append("svg:path")
                      .attr("d","M0,0L0,.5 2,.5 2,1.5 4,0 2,-1.5 2,-.5 0,-.5Z")
                      .attr("pointer-events","none")
                      .attr("fill","#aaa");

        var _isFullScreen= container.classed("fullscreen");
        if (_isFullScreen) {
            fullScreenOn();
        }
        else {
            fullScreenOff();
        }

        window.addEventListener("keydown",
            function(evt) {
                if (evt.keyCode==27 && _isFullScreen) {
                    toggleFullScreen();
                }
            },false);

        function fullScreenOn() {
            button.style("position","fixed")
                .style("right","16px")
                .style("top","16px");
            symbol.attr("transform","translate(16,16)rotate(135)scale(5)translate(-1.85,0)");
            body.classed("hidden", true);
            container.classed("fullscreen", true);
        }

        function fullScreenOff() {
            button.style("position","absolute")
                  .style("right","-16px")
                  .style("top","-16px");
            symbol.attr("transform","translate(16,16)rotate(-45)scale(5)translate(-1.85,0)");
            body.classed("hidden", false);
            container.classed("fullscreen", false);
        }

        function toggleFullScreen() {
            _isFullScreen = !_isFullScreen;
            if (_isFullScreen) {
                fullScreenOn();
            }
            else {
                fullScreenOff();
            }
            map.resize();
        }
    }

    /** 
     * gets the country code based on the class prefix 
     * given and classes on the element, eg 
     * getCountry(el, 'iso2-');
     */
    lt.getCountry = function(el, prefix) {
        var classes = d3.select(el).attr("class").split(" ");
        for (var i =0; i < classes.length; i++) {
            var c = classes[i];
            if (c.indexOf(prefix) == 0) {
                return c.substring(prefix.length);
            }
        }
        return null;    
    }
                
    /**
     * transforms from svg-land {x: 0, y: 0 } coordinates {lat: 0, lon: 0} to 
     * coordinate objects. 
     */
    lt.svgCoordinate = function(p, layer) {
        var tileSize = layer.map().tileSize();
        var zoom = layer.zoom()() || 0; // yes really!
        return po.map.coordinateLocation({row: p.y/tileSize.y, column: p.x/tileSize.x, zoom: zoom});
    }

    /**
     * zooms to a lat/lon bbox specified as
     * [lat,lon,lat,lon]
     */ 
    lt.zoomBBox = function(bbox, map) {                            
        var tr = map.locationPoint({ lat: bbox[0], lon: bbox[1] }),
            bl = map.locationPoint({ lat: bbox[2], lon: bbox[3] }),
            sizeActual = map.size(),
            k = Math.max((tr.x - bl.x) / sizeActual.x, (bl.y - tr.y) / sizeActual.y),
            l = map.pointLocation({x: (bl.x + tr.x) / 2, y: (bl.y + tr.y) / 2});
        
        // update the zoom level
        var z = map.zoom() - Math.log(k) / Math.log(2);
        
        lt.animateCenterZoom(map, l, z);
    }
    
    /** 
     * zoom to a svg element ie a country's border 
     * selector is something like iso2-US etc (uses first selected)
     * layer is the containing layer, eg the countries
     * layer. 
     */
    lt.zoomSVG = function(selector, layer, map) {
        var countrySVG = d3.select(selector);
        var svgBBox = countrySVG[0][0].getBBox();
        var tl = lt.svgCoordinate({x: svgBBox.x, y: svgBBox.y}, layer);
        var br = lt.svgCoordinate({x: svgBBox.x + svgBBox.width, 
                                y: svgBBox.y + svgBBox.height}, layer);
        var llbbox = [tl.lat, tl.lon, br.lat, br.lon];
        lt.zoomBBox(llbbox, map);
        // var bboxCenter = {x: bbox.x + bbox.width / 2, y: bbox.y + bbox.height / 2};
        // var countryCenter = svgCoordinate(bboxCenter, countriesLayer);
        //var countryCenter = po.map.coordinateLocation({row: bboxCenter.y/256.0, column: bboxCenter.x/256.0, zoom: 3});
    }
    
    /* taken from https://gist.github.com/600144 */
    
    var _flyInterval;
    lt.animateCenterZoom = function(map, l1, z1) {

        var start = po.map.locationCoordinate(map.center()),
            end   = po.map.locationCoordinate(l1);

        var c0 = { x: start.column, y: start.row },
            c1 = { x: end.column, y: end.row };

        // how much world can we see at zoom 0?
        var w0 = visibleWorld(map);

        // z1 is ds times bigger than this zoom:
        var ds = Math.pow(2, z1 - map.zoom());

        // so how much world at zoom z1?
        var w1 = w0 / ds;

        if (_flyInterval) {
            clearInterval(_flyInterval);
            _flyInterval = 0;
        }

        // GO!
        animateStep(map, c0, w0, c1, w1);

    }

    function visibleWorld(map) {
        // how much world can we see at zoom 0?
        var tileCenter = po.map.locationCoordinate(map.center());
        var topLeft = map.pointCoordinate(tileCenter, { x:0, y:0 });
        var bottomRight = map.pointCoordinate(tileCenter, map.size())
        var correction = Math.pow(2, topLeft.zoom);
        topLeft.column /= correction;
        bottomRight.column /= correction;
        topLeft.row /= correction;
        bottomRight.row /= correction;
        topLeft.zoom = bottomRight.zoom = 0;
        return Math.max(bottomRight.column-topLeft.column, bottomRight.row-topLeft.row);
    }

    /*

        From "Smooth and efficient zooming and panning"
        by Jarke J. van Wijk and Wim A.A. Nuij

        You only need to understand section 3 (equations 1 through 5) 
        and then you can skip to equation 9, implemented below:

    */

    function sq(n) { return n*n; }
    function dist(a,b) { return Math.sqrt(sq(b.x-a.x)+sq(b.y-a.y)); }
    function lerp1(a,b,p) { return a + ((b-a) * p) }
    function lerp2(a,b,p) { return { x: lerp1(a.x,b.x,p), y: lerp1(a.y,b.y,p) }; }
    function cosh(x) { return (Math.exp(x) + Math.exp(-x)) / 2; }
    function sinh(x) { return (Math.exp(x) - Math.exp(-x)) / 2; }
    function tanh(x) { return sinh(x) / cosh(x); }

    function animateStep(map,c0,w0,c1,w1,V,rho) {

        // see section 6 for user testing to derive these values (they can be tuned)
        if (V === undefined)     V = 2.0;  // section 6 suggests 0.9
        if (rho === undefined) rho = 1.42; // section 6 suggests 1.42

        // simple interpolation of positions will be fine:
        var u0 = 0,
            u1 = dist(c0,c1);

        // i = 0 or 1
        function b(i) {
            var n = sq(w1) - sq(w0) + ((i ? -1 : 1) * Math.pow(rho,4) * sq(u1-u0));
            var d = 2 * (i ? w1 : w0) * sq(rho) * (u1-u0);
            return n / d;
        }

        // give this a b(0) or b(1)
        function r(b) {
            return Math.log(-b + Math.sqrt(sq(b)+1));
        }

        var r0 = r(b(0)),
            r1 = r(b(1)),
            S = (r1-r0) / rho; // "distance"

        function u(s) {
            var a = w0/sq(rho),
                b = a * cosh(r0) * tanh(rho*s + r0),
                c = a * sinh(r0);
            return b - c + u0;
        }

        function w(s) {
            return w0 * cosh(r0) / cosh(rho*s + r0);
        }

        // special case
        if (Math.abs(u0-u1) < 0.000001) {
            if (Math.abs(w0-w1) < 0.000001) return;

            var k = w1 < w0 ? -1 : 1;
            S = Math.abs(Math.log(w1/w0)) / rho;
            u = function(s) { 
                return u0;
            }
            w = function(s) { 
                return w0 * Math.exp(k * rho * s);
            }
        }

        var t0 = Date.now();
        _flyInterval = setInterval(function() {
            var t1 = Date.now();
            var t = (t1 - t0) / 1000.0;
            var s = V * t;
            if (s > S) {
                s = S;
                clearInterval(_flyInterval);
                _flyInterval = 0;
            }
            var us = u(s);
            var pos = lerp2(c0,c1,(us-u0)/(u1-u0));
            applyPos(map, pos, w(s));
        }, 40);

    }

    function applyPos(map,pos,w) {
        var w0 = visibleWorld(map), // how much world can we see at zoom 0?
            size = map.size(),
            z = Math.log(w0/w) / Math.LN2,
            p = { x: size.x / 2, y: size.y / 2 },
            l  = po.map.coordinateLocation({ row: pos.y, column: pos.x, zoom: 0 });
        map.zoomBy(z, p, l);
    }

    var _nbuckets = 5;
    var _fillclass = 'fill-g';
    lt.applyColors = function(layersel, datamap) {
        var min = Infinity, max = -Infinity;
        for (var key in datamap) {
          var val = datamap[key];
          if (val < min) min = val;
          if (val > max) max = val;
        }
        if (min == Infinity || max == -Infinity) { console.error('min or max not set'); return; }
        var range = max - min;
        var layer = d3.select(layersel);
        for (var key in datamap) {
          var val = datamap[key];
          var normalized = (val - min) / range;
          var bucket = Math.floor(normalized * _nbuckets);
          if (bucket >= _nbuckets) bucket = _nbuckets - 1;
          var country = layer.selectAll(key);
          // clear any previously-set fill classes
          for (var i=0; i<_nbuckets; ++i) country.classed(_fillclass + i, false);
          country.classed(_fillclass + bucket, true);
        }
    };
})(org.lantern);