'use strict';

function SettingsCtrl($scope) {
  $scope.nsyncs = 0;
}

function RosterCtrl($scope) {
  $scope.nsyncs = 0;
}

$(function(){
  // boilerplate comet setup
  // @see http://cometd.org/documentation/cometd-javascript/subscription
  var cometd = $.cometd;
  cometd.websocketEnabled = false; // disabled server-side
  cometd.configure({
    url: location.protocol+'//'+location.host+'/cometd',
    logLevel: 'info'
  });

  function _connectionEstablished(){
    console.log('CometD Connection Established');
  }

  function _connectionBroken(){
    console.log('CometD Connection Broken');
  }

  function _connectionClosed(){
    console.log('CometD Connection Closed');
  }

  var _connected = false;

  cometd.addListener('/meta/connect', function(msg){
    if(cometd.isDisconnected()){
      _connected = false;
      _connectionClosed();
      return;
    }
    var wasConnected = _connected;
    _connected = msg.successful;
    if(!wasConnected && _connected){ // reconnected
      _connectionEstablished();
    }else if(wasConnected && !_connected){
      _connectionBroken();
    }
  });

  cometd.addListener('/meta/disconnect', function(msg){
    console.log('got disconnect');
    if(msg.successful){
      _connected = false;
      _connectionClosed();
    }
  });

  var _subSettings, _subRoster;

  function _appSubscribe(){
    _subSettings = cometd.subscribe('/sync/settings', function(msg){
      //console.log('got message on channel /sync/settings:', msg);
      var $scope = $('#settings-container').scope();
      if($scope){
        $scope.state = msg.data;
        $scope.nsyncs++;
        $scope.$digest();
        prettyPrint();
      }
    });
    _subRoster = cometd.subscribe('/sync/roster', function(msg){
      //console.log('got message on channel /sync/roster:', msg);
      var $scope = $('#roster-container').scope();
      if($scope){
        $scope.state = msg.data;
        $scope.nsyncs++;
        $scope.$digest();
      }
    });
  }

  function _appUnsubscribe(){
    if(_subSettings) 
      cometd.unsubscribe(_subSettings);
    _subSettings = null;
    if(_subRoster) 
      cometd.unsubscribe(_subRoster);
    _subRoster = null;
  }

  function _refresh(){
    _appUnsubscribe();
    _appSubscribe();
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
