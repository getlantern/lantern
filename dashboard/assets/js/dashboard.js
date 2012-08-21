'use strict';

var CONSOLESHIM = false;

if(CONSOLESHIM){
  console.log_ = console.log;
  console.log = function(){
    for (var i = 0, j = arguments.length; i < j; i++){
      $('#console-shim > pre').append(arguments[i].toString() + ' ');
      console.log_.apply(this, arguments);
    }
      $('#console-shim > pre').append('\n');
  }
}else if(typeof console == 'undefined'){
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
var IPADDRPAT = /((^|\.)((25[0-5])|(2[0-4]\d)|(1\d\d)|([1-9]?\d))){4}$/;
// http://stackoverflow.com/a/46181
var EMAILPAT = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;

var BYTEDIM = {GB: 1024*1024*1024, MB: 1024*1024, KB: 1024, B: 1};
var BYTESTR = {GB: 'gigabyte', MB: 'megabyte', KB: 'kilobyte', B: 'byte'};

/**
 * Alternative call directly from SWT to load the roster.
 */
function loadRoster() {
  var s = getscope();
  s.fetchpeers();
}

/**
 * Alternative call directly from SWT to load the state document.
 */
function loadSettings() {
  console.log("Loading settings!!");
  var s = getscope();
  $.post('/api/state').done(function(state){
    console.log('got state doc');
    s.update(state);
  }).fail(function(jqXHR, textStatus){
    var code = jqXHR.status;
    switch(code){
    case 401:
    break;
    case 500:
    break;
    default:
    console.log('unexpected state sync return code:', code);
    }
    console.log('state sync failed');
  }).always(function() {
    s.$digest();
  });
}

var FRAGMENTPAT = /^[^#]*(#.*)$/;
function clickevt2id(evt){
  return evt.currentTarget.href.match(FRAGMENTPAT)[1];
}

var LION = false;//!!navigator.userAgent.match(/Mac OS X 10_[78]/);
function lionbarsify($el){
  if(LION || !$el.length || $el.hasClass('lionbarsified'))
    return false;
  if($el.is(':hidden') || $el.hasClass('unpopulated')){
    console.log($el, 'is not visible or not populated, scheduling later lionsbars call');
    setTimeout(function(){lionbarsify($el);}, 500);
    return false;
  }
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
  if(id == '#proxiedsites' || id == '#trusted'){
    showid('#settings');
    location.hash = id;
  }
  $('.' + cls + '.selected').removeClass('selected');
  $el.addClass('selected').show();
  if(cls === 'panel'){
    $('#panel-list > li > a.selected').removeClass('selected');
    $('#panel-list > li > a[href='+id+']').addClass('selected');
    $('.flashmsg:not(#tip-trayicon), .overlay').fadeOut().removeClass('selected');
  }
  //lionbarsify($el.find('.lionbars'));
}

function LDCtrl(){
  var self = this;
  self.__IE = __IE;
  self.state = {};
  self.$watch('state', function(scope, newVal, oldVal){
    self.inputemail = self.inputemail || self.state.email;
    self.pmfromemail = self.pmfromemail || self.state.email;
    window['ga-disable-UA-32870114-1'] = !self.state.analytics;
    if (self.state.analytics && !self.tracked) {
      self.tracked = true;
      _gaq.push(['_trackPageview']);
    }
  });
  self.stateloaded = function(){
    return !$.isEmptyObject(self.state);
  };
  self.block = false;
  self.$watch('block');

  self._reset = function(){
    console.log('in _reset');
    self.inputemail = null;
    if(__IE)
      $('.signinpwinput.ie').val('');
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
  self.peerorder = function(peer){
    return peer.name || peer.email;
  };
  self.peerfilter = function(peer){
    if(peer.t && peer.t == 'B') // blocked
      return false;
    var f = self.peerfilterinput;
    f = f && f.toLowerCase() || '';
    if(!f)return true;
    if(peer.name && peer.name.toLowerCase().indexOf(f) !== -1)return true;
    return peer.email.indexOf(f) !== -1;
  };
  self.peers = null;
  self.subreqs = null;
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

  self._logging_in = false;
  self._login_failed = false;

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
  self.badcredentials = null;

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
    var os = (self.state.platform || {osName: ''}).osName.split(' ')[0];
    switch(os){
    case 'Mac':
      return 'menu bar';
    case 'Windows':
      return 'system tray';
    }
    return 'notification icon area';
  };

  self.switchlinktext = function(){
    //if(self.connected())
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
      showid(self.state.getMode && '#systemproxy' || '#done');
    }
  };

  self.fetchpeers = function(){
    if(self.logged_in()){
      console.log('fetching peers');
      self.peers = FETCHING;
      self.$digest();
      $.ajax({url: '/api/roster', dataType: 'json'}).done(function(r){
        self.peers = r.entries;
        self.subreqs = r.subscriptionRequests;
        self.$digest();
        console.log('set peers');
        $('.peerlist, #invite-peerlist, #subreq-peerlist').removeClass('unpopulated');
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
        $('#siteslist').removeClass('unpopulated');
      }).fail(function(e){
        console.log('failed to fetch whitelist:',e);
        self.whitelist = FETCHFAILED;
      });
    }
  };

  self.signin = function(email){
    if(__IE){
      self.inputpassword = $('.signinpwinput.ie:visible').val();
      console.log('set inputpassword to ', self.inputpassword, ' for ie');
    }
    if(self.logged_in()){
      if(self.sameuser() && !self.inputpassword){
        console.log('ingoring signin as', self.state.email, ', already signed in as that user or no new password supplied');
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
    // XXX control this state ourselves due to synchronization issues with backend (#252)
    self._logging_in = true;
    self._login_failed = false;
    self.badcredentials = null;
    self.$digest();
    console.log('Signing in with:', data);
    $.post('/api/signin', data).done(function(state){
      console.log('signin succeeded');
      self.inputemail = '';
      self.inputpassword = '';
      self.pmfromemail = '';
      self.showsignin(false);
      self.update(state);
      if(!self.state.initialSetupComplete){
        showid(self.state.getMode && '#systemproxy' || '#done');
        self.fetchpeers();
        //lionbarsify($('#trustedpeers > .peerlist'));
      }
    }).fail(function(jqXHR, textStatus){
      var code = jqXHR.status;
      switch(code){
      case 401:
        self.badcredentials = true;
        break;
      case 500:
        self.badcredentials = false;
        break;
      default:
        console.log('unexpected signin response status code:', code);
      }
      self._login_failed = true;
      if(self.state.initialSetupComplete)
        self.showsignin(true);
      console.log('signin failed:', code);
    }).always(function(){
      self._logging_in = false;
      self.$digest();
    });
  };

  self.fs_submit_src = function(){
    if(self.fsform.$invalid && !(self.logged_in() && self.sameuser()))
      return 'img/arrow-right-disabled.png';
    if(self._logging_in)
      return 'img/spinner-big.gif';
    return 'img/arrow-right.png';
  };

  self.autoproxy_continue_src = function(){
    if(self._autoproxyresp === FETCHING)
      return 'img/spinner-big.gif';
    return 'img/arrow-right.png';
  };

  self.invite = function(email){
    if(!self.validateemail(email)){
      console.log('invalid email: ' + email);
      return;
    }
    if(self.state.invites === 0){
      console.log('invite() called with no invites left, bailing');
      if(self.state.initialSetupComplete){
        $('.flashmsg').hide();
        $('#flash-main .content').addClass('error').removeClass('success')
          .html('Could not send invite, none remaining').parent('#flash-main').fadeIn();
      }
      return;
    }
    var url = '/api/invite?email=' + encodeURIComponent(email);
    $.post(url).done(function(){
      console.log('successfully invited ' + email); 
      self.$digest();
      $('.invites-remaining').css('color', '#f00').animate({color: '#666'}, 2000);
      if(self.state.initialSetupComplete){
        $('.flashmsg').hide();
        $('#flash-main .content').addClass('success').removeClass('error')
          .html('Invite sent to ' + email).parent('#flash-main').fadeIn();
      }
      self.peerfilterinput = null;
      self.$digest();
      return true;
    }).fail(function(){
      console.log('failed to invite ' + email); 
      if(self.state.initialSetupComplete){
        $('.flashmsg').hide();
        $('#flash-main .content').addClass('error').removeClass('success')
          .html('Error sending invite to ' + email).parent('#flash-main').fadeIn();
      }
    });
  };

  self.invited = function(email){
    var invlist = self.state.invited;
    if(!invlist)return;
    for(var i=0,l=invlist.length; i<l; ++i)
      if(email == invlist[i]) return true;
    return false;
  };

  self.handlesubreq = function(approve, jid) {
    var url = '/api/' + (approve ? '' : 'un') + 'subscribed?jid=' + encodeURIComponent(jid);
    var msg = (approve ? 'Accepted' : 'Declined') + ' invite from ' + jid;
    var $flash = $('#flash-main .content'); 
    $.post(url).done(function(){
      if(self.state.initialSetupComplete){
        $('.flashmsg').hide();
        approve ? $flash.addClass('success').removeClass('error') :
                  $flash.addClass('error').removeClass('success');
        $flash.html(msg).parent('#flash-main').fadeIn();
      }
      self.$digest();
    }).fail(function(){
      if(self.state.initialSetupComplete){
        $('.flashmsg').hide();
        $flash.addClass('error').removeClass('success')
          .html(msg + ' failed').parent('#flash-main').fadeIn();
      }
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
  

  self.validateemail = function(val){
    return EMAILPAT.test(val);
  };

  self._validatewhitelistentry = function(val){
    if(!HOSTNAMEPAT.test(val) && !IPADDRPAT.test(val)){
      console.log('not a valid hostname:', val, '(so much for html5 defenses)');
      return false;
    }
    return true;
  };

  self.undo = function(){
    self._undo();
    $('.flashmsg').hide();
  };
  self.updatewhitelist = function(site, newsite, noundo){
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
          console.log('/api/addtowhitelist?site='+newsite+' succeeded');

          // scroll to and highlight
          var $newentry = $('.whitelistentry[value="'+newsite+'"]').parents('li');
          $newentry.scrollIntoView({
            complete: function(){
              $newentry.css('background-color', '#ffa').animate({backgroundColor: '#fff'}, 2000);
            }
          });

          // show flash msg with undo
          if(!noundo){
            self._undo = function(){
              self.updatewhitelist(newsite, site, true);
            };
            $('.flashmsg').hide();
            $('#flash-main .content').addClass('success').removeClass('error')
              .html('Changed ' + site + ' to ' + newsite + '. <a onclick=getscope().undo()>Undo</a>').parent('#flash-main').fadeIn();
          }
        }).fail(function(){
          console.log('/api/addtowhitelist?site='+newsite+' failed');
          $('.flashmsg').hide();
          $('#flash-main .content').addClass('error').removeClass('success')
            .html('Failed to add ' + newsite).parent('#flash-main').fadeIn();
          });
        self.whitelist = r1.entries;
        console.log('/api/removefromwhitelist?site='+site+' succeeded');
      }).fail(function(){
        console.log('/api/removefromwhitelist?site='+site+' failed');
        $('.flashmsg').hide();
        $('#flash-main .content').addClass('error').removeClass('success')
          .html('Failed to remove ' + site).parent('#flash-main').fadeIn();
      });
    }else if(typeof newsite === 'boolean'){
      if(newsite && !self._validatewhitelistentry(site))return;
      var url = '/api/' + (newsite ? 'addtowhitelist' : 'removefromwhitelist') + '?site=' + site;
      $.post(url).done(function(r){
        if(newsite){ // site added
          $('#sitetoadd').val('');
        }else{ // site removed
          // show flash msg with undo
          self._undo = function(){
            self.updatewhitelist(site, true);
          };
          $('.flashmsg').hide();
          $('#flash-main .content').addClass('success').removeClass('error')
            .html('Removed ' + site + '. <a onclick=getscope().undo()>Undo</a>').parent('#flash-main').fadeIn();
        }
        self.whitelist = r.entries;
        self.$digest();
        console.log(url+' succeeded');
        if(newsite){
          var $newentry = $('.whitelistentry[value="'+site+'"]').parents('li');
          $newentry.scrollIntoView({
            complete: function(){
              $newentry.css('background-color', '#ffa').animate({backgroundColor: '#fff'}, 2000);
            }
          });
        }
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
      showid('#signin');
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

  window.getscope = getscope;

  $('input, textarea').placeholder();

  $(window).bind('hashchange', function(){
    showid(location.hash);
  });
  $('#panel-list a, ' +
    '.panellink, ' +
    '#welcome-container .controls a[href], ' +
    '.overlaylink'
    ).click(function(evt){showid(clickevt2id(evt))});

  function hilite(entiresettingspanel){
    var sel = entiresettingspanel ? '#settings, #onlyproxy' : '#onlyproxy';
    $(sel).css('background-color', '#ffa').animate({
      backgroundColor: 'transparent'}, 2000);
  }
  function mvtipti(after_else_func){
    var $tipti = $('#tip-trayicon');
    if (!$tipti.hasClass('moved')){
      $tipti.animate({top: '+=305'}, 1000, after_else_func).addClass('moved');
    } else {
      after_else_func();
    }
  }
  $('#proxiedsites-tip').click(function(evt){
    evt.preventDefault();
    evt.stopPropagation();
    showid('#settings');
    mvtipti(hilite);
  });
  $('#settings-tip').click(function(){
    mvtipti(function(){hilite(true);});
  });
  $('#invites-tip').click(function(){
    mvtipti(function(){
      $('#invites').css('background-color', '#ffa').animate({
        backgroundColor: 'transparent'}, 2000);
    });
  });

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
  $('.hideflashmsg').click(function(evt){
    $(evt.target).parents('.flashmsg').fadeOut();
  });
  */

  /*
  $('#userlink, #usermenu a').click(function(evt){
    $('#usermenu').slideToggle(50);
    $('#userlink').toggleClass('collapsed');
  });
  */

  /*
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
  */

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


  //lionbarsify($('#trusted > .peerlist'));

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
  function syncHandlerRoster(msg){
    console.log('syncing new roster');
    var s = getscope(), data = msg.data;
    s.peers = data.entries;
    s.subreqs = data.subscriptionRequests;
    s.$digest();
  }

  var _subscription, _subscription_roster;
  function _refresh(){
    _appUnsubscribe();
    _appSubscribe();
  }
  function _appUnsubscribe(){
    if (_subscription) 
      cometd.unsubscribe(_subscription);
    _subscription = null;
    if (_subscription_roster) 
      cometd.unsubscribe(_subscription_roster);
    _subscription_roster = null;
  }
  function _appSubscribe(){
    _subscription = cometd.subscribe('/sync/settings', syncHandler);
    _subscription_roster = cometd.subscribe('/sync/roster', syncHandlerRoster);
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
