describe('unique', function () {
  var uniqueFilter;

  beforeEach(module('ui.unique'));
  beforeEach(inject(function ($filter) {
    uniqueFilter = $filter('unique');
  }));

  it('should return unique entries based on object equality', function () {
    var arrayToFilter = [
      {key: 'value'},
      {key: 'value2'},
      {key: 'value'}
    ];
    expect(uniqueFilter(arrayToFilter)).toEqual([
      {key: 'value'},
      {key: 'value2'}
    ]);
  });

  it('should return unique entries based on object equality for complex objects', function () {
    var arrayToFilter = [
      {key: 'value', other: 'other1'},
      {key: 'value2', other: 'other2'},
      {other: 'other1', key: 'value'}
    ];
    expect(uniqueFilter(arrayToFilter)).toEqual([
      {key: 'value', other: 'other1'},
      {key: 'value2', other: 'other2'}
    ]);
  });

  it('should return unique entries based on the key provided', function () {
    var arrayToFilter = [
      {key: 'value'},
      {key: 'value2'},
      {key: 'value'}
    ];
    expect(uniqueFilter(arrayToFilter, 'key')).toEqual([
      {key: 'value'},
      {key: 'value2'}
    ]);
  });

  it('should return unique entries based on the key provided for complex objects', function () {
    var arrayToFilter = [
      {key: 'value', other: 'other1'},
      {key: 'value2', other: 'other2'},
      {key: 'value', other: 'other3'}
    ];
    expect(uniqueFilter(arrayToFilter, 'key')).toEqual([
      { key: 'value', other: 'other1' },
      { key: 'value2', other: 'other2' }
    ]);
  });

  it('should return unique primitives in arrays', function () {
    expect(uniqueFilter([1, 2, 1, 3])).toEqual([1, 2, 3]);
  });

  it('should work correctly for arrays of mixed elements and object equality', function () {
    expect(uniqueFilter([1, {key: 'value'}, 1, {key: 'value'}, 2, "string", 3])).toEqual([1, {key: 'value'}, 2, "string", 3]);
  });

  it('should work correctly for arrays of mixed elements and a key specified', function () {
    expect(uniqueFilter([1, {key: 'value'}, 1, {key: 'value'}, 2, "string", 3], 'key')).toEqual([1, {key: 'value'}, 2, "string", 3]);
  });

  it('should return unmodified object if not array', function () {
    expect(uniqueFilter('string', 'someKey')).toEqual('string');
  });

  it('should return unmodified array if provided key === false', function () {
    var arrayToFilter = [
      {key: 'value1'},
      {key: 'value2'}
    ];
    expect(uniqueFilter(arrayToFilter, false)).toEqual(arrayToFilter);
  });

});