describe('diagnostics', function () {
  'use strict';

  var assume = require('assume')
    , debug = require('./');

  beforeEach(function () {
    process.env.DEBUG = '';
    process.env.DIAGNOSTICS = '';
  });

  it('is exposed as function', function () {
    assume(debug).to.be.a('function');
  });

  describe('.enabled', function () {
    it('uses the `debug` env', function () {
      process.env.DEBUG = 'bigpipe';

      assume(debug.enabled('bigpipe')).to.be.true();
      assume(debug.enabled('false')).to.be.false();
    });

    it('uses the `diagnostics` env', function () {
      process.env.DIAGNOSTICS = 'bigpipe';

      assume(debug.enabled('bigpipe')).to.be.true();
      assume(debug.enabled('false')).to.be.false();
    });

    it('supports wildcards', function () {
      process.env.DEBUG = 'b*';

      assume(debug.enabled('bigpipe')).to.be.true();
      assume(debug.enabled('bro-fist')).to.be.true();
      assume(debug.enabled('ro-fist')).to.be.false();
    });

    it('is disabled by default', function () {
      process.env.DEBUG = '';

      assume(debug.enabled('bigpipe')).to.be.false();

      process.env.DEBUG = 'bigpipe';

      assume(debug.enabled('bigpipe')).to.be.true();
    });

    it('can ignore loggers using a -', function () {
      process.env.DEBUG = 'bigpipe,-primus,sack';

      assume(debug.enabled('bigpipe')).to.be.true();
      assume(debug.enabled('sack')).to.be.true();
      assume(debug.enabled('primus')).to.be.false();
    });

    it('supports multiple ranges', function () {
      process.env.DEBUG = 'bigpipe*,primus*';

      assume(debug.enabled('bigpipe:')).to.be.true();
      assume(debug.enabled('bigpipes')).to.be.true();
      assume(debug.enabled('primus:')).to.be.true();
      assume(debug.enabled('primush')).to.be.true();
      assume(debug.enabled('unknown')).to.be.false();
    });
  });

  describe('.resolve', function () {
    it('automatically finds a suitable name', function () {
      assume(debug.resolve(module)).to.not.equal('');
    });
  });

  describe('.to', function (next) {
    it('globally overrides the stream', function () {
      debug.to({
        write: function write(line) {
          assume(line).to.contain('foo');
          assume(line).to.contain('bar');

          debug.to(process.stdout);
          next();
        }
      });

      var log = debug('foo');
      log('bar');
    });
  });
});
