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

    it('returns the entire object when no path or a path of "/" is given', function() {
      expect(getByPath(obj)).toBe(obj);
      expect(getByPath(obj, '/')).toBe(obj);
    });

    it('returns defaultVal when there is no such property in obj', function() {
      expect(getByPath(obj, '/missing')).toBeUndefined();
      expect(getByPath(obj, '/2/missing')).toBeUndefined();
      expect(getByPath(obj, '/2/1/missing')).toBeUndefined();
      expect(getByPath(obj, '/0/1/2/3')).toBeUndefined();

      var defaultVal = {default: true};
      expect(getByPath(obj, '/missing', defaultVal)).toBe(defaultVal);
      expect(getByPath(obj, '/2/missing', defaultVal)).toBe(defaultVal);
      expect(getByPath(obj, '/2/1/missing', defaultVal)).toBe(defaultVal);
      expect(getByPath(obj, '/0/1/2/3', defaultVal)).toBe(defaultVal);

      var foo = {bar: undefined};
      // should be undefined, not defaultVal, since 'bar' is in foo and is set to undefined:
      expect(getByPath(foo, '/bar', defaultVal)).toBeUndefined();
    });

    it('throws an error when an invalid path is passed', function() {
      expect(function() { getByPath(obj, ''); }).toThrow();
      expect(function() { getByPath(obj, '0'); }).toThrow();
      expect(function() { getByPath(obj, '//'); }).toThrow();
      expect(function() { getByPath(obj, '/foo/bar//baz'); }).toThrow();
    });

    it('throws an error when a non-plain object is passed as obj', function() {
      expect(function() { getByPath([]); }).toThrow();
    });
  });

  describe('deleteByPath', function() {
    it('returns true deletes the property specified by the given path when it matches', function() {
      expect(obj['0']).toBe('0');
      expect(deleteByPath(obj, '/0')).toBe(true);
      expect(obj['0']).toBeUndefined();

      expect(obj['2']['1']['0']).toBe('2.1.0');
      expect(deleteByPath(obj, '/2/1/0')).toBe(true);
      expect(obj['2']['1']['0']).toBeUndefined();

      expect(obj['2']).toBeDefined();
      expect(deleteByPath(obj, '/2')).toBe(true);
      expect(obj['2']).toBeUndefined();
    });

    it('returns false and does nothing when there is no matching property', function() {
      var objCopy = _.cloneDeep(obj);
      expect(_.isEqual(obj, objCopy)).toBe(true);
      expect(deleteByPath(obj, '/missing')).toBe(false);
      expect(_.isEqual(obj, objCopy)).toBe(true);
      expect(deleteByPath(obj, '/missing/missing2')).toBe(false);
      expect(_.isEqual(obj, objCopy)).toBe(true);

      // now actually delete a property to show the clone is no longer equal
      expect(deleteByPath(obj, '/2')).toBe(true);
      expect(_.isEqual(obj, objCopy)).toBe(false);
    });

    it('deletes all properties when path is "/"', function() {
      expect(obj['0']).toBe('0');
      expect(deleteByPath(obj, '/')).toBe(true);
      expect(_.isEqual(obj, {})).toBe(true);
    });

    it('throws an error when an invalid path is passed', function() {
      expect(function() { deleteByPath(obj, ''); }).toThrow();
      expect(function() { deleteByPath(obj, '0'); }).toThrow();
      expect(function() { deleteByPath(obj, '//'); }).toThrow();
      expect(function() { deleteByPath(obj, '/foo/bar//baz'); }).toThrow();
    });
  });

  describe('setByPath', function() {
    it('sets the property specified by the given path', function() {
      expect(obj['0']).toBe('0');
      setByPath(obj, '/0', 'foo');
      expect(obj['0']).toBe('foo');

      expect(obj['2']['1']['0']).toBe('2.1.0');
      setByPath(obj, '/2/1/0', 'bar');
      expect(obj['2']['1']['0']).toBe('bar');

      // assigns by reference
      var baz = {fleem: true};
      expect(obj['2']).toBeDefined();
      setByPath(obj, '/2', baz);
      baz.fleem = false;
      expect(obj['2']).toBe(baz);
    });

    it('throws an error when an invalid path is passed', function() {
      expect(function() { setByPath(obj, '', 1); }).toThrow();
      expect(function() { setByPath(obj, '0', 1); }).toThrow();
      expect(function() { setByPath(obj, '//', 1); }).toThrow();
      expect(function() { setByPath(obj, '/foo/bar//baz', 1); }).toThrow();
    });
  });
});
