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

(function()
{
    function bind(org_cometd)
    {
        /**
         * With each handshake or connect, the extension sends timestamps within the
         * ext field like: <code>{ext:{timesync:{tc:12345567890,l:23,o:4567},...},...}</code>
         * where:<ul>
         *  <li>tc is the client timestamp in ms since 1970 of when the message was sent.
         *  <li>l is the network lag that the client has calculated.
         *  <li>o is the clock offset that the client has calculated.
         * </ul>
         *
         * <p>
         * A cometd server that supports timesync, can respond with an ext
         * field like: <code>{ext:{timesync:{tc:12345567890,ts:1234567900,p:123,a:3},...},...}</code>
         * where:<ul>
         *  <li>tc is the client timestamp of when the message was sent,
         *  <li>ts is the server timestamp of when the message was received
         *  <li>p is the poll duration in ms - ie the time the server took before sending the response.
         *  <li>a is the measured accuracy of the calculated offset and lag sent by the client
         * </ul>
         *
         * <p>
         * The relationship between tc, ts & l is given by <code>ts=tc+o+l</code> (the
         * time the server received the messsage is the client time plus the offset plus the
         * network lag).   Thus the accuracy of the o and l settings can be determined with
         * <code>a=(tc+o+l)-ts</code>.
         * </p>
         * <p>
         * When the client has received the response, it can make a more accurate estimate
         * of the lag as <code>l2=(now-tc-p)/2</code> (assuming symmetric lag).
         * A new offset can then be calculated with the relationship on the client
         * that <code>ts=tc+o2+l2</code>, thus <code>o2=ts-tc-l2</code>.
         * </p>
         * <p>
         * Since the client also receives the a value calculated on the server, it
         * should be possible to analyse this and compensate for some asymmetry
         * in the lag. But the current client does not do this.
         * </p>
         *
         * @param configuration
         */
        return org_cometd.TimeSyncExtension = function(configuration)
        {
            var _cometd;
            var _maxSamples = configuration && configuration.maxSamples || 10;
            var _lags = [];
            var _offsets = [];
            var _lag = 0;
            var _offset = 0;

            function _debug(text, args)
            {
                _cometd._debug(text, args);
            }

            this.registered = function(name, cometd)
            {
                _cometd = cometd;
                _debug('TimeSyncExtension: executing registration callback');
            };

            this.unregistered = function()
            {
                _debug('TimeSyncExtension: executing unregistration callback');
                _cometd = null;
                _lags = [];
                _offsets = [];
            };

            this.incoming = function(message)
            {
                var channel = message.channel;
                if (channel && channel.indexOf('/meta/') === 0)
                {
                    if (message.ext && message.ext.timesync)
                    {
                        var timesync = message.ext.timesync;
                        _debug('TimeSyncExtension: server sent timesync', timesync);

                        var now = new Date().getTime();
                        var l2 = (now - timesync.tc - timesync.p) / 2;
                        var o2 = timesync.ts - timesync.tc - l2;

                        _lags.push(l2);
                        _offsets.push(o2);
                        if (_offsets.length > _maxSamples)
                        {
                            _offsets.shift();
                            _lags.shift();
                        }

                        var samples = _offsets.length;
                        var lagsSum = 0;
                        var offsetsSum = 0;
                        for (var i = 0; i < samples; ++i)
                        {
                            lagsSum += _lags[i];
                            offsetsSum += _offsets[i];
                        }
                        _lag = parseInt((lagsSum / samples).toFixed());
                        _offset = parseInt((offsetsSum / samples).toFixed());
                        _debug('TimeSyncExtension: network lag', _lag, 'ms, time offset with server', _offset, 'ms', _lag, _offset);
                    }
                }
                return message;
            };

            this.outgoing = function(message)
            {
                var channel = message.channel;
                if (channel && channel.indexOf('/meta/') === 0)
                {
                    if (!message.ext)
                    {
                        message.ext = {};
                    }
                    message.ext.timesync = {
                        tc: new Date().getTime(),
                        l: _lag,
                        o: _offset
                    };
                    _debug('TimeSyncExtension: client sending timesync', org_cometd.JSON.toJSON(message.ext.timesync));
                }
                return message;
            };

            /**
             * Get the estimated offset in ms from the clients clock to the
             * servers clock.  The server time is the client time plus the offset.
             */
            this.getTimeOffset = function()
            {
                return _offset;
            };

            /**
             * Get an array of multiple offset samples used to calculate
             * the offset.
             */
            this.getTimeOffsetSamples = function()
            {
                return _offsets;
            };

            /**
             * Get the estimated network lag in ms from the client to the server.
             */
            this.getNetworkLag = function()
            {
                return _lag;
            };

            /**
             * Get the estimated server time in ms since the epoch.
             */
            this.getServerTime = function()
            {
                return new Date().getTime() + _offset;
            };

            /**
             *
             * Get the estimated server time as a Date object
             */
            this.getServerDate = function()
            {
                return new Date(this.getServerTime());
            };

            /**
             * Set a timeout to expire at given time on the server.
             * @param callback The function to call when the timer expires
             * @param atServerTimeOrDate a js Time or Date object representing the
             * server time at which the timeout should expire
             */
            this.setTimeout = function(callback, atServerTimeOrDate)
            {
                var ts = (atServerTimeOrDate instanceof Date) ? atServerTimeOrDate.getTime() : (0 + atServerTimeOrDate);
                var tc = ts - _offset;
                var interval = tc - new Date().getTime();
                if (interval <= 0)
                {
                    interval = 1;
                }
                return org_cometd.Utils.setTimeout(_cometd, callback, interval);
            };
        };
    }

    if (typeof define === 'function' && define.amd)
    {
        define(['org/cometd'], bind);
    }
    else
    {
        bind(org.cometd);
    }
})();
