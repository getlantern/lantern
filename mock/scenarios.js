var helpers = require('./helpers'),
    enums = require('./enums'),
    CONNECTIVITY = enums.CONNECTIVITY,
    OS = enums.OS;

function make_simple_scenario(state) {
  return function() {
    var model = this.model, publishSync = this.publishSync;
    for (var path in state) {
      helpers.merge(model, path, state[path]);
      publishSync(path);
    }
  };
}

exports.SCENARIOS = {
  os: {
    windows: {
      desc: 'running Windows',
      func: make_simple_scenario({'system.os': OS.windows})
    },
    ubuntu: {
      desc: 'running Ubuntu',
      func: make_simple_scenario({'system.os': OS.ubuntu})
    },
    osx: {
      desc: 'running OS X',
      func: make_simple_scenario({'system.os': OS.osx})
    }
  },
  internet: {
    connection: {
      desc: 'internet connection',
      func: make_simple_scenario({'connectivity.internet': true})
    },
    noConnection: {
      desc: 'no internet connection',
      func: make_simple_scenario({'connectivity.internet': false})
    }
  },
  gtalkAuthorization: {
    notAuthorized: {
      desc: 'not authorized to access Google Talk',
      func: make_simple_scenario({'connectivity.gtalkAuthorized': false})
    },
    authorized: {
      desc: 'authorized to access Google Talk',
      func: make_simple_scenario({'connectivity.gtalkAuthorized': true})
    }
  },
  gtalkConnectivity: {
    notConnected: {
      desc: 'not connected to Google Talk',
      func: make_simple_scenario({'connectivity.gtalk': CONNECTIVITY.notConnected})
    },
    connecting: {
      desc: 'connecting to Google Talk',
      func: make_simple_scenario({'connectivity.gtalk': CONNECTIVITY.connecting})
    },
    connected: {
      desc: 'connected to Google Talk',
      func: make_simple_scenario({'connectivity.gtalk': CONNECTIVITY.connected})
    }
  },
  location: {
    beijing: {
      desc: 'connecting from Beijing',
      func: make_simple_scenario({
              location: {lat:39.904041, lon:116.407528, country:'cn'},
              'connectivity.ip': '123.123.123.123'
            })
    },
    paris: {
      desc: 'connecting from Paris',
      func: make_simple_scenario({
              location: {lat:48.8667, lon:2.3333, country:'fr'},
              'connectivity.ip': '78.250.177.119'
            })
    }
  }
};

/*
var peer1 = {
    "peerid": "peerid1",
    "userid": "lantern_friend1@example.com",
    "mode":"give",
    "ip":"74.120.12.135",
    "lat":51,
    "lon":9,
    "country":"de",
    "type":"desktop"
    }
, peer2 = {
    "peerid": "peerid2",
    "userid": "lantern_power_user@example.com",
    "mode":"give",
    "ip":"93.182.129.82",
    "lat":55.7,
    "lon":13.1833,
    "country":"se",
    "type":"lec2proxy"
  }
, peer3 = {
    "peerid": "peerid3",
    "userid": "lantern_power_user@example.com",
    "mode":"give",
    "ip":"173.194.66.141",
    "lat":37.4192,
    "lon":-122.0574,
    "country":"us",
    "type":"laeproxy"
  }
, peer4 = {
    "peerid": "peerid4",
    "userid": "lantern_power_user@example.com",
    "mode":"give",
    "ip":"...",
    "lat":54,
    "lon":-2,
    "country":"gb",
    "type":"lec2proxy"
  }
, peer5 = {
    "peerid": "peerid5",
    "userid": "lantern_power_user@example.com",
    "mode":"get",
    "ip":"...",
    "lat":31.230381,
    "lon":121.473684,
    "country":"cn",
    "type":"desktop"
  }
;

var roster = [{
  "userid":"lantern_friend1@example.com",
  "name":"Lantern Friend1",
  "avatarUrl":"",
  "status":"available",
  "statusMessage":"",
  "peers":["peerid1"]
  }
 ,{
  "userid":"lantern_power_user@example.com",
  "name":"Lantern Poweruser",
  "avatarUrl":"",
  "status":"available",
  "statusMessage":"Shanghai!",
  "peers":["peerid2", "peerid3", "peerid4", "peerid5"]
  }
];

model.version.updated = {
"label":"0.0.2",
"url":"https://lantern.s3.amazonaws.com/lantern-0.0.2.dmg",
"released":"2012-11-11T00:00:00Z"
}

ApiServlet.prototype._tryConnect = function(model) {
  var userid = model.settings.userid
    , publishSync = this._bayeuxBackend.publishSync.bind(this._bayeuxBackend)
    ;

  // connect to google talk
  model.connectivity.gtalk = CONNECTIVITY.connecting;
  publishSync('connectivity.gtalk');
  model.modal = MODAL.gtalkConnecting;
  publishSync('modal');
  sleep.usleep(3000000);
  if (userid ==  'user_cant_reach_gtalk@example.com') {
    model.connectivity.gtalk = CONNECTIVITY.notConnected;
    publishSync('connectivity.gtalk');
    model.modal = MODAL.gtalkUnreachable;
    publishSync('modal');
    util.puts("user can't reach google talk, set modal to "+MODAL.gtalkUnreachable);
    return;
  }
  model.connectivity.gtalk = CONNECTIVITY.connected;
  publishSync('connectivity.gtalk');

  // refresh roster
  model.roster = roster;
  publishSync('roster');
  sleep.usleep(250000);

  // check for lantern access
  if (userid != 'user@example.com') {
    model.modal = MODAL.notInvited;
    publishSync('modal');
    util.puts("user does not have Lantern access, set modal to "+MODAL.notInvited);
    return;
  }

  // try connecting to known peers
  // (advertised by online Lantern friends or remembered from previous connection)
  model.connectivity.peers.current = [peer1.peerid, peer2.peerid, peer3.peerid, peer4.peerid, peer5.peerid];
  model.connectivity.peers.lifetime = [peer1, peer2, peer3, peer4, peer5];
  publishSync('connectivity.peers');
  util.puts("user has access; connected to google talk, fetched roster:\n"+util.inspect(roster)+"\ndiscovered and connected to peers:\n"+util.inspect(model.connectivity.peers.current));
  ApiServlet._advanceModal.call(this);
};
*/
