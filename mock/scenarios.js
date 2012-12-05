var sleep = require('./node_modules/sleep'),
    helpers = require('./helpers'),
    enums = require('./enums'),
    CONNECTIVITY = enums.CONNECTIVITY,
    MODAL = enums.MODAL,
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
    _applyImmediately: true,
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
    _applyImmediately: true,
    connection: {
      desc: 'internet connection',
      func: make_simple_scenario({'connectivity.internet': true})
    },
    noConnection: {
      desc: 'no internet connection',
      func: make_simple_scenario({'connectivity.internet': false})
    }
  },
  location: {
    _applyImmediately: true,
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
  },
  oauth: {
    notAuthorized: {
      desc: 'oauth: not authorized',
      func: make_simple_scenario({'connectivity.gtalkAuthorized': false})
    },
    authorized: {
      desc: 'oauth: authorized',
      func: make_simple_scenario({'connectivity.gtalkAuthorized': true,
        'settings.userid': 'user@example.com'})
    }
  },
  lanternAccess: {
    noAccess: {
      desc: 'no Lantern access',
      func: make_simple_scenario({'connectivity.lanternAccess': false})
    },
    access: {
      desc: 'Lantern access',
      func: make_simple_scenario({'connectivity.lanternAccess': true})
    }
  },
  gtalkConnect: {
    notReachable: {
      desc: 'cannot reach Google Talk',
      func: function() {
              this.updateModel({'connectivity.gtalk': CONNECTIVITY.connecting,
                modal: MODAL.gtalkConnecting}, true);
              sleep.usleep(2000000);
              this.updateModel({'connectivity.gtalk': CONNECTIVITY.notConnected,
                modal: MODAL.gtalkUnreachable}, true);
            }
    },
    reachable: {
      desc: 'can reach Google Talk',
      func: function() {
              this.updateModel({'connectivity.gtalk': CONNECTIVITY.connecting,
                modal: MODAL.gtalkConnecting}, true);
              sleep.usleep(2000000);
              this.updateModel({'connectivity.gtalk': CONNECTIVITY.connected}, true);
            }
    }
  },
  roster: {
    contactsHaveLantern: {
      desc: 'contacts have Lantern',
      func: function() {
              var roster = [{
                userid: 'lantern_friend1@example.com',
                name: 'Lantern Friend 1',
                avatarUrl: '',
                status: 'away',
                statusMessage: 'meeting',
                peers: ['friend1-1']
                }
               ,{
                userid: 'lantern_friend2@example.com',
                name: 'Lantern Friend 2',
                avatarUrl: '',
                status: 'available',
                statusMessage: 'Bangkok',
                peers: ['friend2-1']
                }
               ,{
                userid: 'not_a_lantern_user1@example.com',
                name: 'Not A Lantern User 1',
                avatarUrl: '',
                status: 'idle',
                statusMessage: 'sleeping'
                }
               ,{
                userid: 'not_a_lantern_user2@example.com',
                name: 'Not A Lantern User 2',
                avatarUrl: '',
                status: 'offline'
                }
               ,{
                userid: 'lantern_power_user@example.com',
                name: 'Lantern Power User',
                avatarUrl: '',
                status: 'available',
                statusMessage: 'Shanghai!',
                peers: ['poweruser-1', 'poweruser-2', 'poweruser-3', 'poweruser-4']
                }
              ];
              this.updateModel({roster: roster}, true);
            }
    }
  },
  peers: {
    peersOnline: {
      desc: 'some peers online',
      func: function() {
              // XXX simulate peers going on and offline
              var peers = {
                current: ['friend1-1', 'friend2-1', 'poweruser-1', 'poweruser-2', 'poweruser-3', 'poweruser-4'],
                pending: [{
                    userid: 'not_on_roster@example.com',
                    name: 'Not On Roster',
                    avatarUrl: '',
                  }
                ],
                lifetime: [{
                    peerid: 'friend1-1',
                    userid: 'lantern_friend1@example.com ',
                    mode: 'give',
                    ip: '74.120.12.135',
                    lat: 51,
                    lon: 9,
                    country: 'de',
                    type: 'desktop'
                  },{
                    peerid: 'friend2-1',
                    userid: 'lantern_friend2@example.com ',
                    mode: 'get',
                    ip: '27.55.2.80',
                    lat: 13.754,
                    lon: 100.5014,
                    country: 'th',
                    type: 'desktop'
                  },{
                    peerid: 'poweruser-1',
                    userid: 'lantern_power_user@example.com',
                    mode: 'give',
                    ip: '93.182.129.82',
                    lat: 55.7,
                    lon: 13.1833,
                    country: 'se',
                    type: 'lec2proxy'
                  },{
                    peerid: 'poweruser-2',
                    userid: 'lantern_power_user@example.com',
                    mode: 'give',
                    ip: '173.194.66.141',
                    lat: 37.4192,
                    lon: -122.0574,
                    country: 'us',
                    type: 'laeproxy'
                  },{
                    peerid: 'poweruser-3',
                    userid: 'lantern_power_user@example.com',
                    mode: 'give',
                    ip: '...',
                    lat: 54,
                    lon: -2,
                    country: 'gb',
                    type: 'lec2proxy'
                  },{
                    peerid: 'poweruser-4',
                    userid: 'lantern_power_user@example.com',
                    mode: 'get',
                    ip: '...',
                    lat: 31.230381,
                    lon: 121.473684,
                    country: 'cn',
                    type: 'desktop'
                  }
                ]
              };
              this.updateModel({'connectivity.peers': peers}, true);
            }
    }
  }
};

/*
model.version.updated = {
"label":"0.0.2",
"url":"https://lantern.s3.amazonaws.com/lantern-0.0.2.dmg",
"released":"2012-11-11T00:00:00Z"
}
*/
