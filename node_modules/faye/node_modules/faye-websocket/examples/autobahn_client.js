var WebSocket = require('../lib/faye/websocket');

var host  = 'ws://localhost:9001',
    agent = 'Faye (Node ' + process.version + ')',
    cases = 0,
    skip  = [];

var socket = new WebSocket.Client(host + '/getCaseCount');

socket.onmessage = function(event) {
  console.log('Total cases to run: ' + event.data);
  cases = parseInt(event.data);
};

socket.onclose = function() {
  var runCase = function(n) {
    if (n > cases) {
      socket = new WebSocket.Client(host + '/updateReports?agent=' + encodeURIComponent(agent));
      socket.onclose = process.exit
      
    } else if (skip.indexOf(n) >= 0) {
      runCase(n + 1);
      
    } else {
      console.log('Running test case #' + n + ' ...');
      socket = new WebSocket.Client(host + '/runCase?case=' + n + '&agent=' + encodeURIComponent(agent));
      
      socket.onmessage = function(event) {
        socket.send(event.data);
      };
      
      socket.onclose = function() {
        runCase(n + 1);
      };
    }
  };
  
  runCase(1);
};

