var WebSocket = require('../lib/faye/websocket'),
    fs = require('fs');

var url     = process.argv[2],
    headers = {Origin: 'http://faye.jcoglan.com'},
    ca      = fs.readFileSync(__dirname + '/../spec/server.crt'),
    proxy   = {origin: process.argv[3], headers: {'User-Agent': 'Echo'}, tls: {ca: ca}},
    ws      = new WebSocket.Client(url, [], {headers: headers, proxy: proxy, tls: {ca: ca}});

ws.onopen = function() {
  console.log('[open]', ws.headers);
  ws.send('mic check');
};

ws.onclose = function(close) {
  console.log('[close]', close.code, close.reason);
};

ws.onerror = function(error) {
  console.log('[error]', error.message);
};

ws.onmessage = function(message) {
  console.log('[message]', message.data);
};
