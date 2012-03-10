'use strict';

if(typeof console == 'undefined'){
  var console = {
    log: function(){}
  };
}

var cometd = $.cometd;
var cometurl = location.protocol + "//" + location.host + "/cometd";
cometd.websocketEnabled = false; // XXX not enabled on server
cometd.configure({
  url: cometurl,
  logLevel: 'info'
});

var FETCHING = 'fetching...'; // poor-man's promise
var FETCHFAILED = 'fetch failed';
var FETCHSUCCESS = 'fetch succeeded';

// http://html5pattern.com/
var HOSTNAMEPAT = /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$/;

var BYTEDIM = {GB: 1024*1024*1024, MB: 1024*1024, KB: 1024, B: 1};
var BYTESTR = {GB: 'gigabyte', MB: 'megabyte', KB: 'kilobyte', B: 'byte'};

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
  // XXX
  var lb = $el.find('.lionbars');
  if(lb.length){
    lb.lionbars();
    lb.removeClass('.lionbars');
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
  self.$watch('state');
  self.stateloaded = function(){
    return !$.isEmptyObject(self.state);
  };
  self.block = false;
  self.$watch('block');
  self.update = function(state){
    self.state = state;
    self.$digest();
  };

  // XXX
  self.FETCHING = FETCHING;
  self.FETCHFAILED = FETCHFAILED;
  self.FETCHSUCCESS = FETCHSUCCESS;

  self.updateavailable = function(){
    return !$.isEmptyObject(self.state.update);
  };

  self.updnrate = function(){
    return self.state.upRate + self.state.downRate;
  };

  self.byteunits = function(nbytes){
    if(isNaN(nbytes)){
      console.log('nbytes is NaN, bailing');
      return '';
    }
    for(var dim in BYTEDIM){ // expects largest units first
      var base = BYTEDIM[dim];
      if(nbytes >= base)
        return dim;
    }
    return 'B';
  };

  self.prettybytes = function(nbytes, longstr, nbytesother){
    var units = self.byteunits(nbytesother || nbytes),
        base = BYTEDIM[units],
        scaled = Math.round(nbytes/base);
    if(longstr){
      units = BYTESTR[units] + (scaled !== 1 ? 's' : '');
      return scaled + ' ' + units;
    }
    return scaled + units;
  };

  self.bytesrate = function(nbytes, longstr, nbytesother){
    var pb = self.prettybytes(nbytes, longstr, nbytesother);
    return longstr ? pb + ' per second' : pb + '/s';
  };

  self.inputemail = null;
  self.inputpassword = null;

  self.peerfilterinput = null;
  self.peerfilter = function(peer){
    var f = self.peerfilterinput;
    if(!f)return true;
    if(peer.name && peer.name.toLowerCase().indexOf(f.toLowerCase()) !== -1)return true;
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
  self.pmsendfrom = true;
  self.pmfromemail = null;

  self.npeers = function() {return self.state.peerCount;}
  self.loggedin = function(){return self.state.connectivity === 'CONNECTED';};
  self.loggedout = function(){return self.state.connectivity === 'DISCONNECTED';};
  self.loggingin = function(){return self.state.connectivity === 'CONNECTING';};

  self.conncaption = function(){
    var c = self.state.connectivity;
    switch(c){
    case 'CONNECTED':
      return (self.state.getMode?'Gett':'Giv')+'ing access';
    case 'DISCONNECTED':
      return 'Not connected';
    case 'CONNECTING':
      return 'Connecting';
    case 'DISCONNECTING':
      return 'Disconnecting';
    }
  };

  self.iconloctxt = function(){
    var platform = self.state.platform || {};
    switch(platform.osName){
    case 'Mac OS X':
      return 'menu bar';
    case 'Windows':
      return 'system tray';
    }
    return 'notification icon area';
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
      showid(self.state.getMode && '#trustedpeers' || '#done');
    }
  };

  self.fetchpeers = function(){
    if(self.state.getMode){
      console.log('fetching peers');
      self.peers = FETCHING;
      self.$digest();
      $.ajax({url: '/api/roster', dataType: 'json'}).done(function(r){
        self.peers = r.entries;
        self.$digest();
        console.log('set peers');
      }).fail(function(e){
        console.log('failed to fetch peers:',e);
        self.peers = FETCHFAILED;
        self.$digest();
      });
    }
  };

  self.fetchwhitelist = function(){
    if(self.state.getMode){
      console.log('fetching whitelist');
      self.whitelist = FETCHING;
      self.$digest();
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
    self.state.connectivity = 'CONNECTING';
    self.$digest();
    console.log('Signing in with:', data);
    $('form.signin').removeClass('badcredentials');
    $.post('/api/signin', data).done(function(state){
      console.log('signin succeeded');
      self.inputpassword = '';
      self.showsignin(false);
      self.update(state);
      self.fetchpeers();
      if(!self.state.initialSetupComplete)
        showid(self.state.getMode && '#trustedpeers' || '#done');
    }).fail(function(){
      // XXX backend does not pass logged_out state immediately, take matters into our own hands
      self.state.connectivity = 'DISCONNECTED';
      self.$digest();
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
      showid('#done');
    }).fail(function(e){
      $('#systemproxy').addClass('autoproxyfailed');
      self._autoproxyresp = FETCHFAILED;
      self.$digest();
      console.log('autoproxy request failed');
    });
  };

  self.finishsetup = function(){
    showid('#done');
    $('#welcome-container').fadeOut('slow');
    setTimeout(function(){
    $.post('/settings?initialSetupComplete=true').done(function(){
      self.showsignin(false)
      showid('#status');
      $('#tip-trayicon').delay(500).fadeIn('slow');
      console.log('finished setup.');
    }).fail(function(e){
      alert('Could not complete setup.'); console.log(e); // XXX
    });
    }, 1000);
  };

  self.toggle = function(setting, manual){
    var newvalue = manual ? !self.state[setting] : self.state[setting];
    console.log('attempting to toggle '+setting+' to '+newvalue);
    self.block = true;
    self.$digest();
    $.post('/settings?' + setting + '=' + newvalue).done(function(){
      console.log('successfully toggled '+setting+' to '+newvalue);
    }).fail(function(){
      console.log('failed to toggle '+setting);
    }).always(function(){
      self.block = false;
      self.$digest();
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
    if(self.pmsendfrom)
      data.replyto = self.pmfromemail || $('#pm-replyto').val(); // XXX ng:model gets out of sync?
    console.log('submitting contact form, data=', data);
    // disable send button, update label
    self.pm = '';
    self.$digest();
    $('#pm-send').html('Sending...');
    $.post('/api/contact', data).done(function(){
      $('.flashmsg').hide();
      $('#flash-main .content').addClass('success').removeClass('error')
        .html('Feedback submitted successfully').parent('#flash-main').fadeIn();
    }).fail(function(e){
      self.pm = data.message;
      self.$digest();
      $('.flashmsg').hide();
      $('#flash-main .content').addClass('error').removeClass('success')
        .html('Could not submit feedback').parent('#flash-main').fadeIn();
    }).always(function(){
      $('#pm-send').html('Send');
    });
  };

  self.todo = function(){alert('todo');}
}

$(document).ready(function(){
  var scope = null;
  var $body = $('body');

  function getscope(){
    if(scope === null){
      scope = $body.scope();
    }
    if(typeof scope === 'undefined'){
      console.log('scope() returned undefined, forcing compilation'); // XXX https://github.com/getlantern/lantern/issues/124
      angular.compile(document)().$apply();
      scope = $body.scope();
      if(typeof scope === 'undefined'){
        console.log('scope() returned undefined again, so much for that idea');
      }else{
        console.log('scope() is now returning a defined value, it worked?');
      }
    }
    return scope;
  }

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
  var KEYCODE_ESC = 27;
  $(document).keyup(function(evt){
    switch(evt.keyCode){
    case KEYCODE_ESC:
      $('.overlay.selected').removeClass('selected');
      getscope().showsignin(false);
      getscope().$digest();
      break;
    }
  });

  $('.flashmsg .close').click(function(evt){
    $(evt.target).parent('.flashmsg').fadeOut();
    evt.preventDefault();
  });

  $('#userlink, #usermenu a').click(function(evt){
    $('#usermenu').slideToggle(50);
    $('#userlink').toggleClass('collapsed');
  });

  // XXX
  $('input.whitelistentry.ng-dirty:not(.ng-invalid)').live('blur', function(){
    console.log('blur - valid -> submitting');
    $(this).closest('form').triggerHandler('submit');
  });
  $('input.whitelistentry:not([readonly])').live('focus', function(){
    console.log('focus');
    $(this).data('pristine', $(this).val());
  });
  $('input.whitelistentry.ng-dirty.ng-invalid').live('blur', function(){
    console.log('blur - invalid -> reverting');
    $(this).val($(this).data('pristine'));
  });
  $('#sitetoadd').live('blur', function(){
    $(this).val('');
  });

  // XXX force revalidation
  $('form.signin input').keyup(function(evt){
    $('form.signin input').change();
  });


  // http://cometd.org/documentation/cometd-javascript/subscription
  function _connectionEstablished(){
    console.log('CometD Connection Established');
  }
  function _connectionBroken(){
    console.log('CometD Connection Broken');
    var s = getscope();
    s.state = {};
    s.$digest();
  }
  function _connectionClosed(){
    console.log('CometD Connection Closed');
  }

  var _connected = false;
  cometd.addListener('/meta/connect', function(message){
    if(cometd.isDisconnected()){
      _connected = false;
      _connectionClosed();
      return;
    }
    var wasConnected = _connected;
    _connected = message.successful;
    if(!wasConnected && _connected){ // reconnected
      _connectionEstablished();
    }else if(wasConnected && !_connected){
      _connectionBroken();
    }
  });
  cometd.addListener('/meta/disconnect', function(message){
    console.log('got disconnect'); // XXX never getting called
    if(message.successful){
      _connected = false;
      _connectionClosed();
    }
  });

  function syncHandler(msg){
    var s = getscope();
    s.update(msg.data);

    // XXX
    if(s.state.getMode){
      if(s.loggedin()){
        if(s.peers === FETCHFAILED){
          // XXX back-off
          console.log('retrying fetchpeers in 1s');
          setTimeout(s.fetchpeers, 1000);
        }else if(s.peers === null){
          console.log('calling fetch peers for the first time');
          s.fetchpeers();
        }
      }
      if(s.whitelist === null){
        s.fetchwhitelist();
      }else if(s.whitelist === FETCHFAILED){
        // XXX back-off
        console.log('retrying fetchwhitelist in 1s');
        setTimeout(s.fetchwhitelist, 1000);
      }
    }
  }

  var _subscription;
  function _refresh(){
    _appUnsubscribe();
    _appSubscribe();
  }
  function _appUnsubscribe(){
    if (_subscription) 
      cometd.unsubscribe(_subscription);
    _subscription = null;
  }
  function _appSubscribe(){
    _subscription = cometd.subscribe('/sync', syncHandler);
  }
  cometd.addListener('/meta/handshake', function(handshake){
    if (handshake.successful === true){
      cometd.batch(function(){
        _refresh();
        if(location.hash)
          showid(location.hash, 'overlay');
      });
    }
  });

  $(window).unload(function(){
    cometd.disconnect(true);
  });

  cometd.handshake();
});
