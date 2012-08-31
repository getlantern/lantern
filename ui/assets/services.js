angular.module('dashboard.services', []).
    factory('syncService', function ($rootScope) {

        // boilerplate comet setup
        // @see http://cometd.org/documentation/cometd-javascript/subscription

        var cometd = $.cometd;
        var connected = false;
        var subscriptions = {};
        var queuedSubscriptions = [];

        cometd.websocketEnabled = false; // disabled server-side
        cometd.configure({
            url: location.protocol + '//' + location.host + '/cometd',
            logLevel: 'info'
        });

        function connectionEstablished() {
            console.log('CometD Connection Established');
            angular.forEach(queuedSubscriptions, function(sub) {
                console.log('subscribing queued subscription request to channel ' + sub.channel);
                subscribe(sub.channel, sub.callback);
            });
        }

        function connectionBroken() {
            console.log('CometD Connection Broken');
        }

        function connectionClosed() {
            console.log('CometD Connection Closed');
        }

        cometd.addListener('/meta/connect', function (msg) {
            if (cometd.isDisconnected()) {
                connected = false;
                connectionClosed();
                return;
            }
            var wasConnected = connected;
            connected = msg.successful;
            if (!wasConnected && connected) { // reconnected
                connectionEstablished();
            } else if (wasConnected && !connected) {
                connectionBroken();
            }
        });

        cometd.addListener('/meta/disconnect', function(msg) {
            console.log('got disconnect');
            if (msg.successful) {
                connected = false;
                connectionClosed();
            }
        });

        function subscribe(channel, callback) {
            if (!connected) {
                console.log('not yet connected; queuing subscription request for channel ' + channel);
                queuedSubscriptions.push({channel: channel, callback: callback});
                return;
            }
            var existing = subscriptions[channel];
            if (existing) {
                var sub = existing[0];
                cometd.unsubscribe(sub);
                console.log('unsubscribing existing subscription request for channel ' + channel);
            }
            subscriptions[channel] = [cometd.subscribe(channel, function(msg) {
                $rootScope.$apply(function() {
                    callback(msg.data);
                });
                prettyPrint(); // XXX
            }), callback];
            console.log('subscribed to channel ' + channel);
        }

        cometd.addListener('/meta/handshake', function(handshake){
            if (handshake.successful) {
                console.log('successful handshake');
                // refresh subscriptions
                var oldSubs = subscriptions;
                subscriptions = {};
                angular.forEach(oldSubs, function(val, key) {
                    var sub = val[0], cb = val[1];
                    if (sub) {
                        cometd.unsubscribe(sub);
                        console.log('unsubscribed from channel ' + key);
                    }
                    subscribe(key, cb);
                });
            }
            else {
                console.log('unsuccessful handshake');
            }
        });

        cometd.handshake();

        return {
            subscribe: function (chan, cb) { subscribe(chan, cb); }
        };
    });