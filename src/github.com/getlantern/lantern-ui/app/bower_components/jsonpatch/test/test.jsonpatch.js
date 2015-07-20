if ('function' === typeof require) {
  jsonpatch = require('../lib/jsonpatch');
  expect = require('expect.js');
}

// blow away the stack trace here (stops stack errors from Mocha on IE)
beforeEach(function(done){
  setTimeout(done, 0);
});

describe('JSONPointer', function () {
  var example;
  beforeEach(function () {
    example = {
      "foo": {
        "anArray": [
          { "prop": 44 },
          "second",
          "third"
        ],
        "another prop": {
          "baz": "A string"
        }
      }
    };
  });

  describe('.add()', function () {
    var add;
    beforeEach(function () {
      add = function (path, doc, value) {
        return (new jsonpatch.JSONPointer(path)).add(doc, value);
      }
    });

    it('should add a element to an object', function () {
      example = add('/foo/newprop',example,'test');
      expect(example.foo.newprop).equal('test');
    });

    it('should add an element to list, pushing up the remaing values', function () {
      example = add('/foo/anArray/1',example,'test');
      expect(example.foo.anArray.length).equal(4);
      expect(example.foo.anArray[1]).equal('test');
      expect(example.foo.anArray[2]).equal('second');
    });

    it('should allow adding to the end of an array', function () {
      example = add('/foo/anArray/-',example,'test');
      expect(example.foo.anArray.length).equal(4);
      expect(example.foo.anArray[3]).equal('test');
    });

    it('should allow adding to the end of an array', function () {
      example = add('/foo/anArray/3',example,'test');
      expect(example.foo.anArray.length).equal(4);
      expect(example.foo.anArray[3]).equal('test');
    });

    it('should fail if adding to an array would create a sparse array', function () {
      expect(function () {
        add('/foo/anArray/4',example,'test');
      }).throwException(function (e) { expect(e).a(jsonpatch.PatchApplyError); expect(e.message).equal('Add operation must not attempt to create a sparse array!') });
    });

    it('should should fail if the place to add specified does not exist', function () {
      expect(function () {
        add('/foo/newprop/alsonew',example,'test');
      }).throwException(function (e) { expect(e).a(jsonpatch.PatchApplyError); expect(e.message).equal('Path not found in document') });
    });

    it('should should succeed when replacing the root', function () {
      expect(add('',{foo: "bar"},'test')).equal('test');
    });
  });

  describe('.remove()', function () {
    function do_remove(pointerStr, doc) {
      return (new jsonpatch.JSONPointer(pointerStr)).remove(doc);
    }

    it('should remove an object key', function () {
      example = do_remove("/foo", example);
      expect(example.foo).an('undefined');
    });

    it('should remove an item from an array', function () {
      example = do_remove("/foo/anArray/1", example);
      expect(example.foo.anArray.length).equal(2);
      expect(example.foo.anArray[1]).equal('third');
    });

    it('should fail if the object key specified doesnt exist', function () {
      expect(function () {do_remove('/foo/notthere', example);}).throwException(function (e) { expect(e).a(jsonpatch.PatchApplyError); expect(e.message).equal('Remove operation must point to an existing value!') });
    });

    it('should should fail if the path specified doesnt exist', function () {
      expect(function () {do_remove('/foo/notthere/orhere', example);}).throwException(function (e) { expect(e).a(jsonpatch.PatchApplyError); expect(e.message).equal('Path not found in document') });
    });

    it('should fail if the array element specified doesnt exist', function () {
      expect(function () {do_remove('/foo/anArray/4', example);}).throwException(function (e) { expect(e).a(jsonpatch.PatchApplyError); expect(e.message).equal('Remove operation must point to an existing value!') });
    });

    it('should return undefined when removing the root', function () {
      expect(do_remove('', example)).an('undefined');
    });
  });

  describe('.get()', function () {
    function do_get(pointerStr, doc) {
      return (new jsonpatch.JSONPointer(pointerStr)).get(doc);
    }

    describe('JSONPointer examples', function () {
      var doc = {
        "foo": ["bar", "baz"],
        "numbers": [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17],
        "": 0,
        "a/b": 1,
        "c%d": 2,
        "e^f": 3,
        "g|h": 4,
        "i\\j": 5,
        "k\"l": 6,
        " ": 7,
        "m~n": 8
      };

      var examples = {
        // Examples from the spec document
        ""     :doc,
        "/foo"  :["bar", "baz"],
        "/foo/0":"bar",
        "/"     :0,
        "/a~1b" :1,
        "/c%d"  :2,
        "/e^f"  :3,
        "/g|h"  :4,
        "/i\\j" :5,
        "/k\"l" :6,
        "/ "    :7,
        "/m~0n" :8,
        // Extra examples
        "/numbers/010": 10,
        "/numbers/00010": 10,
        "/numbers/-": undefined
      };

      for (var example in examples) {
        (function (example) {
          it('should get the correct pointed object for example "' + example + '"', function () {
            expect(do_get(example, doc)).eql(examples[example]);
          });
        })(example);
      }
    });

    it('should get the object pointed to', function () {
      expect(do_get('/foo/another prop/baz', example)).equal('A string');
    });

    it('should get the array element pointed to', function () {
      expect(do_get('/foo/anArray/1', example)).equal('second');
    });
  });
});

describe('JSONPatch', function () {
  var patch;
  describe('constructor', function () {
    if (typeof JSON === 'object') {
      it('should accept a JSON string as a patch', function () {
        patch = new jsonpatch.JSONPatch('[{"op":"remove", "path":"/"}]');
        expect(patch = patch.compiledOps.length).equal(1);
      });
    }
    it('should accept a JS object as a patch', function () {
      patch = new jsonpatch.JSONPatch([{"op":"remove", "path":"/"}, {"op":"remove", "path":"/"}]);
      expect(patch.compiledOps.length).equal(2);
    });
    it('should raise an error for  patches that arent arrays', function () {
      expect(function () {patch = new jsonpatch.JSONPatch({});}).throwException(function (e) { expect(e).a(jsonpatch.InvalidPatch); expect(e.message).equal('Patch must be an array of operations') });
    });
    it('should raise an error if value is not supplied for add or replace operation', function () {
      expect(function () {patch = new jsonpatch.JSONPatch([{op:"add", path:'/'}]);}).throwException(function (e) { expect(e).a(jsonpatch.InvalidPatch); expect(e.message).equal('add must have key value') });
      expect(function () {patch = new jsonpatch.JSONPatch([{op:"replace", path:'/'}]);}).throwException(function (e) { expect(e).a(jsonpatch.InvalidPatch); expect(e.message).equal('replace must have key value') });
    });
    it('should raise an error if an operation is not specified', function () {
      expect(function () {patch = new jsonpatch.JSONPatch([{}]);}).throwException(function (e) { expect(e).a(jsonpatch.InvalidPatch); expect(e.message).equal('Operation missing!') });
    });
    it('should raise an error if un-recognised operation is specified', function () {
      expect(function () {patch = new jsonpatch.JSONPatch([{op:"blam"}]);}).throwException(function (e) { expect(e).a(jsonpatch.InvalidPatch); expect(e.message).equal('Invalid operation!') });
    });

  });


  // only run this test on browsers with the JSON object
  if (typeof JSON === 'object') {
    it('should not mutate the source document', function () {
      var doc = {
        "foo": {
          "anArray": [
            { "prop": 44 },
            "second",
            "third"
          ],
          "another prop": {
            "baz": "A string"
          }
        }
      };
      var json = JSON.stringify(doc);
      var patch = [
        {"op": "remove", "path": "/foo/another prop/baz"},
        {"op": "add", "path": "/foo/new", "value": "hello"},
        {"op": "move", "from": "/foo/new", "path": "/newnew"},
        {"op": "copy", "from": "/foo/anArray/1", "path": "/foo/anArray/-"},
        {"op": "test", "path": "/foo/anArray/3", "value": "second"}
      ];
      var patched = jsonpatch.apply_patch(doc, patch);
      // Check that the doc has not been mutated
      expect(JSON.stringify(doc)).equal(json)
    });
  }

  if (typeof JSON === 'object') {
    it('should mutate the document if the mutate flag is true', function () {
      var doc = {
        "foo": {
          "anArray": [
            { "prop": 44 },
            "second",
            "third"
          ],
          "another prop": {
            "baz": "A string"
          }
        }
      };
      var json = JSON.stringify(doc);
      var patch = [
        {"op": "remove", "path": "/foo/another prop/baz"},
        {"op": "add", "path": "/foo/new", "value": "hello"},
        {"op": "move", "from": "/foo/new", "path": "/newnew"},
        {"op": "copy", "from": "/foo/anArray/1", "path": "/foo/anArray/-"},
        {"op": "test", "path": "/foo/anArray/3", "value": "second"}
      ];
      patch = new jsonpatch.JSONPatch(patch, true); // mutate = true
      var patched = patch.apply(doc);
      // Check that the doc has been mutated
      expect(JSON.stringify(doc)).not.equal(json)
      // Check that it returned a reference to the original doc
      expect(patched).eql(doc)
    });
  }

  describe('.apply()', function () {
    var patch;
    it('should call each operation in turn', function () {
      patch = new jsonpatch.JSONPatch([]);
      var callOrder = [];
      function mockOp(name) {
        return function(doc) {
          expect(doc).equal('TEST_DOC');
          callOrder.push(name);
          return doc;
        };
      }
      patch.compiledOps = [mockOp('one'),mockOp('two'),mockOp('three')];
      patch.apply('TEST_DOC');
      expect(callOrder[0]).equal('one');
      expect(callOrder[2]).equal('three');
    });
  });

  describe('path attribute', function () {
    it('MUST NOT be part of the location specified by "from" in a move operation', function () {
      var doc = {a:{b:true, c:false}};
      expect(function () {
        jsonpatch.apply_patch(doc, [{op: 'move', from: '/a', path: '/a/b'}]);
      }).throwException(function (e) { expect(e).a(jsonpatch.InvalidPatch); expect(e.message).equal('destination must not be a child of source') });
    });
    it('MUST ALLOW source to start with the destinations string as long as one is not actually a subset of the other', function () {
      var doc = {a:{b:true, c:false}};
      jsonpatch.apply_patch(doc, [{op: 'copy', from: '/a', path: '/ab'}]);
    });
  });

  describe('Regressions', function () {
    it('should reject unknown patch operations (even if they are properties of the base Object)', function () {
      expect(function () {
        new jsonpatch.JSONPatch([{op:'hasOwnProperty', path:'/'}]);
      }).throwException(function (e) { expect(e).a(jsonpatch.InvalidPatch); expect(e.message).equal('Invalid operation!') });
    });
  });

  describe('Atomicity', function () {
    it ('should not apply the patch if any of the operations fails, and the original object should be unaffected', function () {
      var doc = {
        "alpha": 1,
        "omega": "lots"
      };

      expect(function () {
        jsonpatch.apply_patch(doc, [
          {"op": "add", "path": "/delta", "value": 2},
          {"op": "replace", "path": "/beta///", "value": 2}
        ]);
      }).throwException(function (e) { expect(e).a(Error); expect(e.message).equal('Path not found in document') });


      expect(doc.beta).equal(undefined);
      //expect(doc.delta).equal(undefined);
    });
  });

});
