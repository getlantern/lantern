'use strict';

/* http://docs.angularjs.org/guide/dev_guide.e2e-testing */

describe('app', function() {

  beforeEach(function() {
    browser().navigateTo('../../app/index.html');
  });


  describe('comet connectivity', function() {

    it('displays waiting message iff comet is not connected', function() {
      // XXX make sure cometd server is disconnected
      expect(element('[x-block-input]').count()).toEqual(1);
      // XXX start up cometd server
      //expect(element('[x-block-input]').count()).toEqual(0);
    });

  });

});
