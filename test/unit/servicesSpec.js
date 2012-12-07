'use strict';

describe('service', function() {
  beforeEach(module('app.services'));

  describe('...', function() {
    it('...', inject(function(MODEL_SYNC_CHANNEL) {
      expect(MODEL_SYNC_CHANNEL).toEqual('/sync');
    }));
  });
});
