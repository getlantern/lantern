'use strict';

/* http://docs.angularjs.org/guide/dev_guide.e2e-testing */

describe('app', function() {

  beforeEach(function() {
    browser().navigateTo('../../app/index.html');
  });


  describe('comet connectivity', function() {

    it('displays waiting message iff comet is not connected', function() {
      // cometd server starts out disconnected
      expect(element('#waiting').count()).toEqual(1);
      // XXX start up cometd server
      //expect(element('#waiting').count()).toEqual(0);
    });

  });

});
