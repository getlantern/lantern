(function($)
{
    var cometd = $.cometd;

    $(document).ready(function()
    {
        function _connectionEstablished()
        {
            $('#body').append('<div>CometD Connection Established</div>');
        }

        function _connectionBroken()
        {
            $('#body').append('<div>CometD Connection Broken</div>');
        }

        function _connectionClosed()
        {
            $('#body').append('<div>CometD Connection Closed</div>');
        }

        // Function that manages the connection status with the Bayeux server
        var _connected = false;
        function _metaConnect(message)
        {
            if (cometd.isDisconnected())
            {
                _connected = false;
                _connectionClosed();
                return;
            }

            var wasConnected = _connected;
            _connected = message.successful === true;
            if (!wasConnected && _connected)
            {
                _connectionEstablished();
            }
            else if (wasConnected && !_connected)
            {
                _connectionBroken();
            }
        }

        // Function invoked when first contacting the server and
        // when the server has lost the state of this client
        function _metaHandshake(handshake)
        {
            if (handshake.successful === true)
            {
                cometd.batch(function()
                {
                    cometd.subscribe('/sync', function(message)
                    {
                    	//console.dir(message);
                    	//$('#content').append(message);
                        //$('#body').append('<div>Server Says: ' + message.data.greeting + '</div>');
                    	$('#body').fadeOut(1000);
                        $('#body').html('<div>Server Says: ' + JSON.stringify(message) + '</div>');
                        $('#body').fadeIn(1000);
                    });
                    /*
                    var update = {"system" : {
                        "connectivity" : null,
                        "updateData" : {
                          "url" : null,
                          "version" : null
                        },
                        "location" : "US",
                        "internet" : {
                          "public" : "216.3.159.66",
                          "private" : "10.0.2.97"
                        },
                        "platform" : {
                          "osName" : "Mac OS X",
                          "osArch" : "x86_64",
                          "osVersion" : "10.6.8"
                        },
                        "startAtLogin" : true,
                        "port" : 8787,
                        "version" : "lantern_version_tok",
                        "connectOnLaunch" : true,
                        "systemProxy" : true
                    }};
                    */
                    var update = {
                        "system" : {
                            "startAtLogin" : false
                        }
                    };
                    // Publish on a service channel since the message is for the server only
                    cometd.publish('/service/sync', update);//{ name: 'Josh' });
                });
            }
        }

        // Disconnect when the page unloads
        $(window).unload(function()
        {
            cometd.disconnect(true);
        });

        var cometURL = location.protocol + "//" + location.host + config.contextPath + "/cometd";
        cometd.configure({
            url: cometURL,
            logLevel: 'debug'
        });

        cometd.addListener('/meta/handshake', _metaHandshake);
        cometd.addListener('/meta/connect', _metaConnect);

        cometd.handshake();
    });
})(jQuery);
