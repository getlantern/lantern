/*
 * Copyright (c) 2010 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

if (typeof dojo !== 'undefined')
{
    dojo.provide('org.cometd');
}
else
{
    // Namespaces for the cometd implementation
    this.org = this.org || {};
    org.cometd = {};
}

org.cometd.JSON = {};
org.cometd.JSON.toJSON = org.cometd.JSON.fromJSON = function(object)
{
    throw 'Abstract';
};

org.cometd.Utils = {};

org.cometd.Utils.isString = function(value)
{
    if (value === undefined || value === null)
    {
        return false;
    }
    return typeof value === 'string' ||  value instanceof String;
};

org.cometd.Utils.isArray = function(value)
{
    if (value === undefined || value === null)
    {
        return false;
    }
    return value instanceof Array;
};

/**
 * Returns whether the given element is contained into the given array.
 * @param element the element to check presence for
 * @param array the array to check for the element presence
 * @return the index of the element, if present, or a negative index if the element is not present
 */
org.cometd.Utils.inArray = function(element, array)
{
    for (var i = 0; i < array.length; ++i)
    {
        if (element == array[i])
        {
            return i;
        }
    }
    return -1;
};

org.cometd.Utils.setTimeout = function(cometd, funktion, delay)
{
    return setTimeout(function()
    {
        try
        {
            funktion();
        }
        catch (x)
        {
            cometd._debug('Exception invoking timed function', funktion, x);
        }
    }, delay);
};

/**
 * A registry for transports used by the Cometd object.
 */
org.cometd.TransportRegistry = function()
{
    var _types = [];
    var _transports = {};

    this.getTransportTypes = function()
    {
        return _types.slice(0);
    };

    this.findTransportTypes = function(version, crossDomain, url)
    {
        var result = [];
        for (var i = 0; i < _types.length; ++i)
        {
            var type = _types[i];
            if (_transports[type].accept(version, crossDomain, url) === true)
            {
                result.push(type);
            }
        }
        return result;
    };

    this.negotiateTransport = function(types, version, crossDomain, url)
    {
        for (var i = 0; i < _types.length; ++i)
        {
            var type = _types[i];
            for (var j = 0; j < types.length; ++j)
            {
                if (type == types[j])
                {
                    var transport = _transports[type];
                    if (transport.accept(version, crossDomain, url) === true)
                    {
                        return transport;
                    }
                }
            }
        }
        return null;
    };

    this.add = function(type, transport, index)
    {
        var existing = false;
        for (var i = 0; i < _types.length; ++i)
        {
            if (_types[i] == type)
            {
                existing = true;
                break;
            }
        }

        if (!existing)
        {
            if (typeof index !== 'number')
            {
                _types.push(type);
            }
            else
            {
                _types.splice(index, 0, type);
            }
            _transports[type] = transport;
        }

        return !existing;
    };

    this.find = function(type)
    {
        for (var i = 0; i < _types.length; ++i)
        {
            if (_types[i] == type)
            {
                return _transports[type];
            }
        }
        return null;
    };

    this.remove = function(type)
    {
        for (var i = 0; i < _types.length; ++i)
        {
            if (_types[i] == type)
            {
                _types.splice(i, 1);
                var transport = _transports[type];
                delete _transports[type];
                return transport;
            }
        }
        return null;
    };

    this.reset = function()
    {
        for (var i = 0; i < _types.length; ++i)
        {
            _transports[_types[i]].reset();
        }
    };
};

/**
 * Base object with the common functionality for transports.
 */
org.cometd.Transport = function()
{
    var _type;
    var _cometd;

    /**
     * Function invoked just after a transport has been successfully registered.
     * @param type the type of transport (for example 'long-polling')
     * @param cometd the cometd object this transport has been registered to
     * @see #unregistered()
     */
    this.registered = function(type, cometd)
    {
        _type = type;
        _cometd = cometd;
    };

    /**
     * Function invoked just after a transport has been successfully unregistered.
     * @see #registered(type, cometd)
     */
    this.unregistered = function()
    {
        _type = null;
        _cometd = null;
    };

    this._debug = function()
    {
        _cometd._debug.apply(_cometd, arguments);
    };

    this._mixin = function()
    {
        return _cometd._mixin.apply(_cometd, arguments);
    };

    this.getConfiguration = function()
    {
        return _cometd.getConfiguration();
    };

    this.getAdvice = function()
    {
        return _cometd.getAdvice();
    };

    this.setTimeout = function(funktion, delay)
    {
        return org.cometd.Utils.setTimeout(_cometd, funktion, delay);
    };

    /**
     * Converts the given response into an array of bayeux messages
     * @param response the response to convert
     * @return an array of bayeux messages obtained by converting the response
     */
    this.convertToMessages = function (response)
    {
        if (org.cometd.Utils.isString(response))
        {
            try
            {
                return org.cometd.JSON.fromJSON(response);
            }
            catch(x)
            {
                this._debug('Could not convert to JSON the following string', '"' + response + '"');
                throw x;
            }
        }
        if (org.cometd.Utils.isArray(response))
        {
            return response;
        }
        if (response === undefined || response === null)
        {
            return [];
        }
        if (response instanceof Object)
        {
            return [response];
        }
        throw 'Conversion Error ' + response + ', typeof ' + (typeof response);
    };

    /**
     * Returns whether this transport can work for the given version and cross domain communication case.
     * @param version a string indicating the transport version
     * @param crossDomain a boolean indicating whether the communication is cross domain
     * @return true if this transport can work for the given version and cross domain communication case,
     * false otherwise
     */
    this.accept = function(version, crossDomain, url)
    {
        throw 'Abstract';
    };

    /**
     * Returns the type of this transport.
     * @see #registered(type, cometd)
     */
    this.getType = function()
    {
        return _type;
    };

    this.send = function(envelope, metaConnect)
    {
        throw 'Abstract';
    };

    this.reset = function()
    {
        this._debug('Transport', _type, 'reset');
    };

    this.abort = function()
    {
        this._debug('Transport', _type, 'aborted');
    };

    this.toString = function()
    {
        return this.getType();
    };
};

org.cometd.Transport.derive = function(baseObject)
{
    function F() {}
    F.prototype = baseObject;
    return new F();
};

/**
 * Base object with the common functionality for transports based on requests.
 * The key responsibility is to allow at most 2 outstanding requests to the server,
 * to avoid that requests are sent behind a long poll.
 * To achieve this, we have one reserved request for the long poll, and all other
 * requests are serialized one after the other.
 */
org.cometd.RequestTransport = function()
{
    var _super = new org.cometd.Transport();
    var _self = org.cometd.Transport.derive(_super);
    var _requestIds = 0;
    var _metaConnectRequest = null;
    var _requests = [];
    var _envelopes = [];

    function _coalesceEnvelopes(envelope)
    {
        while (_envelopes.length > 0)
        {
            var envelopeAndRequest = _envelopes[0];
            var newEnvelope = envelopeAndRequest[0];
            var newRequest = envelopeAndRequest[1];
            if (newEnvelope.url === envelope.url &&
                    newEnvelope.sync === envelope.sync)
            {
                _envelopes.shift();
                envelope.messages = envelope.messages.concat(newEnvelope.messages);
                this._debug('Coalesced', newEnvelope.messages.length, 'messages from request', newRequest.id);
                continue;
            }
            break;
        }
    }

    function _transportSend(envelope, request)
    {
        this.transportSend(envelope, request);
        request.expired = false;

        if (!envelope.sync)
        {
            var maxDelay = this.getConfiguration().maxNetworkDelay;
            var delay = maxDelay;
            if (request.metaConnect === true)
            {
                delay += this.getAdvice().timeout;
            }

            this._debug('Transport', this.getType(), 'waiting at most', delay, 'ms for the response, maxNetworkDelay', maxDelay);

            var self = this;
            request.timeout = this.setTimeout(function()
            {
                request.expired = true;
                if (request.xhr)
                {
                    request.xhr.abort();
                }
                var errorMessage = 'Request ' + request.id + ' of transport ' + self.getType() + ' exceeded ' + delay + ' ms max network delay';
                self._debug(errorMessage);
                self.complete(request, false, request.metaConnect);
                envelope.onFailure(request.xhr, envelope.messages, 'timeout', errorMessage);
            }, delay);
        }
    }

    function _queueSend(envelope)
    {
        var requestId = ++_requestIds;
        var request = {
            id: requestId,
            metaConnect: false
        };

        // Consider the metaConnect requests which should always be present
        if (_requests.length < this.getConfiguration().maxConnections - 1)
        {
            _requests.push(request);
            _transportSend.call(this, envelope, request);
        }
        else
        {
            this._debug('Transport', this.getType(), 'queueing request', requestId, 'envelope', envelope);
            _envelopes.push([envelope, request]);
        }
    }

    function _metaConnectComplete(request)
    {
        var requestId = request.id;
        this._debug('Transport', this.getType(), 'metaConnect complete, request', requestId);
        if (_metaConnectRequest !== null && _metaConnectRequest.id !== requestId)
        {
            throw 'Longpoll request mismatch, completing request ' + requestId;
        }

        // Reset metaConnect request
        _metaConnectRequest = null;
    }

    function _complete(request, success)
    {
        var index = org.cometd.Utils.inArray(request, _requests);
        // The index can be negative if the request has been aborted
        if (index >= 0)
        {
            _requests.splice(index, 1);
        }

        if (_envelopes.length > 0)
        {
            var envelopeAndRequest = _envelopes.shift();
            var nextEnvelope = envelopeAndRequest[0];
            var nextRequest = envelopeAndRequest[1];
            this._debug('Transport dequeued request', nextRequest.id);
            if (success)
            {
                if (this.getConfiguration().autoBatch)
                {
                    _coalesceEnvelopes.call(this, nextEnvelope);
                }
                _queueSend.call(this, nextEnvelope);
                this._debug('Transport completed request', request.id, nextEnvelope);
            }
            else
            {
                // Keep the semantic of calling response callbacks asynchronously after the request
                var self = this;
                this.setTimeout(function()
                {
                    self.complete(nextRequest, false, nextRequest.metaConnect);
                    nextEnvelope.onFailure(nextRequest.xhr, nextEnvelope.messages, 'error', 'Previous request failed');
                }, 0);
            }
        }
    }

    _self.complete = function(request, success, metaConnect)
    {
        if (metaConnect)
        {
            _metaConnectComplete.call(this, request);
        }
        else
        {
            _complete.call(this, request, success);
        }
    };

    /**
     * Performs the actual send depending on the transport type details.
     * @param envelope the envelope to send
     * @param request the request information
     */
    _self.transportSend = function(envelope, request)
    {
        throw 'Abstract';
    };

    _self.transportSuccess = function(envelope, request, responses)
    {
        if (!request.expired)
        {
            clearTimeout(request.timeout);
            this.complete(request, true, request.metaConnect);
            if (responses && responses.length > 0)
            {
                envelope.onSuccess(responses);
            }
            else
            {
                envelope.onFailure(request.xhr, envelope.messages, 'Empty HTTP response');
            }
        }
    };

    _self.transportFailure = function(envelope, request, reason, exception)
    {
        if (!request.expired)
        {
            clearTimeout(request.timeout);
            this.complete(request, false, request.metaConnect);
            envelope.onFailure(request.xhr, envelope.messages, reason, exception);
        }
    };

    function _metaConnectSend(envelope)
    {
        if (_metaConnectRequest !== null)
        {
            throw 'Concurrent metaConnect requests not allowed, request id=' + _metaConnectRequest.id + ' not yet completed';
        }

        var requestId = ++_requestIds;
        this._debug('Transport', this.getType(), 'metaConnect send, request', requestId, 'envelope', envelope);
        var request = {
            id: requestId,
            metaConnect: true
        };
        _transportSend.call(this, envelope, request);
        _metaConnectRequest = request;
    }

    _self.send = function(envelope, metaConnect)
    {
        if (metaConnect)
        {
            _metaConnectSend.call(this, envelope);
        }
        else
        {
            _queueSend.call(this, envelope);
        }
    };

    _self.abort = function()
    {
        _super.abort();
        for (var i = 0; i < _requests.length; ++i)
        {
            var request = _requests[i];
            this._debug('Aborting request', request);
            if (request.xhr)
            {
                request.xhr.abort();
            }
        }
        if (_metaConnectRequest)
        {
            this._debug('Aborting metaConnect request', _metaConnectRequest);
            if (_metaConnectRequest.xhr)
            {
                _metaConnectRequest.xhr.abort();
            }
        }
        this.reset();
    };

    _self.reset = function()
    {
        _super.reset();
        _metaConnectRequest = null;
        _requests = [];
        _envelopes = [];
    };

    return _self;
};

org.cometd.LongPollingTransport = function()
{
    var _super = new org.cometd.RequestTransport();
    var _self = org.cometd.Transport.derive(_super);
    // By default, support cross domain
    var _supportsCrossDomain = true;

    _self.accept = function(version, crossDomain, url)
    {
        return _supportsCrossDomain || !crossDomain;
    };

    _self.xhrSend = function(packet)
    {
        throw 'Abstract';
    };

    _self.transportSend = function(envelope, request)
    {
        this._debug('Transport', this.getType(), 'sending request', request.id, 'envelope', envelope);

        var self = this;
        try
        {
            var sameStack = true;
            request.xhr = this.xhrSend({
                transport: this,
                url: envelope.url,
                sync: envelope.sync,
                headers: this.getConfiguration().requestHeaders,
                body: org.cometd.JSON.toJSON(envelope.messages),
                onSuccess: function(response)
                {
                    self._debug('Transport', self.getType(), 'received response', response);
                    var success = false;
                    try
                    {
                        var received = self.convertToMessages(response);
                        if (received.length === 0)
                        {
                            _supportsCrossDomain = false;
                            self.transportFailure(envelope, request, 'no response', null);
                        }
                        else
                        {
                            success = true;
                            self.transportSuccess(envelope, request, received);
                        }
                    }
                    catch(x)
                    {
                        self._debug(x);
                        if (!success)
                        {
                            _supportsCrossDomain = false;
                            self.transportFailure(envelope, request, 'bad response', x);
                        }
                    }
                },
                onError: function(reason, exception)
                {
                    _supportsCrossDomain = false;
                    if (sameStack)
                    {
                        // Keep the semantic of calling response callbacks asynchronously after the request
                        self.setTimeout(function()
                        {
                            self.transportFailure(envelope, request, reason, exception);
                        }, 0);
                    }
                    else
                    {
                        self.transportFailure(envelope, request, reason, exception);
                    }
                }
            });
            sameStack = false;
        }
        catch (x)
        {
            _supportsCrossDomain = false;
            // Keep the semantic of calling response callbacks asynchronously after the request
            this.setTimeout(function()
            {
                self.transportFailure(envelope, request, 'error', x);
            }, 0);
        }
    };

    _self.reset = function()
    {
        _super.reset();
        _supportsCrossDomain = true;
    };

    return _self;
};

org.cometd.CallbackPollingTransport = function()
{
    var _super = new org.cometd.RequestTransport();
    var _self = org.cometd.Transport.derive(_super);
    var _maxLength = 2000;

    _self.accept = function(version, crossDomain, url)
    {
        return true;
    };

    _self.jsonpSend = function(packet)
    {
        throw 'Abstract';
    };

    _self.transportSend = function(envelope, request)
    {
        var self = this;

        // Microsoft Internet Explorer has a 2083 URL max length
        // We must ensure that we stay within that length
        var start = 0;
        var length = envelope.messages.length;
        var lengths = [];
        while (length > 0)
        {
            // Encode the messages because all brackets, quotes, commas, colons, etc
            // present in the JSON will be URL encoded, taking many more characters
            var json = org.cometd.JSON.toJSON(envelope.messages.slice(start, start + length));
            var urlLength = envelope.url.length + encodeURI(json).length;

            // Let's stay on the safe side and use 2000 instead of 2083
            // also because we did not count few characters among which
            // the parameter name 'message' and the parameter 'jsonp',
            // which sum up to about 50 chars
            if (urlLength > _maxLength)
            {
                if (length == 1)
                {
                    var x = 'Bayeux message too big (' + urlLength + ' bytes, max is ' + _maxLength + ') ' +
                            'for transport ' + this.getType();
                    // Keep the semantic of calling response callbacks asynchronously after the request
                    this.setTimeout(function()
                    {
                        self.transportFailure(envelope, request, 'error', x);
                    }, 0);
                    return;
                }

                --length;
                continue;
            }

            lengths.push(length);
            start += length;
            length = envelope.messages.length - start;
        }

        // Here we are sure that the messages can be sent within the URL limit

        var envelopeToSend = envelope;
        if (lengths.length > 1)
        {
            var begin = 0;
            var end = lengths[0];
            this._debug('Transport', this.getType(), 'split', envelope.messages.length, 'messages into', lengths.join(' + '));
            envelopeToSend = this._mixin(false, {}, envelope);
            envelopeToSend.messages = envelope.messages.slice(begin, end);
            envelopeToSend.onSuccess = envelope.onSuccess;
            envelopeToSend.onFailure = envelope.onFailure;

            for (var i = 1; i < lengths.length; ++i)
            {
                var nextEnvelope = this._mixin(false, {}, envelope);
                begin = end;
                end += lengths[i];
                nextEnvelope.messages = envelope.messages.slice(begin, end);
                nextEnvelope.onSuccess = envelope.onSuccess;
                nextEnvelope.onFailure = envelope.onFailure;
                this.send(nextEnvelope, request.metaConnect);
            }
        }

        this._debug('Transport', this.getType(), 'sending request', request.id, 'envelope', envelopeToSend);

        try
        {
            var sameStack = true;
            this.jsonpSend({
                transport: this,
                url: envelopeToSend.url,
                sync: envelopeToSend.sync,
                headers: this.getConfiguration().requestHeaders,
                body: org.cometd.JSON.toJSON(envelopeToSend.messages),
                onSuccess: function(responses)
                {
                    var success = false;
                    try
                    {
                        var received = self.convertToMessages(responses);
                        if (received.length === 0)
                        {
                            self.transportFailure(envelopeToSend, request, 'no response');
                        }
                        else
                        {
                            success=true;
                            self.transportSuccess(envelopeToSend, request, received);
                        }
                    }
                    catch (x)
                    {
                        self._debug(x);
                        if (!success)
                        {
                            self.transportFailure(envelopeToSend, request, 'bad response', x);
                        }
                    }
                },
                onError: function(reason, exception)
                {
                    if (sameStack)
                    {
                        // Keep the semantic of calling response callbacks asynchronously after the request
                        self.setTimeout(function()
                        {
                            self.transportFailure(envelopeToSend, request, reason, exception);
                        }, 0);
                    }
                    else
                    {
                        self.transportFailure(envelopeToSend, request, reason, exception);
                    }
                }
            });
            sameStack = false;
        }
        catch (xx)
        {
            // Keep the semantic of calling response callbacks asynchronously after the request
            this.setTimeout(function()
            {
                self.transportFailure(envelopeToSend, request, 'error', xx);
            }, 0);
        }
    };

    return _self;
};

org.cometd.WebSocketTransport = function()
{
    var OPENED = 1;
    var CLOSED = 2;

    var _super = new org.cometd.Transport();
    var _self = org.cometd.Transport.derive(_super);
    var _cometd;
    // By default, support WebSocket
    var _supportsWebSocket = true;
    var _webSocketSupported = false;
    var _state = CLOSED;
    var _timeouts = {};
    var _envelopes = {};
    var _webSocket;
    var _successCallback;

    _self.registered = function(type, cometd)
    {
        _super.registered(type, cometd);
        _cometd = cometd;
    };

    _self.accept = function(version, crossDomain, url)
    {
        // Using !! to return a boolean (and not the WebSocket object)
        return _supportsWebSocket && !!window.WebSocket && _cometd.websocketEnabled === true;
    };

    function _websocketSend(envelope, metaConnect)
    {
        try
        {
            var json = org.cometd.JSON.toJSON(envelope.messages);
            _webSocket.send(json);
            this._debug('Transport', this.getType(), 'sent', envelope, 'metaConnect =', metaConnect);

            // Manage the timeout waiting for the response
            var maxDelay = this.getConfiguration().maxNetworkDelay;
            var delay = maxDelay;
            if (metaConnect)
            {
                delay += this.getAdvice().timeout;
            }

            var messageIds = [];
            for (var i = 0; i < envelope.messages.length; ++i)
            {
                var message = envelope.messages[i];
                if (message.id)
                {
                    messageIds.push(message.id);
                    var self = this;
                    _timeouts[message.id] = this.setTimeout(function()
                    {
                        var errorMessage = 'Message ' + message.id + ' of transport ' + self.getType() + ' exceeded ' + delay + ' ms max network delay';
                        self._debug(errorMessage);

                        delete _timeouts[message.id];

                        for (var ids in _envelopes)
                        {
                            if (_envelopes[ids] === envelope)
                            {
                                delete _envelopes[ids];
                                break;
                            }
                        }
                        envelope.onFailure(_webSocket, envelope.messages, 'timeout', errorMessage);
                    }, delay);
                }
            }

            this._debug('Transport', this.getType(), 'waiting at most', delay, ' ms for messages', messageIds, 'maxNetworkDelay', maxDelay, ', timeouts:', _timeouts);
        }
        catch (x)
        {
            // Keep the semantic of calling response callbacks asynchronously after the request
            this.setTimeout(function()
            {
                envelope.onFailure(_webSocket, envelope.messages, 'error', x);
            }, 0);
        }
    }

    _self.onMessage = function(wsMessage)
    {
        this._debug('Transport', this.getType(), 'received websocket message', wsMessage);

        if (_state === OPENED)
        {
            var messages = this.convertToMessages(wsMessage.data);
            var messageIds = [];
            for (var i = 0; i < messages.length; ++i)
            {
                var message = messages[i];

                // Detect if the message is a response to a request we made.
                // If it's a meta message, for sure it's a response;
                // otherwise it's a publish message and publish responses lack the data field
                if (/^\/meta\//.test(message.channel) || message.data === undefined)
                {
                    if (message.id)
                    {
                        messageIds.push(message.id);

                        var timeout = _timeouts[message.id];
                        if (timeout)
                        {
                            clearTimeout(timeout);
                            delete _timeouts[message.id];
                            this._debug('Transport', this.getType(), 'removed timeout for message', message.id, ', timeouts', _timeouts);
                        }
                    }
                }

                if ('/meta/disconnect' === message.channel && message.successful)
                {
                    _webSocket.close();
                }
            }

            // Remove the envelope corresponding to the messages
            var removed = false;
            for (var j = 0; j < messageIds.length; ++j)
            {
                var id = messageIds[j];
                for (var key in _envelopes)
                {
                    var ids = key.split(',');
                    var index = org.cometd.Utils.inArray(id, ids);
                    if (index >= 0)
                    {
                        removed = true;
                        ids.splice(index, 1);
                        var envelope = _envelopes[key];
                        delete _envelopes[key];
                        if (ids.length > 0)
                        {
                            _envelopes[ids.join(',')] = envelope;
                        }
                        break;
                    }
                }
            }
            if (removed)
            {
                this._debug('Transport', this.getType(), 'removed envelope, envelopes', _envelopes);
            }

            _successCallback.call(this, messages);
        }
    };

    _self.onClose = function()
    {
        this._debug('Transport', this.getType(), 'closed', _webSocket);

        // Remember if we were able to connect
        // This close event could be due to server shutdown, and if it restarts we want to try websocket again
        _supportsWebSocket = _webSocketSupported;

        for (var id in _timeouts)
        {
            clearTimeout(_timeouts[id]);
            delete _timeouts[id];
        }

        for (var ids in _envelopes)
        {
            _envelopes[ids].onFailure(_webSocket, _envelopes[ids].messages, 'closed');
            delete _envelopes[ids];
        }

        _state = CLOSED;
    };

    _self.send = function(envelope, metaConnect)
    {
        this._debug('Transport', this.getType(), 'sending', envelope, 'metaConnect =', metaConnect);

        // Store the envelope in any case; if the websocket cannot be opened, we fail it in close()
        var messageIds = [];
        for (var i = 0; i < envelope.messages.length; ++i)
        {
            var message = envelope.messages[i];
            if (message.id)
            {
                messageIds.push(message.id);
            }
        }
        _envelopes[messageIds.join(',')] = envelope;
        this._debug('Transport', this.getType(), 'stored envelope, envelopes', _envelopes);

        if (_state === OPENED)
        {
            _websocketSend.call(this, envelope, metaConnect);
        }
        else
        {
            // Mangle the URL, changing the scheme from 'http' to 'ws'
            var url = envelope.url.replace(/^http/, 'ws');
            this._debug('Transport', this.getType(), 'connecting to URL', url);

            _webSocket = new window.WebSocket(url);
            var self = this;
            _webSocket.onopen = function()
            {
                self._debug('WebSocket opened', _webSocket);
                _webSocketSupported = true;
                _state = OPENED;
                // Store the success callback, which is independent from the envelope,
                // so that it can be used to notify arrival of messages.
                _successCallback = envelope.onSuccess;
                _websocketSend.call(self, envelope, metaConnect);
            };
            _webSocket.onclose = function()
            {
                self.onClose();
            };
            _webSocket.onmessage = function(message)
            {
                self.onMessage(message);
            };
        }
    };

    _self.reset = function()
    {
        _super.reset();
        if (_webSocket)
        {
            _webSocket.close();
        }
        _supportsWebSocket = true;
        _webSocketSupported = false;
        _state = CLOSED;
        _timeouts = {};
        _envelopes = {};
        _webSocket = null;
        _successCallback = null;
    };

    return _self;
};

/**
 * The constructor for a Cometd object, identified by an optional name.
 * The default name is the string 'default'.
 * In the rare case a page needs more than one Bayeux conversation,
 * a new instance can be created via:
 * <pre>
 * var bayeuxUrl2 = ...;
 *
 * // Dojo style
 * var cometd2 = new dojox.Cometd('another_optional_name');
 *
 * // jQuery style
 * var cometd2 = new $.Cometd('another_optional_name');
 *
 * cometd2.init({url: bayeuxUrl2});
 * </pre>
 * @param name the optional name of this cometd object
 */
// IMPLEMENTATION NOTES:
// Be very careful in not changing the function order and pass this file every time through JSLint (http://jslint.com)
// The only implied globals must be "dojo", "org" and "window", and check that there are no "unused" warnings
// Failing to pass JSLint may result in shrinkers/minifiers to create an unusable file.
org.cometd.Cometd = function(name)
{
    var _cometd = this;
    var _name = name || 'default';
    var _crossDomain = false;
    var _transports = new org.cometd.TransportRegistry();
    var _transport;
    var _status = 'disconnected';
    var _messageId = 0;
    var _clientId = null;
    var _batch = 0;
    var _messageQueue = [];
    var _internalBatch = false;
    var _listeners = {};
    var _backoff = 0;
    var _scheduledSend = null;
    var _extensions = [];
    var _advice = {};
    var _handshakeProps;
    var _reestablish = false;
    var _connected = false;
    var _config = {
        maxConnections: 2,
        backoffIncrement: 1000,
        maxBackoff: 60000,
        logLevel: 'info',
        reverseIncomingExtensions: true,
        maxNetworkDelay: 10000,
        requestHeaders: {},
        appendMessageTypeToURL: true,
        autoBatch: false,
        advice: {
            timeout: 60000,
            interval: 0,
            reconnect: 'retry'
        }
    };

    /**
     * Mixes in the given objects into the target object by copying the properties.
     * @param deep if the copy must be deep
     * @param target the target object
     * @param objects the objects whose properties are copied into the target
     */
    function _mixin(deep, target, objects)
    {
        var result = target || {};

        // Skip first 2 parameters (deep and target), and loop over the others
        for (var i = 2; i < arguments.length; ++i)
        {
            var object = arguments[i];

            if (object === undefined || object === null)
            {
                continue;
            }

            for (var propName in object)
            {
                var prop = object[propName];

                // Avoid infinite loops
                if (prop === target)
                {
                    continue;
                }
                // Do not mixin undefined values
                if (prop === undefined)
                {
                    continue;
                }

                if (deep && typeof prop === 'object' && prop !== null)
                {
                    if (prop instanceof Array)
                    {
                        result[propName] = _mixin(deep, [], prop);
                    }
                    else
                    {
                        result[propName] = _mixin(deep, {}, prop);
                    }
                }
                else
                {
                    result[propName] = prop;
                }
            }
        }

        return result;
    }

    /**
     * This method is exposed as facility for extensions that may need to clone messages.
     */
    this._mixin = _mixin;

    function _isString(value)
    {
        return org.cometd.Utils.isString(value);
    }

    function _isFunction(value)
    {
        if (value === undefined || value === null)
        {
            return false;
        }
        return typeof value === 'function';
    }

    function _log(level, args)
    {
        if (window.console)
        {
            var logger = window.console[level];
            if (_isFunction(logger))
            {
                logger.apply(window.console, args);
            }
        }
    }

    function _warn()
    {
        _log('warn', arguments);
    }
    this._warn = _warn;

    function _info()
    {
        if (_config.logLevel != 'warn')
        {
            _log('info', arguments);
        }
    }
    this._info = _info;

    function _debug()
    {
        if (_config.logLevel == 'debug')
        {
            _log('debug', arguments);
        }
    }
    this._debug = _debug;

    function _configure(configuration)
    {
        _debug('Configuring cometd object with', configuration);
        // Support old style param, where only the Bayeux server URL was passed
        if (_isString(configuration))
        {
            configuration = { url: configuration };
        }
        if (!configuration)
        {
            configuration = {};
        }

        _config = _mixin(false, _config, configuration);

        if (!_config.url)
        {
            throw 'Missing required configuration parameter \'url\' specifying the Bayeux server URL';
        }

        // Check if we're cross domain
        // [1] = protocol:, [2] = //host:port, [3] = host:port, [4] = host, [5] = :port, [6] = port, [7] = uri, [8] = rest
        var urlParts = /(^https?:)?(\/\/(([^:\/\?#]+)(:(\d+))?))?([^\?#]*)(.*)?/.exec(_config.url);
        _crossDomain = urlParts[3] && urlParts[3] != window.location.host;

        // Check if appending extra path is supported
        if (_config.appendMessageTypeToURL)
        {
            if (urlParts[8] !== undefined && urlParts[8].length > 0)
            {
                _info('Appending message type to URI ' + urlParts[7] + urlParts[8] + ' is not supported, disabling \'appendMessageTypeToURL\' configuration');
                _config.appendMessageTypeToURL = false;
            }
            else
            {
                var uriSegments = urlParts[7].split('/');
                var lastSegmentIndex = uriSegments.length - 1;
                if (urlParts[7].match(/\/$/))
                {
                    lastSegmentIndex -= 1;
                }
                if (uriSegments[lastSegmentIndex].indexOf('.') >= 0)
                {
                    // Very likely the CometD servlet's URL pattern is mapped to an extension, such as *.cometd
                    // It will be difficult to add the extra path in this case
                    _info('Appending message type to URI ' + urlParts[7] + ' is not supported, disabling \'appendMessageTypeToURL\' configuration');
                    _config.appendMessageTypeToURL = false;
                }
            }
        }
    }

    function _clearSubscriptions()
    {
        for (var channel in _listeners)
        {
            var subscriptions = _listeners[channel];
            for (var i = 0; i < subscriptions.length; ++i)
            {
                var subscription = subscriptions[i];
                if (subscription && !subscription.listener)
                {
                    delete subscriptions[i];
                    _debug('Removed subscription', subscription, 'for channel', channel);
                }
            }
        }
    }

    function _setStatus(newStatus)
    {
        if (_status != newStatus)
        {
            _debug('Status', _status, '->', newStatus);
            _status = newStatus;
        }
    }

    function _isDisconnected()
    {
        return _status == 'disconnecting' || _status == 'disconnected';
    }

    function _nextMessageId()
    {
        return ++_messageId;
    }

    function _applyExtension(scope, callback, name, message, outgoing)
    {
        try
        {
            return callback.call(scope, message);
        }
        catch (x)
        {
            _debug('Exception during execution of extension', name, x);
            var exceptionCallback = _cometd.onExtensionException;
            if (_isFunction(exceptionCallback))
            {
                _debug('Invoking extension exception callback', name, x);
                try
                {
                    exceptionCallback.call(_cometd, x, name, outgoing, message);
                }
                catch(xx)
                {
                    _info('Exception during execution of exception callback in extension', name, xx);
                }
            }
            return message;
        }
    }

    function _applyIncomingExtensions(message)
    {
        for (var i = 0; i < _extensions.length; ++i)
        {
            if (message === undefined || message === null)
            {
                break;
            }

            var index = _config.reverseIncomingExtensions ? _extensions.length - 1 - i : i;
            var extension = _extensions[index];
            var callback = extension.extension.incoming;
            if (_isFunction(callback))
            {
                var result = _applyExtension(extension.extension, callback, extension.name, message, false);
                message = result === undefined ? message : result;
            }
        }
        return message;
    }

    function _applyOutgoingExtensions(message)
    {
        for (var i = 0; i < _extensions.length; ++i)
        {
            if (message === undefined || message === null)
            {
                break;
            }

            var extension = _extensions[i];
            var callback = extension.extension.outgoing;
            if (_isFunction(callback))
            {
                var result = _applyExtension(extension.extension, callback, extension.name, message, true);
                message = result === undefined ? message : result;
            }
        }
        return message;
    }

    function _notify(channel, message)
    {
        var subscriptions = _listeners[channel];
        if (subscriptions && subscriptions.length > 0)
        {
            for (var i = 0; i < subscriptions.length; ++i)
            {
                var subscription = subscriptions[i];
                // Subscriptions may come and go, so the array may have 'holes'
                if (subscription)
                {
                    try
                    {
                        subscription.callback.call(subscription.scope, message);
                    }
                    catch (x)
                    {
                        _debug('Exception during notification', subscription, message, x);
                        var listenerCallback = _cometd.onListenerException;
                        if (_isFunction(listenerCallback))
                        {
                            _debug('Invoking listener exception callback', subscription, x);
                            try
                            {
                                listenerCallback.call(_cometd, x, subscription.handle, subscription.listener, message);
                            }
                            catch (xx)
                            {
                                _info('Exception during execution of listener callback', subscription, xx);
                            }
                        }
                    }
                }
            }
        }
    }

    function _notifyListeners(channel, message)
    {
        // Notify direct listeners
        _notify(channel, message);

        // Notify the globbing listeners
        var channelParts = channel.split('/');
        var last = channelParts.length - 1;
        for (var i = last; i > 0; --i)
        {
            var channelPart = channelParts.slice(0, i).join('/') + '/*';
            // We don't want to notify /foo/* if the channel is /foo/bar/baz,
            // so we stop at the first non recursive globbing
            if (i == last)
            {
                _notify(channelPart, message);
            }
            // Add the recursive globber and notify
            channelPart += '*';
            _notify(channelPart, message);
        }
    }

    function _cancelDelayedSend()
    {
        if (_scheduledSend !== null)
        {
            clearTimeout(_scheduledSend);
        }
        _scheduledSend = null;
    }

    function _delayedSend(operation)
    {
        _cancelDelayedSend();
        var delay = _advice.interval + _backoff;
        _debug('Function scheduled in', delay, 'ms, interval =', _advice.interval, 'backoff =', _backoff, operation);
        _scheduledSend = org.cometd.Utils.setTimeout(_cometd, operation, delay);
    }

    // Needed to break cyclic dependencies between function definitions
    var _handleMessages;
    var _handleFailure;

    /**
     * Delivers the messages to the CometD server
     * @param messages the array of messages to send
     * @param longpoll true if this send is a long poll
     */
    function _send(sync, messages, longpoll, extraPath)
    {
        // We must be sure that the messages have a clientId.
        // This is not guaranteed since the handshake may take time to return
        // (and hence the clientId is not known yet) and the application
        // may create other messages.
        for (var i = 0; i < messages.length; ++i)
        {
            var message = messages[i];
            message.id = '' + _nextMessageId();
            if (_clientId)
            {
                message.clientId = _clientId;
            }
            message = _applyOutgoingExtensions(message);
            if (message !== undefined && message !== null)
            {
                messages[i] = message;
            }
            else
            {
                messages.splice(i--, 1);
            }
        }
        if (messages.length === 0)
        {
            return;
        }

        var url = _config.url;
        if (_config.appendMessageTypeToURL)
        {
            // If url does not end with '/', then append it
            if (!url.match(/\/$/))
            {
                url = url + '/';
            }
            if (extraPath)
            {
                url = url + extraPath;
            }
        }

        var envelope = {
            url: url,
            sync: sync,
            messages: messages,
            onSuccess: function(rcvdMessages)
            {
                try
                {
                    _handleMessages.call(_cometd, rcvdMessages);
                }
                catch (x)
                {
                    _debug('Exception during handling of messages', x);
                }
            },
            onFailure: function(conduit, messages, reason, exception)
            {
                try
                {
                    _handleFailure.call(_cometd, conduit, messages, reason, exception);
                }
                catch (x)
                {
                    _debug('Exception during handling of failure', x);
                }
            }
        };
        _debug('Send', envelope);
        _transport.send(envelope, longpoll);
    }

    function _queueSend(message)
    {
        if (_batch > 0 || _internalBatch === true)
        {
            _messageQueue.push(message);
        }
        else
        {
            _send(false, [message], false);
        }
    }

    /**
     * Sends a complete bayeux message.
     * This method is exposed as a public so that extensions may use it
     * to send bayeux message directly, for example in case of re-sending
     * messages that have already been sent but that for some reason must
     * be resent.
     */
    this.send = _queueSend;

    function _resetBackoff()
    {
        _backoff = 0;
    }

    function _increaseBackoff()
    {
        if (_backoff < _config.maxBackoff)
        {
            _backoff += _config.backoffIncrement;
        }
    }

    /**
     * Starts a the batch of messages to be sent in a single request.
     * @see #_endBatch(sendMessages)
     */
    function _startBatch()
    {
        ++_batch;
    }

    function _flushBatch()
    {
        var messages = _messageQueue;
        _messageQueue = [];
        if (messages.length > 0)
        {
            _send(false, messages, false);
        }
    }

    /**
     * Ends the batch of messages to be sent in a single request,
     * optionally sending messages present in the message queue depending
     * on the given argument.
     * @see #_startBatch()
     */
    function _endBatch()
    {
        --_batch;
        if (_batch < 0)
        {
            throw 'Calls to startBatch() and endBatch() are not paired';
        }

        if (_batch === 0 && !_isDisconnected() && !_internalBatch)
        {
            _flushBatch();
        }
    }

    /**
     * Sends the connect message
     */
    function _connect()
    {
        if (!_isDisconnected())
        {
            var message = {
                channel: '/meta/connect',
                connectionType: _transport.getType()
            };

            // In case of reload or temporary loss of connection
            // we want the next successful connect to return immediately
            // instead of being held by the server, so that connect listeners
            // can be notified that the connection has been re-established
            if (!_connected)
            {
                message.advice = { timeout: 0 };
            }

            _setStatus('connecting');
            _debug('Connect sent', message);
            _send(false, [message], true, 'connect');
            _setStatus('connected');
        }
    }

    function _delayedConnect()
    {
        _setStatus('connecting');
        _delayedSend(function()
        {
            _connect();
        });
    }

    function _updateAdvice(newAdvice)
    {
        if (newAdvice)
        {
            _advice = _mixin(false, {}, _config.advice, newAdvice);
            _debug('New advice', _advice);
        }
    }

    function _disconnect(abort)
    {
        _cancelDelayedSend();
        if (abort)
        {
            _transport.abort();
        }
        _clientId = null;
        _setStatus('disconnected');
        _batch = 0;
        _resetBackoff();

        // Fail any existing queued message
        if (_messageQueue.length > 0)
        {
            _handleFailure.call(_cometd, undefined, _messageQueue, 'error', 'Disconnected');
            _messageQueue = [];
        }
    }

    /**
     * Sends the initial handshake message
     */
    function _handshake(handshakeProps)
    {
        _clientId = null;

        _clearSubscriptions();

        // Reset the transports if we're not retrying the handshake
        if (_isDisconnected())
        {
            _transports.reset();
            _updateAdvice(_config.advice);
        }
        else
        {
            // We are retrying the handshake, either because another handshake failed
            // and we're backing off, or because the server timed us out and asks us to
            // re-handshake: in both cases, make sure that if the handshake succeeds
            // the next action is a connect.
            _updateAdvice(_mixin(false, _advice, {reconnect: 'retry'}));
        }

        _batch = 0;

        // Mark the start of an internal batch.
        // This is needed because handshake and connect are async.
        // It may happen that the application calls init() then subscribe()
        // and the subscribe message is sent before the connect message, if
        // the subscribe message is not held until the connect message is sent.
        // So here we start a batch to hold temporarily any message until
        // the connection is fully established.
        _internalBatch = true;

        // Save the properties provided by the user, so that
        // we can reuse them during automatic re-handshake
        _handshakeProps = handshakeProps;

        var version = '1.0';

        // Figure out the transports to send to the server
        var transportTypes = _transports.findTransportTypes(version, _crossDomain, _config.url);

        var bayeuxMessage = {
            version: version,
            minimumVersion: '0.9',
            channel: '/meta/handshake',
            supportedConnectionTypes: transportTypes,
            advice: {
                timeout: _advice.timeout,
                interval: _advice.interval
            }
        };
        // Do not allow the user to mess with the required properties,
        // so merge first the user properties and *then* the bayeux message
        var message = _mixin(false, {}, _handshakeProps, bayeuxMessage);

        // Pick up the first available transport as initial transport
        // since we don't know if the server supports it
        _transport = _transports.negotiateTransport(transportTypes, version, _crossDomain, _config.url);
        _debug('Initial transport is', _transport.getType());

        // We started a batch to hold the application messages,
        // so here we must bypass it and send immediately.
        _setStatus('handshaking');
        _debug('Handshake sent', message);
        _send(false, [message], false, 'handshake');
    }

    function _delayedHandshake()
    {
        _setStatus('handshaking');

        // We will call _handshake() which will reset _clientId, but we want to avoid
        // that between the end of this method and the call to _handshake() someone may
        // call publish() (or other methods that call _queueSend()).
        _internalBatch = true;

        _delayedSend(function()
        {
            _handshake(_handshakeProps);
        });
    }

    function _failHandshake(message)
    {
        _notifyListeners('/meta/handshake', message);
        _notifyListeners('/meta/unsuccessful', message);

        // Only try again if we haven't been disconnected and
        // the advice permits us to retry the handshake
        var retry = !_isDisconnected() && _advice.reconnect != 'none';
        if (retry)
        {
            _increaseBackoff();
            _delayedHandshake();
        }
        else
        {
            _disconnect(false);
        }
    }

    function _handshakeResponse(message)
    {
        if (message.successful)
        {
            // Save clientId, figure out transport, then follow the advice to connect
            _clientId = message.clientId;

            var newTransport = _transports.negotiateTransport(message.supportedConnectionTypes, message.version, _crossDomain, _config.url);
            if (newTransport === null)
            {
                throw 'Could not negotiate transport with server; client ' +
                      _transports.findTransportTypes(message.version, _crossDomain, _config.url) +
                      ', server ' + message.supportedConnectionTypes;
            }
            else if (_transport != newTransport)
            {
                _debug('Transport', _transport, '->', newTransport);
                _transport = newTransport;
            }

            // End the internal batch and allow held messages from the application
            // to go to the server (see _handshake() where we start the internal batch).
            _internalBatch = false;
            _flushBatch();

            // Here the new transport is in place, as well as the clientId, so
            // the listeners can perform a publish() if they want.
            // Notify the listeners before the connect below.
            message.reestablish = _reestablish;
            _reestablish = true;
            _notifyListeners('/meta/handshake', message);

            var action = _isDisconnected() ? 'none' : _advice.reconnect;
            switch (action)
            {
                case 'retry':
                    _resetBackoff();
                    _delayedConnect();
                    break;
                case 'none':
                    _disconnect(false);
                    break;
                default:
                    throw 'Unrecognized advice action ' + action;
            }
        }
        else
        {
            _failHandshake(message);
        }
    }

    function _handshakeFailure(xhr, message)
    {
        _failHandshake({
            successful: false,
            failure: true,
            channel: '/meta/handshake',
            request: message,
            xhr: xhr,
            advice: {
                reconnect: 'retry',
                interval: _backoff
            }
        });
    }

    function _failConnect(message)
    {
        // Notify the listeners after the status change but before the next action
        _notifyListeners('/meta/connect', message);
        _notifyListeners('/meta/unsuccessful', message);

        // This may happen when the server crashed, the current clientId
        // will be invalid, and the server will ask to handshake again
        // Listeners can call disconnect(), so check the state after they run
        var action = _isDisconnected() ? 'none' : _advice.reconnect;
        switch (action)
        {
            case 'retry':
                _increaseBackoff();
                _delayedConnect();
                break;
            case 'handshake':
                // The current transport may be failed (e.g. network disconnection)
                // Reset the transports so the new handshake picks up the right one
                _transports.reset();
                _resetBackoff();
                _delayedHandshake();
                break;
            case 'none':
                _disconnect(false);
                break;
            default:
                throw 'Unrecognized advice action' + action;
        }
    }

    function _connectResponse(message)
    {
        _connected = message.successful;

        if (_connected)
        {
            _notifyListeners('/meta/connect', message);

            // Normally, the advice will say "reconnect: 'retry', interval: 0"
            // and the server will hold the request, so when a response returns
            // we immediately call the server again (long polling)
            // Listeners can call disconnect(), so check the state after they run
            var action = _isDisconnected() ? 'none' : _advice.reconnect;
            switch (action)
            {
                case 'retry':
                    _resetBackoff();
                    _delayedConnect();
                    break;
                case 'none':
                    _disconnect(false);
                    break;
                default:
                    throw 'Unrecognized advice action ' + action;
            }
        }
        else
        {
            _failConnect(message);
        }
    }

    function _connectFailure(xhr, message)
    {
        _connected = false;
        _failConnect({
            successful: false,
            failure: true,
            channel: '/meta/connect',
            request: message,
            xhr: xhr,
            advice: {
                reconnect: 'retry',
                interval: _backoff
            }
        });
    }

    function _failDisconnect(message)
    {
        _disconnect(true);
        _notifyListeners('/meta/disconnect', message);
        _notifyListeners('/meta/unsuccessful', message);
    }

    function _disconnectResponse(message)
    {
        if (message.successful)
        {
            _disconnect(false);
            _notifyListeners('/meta/disconnect', message);
        }
        else
        {
            _failDisconnect(message);
        }
    }

    function _disconnectFailure(xhr, message)
    {
        _failDisconnect({
            successful: false,
            failure: true,
            channel: '/meta/disconnect',
            request: message,
            xhr: xhr,
            advice: {
                reconnect: 'none',
                interval: 0
            }
        });
    }

    function _failSubscribe(message)
    {
        _notifyListeners('/meta/subscribe', message);
        _notifyListeners('/meta/unsuccessful', message);
    }

    function _subscribeResponse(message)
    {
        if (message.successful)
        {
            _notifyListeners('/meta/subscribe', message);
        }
        else
        {
            _failSubscribe(message);
        }
    }

    function _subscribeFailure(xhr, message)
    {
        _failSubscribe({
            successful: false,
            failure: true,
            channel: '/meta/subscribe',
            request: message,
            xhr: xhr,
            advice: {
                reconnect: 'none',
                interval: 0
            }
        });
    }

    function _failUnsubscribe(message)
    {
        _notifyListeners('/meta/unsubscribe', message);
        _notifyListeners('/meta/unsuccessful', message);
    }

    function _unsubscribeResponse(message)
    {
        if (message.successful)
        {
            _notifyListeners('/meta/unsubscribe', message);
        }
        else
        {
            _failUnsubscribe(message);
        }
    }

    function _unsubscribeFailure(xhr, message)
    {
        _failUnsubscribe({
            successful: false,
            failure: true,
            channel: '/meta/unsubscribe',
            request: message,
            xhr: xhr,
            advice: {
                reconnect: 'none',
                interval: 0
            }
        });
    }

    function _failMessage(message)
    {
        _notifyListeners('/meta/publish', message);
        _notifyListeners('/meta/unsuccessful', message);
    }

    function _messageResponse(message)
    {
        if (message.successful === undefined)
        {
            if (message.data)
            {
                // It is a plain message, and not a bayeux meta message
                _notifyListeners(message.channel, message);
            }
            else
            {
                _debug('Unknown message', message);
            }
        }
        else
        {
            if (message.successful)
            {
                _notifyListeners('/meta/publish', message);
            }
            else
            {
                _failMessage(message);
            }
        }
    }

    function _messageFailure(xhr, message)
    {
        _failMessage({
            successful: false,
            failure: true,
            channel: message.channel,
            request: message,
            xhr: xhr,
            advice: {
                reconnect: 'none',
                interval: 0
            }
        });
    }

    function _receive(message)
    {
        message = _applyIncomingExtensions(message);
        if (message === undefined || message === null)
        {
            return;
        }

        _updateAdvice(message.advice);

        var channel = message.channel;
        switch (channel)
        {
            case '/meta/handshake':
                _handshakeResponse(message);
                break;
            case '/meta/connect':
                _connectResponse(message);
                break;
            case '/meta/disconnect':
                _disconnectResponse(message);
                break;
            case '/meta/subscribe':
                _subscribeResponse(message);
                break;
            case '/meta/unsubscribe':
                _unsubscribeResponse(message);
                break;
            default:
                _messageResponse(message);
                break;
        }
    }

    /**
     * Receives a message.
     * This method is exposed as a public so that extensions may inject
     * messages simulating that they had been received.
     */
    this.receive = _receive;

    _handleMessages = function _handleMessages(rcvdMessages)
    {
        _debug('Received', rcvdMessages);

        for (var i = 0; i < rcvdMessages.length; ++i)
        {
            var message = rcvdMessages[i];
            _receive(message);
        }
    };

    _handleFailure = function _handleFailure(conduit, messages, reason, exception)
    {
        _debug('handleFailure', conduit, messages, reason, exception);

        for (var i = 0; i < messages.length; ++i)
        {
            var message = messages[i];
            var channel = message.channel;
            switch (channel)
            {
                case '/meta/handshake':
                    _handshakeFailure(conduit, message);
                    break;
                case '/meta/connect':
                    _connectFailure(conduit, message);
                    break;
                case '/meta/disconnect':
                    _disconnectFailure(conduit, message);
                    break;
                case '/meta/subscribe':
                    _subscribeFailure(conduit, message);
                    break;
                case '/meta/unsubscribe':
                    _unsubscribeFailure(conduit, message);
                    break;
                default:
                    _messageFailure(conduit, message);
                    break;
            }
        }
    };

    function _hasSubscriptions(channel)
    {
        var subscriptions = _listeners[channel];
        if (subscriptions)
        {
            for (var i = 0; i < subscriptions.length; ++i)
            {
                if (subscriptions[i])
                {
                    return true;
                }
            }
        }
        return false;
    }

    function _resolveScopedCallback(scope, callback)
    {
        var delegate = {
            scope: scope,
            method: callback
        };
        if (_isFunction(scope))
        {
            delegate.scope = undefined;
            delegate.method = scope;
        }
        else
        {
            if (_isString(callback))
            {
                if (!scope)
                {
                    throw 'Invalid scope ' + scope;
                }
                delegate.method = scope[callback];
                if (!_isFunction(delegate.method))
                {
                    throw 'Invalid callback ' + callback + ' for scope ' + scope;
                }
            }
            else if (!_isFunction(callback))
            {
                throw 'Invalid callback ' + callback;
            }
        }
        return delegate;
    }

    function _addListener(channel, scope, callback, isListener)
    {
        // The data structure is a map<channel, subscription[]>, where each subscription
        // holds the callback to be called and its scope.

        var delegate = _resolveScopedCallback(scope, callback);
        _debug('Adding listener on', channel, 'with scope', delegate.scope, 'and callback', delegate.method);

        var subscription = {
            channel: channel,
            scope: delegate.scope,
            callback: delegate.method,
            listener: isListener
        };

        var subscriptions = _listeners[channel];
        if (!subscriptions)
        {
            subscriptions = [];
            _listeners[channel] = subscriptions;
        }

        // Pushing onto an array appends at the end and returns the id associated with the element increased by 1.
        // Note that if:
        // a.push('a'); var hb=a.push('b'); delete a[hb-1]; var hc=a.push('c');
        // then:
        // hc==3, a.join()=='a',,'c', a.length==3
        var subscriptionID = subscriptions.push(subscription) - 1;
        subscription.id = subscriptionID;
        subscription.handle = [channel, subscriptionID];

        _debug('Added listener', subscription, 'for channel', channel, 'having id =', subscriptionID);

        // The subscription to allow removal of the listener is made of the channel and the index
        return subscription.handle;
    }

    function _removeListener(subscription)
    {
        var subscriptions = _listeners[subscription[0]];
        if (subscriptions)
        {
            delete subscriptions[subscription[1]];
            _debug('Removed listener', subscription);
        }
    }

    //
    // PUBLIC API
    //

    /**
     * Registers the given transport under the given transport type.
     * The optional index parameter specifies the "priority" at which the
     * transport is registered (where 0 is the max priority).
     * If a transport with the same type is already registered, this function
     * does nothing and returns false.
     * @param type the transport type
     * @param transport the transport object
     * @param index the index at which this transport is to be registered
     * @return true if the transport has been registered, false otherwise
     * @see #unregisterTransport(type)
     */
    this.registerTransport = function(type, transport, index)
    {
        var result = _transports.add(type, transport, index);
        if (result)
        {
            _debug('Registered transport', type);

            if (_isFunction(transport.registered))
            {
                transport.registered(type, this);
            }
        }
        return result;
    };

    /**
     * @return an array of all registered transport types
     */
    this.getTransportTypes = function()
    {
        return _transports.getTransportTypes();
    };

    /**
     * Unregisters the transport with the given transport type.
     * @param type the transport type to unregister
     * @return the transport that has been unregistered,
     * or null if no transport was previously registered under the given transport type
     */
    this.unregisterTransport = function(type)
    {
        var transport = _transports.remove(type);
        if (transport !== null)
        {
            _debug('Unregistered transport', type);

            if (_isFunction(transport.unregistered))
            {
                transport.unregistered();
            }
        }
        return transport;
    };

    this.findTransport = function(name)
    {
        return _transports.find(name);
    };

    /**
     * Configures the initial Bayeux communication with the Bayeux server.
     * Configuration is passed via an object that must contain a mandatory field <code>url</code>
     * of type string containing the URL of the Bayeux server.
     * @param configuration the configuration object
     */
    this.configure = function(configuration)
    {
        _configure.call(this, configuration);
    };

    /**
     * Configures and establishes the Bayeux communication with the Bayeux server
     * via a handshake and a subsequent connect.
     * @param configuration the configuration object
     * @param handshakeProps an object to be merged with the handshake message
     * @see #configure(configuration)
     * @see #handshake(handshakeProps)
     */
    this.init = function(configuration, handshakeProps)
    {
        this.configure(configuration);
        this.handshake(handshakeProps);
    };

    /**
     * Establishes the Bayeux communication with the Bayeux server
     * via a handshake and a subsequent connect.
     * @param handshakeProps an object to be merged with the handshake message
     */
    this.handshake = function(handshakeProps)
    {
        _setStatus('disconnected');
        _reestablish = false;
        _handshake(handshakeProps);
    };

    /**
     * Disconnects from the Bayeux server.
     * It is possible to suggest to attempt a synchronous disconnect, but this feature
     * may only be available in certain transports (for example, long-polling may support
     * it, callback-polling certainly does not).
     * @param sync whether attempt to perform a synchronous disconnect
     * @param disconnectProps an object to be merged with the disconnect message
     */
    this.disconnect = function(sync, disconnectProps)
    {
        if (_isDisconnected())
        {
            return;
        }

        if (disconnectProps === undefined)
        {
            if (typeof sync !== 'boolean')
            {
                disconnectProps = sync;
                sync = false;
            }
        }

        var bayeuxMessage = {
            channel: '/meta/disconnect'
        };
        var message = _mixin(false, {}, disconnectProps, bayeuxMessage);
        _setStatus('disconnecting');
        _send(sync === true, [message], false, 'disconnect');
    };

    /**
     * Marks the start of a batch of application messages to be sent to the server
     * in a single request, obtaining a single response containing (possibly) many
     * application reply messages.
     * Messages are held in a queue and not sent until {@link #endBatch()} is called.
     * If startBatch() is called multiple times, then an equal number of endBatch()
     * calls must be made to close and send the batch of messages.
     * @see #endBatch()
     */
    this.startBatch = function()
    {
        _startBatch();
    };

    /**
     * Marks the end of a batch of application messages to be sent to the server
     * in a single request.
     * @see #startBatch()
     */
    this.endBatch = function()
    {
        _endBatch();
    };

    /**
     * Executes the given callback in the given scope, surrounded by a {@link #startBatch()}
     * and {@link #endBatch()} calls.
     * @param scope the scope of the callback, may be omitted
     * @param callback the callback to be executed within {@link #startBatch()} and {@link #endBatch()} calls
     */
    this.batch = function(scope, callback)
    {
        var delegate = _resolveScopedCallback(scope, callback);
        this.startBatch();
        try
        {
            delegate.method.call(delegate.scope);
            this.endBatch();
        }
        catch (x)
        {
            _debug('Exception during execution of batch', x);
            this.endBatch();
            throw x;
        }
    };

    /**
     * Adds a listener for bayeux messages, performing the given callback in the given scope
     * when a message for the given channel arrives.
     * @param channel the channel the listener is interested to
     * @param scope the scope of the callback, may be omitted
     * @param callback the callback to call when a message is sent to the channel
     * @returns the subscription handle to be passed to {@link #removeListener(object)}
     * @see #removeListener(subscription)
     */
    this.addListener = function(channel, scope, callback)
    {
        if (arguments.length < 2)
        {
            throw 'Illegal arguments number: required 2, got ' + arguments.length;
        }
        if (!_isString(channel))
        {
            throw 'Illegal argument type: channel must be a string';
        }

        return _addListener(channel, scope, callback, true);
    };

    /**
     * Removes the subscription obtained with a call to {@link #addListener(string, object, function)}.
     * @param subscription the subscription to unsubscribe.
     * @see #addListener(channel, scope, callback)
     */
    this.removeListener = function(subscription)
    {
        if (!org.cometd.Utils.isArray(subscription))
        {
            throw 'Invalid argument: expected subscription, not ' + subscription;
        }

        _removeListener(subscription);
    };

    /**
     * Removes all listeners registered with {@link #addListener(channel, scope, callback)} or
     * {@link #subscribe(channel, scope, callback)}.
     */
    this.clearListeners = function()
    {
        _listeners = {};
    };

    /**
     * Subscribes to the given channel, performing the given callback in the given scope
     * when a message for the channel arrives.
     * @param channel the channel to subscribe to
     * @param scope the scope of the callback, may be omitted
     * @param callback the callback to call when a message is sent to the channel
     * @param subscribeProps an object to be merged with the subscribe message
     * @return the subscription handle to be passed to {@link #unsubscribe(object)}
     */
    this.subscribe = function(channel, scope, callback, subscribeProps)
    {
        if (arguments.length < 2)
        {
            throw 'Illegal arguments number: required 2, got ' + arguments.length;
        }
        if (!_isString(channel))
        {
            throw 'Illegal argument type: channel must be a string';
        }
        if (_isDisconnected())
        {
            throw 'Illegal state: already disconnected';
        }

        // Normalize arguments
        if (_isFunction(scope))
        {
            subscribeProps = callback;
            callback = scope;
            scope = undefined;
        }

        // Only send the message to the server if this clientId has not yet subscribed to the channel
        var send = !_hasSubscriptions(channel);

        var subscription = _addListener(channel, scope, callback, false);

        if (send)
        {
            // Send the subscription message after the subscription registration to avoid
            // races where the server would send a message to the subscribers, but here
            // on the client the subscription has not been added yet to the data structures
            var bayeuxMessage = {
                channel: '/meta/subscribe',
                subscription: channel
            };
            var message = _mixin(false, {}, subscribeProps, bayeuxMessage);
            _queueSend(message);
        }

        return subscription;
    };

    /**
     * Unsubscribes the subscription obtained with a call to {@link #subscribe(string, object, function)}.
     * @param subscription the subscription to unsubscribe.
     */
    this.unsubscribe = function(subscription, unsubscribeProps)
    {
        if (arguments.length < 1)
        {
            throw 'Illegal arguments number: required 1, got ' + arguments.length;
        }
        if (_isDisconnected())
        {
            throw 'Illegal state: already disconnected';
        }

        // Remove the local listener before sending the message
        // This ensures that if the server fails, this client does not get notifications
        this.removeListener(subscription);

        var channel = subscription[0];
        // Only send the message to the server if this clientId unsubscribes the last subscription
        if (!_hasSubscriptions(channel))
        {
            var bayeuxMessage = {
                channel: '/meta/unsubscribe',
                subscription: channel
            };
            var message = _mixin(false, {}, unsubscribeProps, bayeuxMessage);
            _queueSend(message);
        }
    };

    /**
     * Removes all subscriptions added via {@link #subscribe(channel, scope, callback, subscribeProps)},
     * but does not remove the listeners added via {@link addListener(channel, scope, callback)}.
     */
    this.clearSubscriptions = function()
    {
        _clearSubscriptions();
    };

    /**
     * Publishes a message on the given channel, containing the given content.
     * @param channel the channel to publish the message to
     * @param content the content of the message
     * @param publishProps an object to be merged with the publish message
     */
    this.publish = function(channel, content, publishProps)
    {
        if (arguments.length < 1)
        {
            throw 'Illegal arguments number: required 1, got ' + arguments.length;
        }
        if (!_isString(channel))
        {
            throw 'Illegal argument type: channel must be a string';
        }
        if (_isDisconnected())
        {
            throw 'Illegal state: already disconnected';
        }

        var bayeuxMessage = {
            channel: channel,
            data: content
        };
        var message = _mixin(false, {}, publishProps, bayeuxMessage);
        _queueSend(message);
    };

    /**
     * Returns a string representing the status of the bayeux communication with the Bayeux server.
     */
    this.getStatus = function()
    {
        return _status;
    };

    /**
     * Returns whether this instance has been disconnected.
     */
    this.isDisconnected = _isDisconnected;

    /**
     * Sets the backoff period used to increase the backoff time when retrying an unsuccessful or failed message.
     * Default value is 1 second, which means if there is a persistent failure the retries will happen
     * after 1 second, then after 2 seconds, then after 3 seconds, etc. So for example with 15 seconds of
     * elapsed time, there will be 5 retries (at 1, 3, 6, 10 and 15 seconds elapsed).
     * @param period the backoff period to set
     * @see #getBackoffIncrement()
     */
    this.setBackoffIncrement = function(period)
    {
        _config.backoffIncrement = period;
    };

    /**
     * Returns the backoff period used to increase the backoff time when retrying an unsuccessful or failed message.
     * @see #setBackoffIncrement(period)
     */
    this.getBackoffIncrement = function()
    {
        return _config.backoffIncrement;
    };

    /**
     * Returns the backoff period to wait before retrying an unsuccessful or failed message.
     */
    this.getBackoffPeriod = function()
    {
        return _backoff;
    };

    /**
     * Sets the log level for console logging.
     * Valid values are the strings 'error', 'warn', 'info' and 'debug', from
     * less verbose to more verbose.
     * @param level the log level string
     */
    this.setLogLevel = function(level)
    {
        _config.logLevel = level;
    };

    /**
     * Registers an extension whose callbacks are called for every incoming message
     * (that comes from the server to this client implementation) and for every
     * outgoing message (that originates from this client implementation for the
     * server).
     * The format of the extension object is the following:
     * <pre>
     * {
     *     incoming: function(message) { ... },
     *     outgoing: function(message) { ... }
     * }
     * </pre>
     * Both properties are optional, but if they are present they will be called
     * respectively for each incoming message and for each outgoing message.
     * @param name the name of the extension
     * @param extension the extension to register
     * @return true if the extension was registered, false otherwise
     * @see #unregisterExtension(name)
     */
    this.registerExtension = function(name, extension)
    {
        if (arguments.length < 2)
        {
            throw 'Illegal arguments number: required 2, got ' + arguments.length;
        }
        if (!_isString(name))
        {
            throw 'Illegal argument type: extension name must be a string';
        }

        var existing = false;
        for (var i = 0; i < _extensions.length; ++i)
        {
            var existingExtension = _extensions[i];
            if (existingExtension.name == name)
            {
                existing = true;
                break;
            }
        }
        if (!existing)
        {
            _extensions.push({
                name: name,
                extension: extension
            });
            _debug('Registered extension', name);

            // Callback for extensions
            if (_isFunction(extension.registered))
            {
                extension.registered(name, this);
            }

            return true;
        }
        else
        {
            _info('Could not register extension with name', name, 'since another extension with the same name already exists');
            return false;
        }
    };

    /**
     * Unregister an extension previously registered with
     * {@link #registerExtension(name, extension)}.
     * @param name the name of the extension to unregister.
     * @return true if the extension was unregistered, false otherwise
     */
    this.unregisterExtension = function(name)
    {
        if (!_isString(name))
        {
            throw 'Illegal argument type: extension name must be a string';
        }

        var unregistered = false;
        for (var i = 0; i < _extensions.length; ++i)
        {
            var extension = _extensions[i];
            if (extension.name == name)
            {
                _extensions.splice(i, 1);
                unregistered = true;
                _debug('Unregistered extension', name);

                // Callback for extensions
                var ext = extension.extension;
                if (_isFunction(ext.unregistered))
                {
                    ext.unregistered();
                }

                break;
            }
        }
        return unregistered;
    };

    /**
     * Find the extension registered with the given name.
     * @param name the name of the extension to find
     * @return the extension found or null if no extension with the given name has been registered
     */
    this.getExtension = function(name)
    {
        for (var i = 0; i < _extensions.length; ++i)
        {
            var extension = _extensions[i];
            if (extension.name == name)
            {
                return extension.extension;
            }
        }
        return null;
    };

    /**
     * Returns the name assigned to this Cometd object, or the string 'default'
     * if no name has been explicitly passed as parameter to the constructor.
     */
    this.getName = function()
    {
        return _name;
    };

    /**
     * Returns the clientId assigned by the Bayeux server during handshake.
     */
    this.getClientId = function()
    {
        return _clientId;
    };

    /**
     * Returns the URL of the Bayeux server.
     */
    this.getURL = function()
    {
        return _config.url;
    };

    this.getTransport = function()
    {
        return _transport;
    };

    this.getConfiguration = function()
    {
        return _mixin(true, {}, _config);
    };

    this.getAdvice = function()
    {
        return _mixin(true, {}, _advice);
    };
};

