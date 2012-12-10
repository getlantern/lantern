describe('helpers', function() {

  var obj;
  
  beforeEach(function() {
    obj = {0: '0', 1: {0: '1.0'}, 2: {0: '2.0', 1: {0: '2.1.0'}}};
  });

  describe('getByPath', function() {
    it('gets the property specified by the given path', function() {
      expect(getByPath(obj, '0')).toBe('0');
      expect(getByPath(obj, '1.0')).toBe('1.0');
      expect(getByPath(obj, '2.0')).toBe('2.0');
      expect(getByPath(obj, '2.1.0')).toBe('2.1.0');

      expect(getByPath(obj, '2')).toBe(obj['2']);
      expect(getByPath(obj, '2.1')).toBe(obj['2']['1']);
    });

    it('returns the entire object when a falsy path is given', function() {
      expect(getByPath(obj, '')).toBe(obj);
      expect(getByPath(obj)).toBe(obj);
    });

    it('returns defaultVal when there is no matching property', function() {
      expect(getByPath(obj, 'missing')).toBeUndefined();
      expect(getByPath(obj, '2.missing')).toBeUndefined();
      expect(getByPath(obj, '2.1.missing')).toBeUndefined();

      var defaultVal = {default: true};
      expect(getByPath(obj, 'missing', defaultVal)).toBe(defaultVal);
      expect(getByPath(obj, '2.missing', defaultVal)).toBe(defaultVal);
      expect(getByPath(obj, '2.1.missing', defaultVal)).toBe(defaultVal);
    });
  });

  describe('deleteByPath', function() {
    it('deletes the property specified by the given path', function() {
      expect(obj['0']).toBe('0');
      deleteByPath(obj, '0');
      expect(obj['0']).toBeUndefined();

      expect(obj['2']['1']['0']).toBe('2.1.0');
      deleteByPath(obj, '2.1.0');
      expect(obj['2']['1']['0']).toBeUndefined();

      expect(obj['2']).toBeDefined();
      deleteByPath(obj, '2');
      expect(obj['2']).toBeUndefined();
    });

    it('does nothing when there is no matching property', function() {
      var objCopy = _.clone(obj);
      expect(_.isEqual(obj, objCopy)).toBe(true);
      deleteByPath(obj, 'missing');
      expect(_.isEqual(obj, objCopy)).toBe(true);

      deleteByPath(obj, '2');
      expect(_.isEqual(obj, objCopy)).toBe(false);
    });

    it('deletes all propreties when path is empty string', function() {
      expect(obj['0']).toBe('0');
      deleteByPath(obj, '');
      expect(_.isEqual(obj, {})).toBe(true);
    });
  });

  describe('merge', function() {
    it('handles blank path (top-level) merge correctly', function() {
      var srcObj = {3: {2: {1: {0: '0'}}}};
      merge(obj, srcObj);
      expect(obj['3']['2']['1']['0']).toBe('0');
    });

    it('handles non-blank path (sub-object) merge correctly', function() {
      merge(obj, {1: '2.1.1'}, '2.1');
      expect(obj['2']['1']['1']).toBe('2.1.1');
      // should not have clobbered any existing properties
      expect(obj['2']['1']['0']).toBe('2.1.0');
    });

    it('merges arrays correctly', function() {
      obj.arr = [0, 1];
      merge(obj, {2: 2}, 'arr');
      expect(obj.arr.length).toBe(3);
      expect(_.isEqual(obj.arr, [0, 1, 2])).toBe(true);

      merge(obj, [1, 2], 'arr'); // array merge overwrites existing value
      expect(obj.arr.length).toBe(2);
      expect(obj.arr[1]).toBe(2);
      expect(_.isEqual(obj.arr, [1, 2])).toBe(true);
    });

    it('merges primitives correctly', function() {
      obj.int = 0;
      merge(obj, 1, 'int');
      expect(obj.int).toBe(1);

      merge(obj, 'string', 'string');
      expect(obj.string).toBe('string');

      merge(obj, true, 'nested.bool');
      expect(obj.nested.bool).toBe(true);
    });

    it('merges complex values correctly', function() {
      obj.complex = {0: '0', arr: [[0], {0: 0}]};
      merge(obj, {2: 2}, 'complex.arr');
      expect(obj.complex.arr.length).toBe(3);
      expect(obj.complex.arr[2]).toBe(2);
      expect(obj.complex.arr[0][0]).toBe(0);

      merge(obj, {1: {1: 1}}, 'complex.arr');
      expect(obj.complex.arr[1][0]).toBe(0);
      expect(obj.complex.arr[1][1]).toBe(1);
    });

    it('throws an error if merging primitives at top level', function() {
      expect(function() { merge(obj, '', 1); }).toThrow();
    });

    it('throws an error for non-object destination', function() {
      expect(function() { merge(1, '', {1: 1}); }).toThrow();
      expect(function() { merge(null, '', {1: 1}); }).toThrow();
    });

    it('creates nested objects if necessary to satisfy the path', function() {
      expect(getByPath(obj, 'three.part.path')).toBeUndefined();
      obj.three = 3;
      merge(obj, {it: 'works'}, 'three.part.path'); // overwrites existing value
      expect(obj.three).not.toBe(3);
      expect(obj.three.part.path.it).toBe('works');
    });
  });
});
