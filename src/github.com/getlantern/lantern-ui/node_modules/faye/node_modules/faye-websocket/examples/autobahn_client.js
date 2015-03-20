var WebSocket = require('../lib/faye/websocket'),
    deflate   = require('permessage-deflate'),
    pace      = require('pace');

var host    = 'ws://localhost:9001',
    agent   = encodeURIComponent('node-' + process.version),
    cases   = 0,
    options = {extensions: [deflate]};

var socket = new WebSocket.Client(host + '/getCaseCount'),
    url, progress;

socket.onmessage = function(event) {
  console.log('Total cases to run: ' + event.data);
  cases = parseInt(event.data);
  progress = pace(cases);
};

var runCase = function(n) {
  if (n > cases) {
    url = host + '/updateReports?agent=' + agent;
    socket = new WebSocket.Client(url);
    socket.onclose = process.exit;
    return;
  }

  url = host + '/runCase?case=' + n + '&agent=' + agent;
  socket = new WebSocket.Client(url, [], options);
  socket.pipe(socket);

  socket.on('close', function() {
    progress.op();
    runCase(n + 1);
  });
};

socket.onclose = function() {
  runCase(1);
};
