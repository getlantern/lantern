var sleep = require('./node_modules/sleep'),
    _ = require('../app/lib/lodash.js')._,
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
  updateAvailable: {
    _applyImmediately: true,
    true: {
      desc: 'updateAvailable: true',
      func: make_simple_scenario({'version.updateAvailable': true,
              'version.latest': {
                "major": 0,
                "minor": 23,
                "patch": 0,
                "tag": "beta",
                "git": "ac7de5f",
                "releaseDate": "2013-1-30",
                "installerUrl": "https://lantern.s3.amazonaws.com/lantern-0.23.0.dmg",
                "installerSHA1": "b3d15ec2d190fac79e858f5dec57ba296ac85776",
                "changes": [{
                    "en": "(English translation of <a href=\"#\">feature x</a>)",
                    "zh": "(Chinese translation of <a href=\"#\">feature x</a>)"
                  },{
                    "en": "(English translation of <a href=\"#\">feature y</a>)",
                    "zh": "(Chinese translation of <a href=\"#\">feature y</a>)"
                  }
                ],
                "modelSchema": {
                  "major": 0,
                  "minor": 0,
                  "patch": 1
                },
                "httpApi": {
                  "major": 0,
                  "minor": 0,
                  "patch": 1
                },
                "bayeuxProtocol": {
                  "major": 0,
                  "minor": 0,
                  "patch": 1
                }
              }
            })
    },
    false: {
      desc: 'updateAvailable: false',
      func: make_simple_scenario({'version.updateAvailable': false})
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
    nyc: {
      desc: 'location: NYC',
      func: make_simple_scenario({
              location: {lat:40.7089, lon:-74.0012, country:'us'},
              'connectivity.ip': '64.90.182.55'
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
        'settings.email': 'user@example.com'})
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
  ninvites: {
    0: {
      desc: 'ninvites: 0',
      func: make_simple_scenario({'ninvites': 0})
    },
    10: {
      desc: 'ninvites: 10',
      func: make_simple_scenario({'ninvites': 10})
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
                email: 'user1@example.com',
                name: 'User 1',
                link: '',
                picture: '',
                status: 'idle',
                statusMessage: 'sleeping'
                }
               ,{
                email: 'user2@example.com',
                name: 'User 2',
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
                           email: 'user7@example.com',
                           name: 'User 7',
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
              var peers = [{
                    peerid: 'friend1-1',
                    email: 'lantern_friend1@example.com ',
                    mode: 'give',
                    ip: '74.120.12.135',
                    lat: 51,
                    lon: 9,
                    country: 'de',
                    type: 'desktop'
                  },{
                    peerid: 'friend2-1',
                    email: 'lantern_friend2@example.com ',
                    mode: 'get',
                    ip: '27.55.2.80',
                    lat: 13.754,
                    lon: 100.5014,
                    country: 'th',
                    type: 'desktop'
                  },{
                    peerid: 'poweruser-1',
                    email: 'lantern_power_user@example.com',
                    mode: 'give',
                    ip: '93.182.129.82',
                    lat: 55.7,
                    lon: 13.1833,
                    country: 'se',
                    type: 'lec2proxy'
                  },{
                    peerid: 'poweruser-2',
                    email: 'lantern_power_user@example.com',
                    mode: 'give',
                    ip: '173.194.66.141',
                    lat: 37.4192,
                    lon: -122.0574,
                    country: 'us',
                    type: 'laeproxy'
                  },{
                    peerid: 'poweruser-3',
                    email: 'lantern_power_user@example.com',
                    mode: 'give',
                    ip: '...',
                    lat: 54,
                    lon: -2,
                    country: 'gb',
                    type: 'lec2proxy'
                  },{
                    peerid: 'poweruser-4',
                    email: 'lantern_power_user@example.com',
                    mode: 'get',
                    ip: '...',
                    lat: 31.230381,
                    lon: 121.473684,
                    country: 'cn',
                    type: 'desktop'
                  }
              ];
              this.updateModel({'connectivity.peers': {
                current: peers,
                lifetime: _.cloneDeep(peers)
              }}, true);
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
