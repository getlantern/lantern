
try {
  module.exports = require('./build/Release/sleep.node');
} catch (e) {
  module.exports = {
    sleep: function(s) {
      var e = new Date().getTime() + (s * 1000);

      while (new Date().getTime() <= e) {
        ;
      }
    },

    usleep: function(s) {
      var e = new Date().getTime() + (s / 1000);

      while (new Date().getTime() <= e) {
        ;
      }
    }
  };
}

