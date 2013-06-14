var sleep = require('./node_modules/sleep'),
    _ = require('../app/components/lodash/lodash.js')._,
    helpers = require('../app/js/helpers.js'),
      makeLogger = helpers.makeLogger,
        log = makeLogger('scenarios'),
      randomChoice = helpers.randomChoice,
      getByPath = helpers.getByPath,
    constants = require('../app/js/constants.js'),
      ENUMS = constants.ENUMS,
        PEER_TYPE = ENUMS.PEER_TYPE,
        CONNECTIVITY = ENUMS.CONNECTIVITY,
        MODAL = ENUMS.MODAL,
        MODE = ENUMS.MODE,
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
                'releaseDate': '2013-01-30',
                'installerUrl': 'https://lantern.s3.amazonaws.com/lantern-0.23.0.dmg',
                'installerSHA1': 'b3d15ec2d190fac79e858f5dec57ba296ac85776',
                'infoUrl': 'https://www.getlantern.org/news/2013-01-30/blog-post-for-new-release'
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
      func: make_simple_scenario({
        '/connectivity/gtalkAuthorized': true,
        '/modal': MODAL.connecting
      })
    }
  },
  invited: {
    true: {
      desc: 'invited: true',
      func: function() {
              this.sync({'/connectivity/connectingStatus': 'Connecting to Lantern...'});
              sleep.usleep(3000000);
              this.sync({'/connectivity/connectingStatus': 'Connecting to Lantern... Done',
                         '/connectivity/peerid': 'lantern-45678',
                         '/connectivity/type': 'pc',
                         '/connectivity/invited': true});
            }
    },
    false: {
      desc: 'invited: false',
      func: function() {
              this.sync({'/connectivity/connectingStatus': 'Connecting to Lantern...'});
              sleep.usleep(3000000);
              this.sync({'/connectivity/connectingStatus': 'Connecting to Lantern... Done',
                         '/connectivity/invited': false,
                         '/modal': MODAL.notInvited
                         });
            }
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
                '/connectivity/connectingStatus': 'Connecting to Google Talk...',
                '/modal': MODAL.connecting});
              sleep.usleep(3000000);
              this.sync({'/connectivity/gtalk': CONNECTIVITY.notConnected,
                '/connectivity/connectingStatus': 'Connecting to Google Talk...Failed',
                '/notifications/-': {type: 'error', message: 'Unable to reach Google Talk.'},
                '/modal': MODAL.authorize});
            }
    },
    true: {
      desc: 'gtalkReachable: true',
      func: function() {
              this.sync({'/connectivity/gtalk': CONNECTIVITY.connecting,
                '/connectivity/connectingStatus': 'Connecting to Google Talk...',
                '/modal': MODAL.connecting});
              sleep.usleep(3000000);
              this.sync({'/connectivity/gtalk': CONNECTIVITY.connected,
                '/profile': {
                  email: 'user@example.com',
                  name: 'Your Name Here',
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
                name: 'Snyder Pearson',
                link: '',
                picture: 'img/default-avatar.png',
                status: 'away',
                statusMessage: 'meeting'
              },{
                email: 'lantern_friend2@example.com',
                name: 'Leah X Schmidt',
                link: '',
                picture: 'img/default-avatar.png',
                status: 'available',
                statusMessage: 'Bangkok'
              },{
                email: 'user1@example.com',
                name: 'Willie Forkner',
                link: '',
                picture: 'img/default-avatar.png',
                status: 'idle',
                statusMessage: 'sleeping'
              },{
                email: 'user2@example.com',
                name: 'J.P. Zenger',
                link: '',
                picture: 'img/default-avatar.png',
                status: 'offline'
              },{
                email: 'lantern_power_user@example.com',
                name: 'Myles Horton',
                link: '',
                picture: 'img/default-avatar.png',
                status: 'available',
                statusMessage: 'Shanghai!'
              }];
              this.sync({'/connectivity/connectingStatus': 'Retrieving contacts...'});
              sleep.usleep(1000000);
              this.sync({'/connectivity/connectingStatus': 'Retrieving contacts... Done',
                         '/roster': roster});
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
                           picture: 'img/default-avatar.png',
                           name: 'Snyder Pearson'
                          },
                          {
                           email: 'lantern_friend2@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Leah X Schmidt'
                          },
                          {
                           email: 'lantern_power_user@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Myles Horton'
                          }],
                pending: [{
                           email: 'inviter1@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Example Inviter'
                          },{
                           email: 'inviter2@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Another Inviter'
                          },{
                           email: 'inviter3@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Third Inviter'
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
                  testPeers = [{
                    peerid: 'friend1-1',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_friend1@example.com'}),
                    mode: 'give',
                    ip: '74.120.12.135',
                    lat: 51,
                    lon: 9,
                    country: 'DE',
                    type: 'pc'
                  },{
                    peerid: 'friend2-1',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_friend2@example.com'}),
                    mode: 'get',
                    ip: '27.55.2.80',
                    lat: 13.754,
                    lon: 100.5014,
                    country: 'TH',
                    type: 'pc'
                  },{
                    peerid: 'poweruser-1',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_power_user@example.com'}),
                    mode: 'give',
                    ip: '93.182.129.82',
                    lat: 55.7,
                    lon: 13.1833,
                    country: 'SE',
                    type: 'cloud'
                  },{
                    peerid: 'poweruser-2',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_power_user@example.com'}),
                    mode: 'give',
                    ip: '123.456.789.123',
                    lat: 37.4192,
                    lon: -122.0574,
                    country: 'US',
                    type: 'laeproxy'
                  },{
                    peerid: 'poweruser-3',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_power_user@example.com'}),
                    mode: 'give',
                    ip: '195.27.40.32',
                    lat: 54,
                    lon: -2,
                    country: 'GB',
                    type: 'cloud'
                  },{
                    peerid: 'poweruser-4',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_power_user@example.com'}),
                    mode: 'get',
                    ip: '59.108.60.58',
                    lat: 31.230381,
                    lon: 121.473684,
                    country: 'CN',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-1',
                    mode: 'get',
                    ip: '2.88.102.152',
                    lat: 26.3032,
                    lon: 50.1353,
                    country: 'SA',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-2',
                    mode: 'give',
                    ip: '186.2.61.111',
                    lat: -16.5,
                    lon: -68.15,
                    country: 'BO',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-3',
                    mode: 'give',
                    ip: '187.137.225.219',
                    lat: 22.15,
                    lon: -100.9833,
                    country: 'MX',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-4',
                    mode: 'get',
                    ip: '78.108.178.25',
                    lat: 49.75,
                    lon: 15.5,
                    country: 'CZ',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-5',
                    mode: 'get',
                    ip: '88.19.63.196',
                    lat: 37.3824,
                    lon: -5.9761,
                    country: 'ES',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-6',
                    mode: 'give',
                    ip: '79.55.82.37',
                    lat: 39.2167,
                    lon: 9.1167,
                    country: 'IT',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-7',
                    mode: 'get',
                    ip: '77.49.7.129',
                    lat: 37.9833,
                    lon: 23.7333,
                    country: 'GR',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-8',
                    mode: 'give',
                    ip: '123.456.789.123',
                    lat: 39.0437,
                    lon: -77.4875,
                    country: 'US',
                    type: 'cloud'
                  },{
                    peerid: 'friend-of-friend1-9',
                    mode: 'give',
                    ip: '177.64.207.97',
                    lat: -5.7833,
                    lon: -35.2167,
                    country: 'BR',
                    type: 'pc'
                  }];
              _.each(testPeers, function(peer) {
                _.merge(peer, {bytesUp: 0, bytesDn: 0, lastConnected: new Date().toJSON()});
              });
              this.sync({'/peers': testPeers});
              setInterval(function() {
                if (!this_.model.setupComplete) return;
                var mode = getByPath(this_.model, '/settings/mode'),
                    peers = this_.model.peers,
                    peersCurrent = _.filter(peers, 'connected'),
                    update = [];

                //log('peers:', _.pluck(peersCurrent, 'peerid'));

                function done() {
                  _.each(peersCurrent, function(peer) {
                    var i = peers.indexOf(peer);
                    if (peer.mode === mode) {
                      peer.bpsUp = 0; peer.bpsDn = 0; peer.bpsUpDn = 0;
                      update.push({op: 'add', path: '/peers/'+i+'/bpsUp', value: 0});
                      update.push({op: 'add', path: '/peers/'+i+'/bpsDn', value: 0});
                      update.push({op: 'add', path: '/peers/'+i+'/bpsUpDn', value: 0});
                    } else {
                      var bpsUp = peer.bpsUp || 0,
                          bpsDn = peer.bpsDn || 0,
                          bpsUpDn = peer.bpsUpDn || 0,
                          bytesUp = getByPath(this_.model, '/transfers/bytesUp') || 0,
                          bytesDn = getByPath(this_.model, '/transfers/bytesDn') || 0,
                          bytesUpDn = getByPath(this_.model, '/transfers/bytesUpDn') || 0;
                      bpsUp = Math.max(0, bpsUp + _.random(-1024*2, 1024*2));
                      bpsDn = Math.max(0, bpsDn + _.random(-1024*2, 1024*2));
                      bpsUpDn = bpsUp + bpsDn;
                      peer.bpsUp = bpsUp;
                      peer.bpsDn = bpsDn;
                      peer.bpsUpDn = bpsUpDn;
                      peer.bytesUp = (peer.bytesUp || 0) + bpsUp;
                      peer.bytesDn = (peer.bytesDn || 0) + bpsDn;
                      peer.bytesUpDn = (peer.bytesUpDn || 0) + bpsUpDn;
                      bytesUp += bpsUp;
                      bytesDn += bpsDn;
                      bytesUpDn += bpsUpDn;
                      update.push({op: 'add', path: '/peers/'+i+'/bpsUp', value: bpsUp});
                      update.push({op: 'add', path: '/peers/'+i+'/bpsDn', value: bpsDn});
                      update.push({op: 'add', path: '/peers/'+i+'/bpsUpDn', value: bpsUpDn});
                      update.push({op: 'add', path: '/peers/'+i+'/bytesUp', value: peer.bytesUp});
                      update.push({op: 'add', path: '/peers/'+i+'/bytesDn', value: peer.bytesDn});
                      update.push({op: 'add', path: '/peers/'+i+'/bytesUpDn', value: peer.bytesUpDn});
                      update.push({op: 'add', path: '/transfers/bytesUp', value: bytesUp});
                      update.push({op: 'add', path: '/transfers/bytesDn', value: bytesDn});
                      update.push({op: 'add', path: '/transfers/bytesUpDn', value: bytesUpDn});
                    }
                    //log('update:', update);
                  });

                  var bpsUp = 0, bpsDn = 0, bpsUpDn = 0;
                  for (var i=0, p=peersCurrent[i]; p; p=peersCurrent[++i]) {
                    bpsUp += p.bpsUp;
                    bpsDn += p.bpsDn;
                    bpsUpDn += p.bpsUpDn;
                  }
                  update.push({op: 'add', path: '/transfers/bpsUp', value: bpsUp});
                  update.push({op: 'add', path: '/transfers/bpsDn', value: bpsDn});
                  update.push({op: 'add', path: '/transfers/bpsUpDn', value: bpsUpDn});
                  this_.sync(update);
                }

                if (Math.random() < .5) { return done(); }

                if (_.isEmpty(peersCurrent)) {
                  var i = _.random(peers.length - 1);
                  update.push({op: 'add', path: '/peers/'+i+'/connected', value: true});
                  update.push({op: 'add', path: '/peers/'+i+'/lastConnected', value: new Date().toJSON()});
                  //log('No current peers, added random peer', peers[i].peerid);
                  return done();
                }

                if (peersCurrent.length === peers.length) {
                  var i = _.random(peers.length - 1);
                  //log('Connected to all available peers, removing random peer', peers[i].peerid);
                  update.push({op: 'add', path: '/peers/'+i+'/connected', value: false});
                  return done();
                }

                if (Math.random() < .9) { // switch modes for a random non-cloud peer running from a non-censoring country
                  var randomPeer = randomChoice(peersCurrent),
                      i = _.indexOf(peers, randomPeer);
                  if (randomPeer.type !== PEER_TYPE.pc) return;
                  if (getByPath(this_.model, '/countries/'+randomPeer.country+'/censors')) return;
                  var mode = randomPeer.mode === MODE.give ? MODE.get : MODE.give;
                  update.push({op: 'add', path: '/peers/'+i+'/mode', value: mode});
                  //log('toggling mode for peer', randomPeer.peerid);
                }

                var ppeersall = _.pluck(peers, 'peerid'),
                    ppeerscur = _.pluck(peersCurrent, 'peerid'),
                    ppeersnot = _.difference(ppeersall, ppeerscur);
                if (Math.random() < .5) { // add a random not connected peer
                  var randomPeerid = randomChoice(ppeersnot),
                      i = _.indexOf(ppeersall, randomPeerid);
                  update.push({op: 'add', path: '/peers/'+i+'/connected', value: true});
                  update.push({op: 'add', path: '/peers/'+i+'/lastConnected', value: new Date().toJSON()});
                  //log('heads: added random peer', randomPeerid);

                  /*
                  if (Math.random() < .2) { // move the peer by a random amount
                    var peer = peers[i], lat = peer.lat, lon = peer.lon;
                    update.push({op: 'add', path: '/peers/'+i+'/lat', value: lat + _.random(-3, 1)});
                    update.push({op: 'add', path: '/peers/'+i+'/lon', value: lon + _.random(-1, 1)});
                    log('moving peer by a random amount', peers[i].peerid);
                  }
                  */
                } else { // remove a random connected peer
                  var randomPeerid = randomChoice(ppeerscur),
                      i = _.indexOf(ppeersall, randomPeerid);
                  //log('tails: removing random peer', randomPeerid);
                  peersCurrent.splice(_.indexOf(ppeerscur, randomPeerid), 1);
                  update.push({op: 'add', path: '/peers/'+i+'/connected', value: false});
                  update.push({op: 'add', path: '/peers/'+i+'/bpsUp', value: 0});
                  update.push({op: 'add', path: '/peers/'+i+'/bpsDn', value: 0});
                  update.push({op: 'add', path: '/peers/'+i+'/bpsUpDn', value: 0});
                }

                return done();
              }, 1000);
            }
    }
  },
  countries: {
    countries1: {
      desc: 'countries1',
      func: function() {
        var this_ = this,
            update = {},
            initialCountries = ['US', 'CA', 'CN', 'IR', 'SA', 'DE', 'GB', 'SE', 'TH'];

        // XXX do this on reset
        _.each(this.model.countries, function(country, alpha2) {
          var npeersPath = '/countries/'+alpha2+'/npeers',
              nusersPath = '/countries/'+alpha2+'/nusers';
          if (/*Math.random() < .1 ||*/ _.contains(initialCountries, alpha2)) {
            var ever = {get: _.random(200, 1000)};
            ever.give = country.censors ? 0 : _.random(500, 1000);
            ever.giveGet = ever.give + ever.get;
            update[npeersPath] = {online: {}, ever: ever};
            updateCountry(alpha2, update);
          } else {
            update[npeersPath] = {online: {give: 0, get: 0, giveGet: 0}, ever: {give: 0, get: 0, giveGet: 0}};
            update[nusersPath] = {online: 0, ever:  0};
          }
        });
        this_.sync(update);

        setInterval(function() {
          if (!this_.model.showVis) return;
          var update = {}, ncountries = _.random(0, 5);
          for (var i=0; i<ncountries; ++i) {
            var country = randomChoice(/*Math.random() < .25 ?
              this_.model.countries :*/ initialCountries
            );
            updateCountry(country, update);
          }
          if (ncountries) this_.sync(update);
        }, 60000);

        function updateCountry(country, update) {
          var stats = this_.model.countries[country],
              censors = stats.censors,
              npeersOnlineGive = getByPath(stats, '/npeers/online/give'),
              npeersOnlineGet = getByPath(stats, '/npeers/online/get'),
              npeersOnlineGlobal = getByPath(this_.model, '/global/nusers/online'),
              giveDelta = censors ? 0 : _.random(-Math.min(50, npeersOnlineGive), 50),
              getDelta = _.random(-Math.min(50, npeersOnlineGet), 50);
          if (_.isUndefined(npeersOnlineGive)) {
            npeersOnlineGive = npeersOnlineGive || censors ? 0 : _.random(0, 100);
            npeersOnlineGet = npeersOnlineGet || censors ? _.random(0, 100) : _.random(0, 50);
          }
          npeersOnlineGive += giveDelta;
          npeersOnlineGet += getDelta;
          var npeersOnlineGiveGet = npeersOnlineGive + npeersOnlineGet;
          update['/countries/'+country+'/npeers/online'] = {
            give: npeersOnlineGive,
            get: npeersOnlineGet,
            giveGet: npeersOnlineGiveGet
          };
          update['/countries/'+country+'/nusers'] = {
            online: npeersOnlineGiveGet,
            ever: _.random(npeersOnlineGiveGet, npeersOnlineGiveGet*2)
          };
          npeersOnlineGlobal += giveDelta + getDelta;
          this_.sync({'/global/nusers/online': npeersOnlineGlobal});
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
