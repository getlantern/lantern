'use strict';

var cometd = $.cometd;

var FETCHING = 'fetching...'; // poor-man's promise
var FETCHFAILED = 'fetch failed';
var FETCHSUCCESS = 'fetch succeeded';

// http://html5pattern.com/
var HOSTNAMEPAT = /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$/;

var BYTEDIM = {GB: 1024*1024*1024, MB: 1024*1024, KB: 1024};
angular.filter('bytes', function(input){
  var nbytes = parseInt(input);
  if(isNaN(nbytes))return input;
  for(var dim in BYTEDIM){
    var base = BYTEDIM[dim];
    if(nbytes >= base){
      return Math.round(nbytes/base) + dim;
    }
  }
  return nbytes + 'B';
});

var FRAGMENTPAT = /^[^#]*(#.*)$/;
function clickevt2id(evt){
  return evt.currentTarget.href.match(FRAGMENTPAT)[1];
}

function showid(id, ignorecls){
  var $el = $(id);
  if(!$el.length)
    return;
  location.hash = id;
  if($el.hasClass('selected'))
    return;
  var cls = $el.attr('data-cls');
  if(cls === ignorecls)
    return;
  $('.' + cls + '.selected').toggleClass('selected');
  $el.toggleClass('selected');
  if(cls === 'panel'){
    $('#panel-list > li > a.selected').toggleClass('selected');
    $('#panel-list > li > a[href='+id+']').toggleClass('selected');
  }
}

function showidclickhandler(evt){
  showid(clickevt2id(evt));
  // XXX height hack unneeded when viewport has minheight of 630
  //var docheight = $(document).height(), bodheight = $('body').height();
  //if(docheight > bodheight){
  //  console.log('height hack: increasing body height from', bodheight, 'to', docheight);
  //  $('body').height(docheight);
  //}
}

function LDCtrl(){
  var self = this;
  self.state = {};
  self.stateloaded = function(){
    return !$.isEmptyObject(self.state);
  };
  self.$watch('state');
  self.update = function(state){
    self.state = state;
    self.$digest();
  };

  // XXX dummy data
  self.newversion = {
    number: "0.10.1",
    released: "2012-02-20T11:15:00.0Z",
    url: {
      macos:   "http://path/to/installer.dmg",
      windows: "http://path/to/installer.exe",
      ubuntu:  "http://path/to/package.deb",
      fedora:  "http://path/to/package.rpm",
      tarball: "http://path/to/source.tgz"
    }
  };

  self.inputemail = null;
  self.inputpassword = null;

  self.peerfilterinput = null;
  self.peerfilter = function(peer){
    var f = self.peerfilterinput;
    if(!f)return true;
    if(peer.name && peer.name.indexOf(f) !== -1)return true;
    return peer.email.indexOf(f) !== -1;
  };
  self.peers = null;
  self.whitelist = null;

  self.sameuser = function(){
    var inputemail = self.inputemail, stateemail = self.state.email;
    return inputemail === null || inputemail === stateemail || inputemail + '@gmail.com' === stateemail;
  };

  self.passrequired = function(){
    return !(self.sameuser() && self.state.passwordSaved && self.state.savePassword);
  };

  self.passplaceholder = function(){
    if(!self.passrequired())
      return '••••••••••••••••';
    return 'password';
  };

  self.showsignin = function(val){
    if(typeof val == 'undefined'){
      if(typeof self._showsignin == 'undefined'){
        self._showsignin = !self.loggedin() && self.state.connectOnLaunch && !self.state.passwordSaved;
        console.log('set _showsignin to', self._showsignin);
      }
    }else{
      self._showsignin = val;
    }
    return self._showsignin;
  }

  self.pm = null;
  self.requestreply = false;
  self.requestreplyto = null;

  self.loggedin = function(){return self.state.authenticationStatus === 'LOGGED_IN';};
  self.loggedout = function(){return self.state.authenticationStatus === 'LOGGED_OUT';};
  self.loggingin = function(){return self.state.authenticationStatus === 'LOGGING_IN';};

  self.conncaption = function(){
    switch(self.state.authenticationStatus){
    case 'LOGGED_OUT':
      return 'Not connected';
    case 'LOGGING_IN':
      return 'Connecting';
    case 'LOGGING_OUT':
      return 'Disconnecting';
    case 'LOGGED_IN':
      return (self.state.getMode?'Gett':'Giv')+'ing access';
    }
  };

  self.switchlinktext = function(){
    if(self.loggedin())
      return 'Switch to '+(self.state.getMode?'giv':'gett')+'ing access';
  };

  self.fs_submit = function(){
    if(self.loggedout() || !self.sameuser()){
      if(self.fsform.$invalid){
        console.log('form invalid, doing nothing');
        return;
      }
      console.log('calling signin');
      self.signin(self.inputemail);
    }else{
      console.log('already signed in, just skipping to next screen');
      self.inputpassword = '';
      showid(self.state.getMode && '#trustedpeers' || '#setupcomplete');
    }
  };

  self.fetchpeers = function(){
    if(self.state.getMode){
      console.log('fetching peers');
      self.peers = FETCHING;
      $.ajax({url: '/api/roster', dataType: 'json'}).done(function(r){
        self.peers = r.entries;
        console.log('set peers');
      }).fail(function(e){
        console.log('failed to fetch peers:',e);
        self.peers = FETCHFAILED;
      });
    }
  };

  self.fetchwhitelist = function(){
    if(self.state.getMode){
      console.log('fetching whitelist');
      self.whitelist = FETCHING;
      $.ajax({url: '/api/whitelist', dataType: 'json'}).done(function(r){
        self.whitelist = r.entries;
        self.$digest();
        console.log('set whitelist');
      }).fail(function(e){
        console.log('failed to fetch whitelist:',e);
        self.whitelist = FETCHFAILED;
      });
    }
  };

  self.signin = function(email){
    if(self.loggedin()){
      if(email === null || email === self.state.email || email + '@gmail.com' === self.state.email){
        console.log('ingoring signin as', self.state.email, 'already signed in as that user');
        self.showsignin(false);
        self.inputpassword = '';
        return;
      }
    }
    var data = {
      email: email || self.state.email
    };
    if(self.passrequired()){
      if(!self.inputpassword){
        console.log('no password saved or supplied, bailing');
        return;
      }
      data.password = self.inputpassword;
    }
    // XXX force this for smoother looking login
    self.state.authenticationStatus = 'LOGGING_IN';
    self.$digest();
    console.log('Signing in with:', data);
    $.post('/api/signin', data).done(function(state){
      console.log('signin succeeded');
      $('form.signin').removeClass('badcredentials');
      self.inputpassword = '';
      self.showsignin(false);
      self.update(state);
      self.fetchpeers();
      if(!self.state.initialSetupComplete)
        showid(self.state.getMode && '#trustedpeers' || '#setupcomplete');
    }).fail(function(){
      if(self.state.initialSetupComplete)
        self.showsignin(true);
      $('form.signin').addClass('badcredentials');
      console.log('signin failed');
    });
  };

  self.fs_submit_src = function(){
    if(self.fsform.$invalid && !(self.loggedin() && self.sameuser()))
      return 'img/arrow-right-disabled.png';
    if(self.loggingin())
      return 'img/spinner-big.gif';
    return 'img/arrow-right.png';
  };

  self.autoproxy_continue_src = function(){
    if(self._autoproxyresp === FETCHING)
      return 'img/spinner-big.gif';
    return 'img/arrow-right.png';
  };

  self.toggleTrusted = function(peer){
    var url = '/api/' + (peer.trusted ? 'add' : 'remove') + 'trustedpeer?email=' + peer.email;
    $.post(url).done(function(){
      console.log('successfully set peer.trusted to ' + peer.trusted + ' for ' + peer.email); 
    }).fail(function(){
      peer.trusted = !peer.trusted;
      console.log('failed to set peer.trusted to ' + peer.trusted + ' for ' + peer.email); 
    });
  };

  self.init_applyautoproxy = function(){
    console.log('in init_applyautoproxy');
    if(self._autoproxyresp === FETCHING){
      console.log('autoproxy request pending, ignoring');
      return;
    }
    self._autoproxyresp = FETCHING;
    self.$digest();
    $.post('/api/applyautoproxy').done(function(){
      $('#systemproxy').removeClass('autoproxyfailed');
      self._autoproxyresp = FETCHSUCCESS;
      self.$digest();
      console.log('autoproxy request succeeded');
      showid('#setupcomplete');
    }).fail(function(e){
      $('#systemproxy').addClass('autoproxyfailed');
      self._autoproxyresp = FETCHFAILED;
      self.$digest();
      console.log('autoproxy request failed');
    });
  };

  self.finishsetup = function(){
    showid('#setupcomplete');
    $('#welcome-container').fadeOut('slow');
    setTimeout(function(){
    $.post('/settings?initialSetupComplete=true').done(function(){
      self.showsignin(false)
      showid('#status');
      console.log('finished setup.');
    }).fail(function(e){
      alert('Could not complete setup.'); console.log(e); // XXX
    });
    }, 1000);
  };

  self.signout = function(){
    $.post('/api/signout').done(function(state){
      console.log('signout succeeded');
      self.update(state);
    }).fail(function(){
      console.log('signout failed');
    });
  };

  self.toggle = function(setting, manual){
    if(manual)
      self.state[setting] = !self.state[setting];
    $.post('/settings?'+setting+'='+self.state[setting]).done(function(){
      console.log('successfully toggled '+setting+' to '+self.state[setting]);
    }).fail(function(){
      console.log('failed to toggle '+setting);
    });
  };

  self.switchmode = function(manual){
    var proceed = true;
    if(self.state.getMode && self.state.countryDetected.censoring)
      proceed = confirm('It looks like you may be in a censoring country. ' +
        'Only run Lantern in “give access” mode if you believe your ' +
        'connection to be private and properly secured.');
    proceed && self.toggle('getMode', manual);
  };

  self.reset = function(){
    var msg = 'Are you sure you want to reset Lantern? ' +
      (self.loggedin() ? 'You will be signed out and y' : 'Y') +
      'our settings will be erased.';
    if(confirm(msg)){
      $.post('/api/reset').done(function(state){
        self.update(state);
        showid('#welcome');
      });
    }
  };

  self._validatewhitelistentry = function(val){
    // XXX ip addresses acceptable?
    if(!HOSTNAMEPAT.test(val)){
      console.log('not a valid hostname:', val, '(so much for html5 defenses)');
      return false;
    }
    return true;
  };

  self.updatewhitelist = function(site, newsite){
    if(typeof newsite === 'string'){
      if(newsite === site){
        console.log('site == newsite == ', site, 'ignoring');
        return;
      }
      if(!self._validatewhitelistentry(newsite))return;
      $.post('/api/removefromwhitelist?site=' + site).done(function(r1){
        $.post('/api/addtowhitelist?site=' + newsite).done(function(r2){
          self.whitelist = r2.entries;
          self.$digest();
          console.log('/api/addtowhitelist?site='+site+' succeeded');
        }).fail(function(){
          console.log('/api/addtowhitelist?site='+site+' failed');
        });
        self.whitelist = r1.entries;
        self.$digest();
        console.log('/api/removefromwhitelist?site='+site+' succeeded');
      }).fail(function(){
        console.log('/api/removefromwhitelist?site='+site+' failed');
      });
    }else if(typeof newsite === 'boolean'){
      if(newsite && !self._validatewhitelistentry(site))return;
      var url = '/api/' + (newsite ? 'addtowhitelist' : 'removefromwhitelist') + '?site=' + site;
      $.post(url).done(function(r){
        if(newsite)
          $('#sitetoadd').val('');
        self.whitelist = r.entries;
        self.$digest();
        console.log(url+' succeeded');
      }).fail(function(){
        console.log(url+' failed');
      });
    }
  };

  self.sendpm = function(){
    if(!self.pm)return;
    var data = {
      message: self.pm
    };
    console.log('submitting contact form, data=', data);
    $.post('/api/contact', data).done(function(){
      $('#pm-result').removeClass('error').html('Feedback submitted successfully').show().delay(5000).fadeOut();
      self.pm = '';
    }).fail(function(e){
      $('#pm-result').addClass('error').html('Could not submit feedback').show().delay(5000).fadeOut();
    });
  };

  self.todo = function(){alert('todo');}
}

$(document).ready(function(){
  var scope = null;
  var $body = $('body');

  $(window).bind('hashchange', function(){
    showid(location.hash);
  });
  $('#panel-list a, ' +
    '.panellink, ' +
    '#welcome-container .controls a[href], ' +
    '.overlaylink'
    ).click(showidclickhandler);

  // XXX height hack unneeded when viewport has minheight of 630
  //$window = $(window);
  //function _resize_body(){
  //  $body.height($window.height());
  //}
  //$window.resize(_resize_body);

  $('.overlay .close').click(function(evt){
    $(evt.target).parent('.overlay').removeClass('selected');
    evt.preventDefault();
    //_resize_body(); // XXX height hack
  });

  $('#userlink, #usermenu a').click(function(evt){
    $('#usermenu').slideToggle(50);
    $('#userlink').toggleClass('collapsed');
  });

  // XXX
  $('input.whitelistentry').live('blur', function(){
    console.log('blur');
    if(!scope)
      scope = $body.scope();
    setTimeout(scope.fetchwhitelist, 200);
  });
  $('#sitetoadd').live('blur', function(){
    $(this).val('');
  });

  function _connectionEstablished(){
    console.log('CometD Connection Established');
  }

  function _connectionBroken(){
    console.log('CometD Connection Broken');
    // XXX "Closing window in x seconds..."?
  }

  // XXX never getting called?
  function _connectionClosed(){
    console.log('CometD Connection Closed');
    // XXX "Lantern has shut down." Close window
    //alert('CometD Connection Closed');
  }

  // Function that manages the connection status with the Bayeux server
  var _connected = false;
  function _metaConnect(message){
    if (cometd.isDisconnected()){
      _connected = false;
      _connectionClosed();
      return;
    }

    var wasConnected = _connected;
    _connected = message.successful === true;
    if (!wasConnected && _connected){
      _connectionEstablished();
    }else if(wasConnected && !_connected){
      _connectionBroken();
    }
  }

  function syncHandler(msg){
    if(!scope)
      scope = $body.scope();
    scope.update(msg.data);

    // XXX
    if(scope.state.getMode){
      if(scope.loggedin()){
        if(scope.peers === FETCHFAILED){
          // XXX back-off
          console.log('retrying fetchpeers in 1s');
          setTimeout(scope.fetchpeers, 1000);
        }else if(scope.peers === null){
          console.log('calling fetch peers for the first time');
          scope.fetchpeers();
        }
      }
      if(scope.whitelist === null){
        scope.fetchwhitelist();
      }else if(scope.whitelist === FETCHFAILED){
        // XXX back-off
        console.log('retrying fetchwhitelist in 1s');
        setTimeout(scope.fetchwhitelist, 1000);
      }
    }
  }

  function _metaHandshake(handshake){
    if (handshake.successful === true){
      cometd.batch(function(){
        cometd.subscribe('/sync', syncHandler);
        if(location.hash)
          showid(location.hash, 'overlay');
      });
    }
  }

  $(window).unload(function(){
    cometd.disconnect(true);
  });

  var cometURL = location.protocol + "//" + location.host + "/cometd";
  cometd.configure({
    url: cometURL,
    logLevel: 'info'
  });

  cometd.addListener('/meta/handshake', _metaHandshake);
  cometd.addListener('/meta/connect', _metaConnect);
  // XXX subscribe to /meta/disconnect?

  cometd.handshake();
});
