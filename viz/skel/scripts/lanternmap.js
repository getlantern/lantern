$(document).ready(function() {
    var lt = org.lantern; 
    var po = org.polymaps;

    var historicData = new Array();
    var countryData = {};
    var fetchData = function() {
        $.getJSON('http://localhost:7878/stats?callback=?', function(data) {
          var countries = data.countries;
          historicData.push(countries);
          if (historicData.length > 400) {
              historicData.shift();
          }
          if (activelayer == 'usersmap')
            update_users_layer(data);
          else if (activelayer == 'onimap')
            update_oni_layer(data);
          else if (activelayer == 'googmap')
            update_goog_layer(data);
          for (var i=0, ln=countries.length; i<ln; ++i) {
            var co = countries[i];
            if (!co.censored) {
                continue;
            }
            var code = co.code,
                name = co.name,
                lantern = co.lantern,
                users = lantern.users;

            //console.info("Processing "+lantern.code);
            if (!(code in countryData)) {
                //console.info('Adding "new-country" class for '+name);
                try {
                    var countrysvg = d3.select('.iso2-' + code);
                    countrysvg.classed("new-country", true);
                    if (code == 'YE') {
                         //lt.zoomSVG('.iso2-YE', um, map);
                    }
                } catch(err) {
                    console.info('could not add class for country ' + code + ":" + err);
                }
            } else {
                var oldData = countryData[code];
                if (oldData.lantern.users < users) {
                    try {
                        //console.info("Got new users in "+name);
                        d3.select('.iso2-' + code).classed("new-users", true)
                            .classed("new-country", false);
                        /*
                        d3.select('.iso2-' + code).transition()
                            .delay(750)
                            .classed("new-country", false);
                        */
                    } catch(err) {
                        console.info('Transition failed for ' + code + err);
                   }
                } else {
                    //console.info(oldData.users +" not less than "+users);
                }
            } 

            countryData[code] = co;
            try {
              d3.select('.iso2-' + code + ' title').text(name + ': users: ' + users);
            } catch(err) {
              //console.error('could not set title for country ' + code);
            }
          }
          var home = data.my_country;
          d3.select('.iso2-' + home).classed("my-country", true);
        });
    }

    // called by the above click handler if a country is clicked
    function countryClicked(countryCode, el) {
        lt.zoomSVG('.iso2-' + countryCode, um, map);
        showCountryData(countryCode);
    }

    function map_ready() {
        fetchData();
        setInterval(function() {
            fetchData();
        }, 2000);

        // override default click handler 
        d3.select(map.container()).on("dblclick", function(evt) {
            // try to detect a click on a country and extract the iso2 cc
            var cc = lt.getCountry(d3.event.target, 'iso2-');
            if (cc != null) {
                countryClicked(cc, d3.event.target);
            }
        });

    }

    var map = po.map()
        .container(document.getElementById("map").appendChild(po.svg("svg")))
        .center({lat: 40, lon: 0})
        .zoomRange([2.25, 7])
        .zoom(2.25)
        .add(po.interact());

    // map.add(lt.blueMarbleBaseLayer());
    // $("#map").addClass("blue-marble-map");

    // map.add(lt.lightBaseLayer());
    // $("#map").addClass("light-map");

    map.add(lt.darkBaseLayer());
    $("#map").addClass("dark-map");

    var layer2obj = {};

    var oni = po.geoJson()
            .url('../data/world_tm03_bigs.json')
            .tile(false)
            .zoom(3)
            .on('load', function(e) { countries_loaded(e); });
    d3.select(oni.container()).attr('id', 'onimap').classed('layerhidden', true);
    layer2obj['onimap'] = oni;
        map.add(oni);

    var googlayer = po.geoJson()
            .url('../data/world_tm03_bigs.json')
            .tile(false)
            .zoom(3)
            .on('load', function(e) { countries_loaded(e); });
    d3.select(googlayer.container()).attr('id', 'googmap').classed('layerhidden', true);
    layer2obj['googmap'] = googlayer;
        map.add(googlayer);

    var um = po.geoJson()
            .url('../data/world_tm03_bigs.json')
            .tile(false)
            .zoom(3)
            .on('load', function(e) { map_ready(); countries_loaded(e); });
    d3.select(um.container()).attr('id', 'usersmap');
    layer2obj['usersmap'] = um;
    map.add(um);

    /*
    map.add(po.layer(function(tile, proj) {
        var g = tile.element = po.svg("g");
        var projection = proj(tile);
        function drawLine(pt0, pt1) {
            var tp0 = projection.locationPoint({lon: pt0[0], lat: pt0[1]});
            var tp1 = projection.locationPoint({lon: pt1[0], lat: pt1[1]});
            var line = ["M", tp0.x, tp0.y, tp1.x, tp1.y];
            d3.select(g).append("svg:path")
                .attr("d", line.join(" "))
                .classed("lantern-line", true);
        }
        drawLine([-74.006, 40.720], [4.33, 50.861]);

    }).tile(false).zoom(3));
    */

    // add these later so they end up "on top"
    var compass = po.compass().pan("none");
    map.add(compass);
    lt.setupFullScreenToggle("#map", map);

    function update_users_layer(data) {
      var choropleth = {};
      var countries = data.countries;
      for (var i=0, ln=countries.length; i<ln; i++) {
        var country = countries[i];
        if (country.censored)
          choropleth['.iso2-' + country.code] = country.lantern.users;
      }
      lt.applyColors('#usersmap', choropleth);
    }

    var _onivaltonum = {
      'pervasive': 10,
      'substantial': 8,
      'selective': 4,
      'suspected': 2
    };
    function update_oni_layer(data) {
      var valspolitical = {};
      var countries = data.countries;
      for (var i=0, ln=countries.length; i<ln; i++) {
        var country = countries[i],
            code = country.code,
            oni = country.oni;
        if (!oni) continue;
        var political = oni.political;
        if (!political || political == 'no evidence') continue;
        valspolitical['.iso2-' + code] = _onivaltonum[political];
      }
      lt.applyColors('#onimap', valspolitical);
    }

    function update_goog_layer(data) {
      var vals = {};
      var countries = data.countries;
      for (var i=0, ln=countries.length; i<ln; i++) {
        var country = countries[i],
            code = country.code,
            goog = country['google-content-removal-requests.csv'];
        if (!goog) continue;
        var val = parseInt(goog['Content Removal Requests']);
        if (isNaN(val)) continue;
        vals['.iso2-' + code] = val;
      }
      lt.applyColors('#googmap', vals);
    }

    var activelayer = 'usersmap';
    var key2layer = {71/*g*/: 'googmap', 79/*o*/: 'onimap', 85/*u*/: 'usersmap'};
    function togglelayer(id, visible) {
      d3.selectAll('#'+id).classed('layerhidden', !visible);
      if (visible)
        activelayer = id;
    }
    function keyhandler(e) {
      var layer = key2layer[e.keyCode];
      if (!layer || activelayer == layer) return;
      for (var k in key2layer) {
        var l = key2layer[k];
        togglelayer(l, l == layer);
      }
    }
    window.addEventListener("keyup", keyhandler, false);

    function countries_loaded(e) {
      var features = e.features;
      for (var i=0, ln=features.length; i<ln; i++) {
        var feature = features[i],
            el = feature.element,
            props = feature.data.properties;
        d3.select(el)
            .classed("country-border", true)
            .classed("fips-" + props.FIPS, true)
            .classed("iso3-" + props.ISO3, true)
            .classed("iso2-" + props.ISO2, true)
            .append('svg:title').text(props.NAME);
      }
    }

    function showCountryData(countryCode) {
        //console.info("Showing country data for "+countryCode);
        $.getJSON('http://localhost:7878/country/'+countryCode+'?callback=?', 
            function(json) {
            
            //console.dir(json);
            var htmlText = 
                "<div class='country-data lantern-data'>" +
                    "Proxy Users: "+json.lantern.users+
                "</div>"+
                "<div class='country-data lantern-data'>" +
                    "Proxied Bytes: "+json.lantern.proxied_bytes+
                "</div>"+
                "<div class='country-data oni-data'>" +
                    "ONI Political: "+json.oni.political+
                "</div>"+
                "<div class='country-data oni-data'>" +
                    "ONI Social: "+json.oni.social+
                "</div>"+
                "<div class='country-data oni-data'>" +
                    "ONI Tools: "+json.oni.tools+
                "</div>"+
                "<div class='country-data oni-data'>" +
                    "ONI Conflict/Security: "+json.oni.conflict_security+
                "</div>";
            var contentRemoval = json["google-content-removal-requests.csv"];
            if (contentRemoval != null && contentRemoval != undefined) {
                for (var prop in contentRemoval) {
                    htmlText +=
                        "<div class='country-data google-data'>" +
                            "Google "+prop+": "+
                            contentRemoval[prop]+
                        "</div>";
                }
            }
            var contentRemovalProduct = 
                json["google-content-removal-requests-by-product.csv"];
            if (contentRemovalProduct != null && 
                contentRemovalProduct != undefined) {
                for (var prop in contentRemovalProduct) {
                    htmlText +=
                        "<div class='country-data google-data'>" +
                            "Google "+prop+": "+
                            contentRemovalProduct[prop]+
                        "</div>";
                }
            }
            /*
            var url =
                "http://www.herdict.org/api/query?fc="+countryCode+"fsd=2011-02-20&fed=2011-02-28";//&fsd=2011-09-01&fed=2011-10-09";
            $.getJSON(url, function(json) {
                console.dir(json);
            });
            */
            $("#dialog").html(htmlText);
            $("#dialog").dialog({
                title: json.name,
                close: function(event, ui) { 
                    var bbox = [-90, 0, 90, 180];
                    map.zoom(0);
                    //lt.zoomBBox(bbox, map);
                }
            });
        });
    };
});
