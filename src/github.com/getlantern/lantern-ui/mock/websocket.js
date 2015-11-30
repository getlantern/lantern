var url = require('url'),
  WebSocketServer = require('ws').Server;

function MockWS(httpServer) {
  wss = new WebSocketServer({server: httpServer, path: '/data'});
  wss.on('connection', function(ws) {
    ws.on('message', function(message) {
      console.log('received: %s', message);
    });
    ws.send(JSON.stringify({Type: "mocked"}));
  });
}


exports.MockWS = MockWS;
