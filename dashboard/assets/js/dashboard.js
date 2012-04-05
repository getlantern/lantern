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

var LION = !!navigator.userAgent.match(/Mac OS X 10_7/);
function lionbarsify($el){
  if(LION || !$el.length || $el.hasClass('lionbarsified'))
    return false;
  console.log('lionbarsifying', $el);
  $el.addClass('lionbarsified').lionbars();
  return true;
}

function showid(id, ignorecls, ignore){
  var $el = $(id);
  if(!$el.length)
    return;
  var cls = $el.attr('data-cls');
  if(cls === ignorecls || ignore){
    location.hash = '';
    return;
  }
  location.hash = id;
  if($el.hasClass('selected')){
    return;
  }
  $('.' + cls + '.selected').removeClass('selected');
  $el.addClass('selected').show();
  if(cls === 'panel'){
    $('#panel-list > li > a.selected').removeClass('selected');
    $('#panel-list > li > a[href='+id+']').addClass('selected');
  }
  lionbarsify($el.find('.lionbars'));
  // XXX
  $('.signinpwinput').blur();
}

function LDCtrl(){
  var self = this;
  self.state = {};
  self.$watch('state', function(scope, newVal, oldVal){
    self.inputemail = self.inputemail || self.state.email;
    self.pmfromemail = self.pmfromemail || self.state.email;
  });
  self.stateloaded = function(){
    return !$.isEmptyObject(self.state);
  };
  self.block = false;
  self.$watch('block');

  self._reset = function(){
    console.log('in _reset');
    self.inputemail = null;
    self.pmfromemail = null;
    self.resetshowsignin();
    if(location.hash && location.hash != '#')
      showid(location.hash, 'overlay', !self.state.initialSetupComplete);
  };

  self.update = function(state){
    var firstupdate = !self.stateloaded();
    self.state = state;
    if(firstupdate)
      self._reset();
    self.$digest();
  };

  // XXX
  self.FETCHING = FETCHING;
  self.FETCHFAILED = FETCHFAILED;
  self.FETCHSUCCESS = FETCHSUCCESS;

  self.stateunset = function() { return self.stateloaded() && self.state.settings.state == 'UNSET'; }
  self.stateset = function() { return self.stateloaded() && self.state.settings.state == 'SET'; }
  self.statelocked = function() { return self.stateloaded() && self.state.settings.state == 'LOCKED'; }
  self.statecorrupt = function() { return self.stateloaded() && self.state.settings.state == 'CORRUPTED'; }

  self.updateavailable = function(){
    // uncomment out to make update panel available:
    // return true;
    return !$.isEmptyObject(self.state.update);
  };

  self.updnrate = function(){
    return self.state.upRate + self.state.downRate;
  };

  self.byteunits = function(nbytes){
    if(isNaN(nbytes)){
      //console.log('nbytes is NaN, bailing');
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
    return inputemail === stateemail || inputemail + '@gmail.com' === stateemail;
  };

  self.passrequired = function(){
    if(self.sameuser() && self.logged_in()) return false;
    return !(self.sameuser() && self.state.passwordSaved && self.state.savePassword);
  };

  self._passreqtxt = 'password';
  self._nopassreqtxt = '••••••••••••••••';
  self.passplaceholder = function(){
    if(!self.passrequired())
      return self._nopassreqtxt;
    return self._passreqtxt;
  };

  self.resetshowsignin = function() {
    self._showsignin = self.logged_out() && !self.state.passwordSaved;
    console.log('set _showsignin to', self._showsignin);
  }

  self.showsignin = function(val){
    if(typeof val == 'undefined'){
      if(typeof self._showsignin == 'undefined'){
        self.resetshowsignin();
      }
    }else{
      self._showsignin = val;
    }
    return self._showsignin;
  }
  
  self.showwelcome = function() {
    if (!self.stateloaded()) return;

    if (self.state.initialSetupComplete) {
      return false;
    }
    else if (self.stateset()) {
      return true;
    }
    else if (self.statelocked()) {
      return !self.state.localPasswordInitialized;
    }
    else {
      console.log('showwelcome: corrupted or unknown state, returning false', self.state);
      return false; // corrupted or unknown
    }
  }
  
  self.pm = null;
  self.pmsendfrom = true;
  self.pmfromemail = null;

  self.npeers = function() {return self.state.peerCount;}



  function bindprops(fieldname, keysobj){ 
    for(var key in keysobj){
      self[key.toLowerCase()] = function(){ var key_ = key;
        return function(){
          return self.state[fieldname] === key_;
        }
      }();
    }
  }
  bindprops('connectivity', {'DISCONNECTED':0, 'CONNECTING':0, 'CONNECTED':0});
  bindprops('googleTalkState', {'LOGGING_OUT':0, 'LOGGING_IN':0, 'LOGGED_IN':0, 'LOGIN_FAILED':0});
  self.logged_out = function(){ var gts = self.state.googleTalkState; return gts === 'LOGGED_OUT' || gts === 'LOGIN_FAILED'; };

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
    if(self.connected())
      return 'Switch to '+(self.state.getMode?'giv':'gett')+'ing access';
  };

  self.fs_submit = function(){
    if(self.logged_out() || (!self.sameuser() || self.inputpassword)){
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
    if(self.state.getMode && self.logged_in()){
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
    if(self.logged_in()){
      if(self.sameuser() && !self.inputpassword){
        console.log('ingoring signin as', self.state.email, ', already signed in as that user and no new password supplied');
        self.showsignin(false);
        self.inputpassword = '';
        return;
      }
    }
    var data = {
      email: email || self.state.email
    };
    if(self.passrequired() || self.inputpassword){
      if(!self.inputpassword){
        console.log('no password saved or supplied, bailing');
        return;
      }
      data.password = self.inputpassword;
    }
    // XXX force this for smoother looking login
    self.state.googleTalkState = 'LOGGING_IN';
    self.$digest();
    console.log('Signing in with:', data);
    $.post('/api/signin', data).done(function(state){
      console.log('signin succeeded');
      self.inputpassword = '';
      self.showsignin(false);
      self.update(state);
      if(!self.state.initialSetupComplete){
        showid(self.state.getMode && '#trustedpeers' || '#done');
        self.fetchpeers();
      }
    }).fail(function(){
      // XXX backend does not pass logged_out state immediately, take matters into our own hands
      self.state.googleTalkState = 'LOGIN_FAILED';
      self.$digest();
      if(self.state.initialSetupComplete)
        self.showsignin(true);
      console.log('signin failed');
    });
  };

  self.fs_submit_src = function(){
    if(self.fsform.$invalid && !(self.logged_in() && self.sameuser()))
      return 'img/arrow-right-disabled.png';
    if(self.logging_in())
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
      (self.connected() ? 'You will be disconnected and y' : 'Y') +
      'our settings will be erased.';
    if(confirm(msg)){
      $.post('/api/reset').done(function(state){
        self.state = {};
        self.update(state);
        showid('#welcome');
      });
    }
  };
  
  self.localpassword = null;
  self.unlocksettings = function() {
    $.post('/api/unlock', {'password': self.localpassword}).done(function(state){
      $('#unlock-welcome').removeClass("unlock-failed");
      $('#unlock-welcome').removeClass("invalid-password");
      self.localpassword = null;
      self.update(state);
      // since this is essentially a re-init prior to 
      // showing the dashboard, we re-init this as well.
      self.resetshowsignin();
      self.$digest();
    }).fail(function(r) {
      if (r.status >= 400 && r.status < 500) {
        $('#unlock-slide').addClass("invalid-password");
      }
      else if (r.status >= 500 && r.status < 600) {
        $('#unlock-slide').addClass("unlock-failed");
      }
    });
  }
  

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
      data.replyto = self.pmfromemail;
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

function SetLocalPasswordCtrl() {
  this.password = '';
  this.password2 = '';
  this.servererr = null;
  this.blankpat = /^\s*$/;
}
SetLocalPasswordCtrl.prototype = {
  isvalid: function() {
    return !this.isblank() && this.passwordsmatch();
  },
  
  isblank: function() {
    return this.blankpat.test(this.password);
  },
  
  passwordsmatch: function() {
    return this.password == this.password2;
  },
  
  hasservererr: function() {
    return this.servererr != null;
  },
  
  submitpassword: function() {
    console.log('submitting local password...');
    var thisCtrl = this;
    $.post('/api/setlocalpassword',
           {'password': this.password}
    ).done(function(){
      thisCtrl.servererr = null;
      thisCtrl.$digest();
      console.log('set local password succeeded.');
      showid('#mode');
    }).fail(function(e){
      thisCtrl.servererr = "An error occurred setting local password.";
      thisCtrl.$digest();
      console.log('request to set local password failed.');
    });
  }
};

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

  $('input, textarea').placeholder(function(input, $input){
    var s = getscope();
    if($input.hasClass('signinpwinput'))
      return input.value == s._passreqtxt || input.value == s._nopassreqtxt;
    return input.value == $input.attr('placeholder');
  });

  $(window).bind('hashchange', function(){
    showid(location.hash);
  });
  $('#panel-list a, ' +
    '.panellink, ' +
    '#welcome-container .controls a[href], ' +
    '.overlaylink'
    ).click(function(evt){showid(clickevt2id(evt))});

  $('.overlay .close').click(function(evt){
    $(evt.target).parent('.overlay').removeClass('selected').hide()
      .parent('.overlay-modal').hide();
    evt.preventDefault();
  });
  var KEYCODE_ESC = 27;
  $(document).keyup(function(evt){
    switch(evt.keyCode){
    case KEYCODE_ESC:
      $('.overlay:visible').removeClass('selected').hide()
        .parent('.overlay-modal').hide();
      getscope().showsignin(false);
      getscope().$digest();
      break;
    }
  });

  $('.flashmsg .close').click(function(evt){
    $(evt.target).parent('.flashmsg').fadeOut();
    evt.preventDefault();
  });

  /*
  $('#userlink, #usermenu a').click(function(evt){
    $('#usermenu').slideToggle(50);
    $('#userlink').toggleClass('collapsed');
  });
  */

  var converter = new Showdown.converter(),
      $mdoverlay = $('#md-overlay');
  $('.showdown-link').click(function(evt){
    var sel = '.showdown[src*=' + $(this).attr('data-md') + ']',
        $target = $(sel);
    if(!$target.length){
      console.log('No element matching', sel);
      return false;
    }
    if(!$target.hasClass('showdownified')){
      console.log('showdownifying ' + sel);
      var md = $target.text(), html = converter.makeHtml(md);
      $target.html(html).addClass('showdownified');
    }
    $('.showdown').removeClass('selected');
    $target.addClass('selected');
    $mdoverlay.show();
    lionbarsify($target);
    return false;
  });

  var $doco = $('#doc-overlay'),
      $docmodal = $('#doc-modal'),
      $doc = $('.doc');
  $('.doc-link').click(function(evt){
    $doc.hide();
    $docmodal.show();
    var $target = $doco.show().find('#' + $(evt.currentTarget).attr('data-doc')).show();
    //lionbarsify($target.show()); // XXX none of the docs overflow #doc-overlay
    $doco.css('margin-top', -Math.round($doco.outerHeight()/2) + 'px');
    return false;
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

  var nfailed_fetchpeers = 0;
  var nfailed_fetchwhitelist = 0;

  function syncHandler(msg){
    var s = getscope();
    s.update(msg.data);

    // XXX
    if(s.state.getMode){
      if(s.connected() && s.logged_in()){
        if(s.peers === FETCHFAILED){
          var backoff = Math.pow(2, ++nfailed_fetchpeers) * 1000;
          console.log('retrying fetchpeers in ', backoff, ' ms');
          setTimeout(s.fetchpeers, backoff);
          s.peers = []; // XXX
        }else if(s.peers === null){
          console.log('calling fetch peers for the first time');
          s.fetchpeers();
        }
      }
      if(s.whitelist === null){
        s.fetchwhitelist();
      }else if(s.whitelist === FETCHFAILED){
        var backoff = Math.pow(2, ++nfailed_fetchwhitelist) * 1000;
        console.log('retrying fetchwhitelist in ', backoff, ' ms');
        setTimeout(s.fetchwhitelist, backoff);
        s.whitelist = []; // XXX
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
      });
    }
  });

  $(window).unload(function(){
    cometd.disconnect(true);
  });

  cometd.handshake();
});
