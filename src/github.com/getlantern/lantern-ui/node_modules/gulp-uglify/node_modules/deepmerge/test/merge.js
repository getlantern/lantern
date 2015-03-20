var merge = require('../')
var test = require('tap').test

test('add keys in target that do not exist at the root', function (t) {
    var src = { key1: 'value1', key2: 'value2' }
    target = {}

    var res = merge(target, src)

    t.deepEqual(target, {}, 'merge should be immutable')
    t.deepEqual(res, src)
    t.end()
})

test('merge existing simple keys in target at the roots', function (t) {
    var src = { key1: 'changed', key2: 'value2' }
    var target = { key1: 'value1', key3: 'value3' }

    var expected = {
        key1: 'changed',
        key2: 'value2',
        key3: 'value3'
    }

    t.deepEqual(target, { key1: 'value1', key3: 'value3' })
    t.deepEqual(merge(target, src), expected)
    t.end()
})

test('merge nested objects into target', function (t) {
    var src = {
        key1: {
            subkey1: 'changed',
            subkey3: 'added'
        }
    }
    var target = {
        key1: {
            subkey1: 'value1',
            subkey2: 'value2'
        }
    }

    var expected = {
        key1: {
            subkey1: 'changed',
            subkey2: 'value2',
            subkey3: 'added'
        }
    }

    t.deepEqual(target, {
        key1: {
            subkey1: 'value1',
            subkey2: 'value2'
        }
    })
    t.deepEqual(merge(target, src), expected)
    t.end()
})

test('replace simple key with nested object in target', function (t) {
    var src = {
        key1: {
            subkey1: 'subvalue1',
            subkey2: 'subvalue2'
        }
    }
    var target = {
        key1: 'value1',
        key2: 'value2'
    }

    var expected = {
        key1: {
            subkey1: 'subvalue1',
            subkey2: 'subvalue2'
        },
        key2: 'value2'
    }

    t.deepEqual(target, { key1: 'value1', key2: 'value2' })
    t.deepEqual(merge(target, src), expected)
    t.end()
})

test('should add nested object in target', function(t) {
    var src = {
        "b": {
            "c": {}
        }
    }

    var target = {
        "a": {}
    }

    var expected = {
        "a": {},
        "b": {
            "c": {}
        }
    }

    t.deepEqual(merge(target, src), expected)
    t.end()
})

test('should replace object with simple key in target', function (t) {
    var src = { key1: 'value1' }
    var target = {
        key1: {
            subkey1: 'subvalue1',
            subkey2: 'subvalue2'
        },
        key2: 'value2'
    }

    var expected = { key1: 'value1', key2: 'value2' }

    t.deepEqual(target, {
        key1: {
            subkey1: 'subvalue1',
            subkey2: 'subvalue2'
        },
        key2: 'value2'
    })
    t.deepEqual(merge(target, src), expected)
    t.end()
})

test('should work on simple array', function (t) {
    var src = ['one', 'three']
    var target = ['one', 'two']

    var expected = ['one', 'two', 'three']

    t.deepEqual(target, ['one', 'two'])
    t.deepEqual(merge(target, src), expected)
    t.ok(Array.isArray(merge(target, src)))
    t.end()
})

test('should work on array properties', function (t) {
    var src = {
        key1: ['one', 'three'],
        key2: ['four']
    }
    var target = {
        key1: ['one', 'two']
    }

    var expected = {
        key1: ['one', 'two', 'three'],
        key2: ['four']
    }

    t.deepEqual(target, {
        key1: ['one', 'two']
    })

    t.deepEqual(merge(target, src), expected)
    t.ok(Array.isArray(merge(target, src).key1))
    t.ok(Array.isArray(merge(target, src).key2))
    t.end()
})

test('should work on array of objects', function (t) {
    var src = [
        { key1: ['one', 'three'], key2: ['one'] },
        { key3: ['five'] }
    ]
    var target = [
        { key1: ['one', 'two'] },
        { key3: ['four'] }
    ]

    var expected = [
        { key1: ['one', 'two', 'three'], key2: ['one'] },
        { key3: ['four', 'five'] }
    ]

    t.deepEqual(target, [
        { key1: ['one', 'two'] },
        { key3: ['four'] }
    ])
    t.deepEqual(merge(target, src), expected)
    t.ok(Array.isArray(merge(target, src)), 'result should be an array')
    t.ok(Array.isArray(merge(target, src)[0].key1), 'subkey should be an array too')

    t.end()
})

test('should work on arrays of nested objects', function(t) {
    var target = [
        { key1: { subkey: 'one' }}
    ]

    var src = [
        { key1: { subkey: 'two' }},
        { key2: { subkey: 'three' }}
    ]

    var expected = [
        { key1: { subkey: 'two' }},
        { key2: { subkey: 'three' }}
    ]

    t.deepEqual(merge(target, src), expected)
    t.end()
})
