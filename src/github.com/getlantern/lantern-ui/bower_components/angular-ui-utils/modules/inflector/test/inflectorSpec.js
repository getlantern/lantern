describe('inflector', function () {
  var inflectorFilter, testPhrase = 'here isMy_phone_number';

  beforeEach(module('ui.inflector'));
  beforeEach(inject(function ($filter) {
    inflectorFilter = $filter('inflector');
  }));

  describe('default', function () {
    it('should default to humanize', function () {
      expect(inflectorFilter(testPhrase)).toEqual('Here Is My Phone Number');
    });
    it('should fail gracefully for invalid input', function () {
      expect(inflectorFilter(undefined)).toBeUndefined();
    });
    it('should do nothing for empty input', function () {
      expect(inflectorFilter('')).toEqual('');
    });
  });

  describe('humanize', function () {
    it('should uppercase first letter and separate words with a space', function () {
      expect(inflectorFilter(testPhrase, 'humanize')).toEqual('Here Is My Phone Number');
    });
  });
  describe('underscore', function () {
    it('should lowercase everything and separate words with an underscore', function () {
      expect(inflectorFilter(testPhrase, 'underscore')).toEqual('here_is_my_phone_number');
    });
  });
  describe('variable', function () {
    it('should remove all separators and camelHump the phrase', function () {
      expect(inflectorFilter(testPhrase, 'variable')).toEqual('hereIsMyPhoneNumber');
    });
    it('should do nothing if already formatted properly', function () {
      expect(inflectorFilter("hereIsMyPhoneNumber", 'variable')).toEqual('hereIsMyPhoneNumber');
    });
  });
});