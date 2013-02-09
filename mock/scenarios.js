var sleep = require('./node_modules/sleep'),
    _ = require('../app/lib/lodash.js')._,
    helpers = require('../app/js/helpers.js'),
      makeLogger = helpers.makeLogger,
        log = makeLogger('scenarios'),
      randomChoice = helpers.randomChoice,
      getByPath = helpers.getByPath,
    constants = require('../app/js/constants.js'),
      ENUMS = constants.ENUMS,
        CONNECTIVITY = ENUMS.CONNECTIVITY,
        MODAL = ENUMS.MODAL,
        OS = ENUMS.OS;

function make_simple_scenario(state) {
  var patch = _.map(state, function(value, path) {
    return {op: 'add', path: path, value: value};
  });
  return function() {
    this.sync(patch);
  };
}

exports.SCENARIOS = {
  os: {
    _applyImmediately: true,
    windows: {
      desc: 'Windows',
      func: make_simple_scenario({'/system/os': OS.windows})
    },
    ubuntu: {
      desc: 'Ubuntu',
      func: make_simple_scenario({'/system/os': OS.ubuntu})
    },
    osx: {
      desc: 'OS X',
      func: make_simple_scenario({'/system/os': OS.osx})
    }
  },
  internet: {
    _applyImmediately: true,
    true: {
      desc: 'internet: true',
      func: make_simple_scenario({'/connectivity/internet': true})
    },
    false: {
      desc: 'internet: false',
      func: make_simple_scenario({'/connectivity/internet': false})
    }
  },
  updateAvailable: {
    _applyImmediately: true,
    true: {
      desc: 'updateAvailable: true',
      func: make_simple_scenario({'/version/updateAvailable': true,
              '/version/latest': {
                'major': 0,
                'minor': 23,
                'patch': 0,
                'tag': 'beta',
                'git': 'ac7de5f',
                'releaseDate': '2013-1-30',
                'installerUrl': 'https://lantern.s3.amazonaws.com/lantern-0.23.0.dmg',
                'installerSHA1': 'b3d15ec2d190fac79e858f5dec57ba296ac85776',
                'changes': [{
                    'en': '(English translation of <a href=\'#\'>feature x</a>)',
                    'zh': '(Chinese translation of <a href=\'#\'>feature x</a>)'
                  },{
                    'en': '(English translation of <a href=\'#\'>feature y</a>)',
                    'zh': '(Chinese translation of <a href=\'#\'>feature y</a>)'
                  }
                ],
                'modelSchema': {
                  'major': 0,
                  'minor': 0,
                  'patch': 1
                },
                'httpApi': {
                  'major': 0,
                  'minor': 0,
                  'patch': 1
                },
                'bayeuxProtocol': {
                  'major': 0,
                  'minor': 0,
                  'patch': 1
                }
              }
            })
    },
    false: {
      desc: 'updateAvailable: false',
      func: make_simple_scenario({'/version/updateAvailable': false})
    }
  },
  location: {
    _applyImmediately: true,
    beijing: {
      desc: 'location: Beijing',
      func: make_simple_scenario({
              '/location': {lat:39.904041, lon:116.407528, country:'CN'},
              '/connectivity/ip': '123.123.123.123'
            })
    },
    nyc: {
      desc: 'location: NYC',
      func: make_simple_scenario({
              '/location': {lat:40.7089, lon:-74.0012, country:'US'},
              '/connectivity/ip': '64.90.182.55'
            })
    },
    paris: {
      desc: 'location: Paris',
      func: make_simple_scenario({
              '/location': {lat:48.8667, lon:2.3333, country:'FR'},
              '/connectivity/ip': '78.250.177.119'
            })
    }
  },
  gtalkAuthorized: {
    false: {
      desc: 'gtalkAuthorized: false',
      func: make_simple_scenario({'/connectivity/gtalkAuthorized': false})
    },
    true: {
      desc: 'gtalkAuthorized: true',
      func: make_simple_scenario({'/connectivity/gtalkAuthorized': true,
        '/settings/email': 'user@example.com'})
    }
  },
  invited: {
    true: {
      desc: 'invited: true',
      func: make_simple_scenario({'/connectivity/invited': true})
    },
    false: {
      desc: 'invited: false',
      func: make_simple_scenario({'/connectivity/invited': false})
    }
  },
  ninvites: {
    0: {
      desc: 'ninvites: 0',
      func: make_simple_scenario({'/ninvites': 0})
    },
    10: {
      desc: 'ninvites: 10',
      func: make_simple_scenario({'/ninvites': 10})
    }
  },
  gtalkReachable: {
    false: {
      desc: 'gtalkReachable: false',
      func: function() {
              this.sync({'/connectivity/gtalk': CONNECTIVITY.connecting,
                '/modal': MODAL.gtalkConnecting});
              this.sync({'/connectivity/gtalk': CONNECTIVITY.notConnected,
                '/modal': MODAL.gtalkUnreachable});
            }
    },
    true: {
      desc: 'gtalkReachable: true',
      func: function() {
              this.sync({'/connectivity/gtalk': CONNECTIVITY.connecting,
                '/modal': MODAL.gtalkConnecting});
              this.sync({'/connectivity/gtalk': CONNECTIVITY.connected});
              this.sync({'/profile': {
                email: 'user@example.com',
                name: 'Some User',
                link: 'https://plus.google.com/1234567',
                picture: 'img/default-avatar.png',
                gender: '',
                birthday: '',
                locale: 'en'
              }});
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
              this.sync({'/roster': roster});
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
              this.sync({'/friends': friends});
            }
    }
  },
  peers: {
    peers1: {
      desc: 'peers1',
      func: function() {
              var this_ = this,
                  peers = [{
                    peerid: 'friend1-1',
                    email: 'lantern_friend1@example.com ',
                    name: 'Lantern Friend 1',
                    mode: 'give',
                    ip: '74.120.12.135',
                    lat: 51,
                    lon: 9,
                    country: 'DE',
                    type: 'desktop'
                  },{
                    peerid: 'friend2-1',
                    email: 'lantern_friend2@example.com ',
                    name: 'Lantern Friend 2',
                    mode: 'get',
                    ip: '27.55.2.80',
                    lat: 13.754,
                    lon: 100.5014,
                    country: 'TH',
                    type: 'desktop'
                  },{
                    peerid: 'poweruser-1',
                    email: 'lantern_power_user@example.com',
                    name: 'Lantern Power User',
                    mode: 'give',
                    ip: '93.182.129.82',
                    lat: 55.7,
                    lon: 13.1833,
                    country: 'SE',
                    type: 'lec2proxy'
                  },{
                    peerid: 'poweruser-2',
                    email: 'lantern_power_user@example.com',
                    name: 'Lantern Power User',
                    mode: 'give',
                    ip: '173.194.66.141',
                    lat: 37.4192,
                    lon: -122.0574,
                    country: 'US',
                    type: 'laeproxy'
                  },{
                    peerid: 'poweruser-3',
                    email: 'lantern_power_user@example.com',
                    name: 'Lantern Power User',
                    mode: 'give',
                    ip: '...',
                    lat: 54,
                    lon: -2,
                    country: 'GB',
                    type: 'lec2proxy'
                  },{
                    peerid: 'poweruser-4',
                    email: 'lantern_power_user@example.com',
                    name: 'Lantern Power User',
                    mode: 'get',
                    ip: '...',
                    lat: 31.230381,
                    lon: 121.473684,
                    country: 'CN',
                    type: 'desktop'
                  }
              ];
              this.sync({
                '/connectivity/peers/current': [],
                '/connectivity/peers/lifetime': peers
              });
              setInterval(function() {
                if (Math.random() < .75 || !this_.model.showVis) return;
                var peersCurrent = getByPath(this_.model, '/connectivity/peers/current');
                //log('peersCurrent:', _.pluck(peersCurrent, 'peerid'));
                if (_.isEmpty(peersCurrent)) {
                  var randomPeer = randomChoice(peers);
                  this_.sync([{op: 'add', path: '/connectivity/peers/current/0', value: randomPeer}]);
                  //log('No current peers, added random peer', randomPeer.peerid);
                  return;
                }
                if (peersCurrent.length === peers.length) {
                  var i = _.random(peers.length - 1);
                  //log('Connected to all available peers, removing random peer', peersCurrent[i].peerid);
                  this_.sync([{op: 'remove', path: '/connectivity/peers/current/'+i}]);
                  return;
                }
                if (Math.random() < .5) { // add a random not connected peer
                  var peersall = _.pluck(peers, 'peerid'),
                      peerscur = _.pluck(peersCurrent, 'peerid'),
                      peersnc = _.difference(peersall, peerscur),
                      randomPeerid = randomChoice(peersnc),
                      randomPeer = _.find(peers, function(p){ return p.peerid === randomPeerid; });
                  this_.sync([{op: 'add', path: '/connectivity/peers/current/'+peersCurrent.length, value: randomPeer}]);
                  //log('heads: added random peer', randomPeerid);
                } else { // remove a random connected peer
                  var i = _.random(peersCurrent.length - 1);
                  //log('tails: removing random peer', peersCurrent[i].peerid);
                  this_.sync([{op: 'remove', path: '/connectivity/peers/current/'+i}]);
                }
              }, 2123);
            }
    }
  },
  countries: {
    countries1: {
      desc: 'countries1',
      func: function() {
        var this_ = this,
            update = {};

        // do this on reset
        _.forEach(this.model.countries, function(_, country) {
          updateCountry(country, update);
        });
        this_.sync(update);

        setInterval(function() {
          if (!this_.model.showVis) return;
          var update = {}, ncountries = _.random(0, 15);
          for (var i=0; i<ncountries; ++i) {
            var country = randomChoice(this_.model.countries);
            updateCountry(country, update);
          }
          this_.sync(update);
        }, 1000);

        function updateCountry(country, update) {
          var stats = this_.model.countries[country],
              censors = stats.censors,
              npeersOnlineGive = getByPath(stats, '/npeers/online/give'),
              npeersOnlineGet = getByPath(stats, '/npeers/online/get');
          if (_.isUndefined(npeersOnlineGive)) {
            npeersOnlineGive = npeersOnlineGive || censors ? 0 : _.random(0, 1000);
            npeersOnlineGet = npeersOnlineGet || censors ? _.random(0, 1000) : _.random(0, 500);
          }
          npeersOnlineGive = censors ? npeersOnlineGive : Math.max(0, npeersOnlineGive + _.random(-100, 100));
          npeersOnlineGet = Math.max(0, npeersOnlineGet + _.random(-100, 100)),
          update['/countries/'+country+'/npeers'] = {
            online: {
              give: npeersOnlineGive,
              get: npeersOnlineGet,
              giveGet: npeersOnlineGive + npeersOnlineGet
            }
          };
        }
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
