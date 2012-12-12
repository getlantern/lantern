var sleep = require('./node_modules/sleep'),
    helpers = require('../app/js/helpers.js'),
      merge = helpers.merge,
    constants = require('../app/js/constants.js'),
      ENUMS = constants.ENUMS,
        CONNECTIVITY = ENUMS.CONNECTIVITY,
        MODAL = ENUMS.MODAL,
        OS = ENUMS.OS;

function make_simple_scenario(state) {
  return function() {
    var model = this.model, publishSync = this.publishSync;
    for (var path in state) {
      merge(model, state[path], path);
      publishSync(path);
    }
  };
}

exports.SCENARIOS = {
  os: {
    _applyImmediately: true,
    windows: {
      desc: 'Windows',
      func: make_simple_scenario({'system.os': OS.windows})
    },
    ubuntu: {
      desc: 'Ubuntu',
      func: make_simple_scenario({'system.os': OS.ubuntu})
    },
    osx: {
      desc: 'OS X',
      func: make_simple_scenario({'system.os': OS.osx})
    }
  },
  internet: {
    _applyImmediately: true,
    true: {
      desc: 'internet: true',
      func: make_simple_scenario({'connectivity.internet': true})
    },
    false: {
      desc: 'internet: false',
      func: make_simple_scenario({'connectivity.internet': false})
    }
  },
  location: {
    _applyImmediately: true,
    beijing: {
      desc: 'location: Beijing',
      func: make_simple_scenario({
              location: {lat:39.904041, lon:116.407528, country:'cn'},
              'connectivity.ip': '123.123.123.123'
            })
    },
    paris: {
      desc: 'location: Paris',
      func: make_simple_scenario({
              location: {lat:48.8667, lon:2.3333, country:'fr'},
              'connectivity.ip': '78.250.177.119'
            })
    }
  },
  gtalkAuthorized: {
    false: {
      desc: 'gtalkAuthorized: false',
      func: make_simple_scenario({'connectivity.gtalkAuthorized': false})
    },
    true: {
      desc: 'gtalkAuthorized: true',
      func: make_simple_scenario({'connectivity.gtalkAuthorized': true,
        'settings.userid': 'user@example.com'})
    }
  },
  invited: {
    true: {
      desc: 'invited: true',
      func: make_simple_scenario({'connectivity.invited': true})
    },
    false: {
      desc: 'invited: false',
      func: make_simple_scenario({'connectivity.invited': false})
    }
  },
  gtalkReachable: {
    false: {
      desc: 'gtalkReachable: false',
      func: function() {
              this.updateModel({'connectivity.gtalk': CONNECTIVITY.connecting,
                modal: MODAL.gtalkConnecting}, true);
              this.updateModel({'connectivity.gtalk': CONNECTIVITY.notConnected,
                modal: MODAL.gtalkUnreachable}, true);
            }
    },
    true: {
      desc: 'gtalkReachable: true',
      func: function() {
              this.updateModel({'connectivity.gtalk': CONNECTIVITY.connecting,
                modal: MODAL.gtalkConnecting}, true);
              this.updateModel({'connectivity.gtalk': CONNECTIVITY.connected}, true);
            }
    }
  },
  roster: {
    roster1: {
      desc: 'roster1',
      func: function() {
              var roster = [{
                email: 'lantern_friend1@example.com',
                name: 'Lantern Friend 1',
                link: '',
                picture: '',
                status: 'away',
                statusMessage: 'meeting',
                }
               ,{
                email: 'lantern_friend2@example.com',
                name: 'Lantern Friend 2',
                link: '',
                picture: '',
                status: 'available',
                statusMessage: 'Bangkok',
                }
               ,{
                email: 'not_a_lantern_user1@example.com',
                name: 'Not A Lantern User 1',
                link: '',
                picture: '',
                status: 'idle',
                statusMessage: 'sleeping'
                }
               ,{
                email: 'not_a_lantern_user2@example.com',
                name: 'Not A Lantern User 2',
                link: '',
                picture: '',
                status: 'offline'
                }
               ,{
                email: 'lantern_power_user@example.com',
                name: 'Lantern Power User',
                link: '',
                picture: '',
                status: 'available',
                statusMessage: 'Shanghai!',
                }
              ];
              this.updateModel({roster: roster}, true);
            }
    }
  },
  friends: {
    friends1: {
      desc: 'friends1',
      func: function() {
              var friends = {
                current: [{
                           email: 'lantern_friend1@example.com',
                           name: 'Lantern Friend 1'
                          },
                          {
                           email: 'lantern_friend2@example.com',
                           name: 'Lantern Friend 2'
                          },
                          {
                           email: 'lantern_power_user@example.com',
                           name: 'Lantern Power User'
                          }],
                pending: [{
                           email: 'not_on_roster@example.com',
                           name: 'Not On Roster',
                          }]
                };
              this.updateModel({friends: friends}, true);
            }
    }
  },
  peers: {
    peers1: {
      desc: 'peers1',
      func: function() {
              // XXX simulate peers going on and offline
              var peers = {
                current: ['friend1-1', 'friend2-1', 'poweruser-1', 'poweruser-2', 'poweruser-3', 'poweruser-4'],
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

/* XXX update available scenario
model.version.updated = {
"label":"0.0.2",
"url":"https://lantern.s3.amazonaws.com/lantern-0.0.2.dmg",
"released":"2012-11-11T00:00:00Z"
}
*/
