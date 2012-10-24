'use strict';

describe('test test', function() {
  it('true should equal true', function() {
    expect(true).toEqual(true);
  });
});

describe('service', function() {
  beforeEach(module('app.services'));

  describe('api version', function() {
    it('should return current API version', inject(function(APIVER) {
      expect(APIVER).toEqual('0.0.1');
    }));
  });
});
