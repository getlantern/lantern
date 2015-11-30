var sleep = require('sleep'),
    _ = require('../bower_components/lodash/dist/lodash.js')._,
    helpers = require('../app/js/helpers.js'),
      makeLogger = helpers.makeLogger,
        log = makeLogger('scenarios'),
      randomChoice = helpers.randomChoice,
      getByPath = helpers.getByPath,
    constants = require('../app/js/constants.js'),
      ENUMS = constants.ENUMS,
        PEER_TYPE = ENUMS.PEER_TYPE,
        FRIEND_STATUS = ENUMS.FRIEND_STATUS,
        CONNECTIVITY = ENUMS.CONNECTIVITY,
        MODAL = ENUMS.MODAL,
        MODE = ENUMS.MODE,
        OS = ENUMS.OS;

var PEER_UPDATE_INTERVAL = 1000; // milliseconds
var COUNTRIES_UPDATE_INTERVAL = 60000; // milliseconds

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
    hanoi: {
      desc: 'location: Hanoi',
      func: make_simple_scenario({
              '/location': {lat:21.0333, lon:105.85, country:'VN'},
              '/connectivity/ip': '123.30.209.59'
            })
    },
    riyadh: {
      desc: 'location: Riyadh',
      func: make_simple_scenario({
              '/location': {lat:24.6537, lon:46.7152, country:'SA'},
              '/connectivity/ip': '87.109.24.69'
            })
    },
    fars: {
      desc: 'location: Fars',
      func: make_simple_scenario({
              '/location': {lat:35.1826, lon:59.3886, country:'IR'},
              '/connectivity/ip': '151.232.47.99'
            })
    },
    ankara: {
      desc: 'location: Ankara',
      func: make_simple_scenario({
              '/location': {lat:39.9117, lon:32.8403, country:'TR'},
              '/connectivity/ip': '193.140.86.3'
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
              sleep.usleep(100000);
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
              sleep.usleep(100000);
              this.sync({'/connectivity/connectingStatus': 'Connecting to Lantern... Done',
                         '/connectivity/invited': false,
                         '/modal': MODAL.notInvited
                         });
            }
    }
  },
  gtalkReachable: {
    false: {
      desc: 'gtalkReachable: false',
      func: function() {
              this.sync({'/connectivity/gtalk': CONNECTIVITY.connecting,
                '/connectivity/connectingStatus': 'Connecting to Google Talk...',
                '/modal': MODAL.connecting});
              sleep.usleep(100000);
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
              sleep.usleep(100000);
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
              sleep.usleep(100);
              this.sync({'/connectivity/connectingStatus': 'Retrieving contacts... Done',
                         '/roster': roster});
            }
    }
  },
  friends: {
    friends1: {
      desc: 'friends1',
      func: function() {
              var friends = [
                          {
                           email: 'lantern_friend1@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Snyder Pearson',
                           status: FRIEND_STATUS.friend
                          },
                          {
                           email: 'lantern_friend2+a_really_realy_long_entry@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Leah X Schmidt',
                           status: FRIEND_STATUS.friend
                          },
                          {
                           email: 'lantern_power_user@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Myles Horton',
                           status: FRIEND_STATUS.friend
                          },
                          {
                           email: 'suggested_friend@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Suggested Friend',
                           reason: 'runningLantern',
                           status: FRIEND_STATUS.pending
                          },{
                           email: 'suggested2+a_really_really_long_entry@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Another Suggestion',
                           reason: 'friendedYou',
                           freeToFriend: true,
                           status: FRIEND_STATUS.pending
                          },{
                           email: 'suggested3@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Third Suggestion',
                           reason: 'runningLantern',
                           status: FRIEND_STATUS.pending
                          },{
                           email: 'suggested4@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Fourth Suggestion',
                           reason: 'runningLantern',
                           status: FRIEND_STATUS.pending
                          },{
                           email: 'suggested5@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Fifth Suggestion',
                           reason: 'friendedYou',
                           freeToFriend: true,
                           status: FRIEND_STATUS.pending
                          },{
                           email: 'suggested6@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Sixth Suggestion',
                           reason: 'runningLantern',
                           status: FRIEND_STATUS.pending
                          },{
                           email: 'suggested7@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Seventh Suggestion',
                           reason: 'friendedYou',
                           freeToFriend: true,
                           status: FRIEND_STATUS.pending
                          },{
                           email: 'suggested8@example.com',
                           picture: 'img/default-avatar.png',
                           name: 'Eighth Suggestion',
                           status: FRIEND_STATUS.rejected
                          }];
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
                    peerid: 'friend1-1 #!@./',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_friend1@example.com'}),
                    mode: 'give',
                    ip: '74.120.12.135',
                    lat: 51,
                    lon: 9,
                    country: 'DE',
                    type: 'pc'
                  },{
                    peerid: 'friend2-1 #!@./',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_friend2@example.com'}),
                    mode: 'get',
                    ip: '27.55.2.80',
                    lat: 13.754,
                    lon: 100.5014,
                    country: 'TH',
                    type: 'pc'
                  },{
                    peerid: 'poweruser-1 #!@./',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_power_user@example.com'}),
                    mode: 'give',
                    ip: '93.182.129.82',
                    lat: 55.7,
                    lon: 13.1833,
                    country: 'SE',
                    type: 'cloud'
                  },{
                    peerid: 'poweruser-2 #!@./',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_power_user@example.com'}),
                    mode: 'give',
                    ip: '123.456.789.123',
                    lat: 37.4192,
                    lon: -122.0574,
                    country: 'US',
                    type: 'laeproxy'
                  },{
                    peerid: 'poweruser-3 #!@./',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_power_user@example.com'}),
                    mode: 'give',
                    ip: '195.27.40.32',
                    lat: 54,
                    lon: -2,
                    country: 'GB',
                    type: 'cloud'
                  },{
                    peerid: 'poweruser-4 #!@./',
                    rosterEntry: _.find(this.model.roster, {email: 'lantern_power_user@example.com'}),
                    mode: 'get',
                    ip: '59.108.60.58',
                    lat: 31.230381,
                    lon: 121.473684,
                    country: 'CN',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-1 #!@./',
                    mode: 'get',
                    ip: '2.88.102.152',
                    lat: 26.3032,
                    lon: 50.1353,
                    country: 'SA',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-2 #!@./',
                    mode: 'give',
                    ip: '186.2.61.111',
                    lat: -16.5,
                    lon: -68.15,
                    country: 'BO',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-3 #!@./',
                    mode: 'give',
                    ip: '187.137.225.219',
                    lat: 22.15,
                    lon: -100.9833,
                    country: 'MX',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-4 #!@./',
                    mode: 'get',
                    ip: '78.108.178.25',
                    lat: 49.75,
                    lon: 15.5,
                    country: 'CZ',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-5 #!@./',
                    mode: 'get',
                    ip: '88.19.63.196',
                    lat: 37.3824,
                    lon: -5.9761,
                    country: 'ES',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-6 #!@./',
                    mode: 'give',
                    ip: '79.55.82.37',
                    lat: 39.2167,
                    lon: 9.1167,
                    country: 'IT',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-7 #!@./',
                    mode: 'get',
                    ip: '77.49.7.129',
                    lat: 37.9833,
                    lon: 23.7333,
                    country: 'GR',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-8 #!@./',
                    mode: 'give',
                    ip: '123.456.789.123',
                    lat: 39.0437,
                    lon: -77.4875,
                    country: 'US',
                    type: 'cloud'
                  },{
                    peerid: 'friend-of-friend1-9 #!@./',
                    mode: 'give',
                    ip: '177.64.207.97',
                    lat: -5.7833,
                    lon: -35.2167,
                    country: 'BR',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-10 #!@./',
                    mode: 'get',
                    ip: '178.65.208.98',
                    lat:40.7089,
                    lon:-74.0012,
                    country:'US',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-11 #!@./',
                    mode: 'get',
                    ip: '178.65.208.98',
                    lat:42.3581,
                    lon:-71.0636,
                    country:'US',
                    type: 'pc'
                  },{
                    peerid: 'friend-of-friend1-12 #!@./',
                    mode: 'get',
                    ip: '179.66.209.99',
                    lat:44.8544,
                    lon:-63.1992,
                    country:'CA',
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
                          bytesGiven = getByPath(this_.model, '/instanceStats/bytesGiven/total') || 0,
                          allBytes = getByPath(this_.model, '/instanceStats/allBytes/total') || 0;
                      bpsUp = Math.max(0, bpsUp + _.random(-1024*2, 1024*2));
                      bpsDn = Math.max(0, bpsDn + _.random(-1024*2, 1024*2));
                      bpsUpDn = bpsUp + bpsDn;
                      peer.bpsUp = bpsUp;
                      peer.bpsDn = bpsDn;
                      peer.bpsUpDn = bpsUpDn;
                      peer.bytesUp = (peer.bytesUp || 0) + bpsUp;
                      peer.bytesDn = (peer.bytesDn || 0) + bpsDn;
                      peer.bytesUpDn = (peer.bytesUpDn || 0) + bpsUpDn;
                      bytesGiven += bpsUpDn;
                      allBytes += bpsUpDn;
                      update.push({op: 'add', path: '/peers/'+i+'/bpsUp', value: bpsUp});
                      update.push({op: 'add', path: '/peers/'+i+'/bpsDn', value: bpsDn});
                      update.push({op: 'add', path: '/peers/'+i+'/bpsUpDn', value: bpsUpDn});
                      update.push({op: 'add', path: '/peers/'+i+'/bytesUp', value: peer.bytesUp});
                      update.push({op: 'add', path: '/peers/'+i+'/bytesDn', value: peer.bytesDn});
                      update.push({op: 'add', path: '/peers/'+i+'/bytesUpDn', value: peer.bytesUpDn});
                      update.push({op: 'add', path: '/instanceStats/bytesGiven/total', value: bytesGiven});
                      update.push({op: 'add', path: '/instanceStats/allBytes/total', value: allBytes});
                    }
                    //log('update:', update);
                  });

                  var bps = 0;
                  for (var i=0, p=peersCurrent[i]; p; p=peersCurrent[++i]) {
                    bps += p.bpsUpDn;
                  }
                  update.push({op: 'add', path: '/instanceStats/bytesGiven/rate', value: bps});
                  update.push({op: 'add', path: '/instanceStats/allBytes/rate', value: bps});
                  //update.push({op: 'replace', path: '/connectivity/nproxies', value:
                  //  _.filter(peersCurrent, {mode: MODE.give}).length});
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
              }, PEER_UPDATE_INTERVAL);
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
          var statsPath = '/countries/'+alpha2+'/stats';
          if (/*Math.random() < .1 ||*/ _.contains(initialCountries, alpha2)) {
            var everGet = _.random(200, 1000);
            var everGive = country.censors ? 0 : _.random(500, 1000);
            var ever = everGive + everGet;
            update[statsPath] = {gauges: {userOnlineGetting: 0, userOnlineGiving: 0, userOnlineEver: ever},
                                 counters: {bytesGiven: 0, bytesGotten: 0}};
            updateCountry(alpha2, update);
          } else {
            update[statsPath] = {gauges: {userOnlineGetting: 0, userOnlineGiving: 0, userOnlineEver: 0},
                                 counters: {bytesGiven: 0, bytesGotten: 0}};
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
        }, COUNTRIES_UPDATE_INTERVAL);

        function updateCountry(country, update) {
          var stats = this_.model.countries[country],
              censors = stats.censors,
              usersOnlineGiving = getByPath(stats, '/stats/gauges/userOnlineGiving'),
              usersOnlineGetting = getByPath(stats, '/stats/gauges/userOnlineGetting'),
              userOnlineGlobal = getByPath(this_.model, '/globalStats/gauges/userOnline'),
              giveDelta = censors ? 0 : _.random(-Math.min(50, usersOnlineGiving), 50),
              getDelta = _.random(-Math.min(50, usersOnlineGetting), 50);
          if (_.isUndefined(usersOnlineGiving)) {
            usersOnlineGiving = usersOnlineGiving || censors ? 0 : _.random(0, 100);
            usersOnlineGetting = usersOnlineGetting || censors ? _.random(0, 100) : _.random(0, 50);
          }
          usersOnlineGiving += giveDelta;
          usersOnlineGetting += getDelta;
          statsUpdate = {
              gauges: {
                userOnlineGiving: usersOnlineGiving,
                userOnlineGetting: usersOnlineGetting,
              }
          };
          userOnlineGlobal += giveDelta + getDelta;
          this_.sync({'/globalStats/gauges/userOnline': userOnlineGlobal});
          if (userOnlineGlobal) {
            var bytesGivenDelta =  _.random(1024, (country.censors ? 10 : 1000) * 1048576); /* 1000 MB */
            var bytesGottenDelta =  _.random(1024, (country.censors ? 1000 : 10)*1048576); /* 1000 MB */
            var bytesEverDelta = bytesGivenDelta + bytesGottenDelta;
            var bytesGotten = 0,
                bytesGiven = 0,
                bytesEver = 0;
            try {
              bytesGiven = (getByPath(stats, 'bytesEver') || 0)
              bytesGotten = (getByPath(stats, 'bytesEver') || 0)
              bytesEver = (getByPath(stats, 'bytesEver') || 0)
            } catch (e) {
              // ignore
            }
            update['/countries/'+country+'/bytesEver'] = bytesEver + bytesEverDelta;
            update['/countries/'+country+'/bps'] = _.random(1000, 10*1048576);
            statsUpdate.counters = {
                bytesGiven: bytesGiven + bytesGivenDelta,
                bytesGotten: bytesGotten + bytesGottenDelta
            };
          }
          
          update['/countries/'+country+'/stats'] = statsUpdate;
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
