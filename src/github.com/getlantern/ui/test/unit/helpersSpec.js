describe('helpers', function() {

  var obj;
  
  beforeEach(function() {
    obj = {0: '0', 1: {0: '1.0'}, 2: {0: '2.0', 1: {0: '2.1.0'}}};
  });

  describe('getByPath', function() {
    it('gets the property specified by the given path', function() {
      expect(getByPath(obj, '/0')).toBe('0');
      expect(getByPath(obj, '/1/0')).toBe('1.0');
      expect(getByPath(obj, '/2/0')).toBe('2.0');
      expect(getByPath(obj, '/2/1/0')).toBe('2.1.0');

      expect(getByPath(obj, '/2')).toBe(obj['2']);
      expect(getByPath(obj, '/2/1')).toBe(obj['2']['1']);
    });

    it('returns the entire object when a path of "" is given', function() {
      expect(getByPath(obj, '')).toBe(obj);
    });

    it('returns undefined when there is no such property in obj', function() {
      expect(getByPath(obj, '/missing')).toBeUndefined();
      expect(getByPath(obj, '/2/missing')).toBeUndefined();
      expect(getByPath(obj, '/2/1/missing')).toBeUndefined();
      expect(getByPath(obj, '/0/1/2/3')).toBeUndefined();
    });

    it('throws an error when an invalid path is passed', function() {
      expect(function() { getByPath(obj, '?'); }).toThrow();
    });
  });
});
