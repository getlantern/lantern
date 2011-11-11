/***

    P R O C E S S I N G . J S - 1.3.6
    a port of the Processing visualization language

    Processing.js is licensed under the MIT License, see LICENSE.
    For a list of copyright holders, please refer to AUTHORS.

    http://processingjs.org

***/

(function(window, document, Math, undef) {
  var nop = function() {};
  var debug = function() {
    if ("console" in window) return function(msg) {
      window.console.log("Processing.js: " + msg)
    };
    return nop()
  }();
  var ajax = function(url) {
    var xhr = new XMLHttpRequest;
    xhr.open("GET", url, false);
    if (xhr.overrideMimeType) xhr.overrideMimeType("text/plain");
    xhr.setRequestHeader("If-Modified-Since", "Fri, 01 Jan 1960 00:00:00 GMT");
    xhr.send(null);
    if (xhr.status !== 200 && xhr.status !== 0) throw "XMLHttpRequest failed, status code " + xhr.status;
    return xhr.responseText
  };
  var isDOMPresent = "document" in this && !("fake" in this.document);
  document.head = document.head || document.getElementsByTagName("head")[0];

  function setupTypedArray(name, fallback) {
    if (name in window) return window[name];
    if (typeof window[fallback] === "function") return window[fallback];
    return function(obj) {
      if (obj instanceof Array) return obj;
      if (typeof obj === "number") {
        var arr = [];
        arr.length = obj;
        return arr
      }
    }
  }
  var Float32Array = setupTypedArray("Float32Array", "WebGLFloatArray"),
    Int32Array = setupTypedArray("Int32Array", "WebGLIntArray"),
    Uint16Array = setupTypedArray("Uint16Array", "WebGLUnsignedShortArray"),
    Uint8Array = setupTypedArray("Uint8Array", "WebGLUnsignedByteArray");
  var PConstants = {
    X: 0,
    Y: 1,
    Z: 2,
    R: 3,
    G: 4,
    B: 5,
    A: 6,
    U: 7,
    V: 8,
    NX: 9,
    NY: 10,
    NZ: 11,
    EDGE: 12,
    SR: 13,
    SG: 14,
    SB: 15,
    SA: 16,
    SW: 17,
    TX: 18,
    TY: 19,
    TZ: 20,
    VX: 21,
    VY: 22,
    VZ: 23,
    VW: 24,
    AR: 25,
    AG: 26,
    AB: 27,
    DR: 3,
    DG: 4,
    DB: 5,
    DA: 6,
    SPR: 28,
    SPG: 29,
    SPB: 30,
    SHINE: 31,
    ER: 32,
    EG: 33,
    EB: 34,
    BEEN_LIT: 35,
    VERTEX_FIELD_COUNT: 36,
    P2D: 1,
    JAVA2D: 1,
    WEBGL: 2,
    P3D: 2,
    OPENGL: 2,
    PDF: 0,
    DXF: 0,
    OTHER: 0,
    WINDOWS: 1,
    MAXOSX: 2,
    LINUX: 3,
    EPSILON: 1.0E-4,
    MAX_FLOAT: 3.4028235E38,
    MIN_FLOAT: -3.4028235E38,
    MAX_INT: 2147483647,
    MIN_INT: -2147483648,
    PI: Math.PI,
    TWO_PI: 2 * Math.PI,
    HALF_PI: Math.PI / 2,
    THIRD_PI: Math.PI / 3,
    QUARTER_PI: Math.PI / 4,
    DEG_TO_RAD: Math.PI / 180,
    RAD_TO_DEG: 180 / Math.PI,
    WHITESPACE: " \t\n\r\u000c\u00a0",
    RGB: 1,
    ARGB: 2,
    HSB: 3,
    ALPHA: 4,
    CMYK: 5,
    TIFF: 0,
    TARGA: 1,
    JPEG: 2,
    GIF: 3,
    BLUR: 11,
    GRAY: 12,
    INVERT: 13,
    OPAQUE: 14,
    POSTERIZE: 15,
    THRESHOLD: 16,
    ERODE: 17,
    DILATE: 18,
    REPLACE: 0,
    BLEND: 1 << 0,
    ADD: 1 << 1,
    SUBTRACT: 1 << 2,
    LIGHTEST: 1 << 3,
    DARKEST: 1 << 4,
    DIFFERENCE: 1 << 5,
    EXCLUSION: 1 << 6,
    MULTIPLY: 1 << 7,
    SCREEN: 1 << 8,
    OVERLAY: 1 << 9,
    HARD_LIGHT: 1 << 10,
    SOFT_LIGHT: 1 << 11,
    DODGE: 1 << 12,
    BURN: 1 << 13,
    ALPHA_MASK: 4278190080,
    RED_MASK: 16711680,
    GREEN_MASK: 65280,
    BLUE_MASK: 255,
    CUSTOM: 0,
    ORTHOGRAPHIC: 2,
    PERSPECTIVE: 3,
    POINT: 2,
    POINTS: 2,
    LINE: 4,
    LINES: 4,
    TRIANGLE: 8,
    TRIANGLES: 9,
    TRIANGLE_STRIP: 10,
    TRIANGLE_FAN: 11,
    QUAD: 16,
    QUADS: 16,
    QUAD_STRIP: 17,
    POLYGON: 20,
    PATH: 21,
    RECT: 30,
    ELLIPSE: 31,
    ARC: 32,
    SPHERE: 40,
    BOX: 41,
    GROUP: 0,
    PRIMITIVE: 1,
    GEOMETRY: 3,
    VERTEX: 0,
    BEZIER_VERTEX: 1,
    CURVE_VERTEX: 2,
    BREAK: 3,
    CLOSESHAPE: 4,
    OPEN: 1,
    CLOSE: 2,
    CORNER: 0,
    CORNERS: 1,
    RADIUS: 2,
    CENTER_RADIUS: 2,
    CENTER: 3,
    DIAMETER: 3,
    CENTER_DIAMETER: 3,
    BASELINE: 0,
    TOP: 101,
    BOTTOM: 102,
    NORMAL: 1,
    NORMALIZED: 1,
    IMAGE: 2,
    MODEL: 4,
    SHAPE: 5,
    SQUARE: "butt",
    ROUND: "round",
    PROJECT: "square",
    MITER: "miter",
    BEVEL: "bevel",
    AMBIENT: 0,
    DIRECTIONAL: 1,
    SPOT: 3,
    BACKSPACE: 8,
    TAB: 9,
    ENTER: 10,
    RETURN: 13,
    ESC: 27,
    DELETE: 127,
    CODED: 65535,
    SHIFT: 16,
    CONTROL: 17,
    ALT: 18,
    CAPSLK: 20,
    PGUP: 33,
    PGDN: 34,
    END: 35,
    HOME: 36,
    LEFT: 37,
    UP: 38,
    RIGHT: 39,
    DOWN: 40,
    F1: 112,
    F2: 113,
    F3: 114,
    F4: 115,
    F5: 116,
    F6: 117,
    F7: 118,
    F8: 119,
    F9: 120,
    F10: 121,
    F11: 122,
    F12: 123,
    NUMLK: 144,
    META: 157,
    INSERT: 155,
    ARROW: "default",
    CROSS: "crosshair",
    HAND: "pointer",
    MOVE: "move",
    TEXT: "text",
    WAIT: "wait",
    NOCURSOR: "url('data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=='), auto",
    DISABLE_OPENGL_2X_SMOOTH: 1,
    ENABLE_OPENGL_2X_SMOOTH: -1,
    ENABLE_OPENGL_4X_SMOOTH: 2,
    ENABLE_NATIVE_FONTS: 3,
    DISABLE_DEPTH_TEST: 4,
    ENABLE_DEPTH_TEST: -4,
    ENABLE_DEPTH_SORT: 5,
    DISABLE_DEPTH_SORT: -5,
    DISABLE_OPENGL_ERROR_REPORT: 6,
    ENABLE_OPENGL_ERROR_REPORT: -6,
    ENABLE_ACCURATE_TEXTURES: 7,
    DISABLE_ACCURATE_TEXTURES: -7,
    HINT_COUNT: 10,
    SINCOS_LENGTH: 720,
    PRECISIONB: 15,
    PRECISIONF: 1 << 15,
    PREC_MAXVAL: (1 << 15) - 1,
    PREC_ALPHA_SHIFT: 24 - 15,
    PREC_RED_SHIFT: 16 - 15,
    NORMAL_MODE_AUTO: 0,
    NORMAL_MODE_SHAPE: 1,
    NORMAL_MODE_VERTEX: 2,
    MAX_LIGHTS: 8
  };

  function virtHashCode(obj) {
    if (typeof obj === "string") {
      var hash = 0;
      for (var i = 0; i < obj.length; ++i) hash = hash * 31 + obj.charCodeAt(i) & 4294967295;
      return hash
    }
    if (typeof obj !== "object") return obj & 4294967295;
    if (obj.hashCode instanceof Function) return obj.hashCode();
    if (obj.$id === undef) obj.$id = Math.floor(Math.random() * 65536) - 32768 << 16 | Math.floor(Math.random() * 65536);
    return obj.$id
  }
  function virtEquals(obj, other) {
    if (obj === null || other === null) return obj === null && other === null;
    if (typeof obj === "string") return obj === other;
    if (typeof obj !== "object") return obj === other;
    if (obj.equals instanceof Function) return obj.equals(other);
    return obj === other
  }
  var ObjectIterator = function(obj) {
    if (obj.iterator instanceof Function) return obj.iterator();
    if (obj instanceof Array) {
      var index = -1;
      this.hasNext = function() {
        return ++index < obj.length
      };
      this.next = function() {
        return obj[index]
      }
    } else throw "Unable to iterate: " + obj;
  };
  var ArrayList = function() {
    function Iterator(array) {
      var index = 0;
      this.hasNext = function() {
        return index < array.length
      };
      this.next = function() {
        return array[index++]
      };
      this.remove = function() {
        array.splice(index, 1)
      }
    }
    function ArrayList() {
      var array;
      if (arguments.length === 0) array = [];
      else if (arguments.length > 0 && typeof arguments[0] !== "number") array = arguments[0].toArray();
      else {
        array = [];
        array.length = 0 | arguments[0]
      }
      this.get = function(i) {
        return array[i]
      };
      this.contains = function(item) {
        return this.indexOf(item) > -1
      };
      this.indexOf = function(item) {
        for (var i = 0, len = array.length; i < len; ++i) if (virtEquals(item, array[i])) return i;
        return -1
      };
      this.add = function() {
        if (arguments.length === 1) array.push(arguments[0]);
        else if (arguments.length === 2) {
          var arg0 = arguments[0];
          if (typeof arg0 === "number") if (arg0 >= 0 && arg0 <= array.length) array.splice(arg0, 0, arguments[1]);
          else throw arg0 + " is not a valid index";
          else throw typeof arg0 + " is not a number";
        } else throw "Please use the proper number of parameters.";
      };
      this.addAll = function(arg1, arg2) {
        var it;
        if (typeof arg1 === "number") {
          if (arg1 < 0 || arg1 > array.length) throw "Index out of bounds for addAll: " + arg1 + " greater or equal than " + array.length;
          it = new ObjectIterator(arg2);
          while (it.hasNext()) array.splice(arg1++, 0, it.next())
        } else {
          it = new ObjectIterator(arg1);
          while (it.hasNext()) array.push(it.next())
        }
      };
      this.set = function() {
        if (arguments.length === 2) {
          var arg0 = arguments[0];
          if (typeof arg0 === "number") if (arg0 >= 0 && arg0 < array.length) array.splice(arg0, 1, arguments[1]);
          else throw arg0 + " is not a valid index.";
          else throw typeof arg0 + " is not a number";
        } else throw "Please use the proper number of parameters.";
      };
      this.size = function() {
        return array.length
      };
      this.clear = function() {
        array.length = 0
      };
      this.remove = function(item) {
        if (typeof item === "number") return array.splice(item, 1)[0];
        item = this.indexOf(item);
        if (item > -1) {
          array.splice(item, 1);
          return true
        }
        return false
      };
      this.isEmpty = function() {
        return !array.length
      };
      this.clone = function() {
        return new ArrayList(this)
      };
      this.toArray = function() {
        return array.slice(0)
      };
      this.iterator = function() {
        return new Iterator(array)
      }
    }
    return ArrayList
  }();
  var HashMap = function() {
    function HashMap() {
      if (arguments.length === 1 && arguments[0] instanceof HashMap) return arguments[0].clone();
      var initialCapacity = arguments.length > 0 ? arguments[0] : 16;
      var loadFactor = arguments.length > 1 ? arguments[1] : 0.75;
      var buckets = [];
      buckets.length = initialCapacity;
      var count = 0;
      var hashMap = this;

      function getBucketIndex(key) {
        var index = virtHashCode(key) % buckets.length;
        return index < 0 ? buckets.length + index : index
      }
      function ensureLoad() {
        if (count <= loadFactor * buckets.length) return;
        var allEntries = [];
        for (var i = 0; i < buckets.length; ++i) if (buckets[i] !== undef) allEntries = allEntries.concat(buckets[i]);
        var newBucketsLength = buckets.length * 2;
        buckets = [];
        buckets.length = newBucketsLength;
        for (var j = 0; j < allEntries.length; ++j) {
          var index = getBucketIndex(allEntries[j].key);
          var bucket = buckets[index];
          if (bucket === undef) buckets[index] = bucket = [];
          bucket.push(allEntries[j])
        }
      }
      function Iterator(conversion, removeItem) {
        var bucketIndex = 0;
        var itemIndex = -1;
        var endOfBuckets = false;

        function findNext() {
          while (!endOfBuckets) {
            ++itemIndex;
            if (bucketIndex >= buckets.length) endOfBuckets = true;
            else if (buckets[bucketIndex] === undef || itemIndex >= buckets[bucketIndex].length) {
              itemIndex = -1;
              ++bucketIndex
            } else return
          }
        }
        this.hasNext = function() {
          return !endOfBuckets
        };
        this.next = function() {
          var result = conversion(buckets[bucketIndex][itemIndex]);
          findNext();
          return result
        };
        this.remove = function() {
          removeItem(this.next());
          --itemIndex
        };
        findNext()
      }
      function Set(conversion, isIn, removeItem) {
        this.clear = function() {
          hashMap.clear()
        };
        this.contains = function(o) {
          return isIn(o)
        };
        this.containsAll = function(o) {
          var it = o.iterator();
          while (it.hasNext()) if (!this.contains(it.next())) return false;
          return true
        };
        this.isEmpty = function() {
          return hashMap.isEmpty()
        };
        this.iterator = function() {
          return new Iterator(conversion, removeItem)
        };
        this.remove = function(o) {
          if (this.contains(o)) {
            removeItem(o);
            return true
          }
          return false
        };
        this.removeAll = function(c) {
          var it = c.iterator();
          var changed = false;
          while (it.hasNext()) {
            var item = it.next();
            if (this.contains(item)) {
              removeItem(item);
              changed = true
            }
          }
          return true
        };
        this.retainAll = function(c) {
          var it = this.iterator();
          var toRemove = [];
          while (it.hasNext()) {
            var entry = it.next();
            if (!c.contains(entry)) toRemove.push(entry)
          }
          for (var i = 0; i < toRemove.length; ++i) removeItem(toRemove[i]);
          return toRemove.length > 0
        };
        this.size = function() {
          return hashMap.size()
        };
        this.toArray = function() {
          var result = [];
          var it = this.iterator();
          while (it.hasNext()) result.push(it.next());
          return result
        }
      }
      function Entry(pair) {
        this._isIn = function(map) {
          return map === hashMap && pair.removed === undef
        };
        this.equals = function(o) {
          return virtEquals(pair.key, o.getKey())
        };
        this.getKey = function() {
          return pair.key
        };
        this.getValue = function() {
          return pair.value
        };
        this.hashCode = function(o) {
          return virtHashCode(pair.key)
        };
        this.setValue = function(value) {
          var old = pair.value;
          pair.value = value;
          return old
        }
      }
      this.clear = function() {
        count = 0;
        buckets = [];
        buckets.length = initialCapacity
      };
      this.clone = function() {
        var map = new HashMap;
        map.putAll(this);
        return map
      };
      this.containsKey = function(key) {
        var index = getBucketIndex(key);
        var bucket = buckets[index];
        if (bucket === undef) return false;
        for (var i = 0; i < bucket.length; ++i) if (virtEquals(bucket[i].key, key)) return true;
        return false
      };
      this.containsValue = function(value) {
        for (var i = 0; i < buckets.length; ++i) {
          var bucket = buckets[i];
          if (bucket === undef) continue;
          for (var j = 0; j < bucket.length; ++j) if (virtEquals(bucket[j].value, value)) return true
        }
        return false
      };
      this.entrySet = function() {
        return new Set(function(pair) {
          return new Entry(pair)
        },


        function(pair) {
          return pair instanceof Entry && pair._isIn(hashMap)
        },


        function(pair) {
          return hashMap.remove(pair.getKey())
        })
      };
      this.get = function(key) {
        var index = getBucketIndex(key);
        var bucket = buckets[index];
        if (bucket === undef) return null;
        for (var i = 0; i < bucket.length; ++i) if (virtEquals(bucket[i].key, key)) return bucket[i].value;
        return null
      };
      this.isEmpty = function() {
        return count === 0
      };
      this.keySet = function() {
        return new Set(function(pair) {
          return pair.key
        },


        function(key) {
          return hashMap.containsKey(key)
        },


        function(key) {
          return hashMap.remove(key)
        })
      };
      this.values = function() {
        return new Set(function(pair) {
          return pair.value
        },


        function(value) {
          return hashMap.containsValue(value)
        },

        function(value) {
          return hashMap.removeByValue(value)
        })
      };
      this.put = function(key, value) {
        var index = getBucketIndex(key);
        var bucket = buckets[index];
        if (bucket === undef) {
          ++count;
          buckets[index] = [{
            key: key,
            value: value
          }];
          ensureLoad();
          return null
        }
        for (var i = 0; i < bucket.length; ++i) if (virtEquals(bucket[i].key, key)) {
          var previous = bucket[i].value;
          bucket[i].value = value;
          return previous
        }++count;
        bucket.push({
          key: key,
          value: value
        });
        ensureLoad();
        return null
      };
      this.putAll = function(m) {
        var it = m.entrySet().iterator();
        while (it.hasNext()) {
          var entry = it.next();
          this.put(entry.getKey(), entry.getValue())
        }
      };
      this.remove = function(key) {
        var index = getBucketIndex(key);
        var bucket = buckets[index];
        if (bucket === undef) return null;
        for (var i = 0; i < bucket.length; ++i) if (virtEquals(bucket[i].key, key)) {
          --count;
          var previous = bucket[i].value;
          bucket[i].removed = true;
          if (bucket.length > 1) bucket.splice(i, 1);
          else buckets[index] = undef;
          return previous
        }
        return null
      };
      this.removeByValue = function(value) {
        var bucket, i, ilen, pair;
        for (bucket in buckets) if (buckets.hasOwnProperty(bucket)) for (i = 0, ilen = buckets[bucket].length; i < ilen; i++) {
          pair = buckets[bucket][i];
          if (pair.value === value) {
            buckets[bucket].splice(i, 1);
            return true
          }
        }
        return false
      };
      this.size = function() {
        return count
      }
    }
    return HashMap
  }();
  var PVector = function() {
    function PVector(x, y, z) {
      this.x = x || 0;
      this.y = y || 0;
      this.z = z || 0
    }
    PVector.dist = function(v1, v2) {
      return v1.dist(v2)
    };
    PVector.dot = function(v1, v2) {
      return v1.dot(v2)
    };
    PVector.cross = function(v1, v2) {
      return v1.cross(v2)
    };
    PVector.angleBetween = function(v1, v2) {
      return Math.acos(v1.dot(v2) / (v1.mag() * v2.mag()))
    };
    PVector.prototype = {
      set: function(v, y, z) {
        if (arguments.length === 1) this.set(v.x || v[0] || 0, v.y || v[1] || 0, v.z || v[2] || 0);
        else {
          this.x = v;
          this.y = y;
          this.z = z
        }
      },
      get: function() {
        return new PVector(this.x, this.y, this.z)
      },
      mag: function() {
        var x = this.x,
          y = this.y,
          z = this.z;
        return Math.sqrt(x * x + y * y + z * z)
      },
      add: function(v, y, z) {
        if (arguments.length === 1) {
          this.x += v.x;
          this.y += v.y;
          this.z += v.z
        } else {
          this.x += v;
          this.y += y;
          this.z += z
        }
      },
      sub: function(v, y, z) {
        if (arguments.length === 1) {
          this.x -= v.x;
          this.y -= v.y;
          this.z -= v.z
        } else {
          this.x -= v;
          this.y -= y;
          this.z -= z
        }
      },
      mult: function(v) {
        if (typeof v === "number") {
          this.x *= v;
          this.y *= v;
          this.z *= v
        } else {
          this.x *= v.x;
          this.y *= v.y;
          this.z *= v.z
        }
      },
      div: function(v) {
        if (typeof v === "number") {
          this.x /= v;
          this.y /= v;
          this.z /= v
        } else {
          this.x /= v.x;
          this.y /= v.y;
          this.z /= v.z
        }
      },
      dist: function(v) {
        var dx = this.x - v.x,
          dy = this.y - v.y,
          dz = this.z - v.z;
        return Math.sqrt(dx * dx + dy * dy + dz * dz)
      },
      dot: function(v, y, z) {
        if (arguments.length === 1) return this.x * v.x + this.y * v.y + this.z * v.z;
        return this.x * v + this.y * y + this.z * z
      },
      cross: function(v) {
        var x = this.x,
          y = this.y,
          z = this.z;
        return new PVector(y * v.z - v.y * z, z * v.x - v.z * x, x * v.y - v.x * y)
      },
      normalize: function() {
        var m = this.mag();
        if (m > 0) this.div(m)
      },
      limit: function(high) {
        if (this.mag() > high) {
          this.normalize();
          this.mult(high)
        }
      },
      heading2D: function() {
        return -Math.atan2(-this.y, this.x)
      },
      toString: function() {
        return "[" + this.x + ", " + this.y + ", " + this.z + "]"
      },
      array: function() {
        return [this.x, this.y, this.z]
      }
    };

    function createPVectorMethod(method) {
      return function(v1, v2) {
        var v = v1.get();
        v[method](v2);
        return v
      }
    }
    for (var method in PVector.prototype) if (PVector.prototype.hasOwnProperty(method) && !PVector.hasOwnProperty(method)) PVector[method] = createPVectorMethod(method);
    return PVector
  }();

  function DefaultScope() {}
  DefaultScope.prototype = PConstants;
  var defaultScope = new DefaultScope;
  defaultScope.ArrayList = ArrayList;
  defaultScope.HashMap = HashMap;
  defaultScope.PVector = PVector;
  defaultScope.ObjectIterator = ObjectIterator;
  defaultScope.PConstants = PConstants;
  defaultScope.defineProperty = function(obj, name, desc) {
    if ("defineProperty" in Object) Object.defineProperty(obj, name, desc);
    else {
      if (desc.hasOwnProperty("get")) obj.__defineGetter__(name, desc.get);
      if (desc.hasOwnProperty("set")) obj.__defineSetter__(name, desc.set)
    }
  };

  function extendClass(subClass, baseClass) {
    function extendGetterSetter(propertyName) {
      defaultScope.defineProperty(subClass, propertyName, {
        get: function() {
          return baseClass[propertyName]
        },
        set: function(v) {
          baseClass[propertyName] = v
        },
        enumerable: true
      })
    }
    var properties = [];
    for (var propertyName in baseClass) if (typeof baseClass[propertyName] === "function") {
      if (!subClass.hasOwnProperty(propertyName)) subClass[propertyName] = baseClass[propertyName]
    } else if (propertyName.charAt(0) !== "$" && !(propertyName in subClass)) properties.push(propertyName);
    while (properties.length > 0) extendGetterSetter(properties.shift())
  }
  defaultScope.extendClassChain = function(base) {
    var path = [base];
    for (var self = base.$upcast; self; self = self.$upcast) {
      extendClass(self, base);
      path.push(self);
      base = self
    }
    while (path.length > 0) path.pop().$self = base
  };
  defaultScope.extendStaticMembers = function(derived, base) {
    extendClass(derived, base)
  };
  defaultScope.extendInterfaceMembers = function(derived, base) {
    extendClass(derived, base)
  };
  defaultScope.addMethod = function(object, name, fn, superAccessor) {
    if (object[name]) {
      var args = fn.length,
        oldfn = object[name];
      object[name] = function() {
        if (arguments.length === args) return fn.apply(this, arguments);
        return oldfn.apply(this, arguments)
      }
    } else object[name] = fn
  };
  defaultScope.createJavaArray = function(type, bounds) {
    var result = null;
    if (typeof bounds[0] === "number") {
      var itemsCount = 0 | bounds[0];
      if (bounds.length <= 1) {
        result = [];
        result.length = itemsCount;
        for (var i = 0; i < itemsCount; ++i) result[i] = 0
      } else {
        result = [];
        var newBounds = bounds.slice(1);
        for (var j = 0; j < itemsCount; ++j) result.push(defaultScope.createJavaArray(type, newBounds))
      }
    }
    return result
  };
  var colors = {
    aliceblue: "#f0f8ff",
    antiquewhite: "#faebd7",
    aqua: "#00ffff",
    aquamarine: "#7fffd4",
    azure: "#f0ffff",
    beige: "#f5f5dc",
    bisque: "#ffe4c4",
    black: "#000000",
    blanchedalmond: "#ffebcd",
    blue: "#0000ff",
    blueviolet: "#8a2be2",
    brown: "#a52a2a",
    burlywood: "#deb887",
    cadetblue: "#5f9ea0",
    chartreuse: "#7fff00",
    chocolate: "#d2691e",
    coral: "#ff7f50",
    cornflowerblue: "#6495ed",
    cornsilk: "#fff8dc",
    crimson: "#dc143c",
    cyan: "#00ffff",
    darkblue: "#00008b",
    darkcyan: "#008b8b",
    darkgoldenrod: "#b8860b",
    darkgray: "#a9a9a9",
    darkgreen: "#006400",
    darkkhaki: "#bdb76b",
    darkmagenta: "#8b008b",
    darkolivegreen: "#556b2f",
    darkorange: "#ff8c00",
    darkorchid: "#9932cc",
    darkred: "#8b0000",
    darksalmon: "#e9967a",
    darkseagreen: "#8fbc8f",
    darkslateblue: "#483d8b",
    darkslategray: "#2f4f4f",
    darkturquoise: "#00ced1",
    darkviolet: "#9400d3",
    deeppink: "#ff1493",
    deepskyblue: "#00bfff",
    dimgray: "#696969",
    dodgerblue: "#1e90ff",
    firebrick: "#b22222",
    floralwhite: "#fffaf0",
    forestgreen: "#228b22",
    fuchsia: "#ff00ff",
    gainsboro: "#dcdcdc",
    ghostwhite: "#f8f8ff",
    gold: "#ffd700",
    goldenrod: "#daa520",
    gray: "#808080",
    green: "#008000",
    greenyellow: "#adff2f",
    honeydew: "#f0fff0",
    hotpink: "#ff69b4",
    indianred: "#cd5c5c",
    indigo: "#4b0082",
    ivory: "#fffff0",
    khaki: "#f0e68c",
    lavender: "#e6e6fa",
    lavenderblush: "#fff0f5",
    lawngreen: "#7cfc00",
    lemonchiffon: "#fffacd",
    lightblue: "#add8e6",
    lightcoral: "#f08080",
    lightcyan: "#e0ffff",
    lightgoldenrodyellow: "#fafad2",
    lightgrey: "#d3d3d3",
    lightgreen: "#90ee90",
    lightpink: "#ffb6c1",
    lightsalmon: "#ffa07a",
    lightseagreen: "#20b2aa",
    lightskyblue: "#87cefa",
    lightslategray: "#778899",
    lightsteelblue: "#b0c4de",
    lightyellow: "#ffffe0",
    lime: "#00ff00",
    limegreen: "#32cd32",
    linen: "#faf0e6",
    magenta: "#ff00ff",
    maroon: "#800000",
    mediumaquamarine: "#66cdaa",
    mediumblue: "#0000cd",
    mediumorchid: "#ba55d3",
    mediumpurple: "#9370d8",
    mediumseagreen: "#3cb371",
    mediumslateblue: "#7b68ee",
    mediumspringgreen: "#00fa9a",
    mediumturquoise: "#48d1cc",
    mediumvioletred: "#c71585",
    midnightblue: "#191970",
    mintcream: "#f5fffa",
    mistyrose: "#ffe4e1",
    moccasin: "#ffe4b5",
    navajowhite: "#ffdead",
    navy: "#000080",
    oldlace: "#fdf5e6",
    olive: "#808000",
    olivedrab: "#6b8e23",
    orange: "#ffa500",
    orangered: "#ff4500",
    orchid: "#da70d6",
    palegoldenrod: "#eee8aa",
    palegreen: "#98fb98",
    paleturquoise: "#afeeee",
    palevioletred: "#d87093",
    papayawhip: "#ffefd5",
    peachpuff: "#ffdab9",
    peru: "#cd853f",
    pink: "#ffc0cb",
    plum: "#dda0dd",
    powderblue: "#b0e0e6",
    purple: "#800080",
    red: "#ff0000",
    rosybrown: "#bc8f8f",
    royalblue: "#4169e1",
    saddlebrown: "#8b4513",
    salmon: "#fa8072",
    sandybrown: "#f4a460",
    seagreen: "#2e8b57",
    seashell: "#fff5ee",
    sienna: "#a0522d",
    silver: "#c0c0c0",
    skyblue: "#87ceeb",
    slateblue: "#6a5acd",
    slategray: "#708090",
    snow: "#fffafa",
    springgreen: "#00ff7f",
    steelblue: "#4682b4",
    tan: "#d2b48c",
    teal: "#008080",
    thistle: "#d8bfd8",
    tomato: "#ff6347",
    turquoise: "#40e0d0",
    violet: "#ee82ee",
    wheat: "#f5deb3",
    white: "#ffffff",
    whitesmoke: "#f5f5f5",
    yellow: "#ffff00",
    yellowgreen: "#9acd32"
  };
  (function(Processing) {
    var unsupportedP5 = ("open() createOutput() createInput() BufferedReader selectFolder() " + "dataPath() createWriter() selectOutput() beginRecord() " + "saveStream() endRecord() selectInput() saveBytes() createReader() " + "beginRaw() endRaw() PrintWriter delay()").split(" "),
      count = unsupportedP5.length,
      prettyName, p5Name;

    function createUnsupportedFunc(n) {
      return function() {
        throw "Processing.js does not support " + n + ".";
      }
    }
    while (count--) {
      prettyName = unsupportedP5[count];
      p5Name = prettyName.replace("()", "");
      Processing[p5Name] = createUnsupportedFunc(prettyName)
    }
  })(defaultScope);
  defaultScope.defineProperty(defaultScope, "screenWidth", {
    get: function() {
      return window.innerWidth
    }
  });
  defaultScope.defineProperty(defaultScope, "screenHeight", {
    get: function() {
      return window.innerHeight
    }
  });
  var processingInstances = [];
  var processingInstanceIds = {};
  var removeInstance = function(id) {
    processingInstances.splice(processingInstanceIds[id], 1);
    delete processingInstanceIds[id]
  };
  var addInstance = function(processing) {
    if (processing.externals.canvas.id === undef || !processing.externals.canvas.id.length) processing.externals.canvas.id = "__processing" + processingInstances.length;
    processingInstanceIds[processing.externals.canvas.id] = processingInstances.length;
    processingInstances.push(processing)
  };

  function computeFontMetrics(pfont) {
    var emQuad = 250,
      correctionFactor = pfont.size / emQuad,
      canvas = document.createElement("canvas");
    canvas.width = 2 * emQuad;
    canvas.height = 2 * emQuad;
    canvas.style.opacity = 0;
    var cfmFont = pfont.getCSSDefinition(emQuad + "px", "normal"),
      ctx = canvas.getContext("2d");
    ctx.font = cfmFont;
    pfont.context2d = ctx;
    var protrusions = "dbflkhyjqpg";
    canvas.width = ctx.measureText(protrusions).width;
    ctx.font = cfmFont;
    var leadDiv = document.createElement("div");
    leadDiv.style.position = "absolute";
    leadDiv.style.opacity = 0;
    leadDiv.style.fontFamily = '"' + pfont.name + '"';
    leadDiv.style.fontSize = emQuad + "px";
    leadDiv.innerHTML = protrusions + "<br/>" + protrusions;
    document.body.appendChild(leadDiv);
    var w = canvas.width,
      h = canvas.height,
      baseline = h / 2;
    ctx.fillStyle = "white";
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = "black";
    ctx.fillText(protrusions, 0, baseline);
    var pixelData = ctx.getImageData(0, 0, w, h).data;
    var i = 0,
      w4 = w * 4,
      len = pixelData.length;
    while (++i < len && pixelData[i] === 255) nop();
    var ascent = Math.round(i / w4);
    i = len - 1;
    while (--i > 0 && pixelData[i] === 255) nop();
    var descent = Math.round(i / w4);
    pfont.ascent = correctionFactor * (baseline - ascent);
    pfont.descent = correctionFactor * (descent - baseline);
    if (document.defaultView.getComputedStyle) {
      var leadDivHeight = document.defaultView.getComputedStyle(leadDiv, null).getPropertyValue("height");
      leadDivHeight = correctionFactor * leadDivHeight.replace("px", "");
      if (leadDivHeight >= pfont.size * 2) pfont.leading = Math.round(leadDivHeight / 2)
    }
    document.body.removeChild(leadDiv)
  }
  function PFont(name, size) {
    if (name === undef) name = "";
    this.name = name;
    if (size === undef) size = 0;
    this.size = size;
    this.glyph = false;
    this.ascent = 0;
    this.descent = 0;
    this.leading = 1.2 * size;
    var illegalIndicator = name.indexOf(" Italic Bold");
    if (illegalIndicator !== -1) name = name.substring(0, illegalIndicator);
    this.style = "normal";
    var italicsIndicator = name.indexOf(" Italic");
    if (italicsIndicator !== -1) {
      name = name.substring(0, italicsIndicator);
      this.style = "italic"
    }
    this.weight = "normal";
    var boldIndicator = name.indexOf(" Bold");
    if (boldIndicator !== -1) {
      name = name.substring(0, boldIndicator);
      this.weight = "bold"
    }
    this.family = "sans-serif";
    if (name !== undef) switch (name) {
    case "sans-serif":
    case "serif":
    case "monospace":
    case "fantasy":
    case "cursive":
      this.family = name;
      break;
    default:
      this.family = '"' + name + '", sans-serif';
      break
    }
    this.context2d = null;
    computeFontMetrics(this);
    this.css = this.getCSSDefinition();
    this.context2d.font = this.css
  }
  PFont.prototype.getCSSDefinition = function(fontSize, lineHeight) {
    if (fontSize === undef) fontSize = this.size + "px";
    if (lineHeight === undef) lineHeight = this.leading + "px";
    var components = [this.style, "normal", this.weight, fontSize + "/" + lineHeight, this.family];
    return components.join(" ")
  };
  PFont.prototype.measureTextWidth = function(string) {
    return this.context2d.measureText(string).width
  };
  PFont.PFontCache = {};
  PFont.get = function(fontName, fontSize) {
    var cache = PFont.PFontCache;
    var idx = fontName + "/" + fontSize;
    if (!cache[idx]) cache[idx] = new PFont(fontName, fontSize);
    return cache[idx]
  };
  PFont.list = function() {
    return ["sans-serif", "serif", "monospace", "fantasy", "cursive"]
  };
  PFont.preloading = {
    template: {},
    initialized: false,
    initialize: function() {
      var generateTinyFont = function() {
        var encoded = "#E3KAI2wAgT1MvMg7Eo3VmNtYX7ABi3CxnbHlm" + "7Abw3kaGVhZ7ACs3OGhoZWE7A53CRobXR47AY3" + "AGbG9jYQ7G03Bm1heH7ABC3CBuYW1l7Ae3AgcG" + "9zd7AI3AE#B3AQ2kgTY18PPPUACwAg3ALSRoo3" + "#yld0xg32QAB77#E777773B#E3C#I#Q77773E#" + "Q7777777772CMAIw7AB77732B#M#Q3wAB#g3B#" + "E#E2BB//82BB////w#B7#gAEg3E77x2B32B#E#" + "Q#MTcBAQ32gAe#M#QQJ#E32M#QQJ#I#g32Q77#";
        var expand = function(input) {
          return "AAAAAAAA".substr(~~input ? 7 - input : 6)
        };
        return encoded.replace(/[#237]/g, expand)
      };
      var fontface = document.createElement("style");
      fontface.setAttribute("type", "text/css");
      fontface.innerHTML = "@font-face {\n" + '  font-family: "PjsEmptyFont";' + "\n" + "  src: url('data:application/x-font-ttf;base64," + generateTinyFont() + "')\n" + "       format('truetype');\n" + "}";
      document.head.appendChild(fontface);
      var element = document.createElement("span");
      element.style.cssText = 'position: absolute; top: 0; left: 0; opacity: 0; font-family: "PjsEmptyFont", fantasy;';
      element.innerHTML = "AAAAAAAA";
      document.body.appendChild(element);
      this.template = element;
      this.initialized = true
    },
    getElementWidth: function(element) {
      return document.defaultView.getComputedStyle(element, "").getPropertyValue("width")
    },
    timeAttempted: 0,
    pending: function(intervallength) {
      if (!this.initialized) this.initialize();
      var element, computedWidthFont, computedWidthRef = this.getElementWidth(this.template);
      for (var i = 0; i < this.fontList.length; i++) {
        element = this.fontList[i];
        computedWidthFont = this.getElementWidth(element);
        if (this.timeAttempted < 4E3 && computedWidthFont === computedWidthRef) {
          this.timeAttempted += intervallength;
          return true
        } else {
          document.body.removeChild(element);
          this.fontList.splice(i--, 1);
          this.timeAttempted = 0
        }
      }
      if (this.fontList.length === 0) return false;
      return true
    },
    fontList: [],
    addedList: {},
    add: function(fontSrc) {
      if (!this.initialized) this.initialize();
      var fontName = typeof fontSrc === "object" ? fontSrc.fontFace : fontSrc,
      fontUrl = typeof fontSrc === "object" ? fontSrc.url : fontSrc;
      if (this.addedList[fontName]) return;
      var style = document.createElement("style");
      style.setAttribute("type", "text/css");
      style.innerHTML = "@font-face{\n  font-family: '" + fontName + "';\n  src:  url('" + fontUrl + "');\n}\n";
      document.head.appendChild(style);
      this.addedList[fontName] = true;
      var element = document.createElement("span");
      element.style.cssText = "position: absolute; top: 0; left: 0; opacity: 0;";
      element.style.fontFamily = '"' + fontName + '", "PjsEmptyFont", fantasy';
      element.innerHTML = "AAAAAAAA";
      document.body.appendChild(element);
      this.fontList.push(element)
    }
  };
  defaultScope.PFont = PFont;
  var Processing = this.Processing = function(aCanvas, aCode) {
    if (! (this instanceof Processing)) throw "called Processing constructor as if it were a function: missing 'new'.";
    var curElement, pgraphicsMode = aCanvas === undef && aCode === undef;
    if (pgraphicsMode) curElement = document.createElement("canvas");
    else curElement = typeof aCanvas === "string" ? document.getElementById(aCanvas) : aCanvas;
    if (! (curElement instanceof HTMLCanvasElement)) throw "called Processing constructor without passing canvas element reference or id.";

    function unimplemented(s) {
      Processing.debug("Unimplemented - " + s)
    }
    var p = this;
    p.externals = {
      canvas: curElement,
      context: undef,
      sketch: undef
    };
    p.name = "Processing.js Instance";
    p.use3DContext = false;
    p.focused = false;
    p.breakShape = false;
    p.glyphTable = {};
    p.pmouseX = 0;
    p.pmouseY = 0;
    p.mouseX = 0;
    p.mouseY = 0;
    p.mouseButton = 0;
    p.mouseScroll = 0;
    p.mouseClicked = undef;
    p.mouseDragged = undef;
    p.mouseMoved = undef;
    p.mousePressed = undef;
    p.mouseReleased = undef;
    p.mouseScrolled = undef;
    p.mouseOver = undef;
    p.mouseOut = undef;
    p.touchStart = undef;
    p.touchEnd = undef;
    p.touchMove = undef;
    p.touchCancel = undef;
    p.key = undef;
    p.keyCode = undef;
    p.keyPressed = nop;
    p.keyReleased = nop;
    p.keyTyped = nop;
    p.draw = undef;
    p.setup = undef;
    p.__mousePressed = false;
    p.__keyPressed = false;
    p.__frameRate = 60;
    p.frameCount = 0;
    p.width = 100;
    p.height = 100;
    var curContext, curSketch, drawing, online = true,
      doFill = true,
      fillStyle = [1, 1, 1, 1],
      currentFillColor = 4294967295,
      isFillDirty = true,
      doStroke = true,
      strokeStyle = [0, 0, 0, 1],
      currentStrokeColor = 4278190080,
      isStrokeDirty = true,
      lineWidth = 1,
      loopStarted = false,
      renderSmooth = false,
      doLoop = true,
      looping = 0,
      curRectMode = 0,
      curEllipseMode = 3,
      normalX = 0,
      normalY = 0,
      normalZ = 0,
      normalMode = 0,
      curFrameRate = 60,
      curMsPerFrame = 1E3 / curFrameRate,
      curCursor = 'default',
      oldCursor = curElement.style.cursor,
      curShape = 20,
      curShapeCount = 0,
      curvePoints = [],
      curTightness = 0,
      curveDet = 20,
      curveInited = false,
      backgroundObj = -3355444,
      bezDetail = 20,
      colorModeA = 255,
      colorModeX = 255,
      colorModeY = 255,
      colorModeZ = 255,
      pathOpen = false,
      mouseDragging = false,
      pmouseXLastFrame = 0,
      pmouseYLastFrame = 0,
      curColorMode = 1,
      curTint = null,
      curTint3d = null,
      getLoaded = false,
      start = Date.now(),
      timeSinceLastFPS = start,
      framesSinceLastFPS = 0,
      textcanvas, curveBasisMatrix, curveToBezierMatrix, curveDrawMatrix, bezierDrawMatrix, bezierBasisInverse, bezierBasisMatrix, curContextCache = {
      attributes: {},
      locations: {}
    },
      programObject3D, programObject2D, programObjectUnlitShape, boxBuffer, boxNormBuffer, boxOutlineBuffer, rectBuffer, rectNormBuffer, sphereBuffer, lineBuffer, fillBuffer, fillColorBuffer, strokeColorBuffer, pointBuffer, shapeTexVBO, canTex, textTex, curTexture = {
      width: 0,
      height: 0
    },
      curTextureMode = 2,
      usingTexture = false,
      textBuffer, textureBuffer, indexBuffer, horizontalTextAlignment = 37,
      verticalTextAlignment = 0,
      textMode = 4,
      curFontName = "Arial",
      curTextSize = 12,
      curTextAscent = 9,
      curTextDescent = 2,
      curTextLeading = 14,
      curTextFont = PFont.get(curFontName, curTextSize),
      originalContext, proxyContext = null,
      isContextReplaced = false,
      setPixelsCached, maxPixelsCached = 1E3,
      pressedKeysMap = [],
      lastPressedKeyCode = null,
      codedKeys = [16, 17, 18, 20, 33, 34, 35, 36, 37, 38, 39, 40, 144, 155, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 157];
    var stylePaddingLeft, stylePaddingTop, styleBorderLeft, styleBorderTop;
    if (document.defaultView && document.defaultView.getComputedStyle) {
      stylePaddingLeft = parseInt(document.defaultView.getComputedStyle(curElement, null)["paddingLeft"], 10) || 0;
      stylePaddingTop = parseInt(document.defaultView.getComputedStyle(curElement, null)["paddingTop"], 10) || 0;
      styleBorderLeft = parseInt(document.defaultView.getComputedStyle(curElement, null)["borderLeftWidth"], 10) || 0;
      styleBorderTop = parseInt(document.defaultView.getComputedStyle(curElement, null)["borderTopWidth"], 10) || 0
    }
    var lightCount = 0;
    var sphereDetailV = 0,
      sphereDetailU = 0,
      sphereX = [],
      sphereY = [],
      sphereZ = [],
      sinLUT = new Float32Array(720),
      cosLUT = new Float32Array(720),
      sphereVerts, sphereNorms;
    var cam, cameraInv, modelView, modelViewInv, userMatrixStack, userReverseMatrixStack, inverseCopy, projection, manipulatingCamera = false,
      frustumMode = false,
      cameraFOV = 60 * (Math.PI / 180),
      cameraX = p.width / 2,
      cameraY = p.height / 2,
      cameraZ = cameraY / Math.tan(cameraFOV / 2),
      cameraNear = cameraZ / 10,
      cameraFar = cameraZ * 10,
      cameraAspect = p.width / p.height;
    var vertArray = [],
      curveVertArray = [],
      curveVertCount = 0,
      isCurve = false,
      isBezier = false,
      firstVert = true;
    var curShapeMode = 0;
    var styleArray = [];
    var boxVerts = new Float32Array([0.5, 0.5, -0.5, 0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, -0.5, 0.5,
      -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5, -0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5]);
    var boxOutlineVerts = new Float32Array([0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, -0.5, 0.5, -0.5, -0.5, -0.5, 0.5, -0.5, -0.5, -0.5, -0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5,
      0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5]);
    var boxNorms = new Float32Array([0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]);
    var rectVerts = new Float32Array([0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0]);
    var rectNorms = new Float32Array([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]);
    var vShaderSrcUnlitShape = "varying vec4 frontColor;" + "attribute vec3 aVertex;" + "attribute vec4 aColor;" + "uniform mat4 uView;" + "uniform mat4 uProjection;" + "uniform float pointSize;" + "void main(void) {" + "  frontColor = aColor;" + "  gl_PointSize = pointSize;" + "  gl_Position = uProjection * uView * vec4(aVertex, 1.0);" + "}";
    var fShaderSrcUnlitShape = "#ifdef GL_ES\n" + "precision highp float;\n" + "#endif\n" + "varying vec4 frontColor;" + "void main(void){" + "  gl_FragColor = frontColor;" + "}";
    var vertexShaderSource2D = "varying vec4 frontColor;" + "attribute vec3 Vertex;" + "attribute vec2 aTextureCoord;" + "uniform vec4 color;" + "uniform mat4 model;" + "uniform mat4 view;" + "uniform mat4 projection;" + "uniform float pointSize;" + "varying vec2 vTextureCoord;" + "void main(void) {" + "  gl_PointSize = pointSize;" + "  frontColor = color;" + "  gl_Position = projection * view * model * vec4(Vertex, 1.0);" + "  vTextureCoord = aTextureCoord;" + "}";
    var fragmentShaderSource2D = "#ifdef GL_ES\n" + "precision highp float;\n" + "#endif\n" + "varying vec4 frontColor;" + "varying vec2 vTextureCoord;" + "uniform sampler2D uSampler;" + "uniform int picktype;" + "void main(void){" + "  if(picktype == 0){" + "    gl_FragColor = frontColor;" + "  }" + "  else if(picktype == 1){" + "    float alpha = texture2D(uSampler, vTextureCoord).a;" + "    gl_FragColor = vec4(frontColor.rgb*alpha, alpha);\n" + "  }" + "}";
    var webglMaxTempsWorkaround = /Windows/.test(navigator.userAgent);
    var vertexShaderSource3D = "varying vec4 frontColor;" + "attribute vec3 Vertex;" + "attribute vec3 Normal;" + "attribute vec4 aColor;" + "attribute vec2 aTexture;" + "varying   vec2 vTexture;" + "uniform vec4 color;" + "uniform bool usingMat;" + "uniform vec3 specular;" + "uniform vec3 mat_emissive;" + "uniform vec3 mat_ambient;" + "uniform vec3 mat_specular;" + "uniform float shininess;" + "uniform mat4 model;" + "uniform mat4 view;" + "uniform mat4 projection;" + "uniform mat4 normalTransform;" + "uniform int lightCount;" + "uniform vec3 falloff;" + "struct Light {" + "  int type;" + "  vec3 color;" + "  vec3 position;" + "  vec3 direction;" + "  float angle;" + "  vec3 halfVector;" + "  float concentration;" + "};" + "uniform Light lights0;" + "uniform Light lights1;" + "uniform Light lights2;" + "uniform Light lights3;" + "uniform Light lights4;" + "uniform Light lights5;" + "uniform Light lights6;" + "uniform Light lights7;" + "Light getLight(int index){" + "  if(index == 0) return lights0;" + "  if(index == 1) return lights1;" + "  if(index == 2) return lights2;" + "  if(index == 3) return lights3;" + "  if(index == 4) return lights4;" + "  if(index == 5) return lights5;" + "  if(index == 6) return lights6;" + "  return lights7;" + "}" + "void AmbientLight( inout vec3 totalAmbient, in vec3 ecPos, in Light light ) {" + "  float d = length( light.position - ecPos );" + "  float attenuation = 1.0 / ( falloff[0] + ( falloff[1] * d ) + ( falloff[2] * d * d ));" + "  totalAmbient += light.color * attenuation;" + "}" + "void DirectionalLight( inout vec3 col, inout vec3 spec, in vec3 vertNormal, in vec3 ecPos, in Light light ) {" + "  float powerfactor = 0.0;" + "  float nDotVP = max(0.0, dot( vertNormal, normalize(-light.position) ));" + "  float nDotVH = max(0.0, dot( vertNormal, normalize(-light.position-normalize(ecPos) )));" + "  if( nDotVP != 0.0 ){" + "    powerfactor = pow( nDotVH, shininess );" + "  }" + "  col += light.color * nDotVP;" + "  spec += specular * powerfactor;" + "}" + "void PointLight( inout vec3 col, inout vec3 spec, in vec3 vertNormal, in vec3 ecPos, in Light light ) {" + "  float powerfactor;" + "   vec3 VP = light.position - ecPos;" + "  float d = length( VP ); " + "  VP = normalize( VP );" + "  float attenuation = 1.0 / ( falloff[0] + ( falloff[1] * d ) + ( falloff[2] * d * d ));" + "  float nDotVP = max( 0.0, dot( vertNormal, VP ));" + "  vec3 halfVector = normalize( VP - normalize(ecPos) );" + "  float nDotHV = max( 0.0, dot( vertNormal, halfVector ));" + "  if( nDotVP == 0.0) {" + "    powerfactor = 0.0;" + "  }" + "  else{" + "    powerfactor = pow( nDotHV, shininess );" + "  }" + "  spec += specular * powerfactor * attenuation;" + "  col += light.color * nDotVP * attenuation;" + "}" + "void SpotLight( inout vec3 col, inout vec3 spec, in vec3 vertNormal, in vec3 ecPos, in Light light ) {" + "  float spotAttenuation;" + "  float powerfactor;" + "  vec3 VP = light.position - ecPos; " + "  vec3 ldir = normalize( -light.direction );" + "  float d = length( VP );" + "  VP = normalize( VP );" + "  float attenuation = 1.0 / ( falloff[0] + ( falloff[1] * d ) + ( falloff[2] * d * d ) );" + "  float spotDot = dot( VP, ldir );" + (webglMaxTempsWorkaround ? "  spotAttenuation = 1.0; " : "  if( spotDot > cos( light.angle ) ) {" + "    spotAttenuation = pow( spotDot, light.concentration );" + "  }" + "  else{" + "    spotAttenuation = 0.0;" + "  }" + "  attenuation *= spotAttenuation;" + "") + "  float nDotVP = max( 0.0, dot( vertNormal, VP ));" + "  vec3 halfVector = normalize( VP - normalize(ecPos) );" + "  float nDotHV = max( 0.0, dot( vertNormal, halfVector ));" + "  if( nDotVP == 0.0 ) {" + "    powerfactor = 0.0;" + "  }" + "  else {" + "    powerfactor = pow( nDotHV, shininess );" + "  }" + "  spec += specular * powerfactor * attenuation;" + "  col += light.color * nDotVP * attenuation;" + "}" + "void main(void) {" + "  vec3 finalAmbient = vec3( 0.0, 0.0, 0.0 );" + "  vec3 finalDiffuse = vec3( 0.0, 0.0, 0.0 );" + "  vec3 finalSpecular = vec3( 0.0, 0.0, 0.0 );" + "  vec4 col = color;" + "  if(color[0] == -1.0){" + "    col = aColor;" + "  }" + "  vec3 norm = normalize(vec3( normalTransform * vec4( Normal, 0.0 ) ));" + "  vec4 ecPos4 = view * model * vec4(Vertex,1.0);" + "  vec3 ecPos = (vec3(ecPos4))/ecPos4.w;" + "  if( lightCount == 0 ) {" + "    frontColor = col + vec4(mat_specular,1.0);" + "  }" + "  else {" + "    for( int i = 0; i < 8; i++ ) {" + "      Light l = getLight(i);" + "      if( i >= lightCount ){" + "        break;" + "      }" + "      if( l.type == 0 ) {" + "        AmbientLight( finalAmbient, ecPos, l );" + "      }" + "      else if( l.type == 1 ) {" + "        DirectionalLight( finalDiffuse, finalSpecular, norm, ecPos, l );" + "      }" + "      else if( l.type == 2 ) {" + "        PointLight( finalDiffuse, finalSpecular, norm, ecPos, l );" + "      }" + "      else {" + "        SpotLight( finalDiffuse, finalSpecular, norm, ecPos, l );" + "      }" + "    }" + "   if( usingMat == false ) {" + "     frontColor = vec4(" + "       vec3(col) * finalAmbient +" + "       vec3(col) * finalDiffuse +" + "       vec3(col) * finalSpecular," + "       col[3] );" + "   }" + "   else{" + "     frontColor = vec4( " + "       mat_emissive + " + "       (vec3(col) * mat_ambient * finalAmbient) + " + "       (vec3(col) * finalDiffuse) + " + "       (mat_specular * finalSpecular), " + "       col[3] );" + "    }" + "  }" + "  vTexture.xy = aTexture.xy;" + "  gl_Position = projection * view * model * vec4( Vertex, 1.0 );" + "}";
    var fragmentShaderSource3D = "#ifdef GL_ES\n" + "precision highp float;\n" + "#endif\n" + "varying vec4 frontColor;" + "uniform sampler2D sampler;" + "uniform bool usingTexture;" + "varying vec2 vTexture;" + "void main(void){" + "  if(usingTexture){" + "    gl_FragColor = vec4(texture2D(sampler, vTexture.xy)) * frontColor;" + "  }" + "  else{" + "    gl_FragColor = frontColor;" + "  }" + "}";

    function uniformf(cacheId, programObj, varName, varValue) {
      var varLocation = curContextCache.locations[cacheId];
      if (varLocation === undef) {
        varLocation = curContext.getUniformLocation(programObj, varName);
        curContextCache.locations[cacheId] = varLocation
      }
      if (varLocation !== null) if (varValue.length === 4) curContext.uniform4fv(varLocation, varValue);
      else if (varValue.length === 3) curContext.uniform3fv(varLocation, varValue);
      else if (varValue.length === 2) curContext.uniform2fv(varLocation, varValue);
      else curContext.uniform1f(varLocation, varValue)
    }
    function uniformi(cacheId, programObj, varName, varValue) {
      var varLocation = curContextCache.locations[cacheId];
      if (varLocation === undef) {
        varLocation = curContext.getUniformLocation(programObj, varName);
        curContextCache.locations[cacheId] = varLocation
      }
      if (varLocation !== null) if (varValue.length === 4) curContext.uniform4iv(varLocation, varValue);
      else if (varValue.length === 3) curContext.uniform3iv(varLocation, varValue);
      else if (varValue.length === 2) curContext.uniform2iv(varLocation, varValue);
      else curContext.uniform1i(varLocation, varValue)
    }
    function uniformMatrix(cacheId, programObj, varName, transpose, matrix) {
      var varLocation = curContextCache.locations[cacheId];
      if (varLocation === undef) {
        varLocation = curContext.getUniformLocation(programObj, varName);
        curContextCache.locations[cacheId] = varLocation
      }
      if (varLocation !== -1) if (matrix.length === 16) curContext.uniformMatrix4fv(varLocation, transpose, matrix);
      else if (matrix.length === 9) curContext.uniformMatrix3fv(varLocation, transpose, matrix);
      else curContext.uniformMatrix2fv(varLocation, transpose, matrix)
    }
    function vertexAttribPointer(cacheId, programObj, varName, size, VBO) {
      var varLocation = curContextCache.attributes[cacheId];
      if (varLocation === undef) {
        varLocation = curContext.getAttribLocation(programObj, varName);
        curContextCache.attributes[cacheId] = varLocation
      }
      if (varLocation !== -1) {
        curContext.bindBuffer(curContext.ARRAY_BUFFER, VBO);
        curContext.vertexAttribPointer(varLocation, size, curContext.FLOAT, false, 0, 0);
        curContext.enableVertexAttribArray(varLocation)
      }
    }
    function disableVertexAttribPointer(cacheId, programObj, varName) {
      var varLocation = curContextCache.attributes[cacheId];
      if (varLocation === undef) {
        varLocation = curContext.getAttribLocation(programObj, varName);
        curContextCache.attributes[cacheId] = varLocation
      }
      if (varLocation !== -1) curContext.disableVertexAttribArray(varLocation)
    }
    var createProgramObject = function(curContext, vetexShaderSource, fragmentShaderSource) {
      var vertexShaderObject = curContext.createShader(curContext.VERTEX_SHADER);
      curContext.shaderSource(vertexShaderObject, vetexShaderSource);
      curContext.compileShader(vertexShaderObject);
      if (!curContext.getShaderParameter(vertexShaderObject, curContext.COMPILE_STATUS)) throw curContext.getShaderInfoLog(vertexShaderObject);
      var fragmentShaderObject = curContext.createShader(curContext.FRAGMENT_SHADER);
      curContext.shaderSource(fragmentShaderObject, fragmentShaderSource);
      curContext.compileShader(fragmentShaderObject);
      if (!curContext.getShaderParameter(fragmentShaderObject, curContext.COMPILE_STATUS)) throw curContext.getShaderInfoLog(fragmentShaderObject);
      var programObject = curContext.createProgram();
      curContext.attachShader(programObject, vertexShaderObject);
      curContext.attachShader(programObject, fragmentShaderObject);
      curContext.linkProgram(programObject);
      if (!curContext.getProgramParameter(programObject, curContext.LINK_STATUS)) throw "Error linking shaders.";
      return programObject
    };
    var imageModeCorner = function(x, y, w, h, whAreSizes) {
      return {
        x: x,
        y: y,
        w: w,
        h: h
      }
    };
    var imageModeConvert = imageModeCorner;
    var imageModeCorners = function(x, y, w, h, whAreSizes) {
      return {
        x: x,
        y: y,
        w: whAreSizes ? w : w - x,
        h: whAreSizes ? h : h - y
      }
    };
    var imageModeCenter = function(x, y, w, h, whAreSizes) {
      return {
        x: x - w / 2,
        y: y - h / 2,
        w: w,
        h: h
      }
    };
    var DrawingShared = function() {};
    var Drawing2D = function() {};
    var Drawing3D = function() {};
    var DrawingPre = function() {};
    Drawing2D.prototype = new DrawingShared;
    Drawing2D.prototype.constructor = Drawing2D;
    Drawing3D.prototype = new DrawingShared;
    Drawing3D.prototype.constructor = Drawing3D;
    DrawingPre.prototype = new DrawingShared;
    DrawingPre.prototype.constructor = DrawingPre;
    DrawingShared.prototype.a3DOnlyFunction = nop;
    var charMap = {};
    var Char = p.Character = function(chr) {
      if (typeof chr === "string" && chr.length === 1) this.code = chr.charCodeAt(0);
      else if (typeof chr === "number") this.code = chr;
      else if (chr instanceof Char) this.code = chr;
      else this.code = NaN;
      return charMap[this.code] === undef ? charMap[this.code] = this : charMap[this.code]
    };
    Char.prototype.toString = function() {
      return String.fromCharCode(this.code)
    };
    Char.prototype.valueOf = function() {
      return this.code
    };
    var PShape = p.PShape = function(family) {
      this.family = family || 0;
      this.visible = true;
      this.style = true;
      this.children = [];
      this.nameTable = [];
      this.params = [];
      this.name = "";
      this.image = null;
      this.matrix = null;
      this.kind = null;
      this.close = null;
      this.width = null;
      this.height = null;
      this.parent = null
    };
    PShape.prototype = {
      isVisible: function() {
        return this.visible
      },
      setVisible: function(visible) {
        this.visible = visible
      },
      disableStyle: function() {
        this.style = false;
        for (var i = 0, j = this.children.length; i < j; i++) this.children[i].disableStyle()
      },
      enableStyle: function() {
        this.style = true;
        for (var i = 0, j = this.children.length; i < j; i++) this.children[i].enableStyle()
      },
      getFamily: function() {
        return this.family
      },
      getWidth: function() {
        return this.width
      },
      getHeight: function() {
        return this.height
      },
      setName: function(name) {
        this.name = name
      },
      getName: function() {
        return this.name
      },
      draw: function() {
        if (this.visible) {
          this.pre();
          this.drawImpl();
          this.post()
        }
      },
      drawImpl: function() {
        if (this.family === 0) this.drawGroup();
        else if (this.family === 1) this.drawPrimitive();
        else if (this.family === 3) this.drawGeometry();
        else if (this.family === 21) this.drawPath()
      },
      drawPath: function() {
        var i, j;
        if (this.vertices.length === 0) return;
        p.beginShape();
        if (this.vertexCodes.length === 0) if (this.vertices[0].length === 2) for (i = 0, j = this.vertices.length; i < j; i++) p.vertex(this.vertices[i][0], this.vertices[i][1]);
        else for (i = 0, j = this.vertices.length; i < j; i++) p.vertex(this.vertices[i][0], this.vertices[i][1], this.vertices[i][2]);
        else {
          var index = 0;
          if (this.vertices[0].length === 2) for (i = 0, j = this.vertexCodes.length; i < j; i++) if (this.vertexCodes[i] === 0) {
            p.vertex(this.vertices[index][0], this.vertices[index][1]);
            if (this.vertices[index]["moveTo"] === true) vertArray[vertArray.length - 1]["moveTo"] = true;
            else if (this.vertices[index]["moveTo"] === false) vertArray[vertArray.length - 1]["moveTo"] = false;
            p.breakShape = false;
            index++
          } else if (this.vertexCodes[i] === 1) {
            p.bezierVertex(this.vertices[index + 0][0], this.vertices[index + 0][1], this.vertices[index + 1][0], this.vertices[index + 1][1], this.vertices[index + 2][0], this.vertices[index + 2][1]);
            index += 3
          } else if (this.vertexCodes[i] === 2) {
            p.curveVertex(this.vertices[index][0], this.vertices[index][1]);
            index++
          } else {
            if (this.vertexCodes[i] === 3) p.breakShape = true
          } else for (i = 0, j = this.vertexCodes.length; i < j; i++) if (this.vertexCodes[i] === 0) {
            p.vertex(this.vertices[index][0], this.vertices[index][1], this.vertices[index][2]);
            if (this.vertices[index]["moveTo"] === true) vertArray[vertArray.length - 1]["moveTo"] = true;
            else if (this.vertices[index]["moveTo"] === false) vertArray[vertArray.length - 1]["moveTo"] = false;
            p.breakShape = false
          } else if (this.vertexCodes[i] === 1) {
            p.bezierVertex(this.vertices[index + 0][0], this.vertices[index + 0][1], this.vertices[index + 0][2], this.vertices[index + 1][0], this.vertices[index + 1][1], this.vertices[index + 1][2], this.vertices[index + 2][0], this.vertices[index + 2][1], this.vertices[index + 2][2]);
            index += 3
          } else if (this.vertexCodes[i] === 2) {
            p.curveVertex(this.vertices[index][0], this.vertices[index][1], this.vertices[index][2]);
            index++
          } else if (this.vertexCodes[i] === 3) p.breakShape = true
        }
        p.endShape(this.close ? 2 : 1)
      },
      drawGeometry: function() {
        var i, j;
        p.beginShape(this.kind);
        if (this.style) for (i = 0, j = this.vertices.length; i < j; i++) p.vertex(this.vertices[i]);
        else for (i = 0, j = this.vertices.length; i < j; i++) {
          var vert = this.vertices[i];
          if (vert[2] === 0) p.vertex(vert[0], vert[1]);
          else p.vertex(vert[0], vert[1], vert[2])
        }
        p.endShape()
      },
      drawGroup: function() {
        for (var i = 0, j = this.children.length; i < j; i++) this.children[i].draw()
      },
      drawPrimitive: function() {
        if (this.kind === 2) p.point(this.params[0], this.params[1]);
        else if (this.kind === 4) if (this.params.length === 4) p.line(this.params[0], this.params[1], this.params[2], this.params[3]);
        else p.line(this.params[0], this.params[1], this.params[2], this.params[3], this.params[4], this.params[5]);
        else if (this.kind === 8) p.triangle(this.params[0], this.params[1], this.params[2], this.params[3], this.params[4], this.params[5]);
        else if (this.kind === 16) p.quad(this.params[0], this.params[1], this.params[2], this.params[3], this.params[4], this.params[5], this.params[6], this.params[7]);
        else if (this.kind === 30) if (this.image !== null) {
          p.imageMode(0);
          p.image(this.image, this.params[0], this.params[1], this.params[2], this.params[3])
        } else {
          p.rectMode(0);
          p.rect(this.params[0], this.params[1], this.params[2], this.params[3])
        } else if (this.kind === 31) {
          p.ellipseMode(0);
          p.ellipse(this.params[0], this.params[1], this.params[2], this.params[3])
        } else if (this.kind === 32) {
          p.ellipseMode(0);
          p.arc(this.params[0], this.params[1], this.params[2], this.params[3], this.params[4], this.params[5])
        } else if (this.kind === 41) if (this.params.length === 1) p.box(this.params[0]);
        else p.box(this.params[0], this.params[1], this.params[2]);
        else if (this.kind === 40) p.sphere(this.params[0])
      },
      pre: function() {
        if (this.matrix) {
          p.pushMatrix();
          curContext.transform(this.matrix.elements[0], this.matrix.elements[3], this.matrix.elements[1], this.matrix.elements[4], this.matrix.elements[2], this.matrix.elements[5])
        }
        if (this.style) {
          p.pushStyle();
          this.styles()
        }
      },
      post: function() {
        if (this.matrix) p.popMatrix();
        if (this.style) p.popStyle()
      },
      styles: function() {
        if (this.stroke) {
          p.stroke(this.strokeColor);
          p.strokeWeight(this.strokeWeight);
          p.strokeCap(this.strokeCap);
          p.strokeJoin(this.strokeJoin)
        } else p.noStroke();
        if (this.fill) p.fill(this.fillColor);
        else p.noFill()
      },
      getChild: function(child) {
        var i, j;
        if (typeof child === "number") return this.children[child];
        var found;
        if (child === "" || this.name === child) return this;
        if (this.nameTable.length > 0) {
          for (i = 0, j = this.nameTable.length; i < j || found; i++) if (this.nameTable[i].getName === child) {
            found = this.nameTable[i];
            break
          }
          if (found) return found
        }
        for (i = 0, j = this.children.length; i < j; i++) {
          found = this.children[i].getChild(child);
          if (found) return found
        }
        return null
      },
      getChildCount: function() {
        return this.children.length
      },
      addChild: function(child) {
        this.children.push(child);
        child.parent = this;
        if (child.getName() !== null) this.addName(child.getName(), child)
      },
      addName: function(name, shape) {
        if (this.parent !== null) this.parent.addName(name, shape);
        else this.nameTable.push([name, shape])
      },
      translate: function() {
        if (arguments.length === 2) {
          this.checkMatrix(2);
          this.matrix.translate(arguments[0], arguments[1])
        } else {
          this.checkMatrix(3);
          this.matrix.translate(arguments[0], arguments[1], 0)
        }
      },
      checkMatrix: function(dimensions) {
        if (this.matrix === null) if (dimensions === 2) this.matrix = new p.PMatrix2D;
        else this.matrix = new p.PMatrix3D;
        else if (dimensions === 3 && this.matrix instanceof p.PMatrix2D) this.matrix = new p.PMatrix3D
      },
      rotateX: function(angle) {
        this.rotate(angle, 1, 0, 0)
      },
      rotateY: function(angle) {
        this.rotate(angle, 0, 1, 0)
      },
      rotateZ: function(angle) {
        this.rotate(angle, 0, 0, 1)
      },
      rotate: function() {
        if (arguments.length === 1) {
          this.checkMatrix(2);
          this.matrix.rotate(arguments[0])
        } else {
          this.checkMatrix(3);
          this.matrix.rotate(arguments[0], arguments[1], arguments[2], arguments[3])
        }
      },
      scale: function() {
        if (arguments.length === 2) {
          this.checkMatrix(2);
          this.matrix.scale(arguments[0], arguments[1])
        } else if (arguments.length === 3) {
          this.checkMatrix(2);
          this.matrix.scale(arguments[0], arguments[1], arguments[2])
        } else {
          this.checkMatrix(2);
          this.matrix.scale(arguments[0])
        }
      },
      resetMatrix: function() {
        this.checkMatrix(2);
        this.matrix.reset()
      },
      applyMatrix: function(matrix) {
        if (arguments.length === 1) this.applyMatrix(matrix.elements[0], matrix.elements[1], 0, matrix.elements[2], matrix.elements[3], matrix.elements[4], 0, matrix.elements[5], 0, 0, 1, 0, 0, 0, 0, 1);
        else if (arguments.length === 6) {
          this.checkMatrix(2);
          this.matrix.apply(arguments[0], arguments[1], arguments[2], 0, arguments[3], arguments[4], arguments[5], 0, 0, 0, 1, 0, 0, 0, 0, 1)
        } else if (arguments.length === 16) {
          this.checkMatrix(3);
          this.matrix.apply(arguments[0], arguments[1], arguments[2], arguments[3], arguments[4], arguments[5], arguments[6], arguments[7], arguments[8], arguments[9], arguments[10], arguments[11], arguments[12], arguments[13], arguments[14], arguments[15])
        }
      }
    };
    var PShapeSVG = p.PShapeSVG = function() {
      p.PShape.call(this);
      if (arguments.length === 1) {
        this.element = arguments[0];
        this.vertexCodes = [];
        this.vertices = [];
        this.opacity = 1;
        this.stroke = false;
        this.strokeColor = 4278190080;
        this.strokeWeight = 1;
        this.strokeCap = 'butt';
        this.strokeJoin = 'miter';
        this.strokeGradient = null;
        this.strokeGradientPaint = null;
        this.strokeName = null;
        this.strokeOpacity = 1;
        this.fill = true;
        this.fillColor = 4278190080;
        this.fillGradient = null;
        this.fillGradientPaint = null;
        this.fillName = null;
        this.fillOpacity = 1;
        if (this.element.getName() !== "svg") throw "root is not <svg>, it's <" + this.element.getName() + ">";
      } else if (arguments.length === 2) if (typeof arguments[1] === "string") {
        if (arguments[1].indexOf(".svg") > -1) {
          this.element = new p.XMLElement(null, arguments[1]);
          this.vertexCodes = [];
          this.vertices = [];
          this.opacity = 1;
          this.stroke = false;
          this.strokeColor = 4278190080;
          this.strokeWeight = 1;
          this.strokeCap = 'butt';
          this.strokeJoin = 'miter';
          this.strokeGradient = "";
          this.strokeGradientPaint = "";
          this.strokeName = "";
          this.strokeOpacity = 1;
          this.fill = true;
          this.fillColor = 4278190080;
          this.fillGradient = null;
          this.fillGradientPaint = null;
          this.fillOpacity = 1
        }
      } else if (arguments[0]) {
        this.element = arguments[1];
        this.vertexCodes = arguments[0].vertexCodes.slice();
        this.vertices = arguments[0].vertices.slice();
        this.stroke = arguments[0].stroke;
        this.strokeColor = arguments[0].strokeColor;
        this.strokeWeight = arguments[0].strokeWeight;
        this.strokeCap = arguments[0].strokeCap;
        this.strokeJoin = arguments[0].strokeJoin;
        this.strokeGradient = arguments[0].strokeGradient;
        this.strokeGradientPaint = arguments[0].strokeGradientPaint;
        this.strokeName = arguments[0].strokeName;
        this.fill = arguments[0].fill;
        this.fillColor = arguments[0].fillColor;
        this.fillGradient = arguments[0].fillGradient;
        this.fillGradientPaint = arguments[0].fillGradientPaint;
        this.fillName = arguments[0].fillName;
        this.strokeOpacity = arguments[0].strokeOpacity;
        this.fillOpacity = arguments[0].fillOpacity;
        this.opacity = arguments[0].opacity
      }
      this.name = this.element.getStringAttribute("id");
      var displayStr = this.element.getStringAttribute("display", "inline");
      this.visible = displayStr !== "none";
      var str = this.element.getAttribute("transform");
      if (str) this.matrix = this.parseMatrix(str);
      var viewBoxStr = this.element.getStringAttribute("viewBox");
      if (viewBoxStr !== null) {
        var viewBox = viewBoxStr.split(" ");
        this.width = viewBox[2];
        this.height = viewBox[3]
      }
      var unitWidth = this.element.getStringAttribute("width");
      var unitHeight = this.element.getStringAttribute("height");
      if (unitWidth !== null) {
        this.width = this.parseUnitSize(unitWidth);
        this.height = this.parseUnitSize(unitHeight)
      } else if (this.width === 0 || this.height === 0) {
        this.width = 1;
        this.height = 1;
        throw "The width and/or height is not " + "readable in the <svg> tag of this file.";
      }
      this.parseColors(this.element);
      this.parseChildren(this.element)
    };
    PShapeSVG.prototype = new PShape;
    PShapeSVG.prototype.parseMatrix = function() {
      function getCoords(s) {
        var m = [];
        s.replace(/\((.*?)\)/, function() {
          return function(all, params) {
            m = params.replace(/,+/g, " ").split(/\s+/)
          }
        }());
        return m
      }
      return function(str) {
        this.checkMatrix(2);
        var pieces = [];
        str.replace(/\s*(\w+)\((.*?)\)/g, function(all) {
          pieces.push(p.trim(all))
        });
        if (pieces.length === 0) return null;
        for (var i = 0, j = pieces.length; i < j; i++) {
          var m = getCoords(pieces[i]);
          if (pieces[i].indexOf("matrix") !== -1) this.matrix.set(m[0], m[2], m[4], m[1], m[3], m[5]);
          else if (pieces[i].indexOf("translate") !== -1) {
            var tx = m[0];
            var ty = m.length === 2 ? m[1] : 0;
            this.matrix.translate(tx, ty)
          } else if (pieces[i].indexOf("scale") !== -1) {
            var sx = m[0];
            var sy = m.length === 2 ? m[1] : m[0];
            this.matrix.scale(sx, sy)
          } else if (pieces[i].indexOf("rotate") !== -1) {
            var angle = m[0];
            if (m.length === 1) this.matrix.rotate(p.radians(angle));
            else if (m.length === 3) {
              this.matrix.translate(m[1], m[2]);
              this.matrix.rotate(p.radians(m[0]));
              this.matrix.translate(-m[1], -m[2])
            }
          } else if (pieces[i].indexOf("skewX") !== -1) this.matrix.skewX(parseFloat(m[0]));
          else if (pieces[i].indexOf("skewY") !== -1) this.matrix.skewY(m[0])
        }
        return this.matrix
      }
    }();
    PShapeSVG.prototype.parseChildren = function(element) {
      var newelement = element.getChildren();
      var children = new p.PShape;
      for (var i = 0, j = newelement.length; i < j; i++) {
        var kid = this.parseChild(newelement[i]);
        if (kid) children.addChild(kid)
      }
      this.children.push(children)
    };
    PShapeSVG.prototype.getName = function() {
      return this.name
    };
    PShapeSVG.prototype.parseChild = function(elem) {
      var name = elem.getName();
      var shape;
      if (name === "g") shape = new PShapeSVG(this, elem);
      else if (name === "defs") shape = new PShapeSVG(this, elem);
      else if (name === "line") {
        shape = new PShapeSVG(this, elem);
        shape.parseLine()
      } else if (name === "circle") {
        shape = new PShapeSVG(this, elem);
        shape.parseEllipse(true)
      } else if (name === "ellipse") {
        shape = new PShapeSVG(this, elem);
        shape.parseEllipse(false)
      } else if (name === "rect") {
        shape = new PShapeSVG(this, elem);
        shape.parseRect()
      } else if (name === "polygon") {
        shape = new PShapeSVG(this, elem);
        shape.parsePoly(true)
      } else if (name === "polyline") {
        shape = new PShapeSVG(this, elem);
        shape.parsePoly(false)
      } else if (name === "path") {
        shape = new PShapeSVG(this, elem);
        shape.parsePath()
      } else if (name === "radialGradient") unimplemented("PShapeSVG.prototype.parseChild, name = radialGradient");
      else if (name === "linearGradient") unimplemented("PShapeSVG.prototype.parseChild, name = linearGradient");
      else if (name === "text") unimplemented("PShapeSVG.prototype.parseChild, name = text");
      else if (name === "filter") unimplemented("PShapeSVG.prototype.parseChild, name = filter");
      else if (name === "mask") unimplemented("PShapeSVG.prototype.parseChild, name = mask");
      else nop();
      return shape
    };
    PShapeSVG.prototype.parsePath = function() {
      this.family = 21;
      this.kind = 0;
      var pathDataChars = [];
      var c;
      var pathData = p.trim(this.element.getStringAttribute("d").replace(/[\s,]+/g, " "));
      if (pathData === null) return;
      pathData = p.__toCharArray(pathData);
      var cx = 0,
        cy = 0,
        ctrlX = 0,
        ctrlY = 0,
        ctrlX1 = 0,
        ctrlX2 = 0,
        ctrlY1 = 0,
        ctrlY2 = 0,
        endX = 0,
        endY = 0,
        ppx = 0,
        ppy = 0,
        px = 0,
        py = 0,
        i = 0,
        valOf = 0;
      var str = "";
      var tmpArray = [];
      var flag = false;
      var lastInstruction;
      var command;
      var j, k;
      while (i < pathData.length) {
        valOf = pathData[i].valueOf();
        if (valOf >= 65 && valOf <= 90 || valOf >= 97 && valOf <= 122) {
          j = i;
          i++;
          if (i < pathData.length) {
            tmpArray = [];
            valOf = pathData[i].valueOf();
            while (! (valOf >= 65 && valOf <= 90 || valOf >= 97 && valOf <= 100 || valOf >= 102 && valOf <= 122) && flag === false) {
              if (valOf === 32) {
                if (str !== "") {
                  tmpArray.push(parseFloat(str));
                  str = ""
                }
                i++
              } else if (valOf === 45) if (pathData[i - 1].valueOf() === 101) {
                str += pathData[i].toString();
                i++
              } else {
                if (str !== "") tmpArray.push(parseFloat(str));
                str = pathData[i].toString();
                i++
              } else {
                str += pathData[i].toString();
                i++
              }
              if (i === pathData.length) flag = true;
              else valOf = pathData[i].valueOf()
            }
          }
          if (str !== "") {
            tmpArray.push(parseFloat(str));
            str = ""
          }
          command = pathData[j];
          valOf = command.valueOf();
          if (valOf === 77) {
            if (tmpArray.length >= 2 && tmpArray.length % 2 === 0) {
              cx = tmpArray[0];
              cy = tmpArray[1];
              this.parsePathMoveto(cx, cy);
              if (tmpArray.length > 2) for (j = 2, k = tmpArray.length; j < k; j += 2) {
                cx = tmpArray[j];
                cy = tmpArray[j + 1];
                this.parsePathLineto(cx, cy)
              }
            }
          } else if (valOf === 109) {
            if (tmpArray.length >= 2 && tmpArray.length % 2 === 0) {
              cx += tmpArray[0];
              cy += tmpArray[1];
              this.parsePathMoveto(cx, cy);
              if (tmpArray.length > 2) for (j = 2, k = tmpArray.length; j < k; j += 2) {
                cx += tmpArray[j];
                cy += tmpArray[j + 1];
                this.parsePathLineto(cx, cy)
              }
            }
          } else if (valOf === 76) {
            if (tmpArray.length >= 2 && tmpArray.length % 2 === 0) for (j = 0, k = tmpArray.length; j < k; j += 2) {
              cx = tmpArray[j];
              cy = tmpArray[j + 1];
              this.parsePathLineto(cx, cy)
            }
          } else if (valOf === 108) {
            if (tmpArray.length >= 2 && tmpArray.length % 2 === 0) for (j = 0, k = tmpArray.length; j < k; j += 2) {
              cx += tmpArray[j];
              cy += tmpArray[j + 1];
              this.parsePathLineto(cx, cy)
            }
          } else if (valOf === 72) for (j = 0, k = tmpArray.length; j < k; j++) {
            cx = tmpArray[j];
            this.parsePathLineto(cx, cy)
          } else if (valOf === 104) for (j = 0, k = tmpArray.length; j < k; j++) {
            cx += tmpArray[j];
            this.parsePathLineto(cx, cy)
          } else if (valOf === 86) for (j = 0, k = tmpArray.length; j < k; j++) {
            cy = tmpArray[j];
            this.parsePathLineto(cx, cy)
          } else if (valOf === 118) for (j = 0, k = tmpArray.length; j < k; j++) {
            cy += tmpArray[j];
            this.parsePathLineto(cx, cy)
          } else if (valOf === 67) {
            if (tmpArray.length >= 6 && tmpArray.length % 6 === 0) for (j = 0, k = tmpArray.length; j < k; j += 6) {
              ctrlX1 = tmpArray[j];
              ctrlY1 = tmpArray[j + 1];
              ctrlX2 = tmpArray[j + 2];
              ctrlY2 = tmpArray[j + 3];
              endX = tmpArray[j + 4];
              endY = tmpArray[j + 5];
              this.parsePathCurveto(ctrlX1, ctrlY1, ctrlX2, ctrlY2, endX, endY);
              cx = endX;
              cy = endY
            }
          } else if (valOf === 99) {
            if (tmpArray.length >= 6 && tmpArray.length % 6 === 0) for (j = 0, k = tmpArray.length; j < k; j += 6) {
              ctrlX1 = cx + tmpArray[j];
              ctrlY1 = cy + tmpArray[j + 1];
              ctrlX2 = cx + tmpArray[j + 2];
              ctrlY2 = cy + tmpArray[j + 3];
              endX = cx + tmpArray[j + 4];
              endY = cy + tmpArray[j + 5];
              this.parsePathCurveto(ctrlX1, ctrlY1, ctrlX2, ctrlY2, endX, endY);
              cx = endX;
              cy = endY
            }
          } else if (valOf === 83) {
            if (tmpArray.length >= 4 && tmpArray.length % 4 === 0) for (j = 0, k = tmpArray.length; j < k; j += 4) {
              if (lastInstruction.toLowerCase() === "c" || lastInstruction.toLowerCase() === "s") {
                ppx = this.vertices[this.vertices.length - 2][0];
                ppy = this.vertices[this.vertices.length - 2][1];
                px = this.vertices[this.vertices.length - 1][0];
                py = this.vertices[this.vertices.length - 1][1];
                ctrlX1 = px + (px - ppx);
                ctrlY1 = py + (py - ppy)
              } else {
                ctrlX1 = this.vertices[this.vertices.length - 1][0];
                ctrlY1 = this.vertices[this.vertices.length - 1][1]
              }
              ctrlX2 = tmpArray[j];
              ctrlY2 = tmpArray[j + 1];
              endX = tmpArray[j + 2];
              endY = tmpArray[j + 3];
              this.parsePathCurveto(ctrlX1, ctrlY1, ctrlX2, ctrlY2, endX, endY);
              cx = endX;
              cy = endY
            }
          } else if (valOf === 115) {
            if (tmpArray.length >= 4 && tmpArray.length % 4 === 0) for (j = 0, k = tmpArray.length; j < k; j += 4) {
              if (lastInstruction.toLowerCase() === "c" || lastInstruction.toLowerCase() === "s") {
                ppx = this.vertices[this.vertices.length - 2][0];
                ppy = this.vertices[this.vertices.length - 2][1];
                px = this.vertices[this.vertices.length - 1][0];
                py = this.vertices[this.vertices.length - 1][1];
                ctrlX1 = px + (px - ppx);
                ctrlY1 = py + (py - ppy)
              } else {
                ctrlX1 = this.vertices[this.vertices.length - 1][0];
                ctrlY1 = this.vertices[this.vertices.length - 1][1]
              }
              ctrlX2 = cx + tmpArray[j];
              ctrlY2 = cy + tmpArray[j + 1];
              endX = cx + tmpArray[j + 2];
              endY = cy + tmpArray[j + 3];
              this.parsePathCurveto(ctrlX1, ctrlY1, ctrlX2, ctrlY2, endX, endY);
              cx = endX;
              cy = endY
            }
          } else if (valOf === 81) {
            if (tmpArray.length >= 4 && tmpArray.length % 4 === 0) for (j = 0, k = tmpArray.length; j < k; j += 4) {
              ctrlX = tmpArray[j];
              ctrlY = tmpArray[j + 1];
              endX = tmpArray[j + 2];
              endY = tmpArray[j + 3];
              this.parsePathQuadto(cx, cy, ctrlX, ctrlY, endX, endY);
              cx = endX;
              cy = endY
            }
          } else if (valOf === 113) {
            if (tmpArray.length >= 4 && tmpArray.length % 4 === 0) for (j = 0, k = tmpArray.length; j < k; j += 4) {
              ctrlX = cx + tmpArray[j];
              ctrlY = cy + tmpArray[j + 1];
              endX = cx + tmpArray[j + 2];
              endY = cy + tmpArray[j + 3];
              this.parsePathQuadto(cx, cy, ctrlX, ctrlY, endX, endY);
              cx = endX;
              cy = endY
            }
          } else if (valOf === 84) {
            if (tmpArray.length >= 2 && tmpArray.length % 2 === 0) for (j = 0, k = tmpArray.length; j < k; j += 2) {
              if (lastInstruction.toLowerCase() === "q" || lastInstruction.toLowerCase() === "t") {
                ppx = this.vertices[this.vertices.length - 2][0];
                ppy = this.vertices[this.vertices.length - 2][1];
                px = this.vertices[this.vertices.length - 1][0];
                py = this.vertices[this.vertices.length - 1][1];
                ctrlX = px + (px - ppx);
                ctrlY = py + (py - ppy)
              } else {
                ctrlX = cx;
                ctrlY = cy
              }
              endX = tmpArray[j];
              endY = tmpArray[j + 1];
              this.parsePathQuadto(cx, cy, ctrlX, ctrlY, endX, endY);
              cx = endX;
              cy = endY
            }
          } else if (valOf === 116) {
            if (tmpArray.length >= 2 && tmpArray.length % 2 === 0) for (j = 0, k = tmpArray.length; j < k; j += 2) {
              if (lastInstruction.toLowerCase() === "q" || lastInstruction.toLowerCase() === "t") {
                ppx = this.vertices[this.vertices.length - 2][0];
                ppy = this.vertices[this.vertices.length - 2][1];
                px = this.vertices[this.vertices.length - 1][0];
                py = this.vertices[this.vertices.length - 1][1];
                ctrlX = px + (px - ppx);
                ctrlY = py + (py - ppy)
              } else {
                ctrlX = cx;
                ctrlY = cy
              }
              endX = cx + tmpArray[j];
              endY = cy + tmpArray[j + 1];
              this.parsePathQuadto(cx, cy, ctrlX, ctrlY, endX, endY);
              cx = endX;
              cy = endY
            }
          } else if (valOf === 90 || valOf === 122) this.close = true;
          lastInstruction = command.toString()
        } else i++
      }
    };
    PShapeSVG.prototype.parsePathQuadto = function(x1, y1, cx, cy, x2, y2) {
      if (this.vertices.length > 0) {
        this.parsePathCode(1);
        this.parsePathVertex(x1 + (cx - x1) * 2 / 3, y1 + (cy - y1) * 2 / 3);
        this.parsePathVertex(x2 + (cx - x2) * 2 / 3, y2 + (cy - y2) * 2 / 3);
        this.parsePathVertex(x2, y2)
      } else throw "Path must start with M/m";
    };
    PShapeSVG.prototype.parsePathCurveto = function(x1, y1, x2, y2, x3, y3) {
      if (this.vertices.length > 0) {
        this.parsePathCode(1);
        this.parsePathVertex(x1, y1);
        this.parsePathVertex(x2, y2);
        this.parsePathVertex(x3, y3)
      } else throw "Path must start with M/m";
    };
    PShapeSVG.prototype.parsePathLineto = function(px, py) {
      if (this.vertices.length > 0) {
        this.parsePathCode(0);
        this.parsePathVertex(px, py);
        this.vertices[this.vertices.length - 1]["moveTo"] = false
      } else throw "Path must start with M/m";
    };
    PShapeSVG.prototype.parsePathMoveto = function(px, py) {
      if (this.vertices.length > 0) this.parsePathCode(3);
      this.parsePathCode(0);
      this.parsePathVertex(px, py);
      this.vertices[this.vertices.length - 1]["moveTo"] = true
    };
    PShapeSVG.prototype.parsePathVertex = function(x, y) {
      var verts = [];
      verts[0] = x;
      verts[1] = y;
      this.vertices.push(verts)
    };
    PShapeSVG.prototype.parsePathCode = function(what) {
      this.vertexCodes.push(what)
    };
    PShapeSVG.prototype.parsePoly = function(val) {
      this.family = 21;
      this.close = val;
      var pointsAttr = p.trim(this.element.getStringAttribute("points").replace(/[,\s]+/g, " "));
      if (pointsAttr !== null) {
        var pointsBuffer = pointsAttr.split(" ");
        if (pointsBuffer.length % 2 === 0) for (var i = 0, j = pointsBuffer.length; i < j; i++) {
          var verts = [];
          verts[0] = pointsBuffer[i];
          verts[1] = pointsBuffer[++i];
          this.vertices.push(verts)
        } else throw "Error parsing polygon points: odd number of coordinates provided";
      }
    };
    PShapeSVG.prototype.parseRect = function() {
      this.kind = 30;
      this.family = 1;
      this.params = [];
      this.params[0] = this.element.getFloatAttribute("x");
      this.params[1] = this.element.getFloatAttribute("y");
      this.params[2] = this.element.getFloatAttribute("width");
      this.params[3] = this.element.getFloatAttribute("height");
      if (this.params[2] < 0 || this.params[3] < 0) throw "svg error: negative width or height found while parsing <rect>";
    };
    PShapeSVG.prototype.parseEllipse = function(val) {
      this.kind = 31;
      this.family = 1;
      this.params = [];
      this.params[0] = this.element.getFloatAttribute("cx") | 0;
      this.params[1] = this.element.getFloatAttribute("cy") | 0;
      var rx, ry;
      if (val) {
        rx = ry = this.element.getFloatAttribute("r");
        if (rx < 0) throw "svg error: negative radius found while parsing <circle>";
      } else {
        rx = this.element.getFloatAttribute("rx");
        ry = this.element.getFloatAttribute("ry");
        if (rx < 0 || ry < 0) throw "svg error: negative x-axis radius or y-axis radius found while parsing <ellipse>";
      }
      this.params[0] -= rx;
      this.params[1] -= ry;
      this.params[2] = rx * 2;
      this.params[3] = ry * 2
    };
    PShapeSVG.prototype.parseLine = function() {
      this.kind = 4;
      this.family = 1;
      this.params = [];
      this.params[0] = this.element.getFloatAttribute("x1");
      this.params[1] = this.element.getFloatAttribute("y1");
      this.params[2] = this.element.getFloatAttribute("x2");
      this.params[3] = this.element.getFloatAttribute("y2")
    };
    PShapeSVG.prototype.parseColors = function(element) {
      if (element.hasAttribute("opacity")) this.setOpacity(element.getAttribute("opacity"));
      if (element.hasAttribute("stroke")) this.setStroke(element.getAttribute("stroke"));
      if (element.hasAttribute("stroke-width")) this.setStrokeWeight(element.getAttribute("stroke-width"));
      if (element.hasAttribute("stroke-linejoin")) this.setStrokeJoin(element.getAttribute("stroke-linejoin"));
      if (element.hasAttribute("stroke-linecap")) this.setStrokeCap(element.getStringAttribute("stroke-linecap"));
      if (element.hasAttribute("fill")) this.setFill(element.getStringAttribute("fill"));
      if (element.hasAttribute("style")) {
        var styleText = element.getStringAttribute("style");
        var styleTokens = styleText.toString().split(";");
        for (var i = 0, j = styleTokens.length; i < j; i++) {
          var tokens = p.trim(styleTokens[i].split(":"));
          if (tokens[0] === "fill") this.setFill(tokens[1]);
          else if (tokens[0] === "fill-opacity") this.setFillOpacity(tokens[1]);
          else if (tokens[0] === "stroke") this.setStroke(tokens[1]);
          else if (tokens[0] === "stroke-width") this.setStrokeWeight(tokens[1]);
          else if (tokens[0] === "stroke-linecap") this.setStrokeCap(tokens[1]);
          else if (tokens[0] === "stroke-linejoin") this.setStrokeJoin(tokens[1]);
          else if (tokens[0] === "stroke-opacity") this.setStrokeOpacity(tokens[1]);
          else if (tokens[0] === "opacity") this.setOpacity(tokens[1])
        }
      }
    };
    PShapeSVG.prototype.setFillOpacity = function(opacityText) {
      this.fillOpacity = parseFloat(opacityText);
      this.fillColor = this.fillOpacity * 255 << 24 | this.fillColor & 16777215
    };
    PShapeSVG.prototype.setFill = function(fillText) {
      var opacityMask = this.fillColor & 4278190080;
      if (fillText === "none") this.fill = false;
      else if (fillText.indexOf("#") === 0) {
        this.fill = true;
        if (fillText.length === 4) fillText = fillText.replace(/#(.)(.)(.)/, "#$1$1$2$2$3$3");
        this.fillColor = opacityMask | parseInt(fillText.substring(1), 16) & 16777215
      } else if (fillText.indexOf("rgb") === 0) {
        this.fill = true;
        this.fillColor = opacityMask | this.parseRGB(fillText)
      } else if (fillText.indexOf("url(#") === 0) this.fillName = fillText.substring(5, fillText.length - 1);
      else if (colors[fillText]) {
        this.fill = true;
        this.fillColor = opacityMask | parseInt(colors[fillText].substring(1), 16) & 16777215
      }
    };
    PShapeSVG.prototype.setOpacity = function(opacity) {
      this.strokeColor = parseFloat(opacity) * 255 << 24 | this.strokeColor & 16777215;
      this.fillColor = parseFloat(opacity) * 255 << 24 | this.fillColor & 16777215
    };
    PShapeSVG.prototype.setStroke = function(strokeText) {
      var opacityMask = this.strokeColor & 4278190080;
      if (strokeText === "none") this.stroke = false;
      else if (strokeText.charAt(0) === "#") {
        this.stroke = true;
        if (strokeText.length === 4) strokeText = strokeText.replace(/#(.)(.)(.)/, "#$1$1$2$2$3$3");
        this.strokeColor = opacityMask | parseInt(strokeText.substring(1), 16) & 16777215
      } else if (strokeText.indexOf("rgb") === 0) {
        this.stroke = true;
        this.strokeColor = opacityMask | this.parseRGB(strokeText)
      } else if (strokeText.indexOf("url(#") === 0) this.strokeName = strokeText.substring(5, strokeText.length - 1);
      else if (colors[strokeText]) {
        this.stroke = true;
        this.strokeColor = opacityMask | parseInt(colors[strokeText].substring(1), 16) & 16777215
      }
    };
    PShapeSVG.prototype.setStrokeWeight = function(weight) {
      this.strokeWeight = this.parseUnitSize(weight)
    };
    PShapeSVG.prototype.setStrokeJoin = function(linejoin) {
      if (linejoin === "miter") this.strokeJoin = 'miter';
      else if (linejoin === "round") this.strokeJoin = 'round';
      else if (linejoin === "bevel") this.strokeJoin = 'bevel'
    };
    PShapeSVG.prototype.setStrokeCap = function(linecap) {
      if (linecap === "butt") this.strokeCap = 'butt';
      else if (linecap === "round") this.strokeCap = 'round';
      else if (linecap === "square") this.strokeCap = 'square'
    };
    PShapeSVG.prototype.setStrokeOpacity = function(opacityText) {
      this.strokeOpacity = parseFloat(opacityText);
      this.strokeColor = this.strokeOpacity * 255 << 24 | this.strokeColor & 16777215
    };
    PShapeSVG.prototype.parseRGB = function(color) {
      var sub = color.substring(color.indexOf("(") + 1, color.indexOf(")"));
      var values = sub.split(", ");
      return values[0] << 16 | values[1] << 8 | values[2]
    };
    PShapeSVG.prototype.parseUnitSize = function(text) {
      var len = text.length - 2;
      if (len < 0) return text;
      if (text.indexOf("pt") === len) return parseFloat(text.substring(0, len)) * 1.25;
      if (text.indexOf("pc") === len) return parseFloat(text.substring(0, len)) * 15;
      if (text.indexOf("mm") === len) return parseFloat(text.substring(0, len)) * 3.543307;
      if (text.indexOf("cm") === len) return parseFloat(text.substring(0, len)) * 35.43307;
      if (text.indexOf("in") === len) return parseFloat(text.substring(0, len)) * 90;
      if (text.indexOf("px") === len) return parseFloat(text.substring(0, len));
      return parseFloat(text)
    };
    p.shape = function(shape, x, y, width, height) {
      if (arguments.length >= 1 && arguments[0] !== null) if (shape.isVisible()) {
        p.pushMatrix();
        if (curShapeMode === 3) if (arguments.length === 5) {
          p.translate(x - width / 2, y - height / 2);
          p.scale(width / shape.getWidth(), height / shape.getHeight())
        } else if (arguments.length === 3) p.translate(x - shape.getWidth() / 2, -shape.getHeight() / 2);
        else p.translate(-shape.getWidth() / 2, -shape.getHeight() / 2);
        else if (curShapeMode === 0) if (arguments.length === 5) {
          p.translate(x, y);
          p.scale(width / shape.getWidth(), height / shape.getHeight())
        } else {
          if (arguments.length === 3) p.translate(x, y)
        } else if (curShapeMode === 1) if (arguments.length === 5) {
          width -= x;
          height -= y;
          p.translate(x, y);
          p.scale(width / shape.getWidth(), height / shape.getHeight())
        } else if (arguments.length === 3) p.translate(x, y);
        shape.draw();
        if (arguments.length === 1 && curShapeMode === 3 || arguments.length > 1) p.popMatrix()
      }
    };
    p.shapeMode = function(mode) {
      curShapeMode = mode
    };
    p.loadShape = function(filename) {
      if (arguments.length === 1) if (filename.indexOf(".svg") > -1) return new PShapeSVG(null, filename);
      return null
    };
    var XMLAttribute = function(fname, n, nameSpace, v, t) {
      this.fullName = fname || "";
      this.name = n || "";
      this.namespace = nameSpace || "";
      this.value = v;
      this.type = t
    };
    XMLAttribute.prototype = {
      getName: function() {
        return this.name
      },
      getFullName: function() {
        return this.fullName
      },
      getNamespace: function() {
        return this.namespace
      },
      getValue: function() {
        return this.value
      },
      getType: function() {
        return this.type
      },
      setValue: function(newval) {
        this.value = newval
      }
    };
    var XMLElement = p.XMLElement = function() {
      this.attributes = [];
      this.children = [];
      this.fullName = null;
      this.name = null;
      this.namespace = "";
      this.content = null;
      this.parent = null;
      this.lineNr = "";
      this.systemID = "";
      this.type = "ELEMENT";
      if (arguments.length === 4) {
        this.fullName = arguments[0] || "";
        if (arguments[1]) this.name = arguments[1];
        else {
          var index = this.fullName.indexOf(":");
          if (index >= 0) this.name = this.fullName.substring(index + 1);
          else this.name = this.fullName
        }
        this.namespace = arguments[1];
        this.lineNr = arguments[3];
        this.systemID = arguments[2]
      } else if (arguments.length === 2 && arguments[1].indexOf(".") > -1) this.parse(arguments[arguments.length - 1]);
      else if (arguments.length === 1 && typeof arguments[0] === "string") this.parse(arguments[0])
    };
    XMLElement.prototype = {
      parse: function(textstring) {
        var xmlDoc;
        try {
          var extension = textstring.substring(textstring.length - 4);
          if (extension === ".xml" || extension === ".svg") textstring = ajax(textstring);
          xmlDoc = (new DOMParser).parseFromString(textstring, "text/xml");
          var elements = xmlDoc.documentElement;
          if (elements) this.parseChildrenRecursive(null, elements);
          else throw "Error loading document";
          return this
        } catch(e) {
          throw e;
        }
      },
      parseChildrenRecursive: function(parent, elementpath) {
        var xmlelement, xmlattribute, tmpattrib, l, m, child;
        if (!parent) {
          this.fullName = elementpath.localName;
          this.name = elementpath.nodeName;
          xmlelement = this
        } else {
          xmlelement = new XMLElement(elementpath.localName, elementpath.nodeName, "", "");
          xmlelement.parent = parent
        }
        if (elementpath.nodeType === 3 && elementpath.textContent !== "") return this.createPCDataElement(elementpath.textContent);
        for (l = 0, m = elementpath.attributes.length; l < m; l++) {
          tmpattrib = elementpath.attributes[l];
          xmlattribute = new XMLAttribute(tmpattrib.getname, tmpattrib.nodeName, tmpattrib.namespaceURI, tmpattrib.nodeValue, tmpattrib.nodeType);
          xmlelement.attributes.push(xmlattribute)
        }
        for (l = 0, m = elementpath.childNodes.length; l < m; l++) {
          var node = elementpath.childNodes[l];
          if (node.nodeType === 1 || node.nodeType === 3) {
            child = xmlelement.parseChildrenRecursive(xmlelement, node);
            if (child !== null) xmlelement.children.push(child)
          }
        }
        return xmlelement
      },
      createElement: function() {
        if (arguments.length === 2) return new XMLElement(arguments[0], arguments[1], null, null);
        return new XMLElement(arguments[0], arguments[1], arguments[2], arguments[3])
      },
      createPCDataElement: function(content) {
        if (content.replace(/^\s+$/g, "") === "") return null;
        var pcdata = new XMLElement;
        pcdata.content = content;
        pcdata.type = "TEXT";
        return pcdata
      },
      hasAttribute: function() {
        if (arguments.length === 1) return this.getAttribute(arguments[0]) !== null;
        if (arguments.length === 2) return this.getAttribute(arguments[0], arguments[1]) !== null
      },
      equals: function(other) {
        if (! (other instanceof XMLElement)) return false;
        var i, j;
        if (this.name !== other.getLocalName()) return false;
        if (this.attributes.length !== other.getAttributeCount()) return false;
        if (this.attributes.length !== other.attributes.length) return false;
        var attr_name, attr_ns, attr_value, attr_type, attr_other;
        for (i = 0, j = this.attributes.length; i < j; i++) {
          attr_name = this.attributes[i].getName();
          attr_ns = this.attributes[i].getNamespace();
          attr_other = other.findAttribute(attr_name, attr_ns);
          if (attr_other === null) return false;
          if (this.attributes[i].getValue() !== attr_other.getValue()) return false;
          if (this.attributes[i].getType() !== attr_other.getType()) return false
        }
        if (this.children.length !== other.getChildCount()) return false;
        if (this.children.length > 0) {
          var child1, child2;
          for (i = 0, j = this.children.length; i < j; i++) {
            child1 = this.getChild(i);
            child2 = other.getChild(i);
            if (!child1.equals(child2)) return false
          }
          return true
        }
        return this.content === other.content
      },
      getContent: function() {
        if (this.type === "TEXT") return this.content;
        var children = this.children;
        if (children.length === 1 && children[0].type === "TEXT") return children[0].content;
        return null
      },
      getAttribute: function() {
        var attribute;
        if (arguments.length === 2) {
          attribute = this.findAttribute(arguments[0]);
          if (attribute) return attribute.getValue();
          return arguments[1]
        } else if (arguments.length === 1) {
          attribute = this.findAttribute(arguments[0]);
          if (attribute) return attribute.getValue();
          return null
        } else if (arguments.length === 3) {
          attribute = this.findAttribute(arguments[0], arguments[1]);
          if (attribute) return attribute.getValue();
          return arguments[2]
        }
      },
      getStringAttribute: function() {
        if (arguments.length === 1) return this.getAttribute(arguments[0]);
        if (arguments.length === 2) return this.getAttribute(arguments[0], arguments[1]);
        return this.getAttribute(arguments[0], arguments[1], arguments[2])
      },
      getString: function(attributeName) {
        return this.getStringAttribute(attributeName)
      },
      getFloatAttribute: function() {
        if (arguments.length === 1) return parseFloat(this.getAttribute(arguments[0], 0));
        if (arguments.length === 2) return this.getAttribute(arguments[0], arguments[1]);
        return this.getAttribute(arguments[0], arguments[1], arguments[2])
      },
      getFloat: function(attributeName) {
        return this.getFloatAttribute(attributeName)
      },
      getIntAttribute: function() {
        if (arguments.length === 1) return this.getAttribute(arguments[0], 0);
        if (arguments.length === 2) return this.getAttribute(arguments[0], arguments[1]);
        return this.getAttribute(arguments[0], arguments[1], arguments[2])
      },
      getInt: function(attributeName) {
        return this.getIntAttribute(attributeName)
      },
      hasChildren: function() {
        return this.children.length > 0
      },
      addChild: function(child) {
        if (child !== null) {
          child.parent = this;
          this.children.push(child)
        }
      },
      insertChild: function(child, index) {
        if (child) {
          if (child.getLocalName() === null && !this.hasChildren()) {
            var lastChild = this.children[this.children.length - 1];
            if (lastChild.getLocalName() === null) {
              lastChild.setContent(lastChild.getContent() + child.getContent());
              return
            }
          }
          child.parent = this;
          this.children.splice(index, 0, child)
        }
      },
      getChild: function() {
        if (typeof arguments[0] === "number") return this.children[arguments[0]];
        if (arguments[0].indexOf("/") !== -1) {
          this.getChildRecursive(arguments[0].split("/"), 0);
          return null
        }
        var kid, kidName;
        for (var i = 0, j = this.getChildCount(); i < j; i++) {
          kid = this.getChild(i);
          kidName = kid.getName();
          if (kidName !== null && kidName === arguments[0]) return kid
        }
        return null
      },
      getChildren: function() {
        if (arguments.length === 1) {
          if (typeof arguments[0] === "number") return this.getChild(arguments[0]);
          if (arguments[0].indexOf("/") !== -1) return this.getChildrenRecursive(arguments[0].split("/"), 0);
          var matches = [];
          var kid, kidName;
          for (var i = 0, j = this.getChildCount(); i < j; i++) {
            kid = this.getChild(i);
            kidName = kid.getName();
            if (kidName !== null && kidName === arguments[0]) matches.push(kid)
          }
          return matches
        }
        return this.children
      },
      getChildCount: function() {
        return this.children.length
      },
      getChildRecursive: function(items, offset) {
        var kid, kidName;
        for (var i = 0, j = this.getChildCount(); i < j; i++) {
          kid = this.getChild(i);
          kidName = kid.getName();
          if (kidName !== null && kidName === items[offset]) {
            if (offset === items.length - 1) return kid;
            offset += 1;
            return kid.getChildRecursive(items, offset)
          }
        }
        return null
      },
      getChildrenRecursive: function(items, offset) {
        if (offset === items.length - 1) return this.getChildren(items[offset]);
        var matches = this.getChildren(items[offset]);
        var kidMatches = [];
        for (var i = 0; i < matches.length; i++) kidMatches = kidMatches.concat(matches[i].getChildrenRecursive(items, offset + 1));
        return kidMatches
      },
      isLeaf: function() {
        return !this.hasChildren()
      },
      listChildren: function() {
        var arr = [];
        for (var i = 0, j = this.children.length; i < j; i++) arr.push(this.getChild(i).getName());
        return arr
      },
      removeAttribute: function(name, namespace) {
        this.namespace = namespace || "";
        for (var i = 0, j = this.attributes.length; i < j; i++) if (this.attributes[i].getName() === name && this.attributes[i].getNamespace() === this.namespace) {
          this.attributes.splice(i, 1);
          break
        }
      },
      removeChild: function(child) {
        if (child) for (var i = 0, j = this.children.length; i < j; i++) if (this.children[i].equals(child)) {
          this.children.splice(i, 1);
          break
        }
      },
      removeChildAtIndex: function(index) {
        if (this.children.length > index) this.children.splice(index, 1)
      },
      findAttribute: function(name, namespace) {
        this.namespace = namespace || "";
        for (var i = 0, j = this.attributes.length; i < j; i++) if (this.attributes[i].getName() === name && this.attributes[i].getNamespace() === this.namespace) return this.attributes[i];
        return null
      },
      setAttribute: function() {
        var attr;
        if (arguments.length === 3) {
          var index = arguments[0].indexOf(":");
          var name = arguments[0].substring(index + 1);
          attr = this.findAttribute(name, arguments[1]);
          if (attr) attr.setValue(arguments[2]);
          else {
            attr = new XMLAttribute(arguments[0], name, arguments[1], arguments[2], "CDATA");
            this.attributes.push(attr)
          }
        } else {
          attr = this.findAttribute(arguments[0]);
          if (attr) attr.setValue(arguments[1]);
          else {
            attr = new XMLAttribute(arguments[0], arguments[0], null, arguments[1], "CDATA");
            this.attributes.push(attr)
          }
        }
      },
      setString: function(attribute, value) {
        this.setAttribute(attribute, value)
      },
      setInt: function(attribute, value) {
        this.setAttribute(attribute, value)
      },
      setFloat: function(attribute, value) {
        this.setAttribute(attribute, value)
      },
      setContent: function(content) {
        if (this.children.length > 0) Processing.debug("Tried to set content for XMLElement with children");
        this.content = content
      },
      setName: function() {
        if (arguments.length === 1) {
          this.name = arguments[0];
          this.fullName = arguments[0];
          this.namespace = null
        } else {
          var index = arguments[0].indexOf(":");
          if (arguments[1] === null || index < 0) this.name = arguments[0];
          else this.name = arguments[0].substring(index + 1);
          this.fullName = arguments[0];
          this.namespace = arguments[1]
        }
      },
      getName: function() {
        return this.fullName
      },
      getLocalName: function() {
        return this.name
      },
      getAttributeCount: function() {
        return this.attributes.length
      },
      toString: function() {
        if (this.type === "TEXT") return this.content;
        var tagstring = (this.namespace !== "" && this.namespace !== this.name ? this.namespace + ":" : "") + this.name;
        var xmlstring = "<" + tagstring;
        var a, c;
        for (a = 0; a < this.attributes.length; a++) {
          var attr = this.attributes[a];
          xmlstring += " " + attr.getName() + "=" + '"' + attr.getValue() + '"'
        }
        if (this.children.length === 0) if (this.content === "") xmlstring += "/>";
        else xmlstring += ">" + this.content + "</" + tagstring + ">";
        else {
          xmlstring += ">";
          for (c = 0; c < this.children.length; c++) xmlstring += this.children[c].toString();
          xmlstring += "</" + tagstring + ">"
        }
        return xmlstring
      }
    };
    XMLElement.parse = function(xmlstring) {
      var element = new XMLElement;
      element.parse(xmlstring);
      return element
    };
    var printMatrixHelper = function(elements) {
      var big = 0;
      for (var i = 0; i < elements.length; i++) if (i !== 0) big = Math.max(big, Math.abs(elements[i]));
      else big = Math.abs(elements[i]);
      var digits = (big + "").indexOf(".");
      if (digits === 0) digits = 1;
      else if (digits === -1) digits = (big + "").length;
      return digits
    };
    var PMatrix2D = p.PMatrix2D = function() {
      if (arguments.length === 0) this.reset();
      else if (arguments.length === 1 && arguments[0] instanceof PMatrix2D) this.set(arguments[0].array());
      else if (arguments.length === 6) this.set(arguments[0], arguments[1], arguments[2], arguments[3], arguments[4], arguments[5])
    };
    PMatrix2D.prototype = {
      set: function() {
        if (arguments.length === 6) {
          var a = arguments;
          this.set([a[0], a[1], a[2], a[3], a[4], a[5]])
        } else if (arguments.length === 1 && arguments[0] instanceof PMatrix2D) this.elements = arguments[0].array();
        else if (arguments.length === 1 && arguments[0] instanceof Array) this.elements = arguments[0].slice()
      },
      get: function() {
        var outgoing = new PMatrix2D;
        outgoing.set(this.elements);
        return outgoing
      },
      reset: function() {
        this.set([1, 0, 0, 0, 1, 0])
      },
      array: function array() {
        return this.elements.slice()
      },
      translate: function(tx, ty) {
        this.elements[2] = tx * this.elements[0] + ty * this.elements[1] + this.elements[2];
        this.elements[5] = tx * this.elements[3] + ty * this.elements[4] + this.elements[5]
      },
      invTranslate: function(tx, ty) {
        this.translate(-tx, -ty)
      },
      transpose: function() {},
      mult: function(source, target) {
        var x, y;
        if (source instanceof
        PVector) {
          x = source.x;
          y = source.y;
          if (!target) target = new PVector
        } else if (source instanceof Array) {
          x = source[0];
          y = source[1];
          if (!target) target = []
        }
        if (target instanceof Array) {
          target[0] = this.elements[0] * x + this.elements[1] * y + this.elements[2];
          target[1] = this.elements[3] * x + this.elements[4] * y + this.elements[5]
        } else if (target instanceof PVector) {
          target.x = this.elements[0] * x + this.elements[1] * y + this.elements[2];
          target.y = this.elements[3] * x + this.elements[4] * y + this.elements[5];
          target.z = 0
        }
        return target
      },
      multX: function(x, y) {
        return x * this.elements[0] + y * this.elements[1] + this.elements[2]
      },
      multY: function(x, y) {
        return x * this.elements[3] + y * this.elements[4] + this.elements[5]
      },
      skewX: function(angle) {
        this.apply(1, 0, 1, angle, 0, 0)
      },
      skewY: function(angle) {
        this.apply(1, 0, 1, 0, angle, 0)
      },
      determinant: function() {
        return this.elements[0] * this.elements[4] - this.elements[1] * this.elements[3]
      },
      invert: function() {
        var d = this.determinant();
        if (Math.abs(d) > -2147483648) {
          var old00 = this.elements[0];
          var old01 = this.elements[1];
          var old02 = this.elements[2];
          var old10 = this.elements[3];
          var old11 = this.elements[4];
          var old12 = this.elements[5];
          this.elements[0] = old11 / d;
          this.elements[3] = -old10 / d;
          this.elements[1] = -old01 / d;
          this.elements[4] = old00 / d;
          this.elements[2] = (old01 * old12 - old11 * old02) / d;
          this.elements[5] = (old10 * old02 - old00 * old12) / d;
          return true
        }
        return false
      },
      scale: function(sx, sy) {
        if (sx && !sy) sy = sx;
        if (sx && sy) {
          this.elements[0] *= sx;
          this.elements[1] *= sy;
          this.elements[3] *= sx;
          this.elements[4] *= sy
        }
      },
      invScale: function(sx, sy) {
        if (sx && !sy) sy = sx;
        this.scale(1 / sx, 1 / sy)
      },
      apply: function() {
        var source;
        if (arguments.length === 1 && arguments[0] instanceof PMatrix2D) source = arguments[0].array();
        else if (arguments.length === 6) source = Array.prototype.slice.call(arguments);
        else if (arguments.length === 1 && arguments[0] instanceof Array) source = arguments[0];
        var result = [0, 0, this.elements[2], 0, 0, this.elements[5]];
        var e = 0;
        for (var row = 0; row < 2; row++) for (var col = 0; col < 3; col++, e++) result[e] += this.elements[row * 3 + 0] * source[col + 0] + this.elements[row * 3 + 1] * source[col + 3];
        this.elements = result.slice()
      },
      preApply: function() {
        var source;
        if (arguments.length === 1 && arguments[0] instanceof PMatrix2D) source = arguments[0].array();
        else if (arguments.length === 6) source = Array.prototype.slice.call(arguments);
        else if (arguments.length === 1 && arguments[0] instanceof Array) source = arguments[0];
        var result = [0, 0, source[2], 0, 0, source[5]];
        result[2] = source[2] + this.elements[2] * source[0] + this.elements[5] * source[1];
        result[5] = source[5] + this.elements[2] * source[3] + this.elements[5] * source[4];
        result[0] = this.elements[0] * source[0] + this.elements[3] * source[1];
        result[3] = this.elements[0] * source[3] + this.elements[3] * source[4];
        result[1] = this.elements[1] * source[0] + this.elements[4] * source[1];
        result[4] = this.elements[1] * source[3] + this.elements[4] * source[4];
        this.elements = result.slice()
      },
      rotate: function(angle) {
        var c = Math.cos(angle);
        var s = Math.sin(angle);
        var temp1 = this.elements[0];
        var temp2 = this.elements[1];
        this.elements[0] = c * temp1 + s * temp2;
        this.elements[1] = -s * temp1 + c * temp2;
        temp1 = this.elements[3];
        temp2 = this.elements[4];
        this.elements[3] = c * temp1 + s * temp2;
        this.elements[4] = -s * temp1 + c * temp2
      },
      rotateZ: function(angle) {
        this.rotate(angle)
      },
      invRotateZ: function(angle) {
        this.rotateZ(angle - Math.PI)
      },
      print: function() {
        var digits = printMatrixHelper(this.elements);
        var output = "" + p.nfs(this.elements[0], digits, 4) + " " + p.nfs(this.elements[1], digits, 4) + " " + p.nfs(this.elements[2], digits, 4) + "\n" + p.nfs(this.elements[3], digits, 4) + " " + p.nfs(this.elements[4], digits, 4) + " " + p.nfs(this.elements[5], digits, 4) + "\n\n";
        p.println(output)
      }
    };
    var PMatrix3D = p.PMatrix3D = function() {
      this.reset()
    };
    PMatrix3D.prototype = {
      set: function() {
        if (arguments.length === 16) this.elements = Array.prototype.slice.call(arguments);
        else if (arguments.length === 1 && arguments[0] instanceof PMatrix3D) this.elements = arguments[0].array();
        else if (arguments.length === 1 && arguments[0] instanceof Array) this.elements = arguments[0].slice()
      },
      get: function() {
        var outgoing = new PMatrix3D;
        outgoing.set(this.elements);
        return outgoing
      },
      reset: function() {
        this.elements = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
      },
      array: function array() {
        return this.elements.slice()
      },
      translate: function(tx, ty, tz) {
        if (tz === undef) tz = 0;
        this.elements[3] += tx * this.elements[0] + ty * this.elements[1] + tz * this.elements[2];
        this.elements[7] += tx * this.elements[4] + ty * this.elements[5] + tz * this.elements[6];
        this.elements[11] += tx * this.elements[8] + ty * this.elements[9] + tz * this.elements[10];
        this.elements[15] += tx * this.elements[12] + ty * this.elements[13] + tz * this.elements[14]
      },
      transpose: function() {
        var temp = this.elements[4];
        this.elements[4] = this.elements[1];
        this.elements[1] = temp;
        temp = this.elements[8];
        this.elements[8] = this.elements[2];
        this.elements[2] = temp;
        temp = this.elements[6];
        this.elements[6] = this.elements[9];
        this.elements[9] = temp;
        temp = this.elements[3];
        this.elements[3] = this.elements[12];
        this.elements[12] = temp;
        temp = this.elements[7];
        this.elements[7] = this.elements[13];
        this.elements[13] = temp;
        temp = this.elements[11];
        this.elements[11] = this.elements[14];
        this.elements[14] = temp
      },
      mult: function(source, target) {
        var x, y, z, w;
        if (source instanceof PVector) {
          x = source.x;
          y = source.y;
          z = source.z;
          w = 1;
          if (!target) target = new PVector
        } else if (source instanceof
        Array) {
          x = source[0];
          y = source[1];
          z = source[2];
          w = source[3] || 1;
          if (!target || target.length !== 3 && target.length !== 4) target = [0, 0, 0]
        }
        if (target instanceof Array) if (target.length === 3) {
          target[0] = this.elements[0] * x + this.elements[1] * y + this.elements[2] * z + this.elements[3];
          target[1] = this.elements[4] * x + this.elements[5] * y + this.elements[6] * z + this.elements[7];
          target[2] = this.elements[8] * x + this.elements[9] * y + this.elements[10] * z + this.elements[11]
        } else if (target.length === 4) {
          target[0] = this.elements[0] * x + this.elements[1] * y + this.elements[2] * z + this.elements[3] * w;
          target[1] = this.elements[4] * x + this.elements[5] * y + this.elements[6] * z + this.elements[7] * w;
          target[2] = this.elements[8] * x + this.elements[9] * y + this.elements[10] * z + this.elements[11] * w;
          target[3] = this.elements[12] * x + this.elements[13] * y + this.elements[14] * z + this.elements[15] * w
        }
        if (target instanceof PVector) {
          target.x = this.elements[0] * x + this.elements[1] * y + this.elements[2] * z + this.elements[3];
          target.y = this.elements[4] * x + this.elements[5] * y + this.elements[6] * z + this.elements[7];
          target.z = this.elements[8] * x + this.elements[9] * y + this.elements[10] * z + this.elements[11]
        }
        return target
      },
      preApply: function() {
        var source;
        if (arguments.length === 1 && arguments[0] instanceof PMatrix3D) source = arguments[0].array();
        else if (arguments.length === 16) source = Array.prototype.slice.call(arguments);
        else if (arguments.length === 1 && arguments[0] instanceof Array) source = arguments[0];
        var result = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        var e = 0;
        for (var row = 0; row < 4; row++) for (var col = 0; col < 4; col++, e++) result[e] += this.elements[col + 0] * source[row * 4 + 0] + this.elements[col + 4] * source[row * 4 + 1] + this.elements[col + 8] * source[row * 4 + 2] + this.elements[col + 12] * source[row * 4 + 3];
        this.elements = result.slice()
      },
      apply: function() {
        var source;
        if (arguments.length === 1 && arguments[0] instanceof PMatrix3D) source = arguments[0].array();
        else if (arguments.length === 16) source = Array.prototype.slice.call(arguments);
        else if (arguments.length === 1 && arguments[0] instanceof Array) source = arguments[0];
        var result = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        var e = 0;
        for (var row = 0; row < 4; row++) for (var col = 0; col < 4; col++, e++) result[e] += this.elements[row * 4 + 0] * source[col + 0] + this.elements[row * 4 + 1] * source[col + 4] + this.elements[row * 4 + 2] * source[col + 8] + this.elements[row * 4 + 3] * source[col + 12];
        this.elements = result.slice()
      },
      rotate: function(angle, v0, v1, v2) {
        if (!v1) this.rotateZ(angle);
        else {
          var c = p.cos(angle);
          var s = p.sin(angle);
          var t = 1 - c;
          this.apply(t * v0 * v0 + c, t * v0 * v1 - s * v2, t * v0 * v2 + s * v1, 0, t * v0 * v1 + s * v2, t * v1 * v1 + c, t * v1 * v2 - s * v0, 0, t * v0 * v2 - s * v1, t * v1 * v2 + s * v0, t * v2 * v2 + c, 0, 0, 0, 0, 1)
        }
      },
      invApply: function() {
        if (inverseCopy === undef) inverseCopy = new PMatrix3D;
        var a = arguments;
        inverseCopy.set(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12], a[13], a[14], a[15]);
        if (!inverseCopy.invert()) return false;
        this.preApply(inverseCopy);
        return true
      },
      rotateX: function(angle) {
        var c = p.cos(angle);
        var s = p.sin(angle);
        this.apply([1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0, 0, 0, 0, 1])
      },
      rotateY: function(angle) {
        var c = p.cos(angle);
        var s = p.sin(angle);
        this.apply([c, 0, s, 0, 0, 1, 0, 0, -s, 0, c, 0, 0, 0, 0, 1])
      },
      rotateZ: function(angle) {
        var c = Math.cos(angle);
        var s = Math.sin(angle);
        this.apply([c,
          -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
      },
      scale: function(sx, sy, sz) {
        if (sx && !sy && !sz) sy = sz = sx;
        else if (sx && sy && !sz) sz = 1;
        if (sx && sy && sz) {
          this.elements[0] *= sx;
          this.elements[1] *= sy;
          this.elements[2] *= sz;
          this.elements[4] *= sx;
          this.elements[5] *= sy;
          this.elements[6] *= sz;
          this.elements[8] *= sx;
          this.elements[9] *= sy;
          this.elements[10] *= sz;
          this.elements[12] *= sx;
          this.elements[13] *= sy;
          this.elements[14] *= sz
        }
      },
      skewX: function(angle) {
        var t = Math.tan(angle);
        this.apply(1, t, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
      },
      skewY: function(angle) {
        var t = Math.tan(angle);
        this.apply(1, 0, 0, 0, t, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
      },
      multX: function(x, y, z, w) {
        if (!z) return this.elements[0] * x + this.elements[1] * y + this.elements[3];
        if (!w) return this.elements[0] * x + this.elements[1] * y + this.elements[2] * z + this.elements[3];
        return this.elements[0] * x + this.elements[1] * y + this.elements[2] * z + this.elements[3] * w
      },
      multY: function(x, y, z, w) {
        if (!z) return this.elements[4] * x + this.elements[5] * y + this.elements[7];
        if (!w) return this.elements[4] * x + this.elements[5] * y + this.elements[6] * z + this.elements[7];
        return this.elements[4] * x + this.elements[5] * y + this.elements[6] * z + this.elements[7] * w
      },
      multZ: function(x, y, z, w) {
        if (!w) return this.elements[8] * x + this.elements[9] * y + this.elements[10] * z + this.elements[11];
        return this.elements[8] * x + this.elements[9] * y + this.elements[10] * z + this.elements[11] * w
      },
      multW: function(x, y, z, w) {
        if (!w) return this.elements[12] * x + this.elements[13] * y + this.elements[14] * z + this.elements[15];
        return this.elements[12] * x + this.elements[13] * y + this.elements[14] * z + this.elements[15] * w
      },
      invert: function() {
        var fA0 = this.elements[0] * this.elements[5] - this.elements[1] * this.elements[4];
        var fA1 = this.elements[0] * this.elements[6] - this.elements[2] * this.elements[4];
        var fA2 = this.elements[0] * this.elements[7] - this.elements[3] * this.elements[4];
        var fA3 = this.elements[1] * this.elements[6] - this.elements[2] * this.elements[5];
        var fA4 = this.elements[1] * this.elements[7] - this.elements[3] * this.elements[5];
        var fA5 = this.elements[2] * this.elements[7] - this.elements[3] * this.elements[6];
        var fB0 = this.elements[8] * this.elements[13] - this.elements[9] * this.elements[12];
        var fB1 = this.elements[8] * this.elements[14] - this.elements[10] * this.elements[12];
        var fB2 = this.elements[8] * this.elements[15] - this.elements[11] * this.elements[12];
        var fB3 = this.elements[9] * this.elements[14] - this.elements[10] * this.elements[13];
        var fB4 = this.elements[9] * this.elements[15] - this.elements[11] * this.elements[13];
        var fB5 = this.elements[10] * this.elements[15] - this.elements[11] * this.elements[14];
        var fDet = fA0 * fB5 - fA1 * fB4 + fA2 * fB3 + fA3 * fB2 - fA4 * fB1 + fA5 * fB0;
        if (Math.abs(fDet) <= 1.0E-9) return false;
        var kInv = [];
        kInv[0] = +this.elements[5] * fB5 - this.elements[6] * fB4 + this.elements[7] * fB3;
        kInv[4] = -this.elements[4] * fB5 + this.elements[6] * fB2 - this.elements[7] * fB1;
        kInv[8] = +this.elements[4] * fB4 - this.elements[5] * fB2 + this.elements[7] * fB0;
        kInv[12] = -this.elements[4] * fB3 + this.elements[5] * fB1 - this.elements[6] * fB0;
        kInv[1] = -this.elements[1] * fB5 + this.elements[2] * fB4 - this.elements[3] * fB3;
        kInv[5] = +this.elements[0] * fB5 - this.elements[2] * fB2 + this.elements[3] * fB1;
        kInv[9] = -this.elements[0] * fB4 + this.elements[1] * fB2 - this.elements[3] * fB0;
        kInv[13] = +this.elements[0] * fB3 - this.elements[1] * fB1 + this.elements[2] * fB0;
        kInv[2] = +this.elements[13] * fA5 - this.elements[14] * fA4 + this.elements[15] * fA3;
        kInv[6] = -this.elements[12] * fA5 + this.elements[14] * fA2 - this.elements[15] * fA1;
        kInv[10] = +this.elements[12] * fA4 - this.elements[13] * fA2 + this.elements[15] * fA0;
        kInv[14] = -this.elements[12] * fA3 + this.elements[13] * fA1 - this.elements[14] * fA0;
        kInv[3] = -this.elements[9] * fA5 + this.elements[10] * fA4 - this.elements[11] * fA3;
        kInv[7] = +this.elements[8] * fA5 - this.elements[10] * fA2 + this.elements[11] * fA1;
        kInv[11] = -this.elements[8] * fA4 + this.elements[9] * fA2 - this.elements[11] * fA0;
        kInv[15] = +this.elements[8] * fA3 - this.elements[9] * fA1 + this.elements[10] * fA0;
        var fInvDet = 1 / fDet;
        kInv[0] *= fInvDet;
        kInv[1] *= fInvDet;
        kInv[2] *= fInvDet;
        kInv[3] *= fInvDet;
        kInv[4] *= fInvDet;
        kInv[5] *= fInvDet;
        kInv[6] *= fInvDet;
        kInv[7] *= fInvDet;
        kInv[8] *= fInvDet;
        kInv[9] *= fInvDet;
        kInv[10] *= fInvDet;
        kInv[11] *= fInvDet;
        kInv[12] *= fInvDet;
        kInv[13] *= fInvDet;
        kInv[14] *= fInvDet;
        kInv[15] *= fInvDet;
        this.elements = kInv.slice();
        return true
      },
      toString: function() {
        var str = "";
        for (var i = 0; i < 15; i++) str += this.elements[i] + ", ";
        str += this.elements[15];
        return str
      },
      print: function() {
        var digits = printMatrixHelper(this.elements);
        var output = "" + p.nfs(this.elements[0], digits, 4) + " " + p.nfs(this.elements[1], digits, 4) + " " + p.nfs(this.elements[2], digits, 4) + " " + p.nfs(this.elements[3], digits, 4) + "\n" + p.nfs(this.elements[4], digits, 4) + " " + p.nfs(this.elements[5], digits, 4) + " " + p.nfs(this.elements[6], digits, 4) + " " + p.nfs(this.elements[7], digits, 4) + "\n" + p.nfs(this.elements[8], digits, 4) + " " + p.nfs(this.elements[9], digits, 4) + " " + p.nfs(this.elements[10], digits, 4) + " " + p.nfs(this.elements[11], digits, 4) + "\n" + p.nfs(this.elements[12], digits, 4) + " " + p.nfs(this.elements[13], digits, 4) + " " + p.nfs(this.elements[14], digits, 4) + " " + p.nfs(this.elements[15], digits, 4) + "\n\n";
        p.println(output)
      },
      invTranslate: function(tx, ty, tz) {
        this.preApply(1, 0, 0, -tx, 0, 1, 0, -ty, 0, 0, 1, -tz, 0, 0, 0, 1)
      },
      invRotateX: function(angle) {
        var c = Math.cos(-angle);
        var s = Math.sin(-angle);
        this.preApply([1, 0, 0, 0, 0, c, -s, 0, 0, s, c, 0,
          0, 0, 0, 1])
      },
      invRotateY: function(angle) {
        var c = Math.cos(-angle);
        var s = Math.sin(-angle);
        this.preApply([c, 0, s, 0, 0, 1, 0, 0, -s, 0, c, 0, 0, 0, 0, 1])
      },
      invRotateZ: function(angle) {
        var c = Math.cos(-angle);
        var s = Math.sin(-angle);
        this.preApply([c, -s, 0, 0, s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
      },
      invScale: function(x, y, z) {
        this.preApply([1 / x, 0, 0, 0, 0, 1 / y, 0, 0, 0, 0, 1 / z, 0, 0, 0, 0, 1])
      }
    };
    var PMatrixStack = p.PMatrixStack = function() {
      this.matrixStack = []
    };
    PMatrixStack.prototype.load = function() {
      var tmpMatrix = drawing.$newPMatrix();
      if (arguments.length === 1) tmpMatrix.set(arguments[0]);
      else tmpMatrix.set(arguments);
      this.matrixStack.push(tmpMatrix)
    };
    Drawing2D.prototype.$newPMatrix = function() {
      return new PMatrix2D
    };
    Drawing3D.prototype.$newPMatrix = function() {
      return new PMatrix3D
    };
    PMatrixStack.prototype.push = function() {
      this.matrixStack.push(this.peek())
    };
    PMatrixStack.prototype.pop = function() {
      return this.matrixStack.pop()
    };
    PMatrixStack.prototype.peek = function() {
      var tmpMatrix = drawing.$newPMatrix();
      tmpMatrix.set(this.matrixStack[this.matrixStack.length - 1]);
      return tmpMatrix
    };
    PMatrixStack.prototype.mult = function(matrix) {
      this.matrixStack[this.matrixStack.length - 1].apply(matrix)
    };
    p.split = function(str, delim) {
      return str.split(delim)
    };
    p.splitTokens = function(str, tokens) {
      if (arguments.length === 1) tokens = "\n\t\r\u000c ";
      tokens = "[" + tokens + "]";
      var ary = [];
      var index = 0;
      var pos = str.search(tokens);
      while (pos >= 0) {
        if (pos === 0) str = str.substring(1);
        else {
          ary[index] = str.substring(0, pos);
          index++;
          str = str.substring(pos)
        }
        pos = str.search(tokens)
      }
      if (str.length > 0) ary[index] = str;
      if (ary.length === 0) ary = undef;
      return ary
    };
    p.append = function(array, element) {
      array[array.length] = element;
      return array
    };
    p.concat = function(array1, array2) {
      return array1.concat(array2)
    };
    p.sort = function(array, numElem) {
      var ret = [];
      if (array.length > 0) {
        var elemsToCopy = numElem > 0 ? numElem : array.length;
        for (var i = 0; i < elemsToCopy; i++) ret.push(array[i]);
        if (typeof array[0] === "string") ret.sort();
        else ret.sort(function(a, b) {
          return a - b
        });
        if (numElem > 0) for (var j = ret.length; j < array.length; j++) ret.push(array[j])
      }
      return ret
    };
    p.splice = function(array, value, index) {
      if (value.length === 0) return array;
      if (value instanceof Array) for (var i = 0, j = index; i < value.length; j++, i++) array.splice(j, 0, value[i]);
      else array.splice(index, 0, value);
      return array
    };
    p.subset = function(array, offset, length) {
      var end = length !== undef ? offset + length : array.length;
      return array.slice(offset, end)
    };
    p.join = function(array, seperator) {
      return array.join(seperator)
    };
    p.shorten = function(ary) {
      var newary = [];
      var len = ary.length;
      for (var i = 0; i < len; i++) newary[i] = ary[i];
      newary.pop();
      return newary
    };
    p.expand = function(ary, targetSize) {
      var temp = ary.slice(0),
        newSize = targetSize || ary.length * 2;
      temp.length = newSize;
      return temp
    };
    p.arrayCopy = function() {
      var src, srcPos = 0,
        dest, destPos = 0,
        length;
      if (arguments.length === 2) {
        src = arguments[0];
        dest = arguments[1];
        length = src.length
      } else if (arguments.length === 3) {
        src = arguments[0];
        dest = arguments[1];
        length = arguments[2]
      } else if (arguments.length === 5) {
        src = arguments[0];
        srcPos = arguments[1];
        dest = arguments[2];
        destPos = arguments[3];
        length = arguments[4]
      }
      for (var i = srcPos, j = destPos; i < length + srcPos; i++, j++) if (dest[j] !== undef) dest[j] = src[i];
      else throw "array index out of bounds exception";
    };
    p.reverse = function(array) {
      return array.reverse()
    };
    p.mix = function(a, b, f) {
      return a + ((b - a) * f >> 8)
    };
    p.peg = function(n) {
      return n < 0 ? 0 : n > 255 ? 255 : n
    };
    p.modes = function() {
      var ALPHA_MASK = 4278190080,
        RED_MASK = 16711680,
        GREEN_MASK = 65280,
        BLUE_MASK = 255,
        min = Math.min,
        max = Math.max;

      function applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb) {
        var a = min(((c1 & 4278190080) >>> 24) + f, 255) << 24;
        var r = ar + ((cr - ar) * f >> 8);
        r = (r < 0 ? 0 : r > 255 ? 255 : r) << 16;
        var g = ag + ((cg - ag) * f >> 8);
        g = (g < 0 ? 0 : g > 255 ? 255 : g) << 8;
        var b = ab + ((cb - ab) * f >> 8);
        b = b < 0 ? 0 : b > 255 ? 255 : b;
        return a | r | g | b
      }
      return {
        replace: function(c1, c2) {
          return c2
        },
        blend: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = c1 & RED_MASK,
            ag = c1 & GREEN_MASK,
            ab = c1 & BLUE_MASK,
            br = c2 & RED_MASK,
            bg = c2 & GREEN_MASK,
            bb = c2 & BLUE_MASK;
          return min(((c1 & ALPHA_MASK) >>> 24) + f, 255) << 24 | ar + ((br - ar) * f >> 8) & RED_MASK | ag + ((bg - ag) * f >> 8) & GREEN_MASK | ab + ((bb - ab) * f >> 8) & BLUE_MASK
        },
        add: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24;
          return min(((c1 & ALPHA_MASK) >>> 24) + f, 255) << 24 | min((c1 & RED_MASK) + ((c2 & RED_MASK) >> 8) * f, RED_MASK) & RED_MASK | min((c1 & GREEN_MASK) + ((c2 & GREEN_MASK) >> 8) * f, GREEN_MASK) & GREEN_MASK | min((c1 & BLUE_MASK) + ((c2 & BLUE_MASK) * f >> 8), BLUE_MASK)
        },
        subtract: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24;
          return min(((c1 & ALPHA_MASK) >>> 24) + f, 255) << 24 | max((c1 & RED_MASK) - ((c2 & RED_MASK) >> 8) * f, GREEN_MASK) & RED_MASK | max((c1 & GREEN_MASK) - ((c2 & GREEN_MASK) >> 8) * f, BLUE_MASK) & GREEN_MASK | max((c1 & BLUE_MASK) - ((c2 & BLUE_MASK) * f >> 8), 0)
        },
        lightest: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24;
          return min(((c1 & ALPHA_MASK) >>> 24) + f, 255) << 24 | max(c1 & RED_MASK, ((c2 & RED_MASK) >> 8) * f) & RED_MASK | max(c1 & GREEN_MASK, ((c2 & GREEN_MASK) >> 8) * f) & GREEN_MASK | max(c1 & BLUE_MASK, (c2 & BLUE_MASK) * f >> 8)
        },
        darkest: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = c1 & RED_MASK,
            ag = c1 & GREEN_MASK,
            ab = c1 & BLUE_MASK,
            br = min(c1 & RED_MASK, ((c2 & RED_MASK) >> 8) * f),
            bg = min(c1 & GREEN_MASK, ((c2 & GREEN_MASK) >> 8) * f),
            bb = min(c1 & BLUE_MASK, (c2 & BLUE_MASK) * f >> 8);
          return min(((c1 & ALPHA_MASK) >>> 24) + f, 255) << 24 | ar + ((br - ar) * f >> 8) & RED_MASK | ag + ((bg - ag) * f >> 8) & GREEN_MASK | ab + ((bb - ab) * f >> 8) & BLUE_MASK
        },
        difference: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK,
            cr = ar > br ? ar - br : br - ar,
          cg = ag > bg ? ag - bg : bg - ag,
          cb = ab > bb ? ab - bb : bb - ab;
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        },
        exclusion: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK,
            cr = ar + br - (ar * br >> 7),
            cg = ag + bg - (ag * bg >> 7),
            cb = ab + bb - (ab * bb >> 7);
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        },
        multiply: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK,
            cr = ar * br >> 8,
            cg = ag * bg >> 8,
            cb = ab * bb >> 8;
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        },
        screen: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK,
            cr = 255 - ((255 - ar) * (255 - br) >> 8),
            cg = 255 - ((255 - ag) * (255 - bg) >> 8),
            cb = 255 - ((255 - ab) * (255 - bb) >> 8);
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        },
        hard_light: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK,
            cr = br < 128 ? ar * br >> 7 : 255 - ((255 - ar) * (255 - br) >> 7),
          cg = bg < 128 ? ag * bg >> 7 : 255 - ((255 - ag) * (255 - bg) >> 7),
          cb = bb < 128 ? ab * bb >> 7 : 255 - ((255 - ab) * (255 - bb) >> 7);
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        },
        soft_light: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK,
            cr = (ar * br >> 7) + (ar * ar >> 8) - (ar * ar * br >> 15),
            cg = (ag * bg >> 7) + (ag * ag >> 8) - (ag * ag * bg >> 15),
            cb = (ab * bb >> 7) + (ab * ab >> 8) - (ab * ab * bb >> 15);
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        },
        overlay: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK,
            cr = ar < 128 ? ar * br >> 7 : 255 - ((255 - ar) * (255 - br) >> 7),
          cg = ag < 128 ? ag * bg >> 7 : 255 - ((255 - ag) * (255 - bg) >> 7),
          cb = ab < 128 ? ab * bb >> 7 : 255 - ((255 - ab) * (255 - bb) >> 7);
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        },
        dodge: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK;
          var cr = 255;
          if (br !== 255) {
            cr = (ar << 8) / (255 - br);
            cr = cr < 0 ? 0 : cr > 255 ? 255 : cr
          }
          var cg = 255;
          if (bg !== 255) {
            cg = (ag << 8) / (255 - bg);
            cg = cg < 0 ? 0 : cg > 255 ? 255 : cg
          }
          var cb = 255;
          if (bb !== 255) {
            cb = (ab << 8) / (255 - bb);
            cb = cb < 0 ? 0 : cb > 255 ? 255 : cb
          }
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        },
        burn: function(c1, c2) {
          var f = (c2 & ALPHA_MASK) >>> 24,
            ar = (c1 & RED_MASK) >> 16,
            ag = (c1 & GREEN_MASK) >> 8,
            ab = c1 & BLUE_MASK,
            br = (c2 & RED_MASK) >> 16,
            bg = (c2 & GREEN_MASK) >> 8,
            bb = c2 & BLUE_MASK;
          var cr = 0;
          if (br !== 0) {
            cr = (255 - ar << 8) / br;
            cr = 255 - (cr < 0 ? 0 : cr > 255 ? 255 : cr)
          }
          var cg = 0;
          if (bg !== 0) {
            cg = (255 - ag << 8) / bg;
            cg = 255 - (cg < 0 ? 0 : cg > 255 ? 255 : cg)
          }
          var cb = 0;
          if (bb !== 0) {
            cb = (255 - ab << 8) / bb;
            cb = 255 - (cb < 0 ? 0 : cb > 255 ? 255 : cb)
          }
          return applyMode(c1, f, ar, ag, ab, br, bg, bb, cr, cg, cb)
        }
      }
    }();

    function color$4(aValue1, aValue2, aValue3, aValue4) {
      var r, g, b, a;
      if (curColorMode === 3) {
        var rgb = p.color.toRGB(aValue1, aValue2, aValue3);
        r = rgb[0];
        g = rgb[1];
        b = rgb[2]
      } else {
        r = Math.round(255 * (aValue1 / colorModeX));
        g = Math.round(255 * (aValue2 / colorModeY));
        b = Math.round(255 * (aValue3 / colorModeZ))
      }
      a = Math.round(255 * (aValue4 / colorModeA));
      r = r < 0 ? 0 : r;
      g = g < 0 ? 0 : g;
      b = b < 0 ? 0 : b;
      a = a < 0 ? 0 : a;
      r = r > 255 ? 255 : r;
      g = g > 255 ? 255 : g;
      b = b > 255 ? 255 : b;
      a = a > 255 ? 255 : a;
      return a << 24 & 4278190080 | r << 16 & 16711680 | g << 8 & 65280 | b & 255
    }
    function color$2(aValue1, aValue2) {
      var a;
      if (aValue1 & 4278190080) {
        a = Math.round(255 * (aValue2 / colorModeA));
        a = a > 255 ? 255 : a;
        a = a < 0 ? 0 : a;
        return aValue1 - (aValue1 & 4278190080) + (a << 24 & 4278190080)
      }
      if (curColorMode === 1) return color$4(aValue1, aValue1, aValue1, aValue2);
      if (curColorMode === 3) return color$4(0, 0, aValue1 / colorModeX * colorModeZ, aValue2)
    }
    function color$1(aValue1) {
      if (aValue1 <= colorModeX && aValue1 >= 0) {
        if (curColorMode === 1) return color$4(aValue1, aValue1, aValue1, colorModeA);
        if (curColorMode === 3) return color$4(0, 0, aValue1 / colorModeX * colorModeZ, colorModeA)
      }
      if (aValue1) {
        if (aValue1 > 2147483647) aValue1 -= 4294967296;
        return aValue1
      }
    }
    p.color = function(aValue1, aValue2, aValue3, aValue4) {
      if (aValue1 !== undef && aValue2 !== undef && aValue3 !== undef && aValue4 !== undef) return color$4(aValue1, aValue2, aValue3, aValue4);
      if (aValue1 !== undef && aValue2 !== undef && aValue3 !== undef) return color$4(aValue1, aValue2, aValue3, colorModeA);
      if (aValue1 !== undef && aValue2 !== undef) return color$2(aValue1, aValue2);
      if (typeof aValue1 === "number") return color$1(aValue1);
      return color$4(colorModeX, colorModeY, colorModeZ, colorModeA)
    };
    p.color.toString = function(colorInt) {
      return "rgba(" + ((colorInt >> 16) & 255) + "," + ((colorInt >> 8) & 255) + "," + (colorInt & 255) + "," + ((colorInt >> 24) & 255) / 255 + ")"
    };
    p.color.toInt = function(r, g, b, a) {
      return a << 24 & 4278190080 | r << 16 & 16711680 | g << 8 & 65280 | b & 255
    };
    p.color.toArray = function(colorInt) {
      return [(colorInt >> 16) & 255, (colorInt >> 8) & 255, colorInt & 255, (colorInt >> 24) & 255]
    };
    p.color.toGLArray = function(colorInt) {
      return [((colorInt >> 16) & 255) / 255, ((colorInt >> 8) & 255) / 255, (colorInt & 255) / 255, ((colorInt & 4278190080) >>> 24) / 255]
    };
    p.color.toRGB = function(h, s, b) {
      h = h > colorModeX ? colorModeX : h;
      s = s > colorModeY ? colorModeY : s;
      b = b > colorModeZ ? colorModeZ : b;
      h = h / colorModeX * 360;
      s = s / colorModeY * 100;
      b = b / colorModeZ * 100;
      var br = Math.round(b / 100 * 255);
      if (s === 0) return [br, br, br];
      var hue = h % 360;
      var f = hue % 60;
      var p = Math.round(b * (100 - s) / 1E4 * 255);
      var q = Math.round(b * (6E3 - s * f) / 6E5 * 255);
      var t = Math.round(b * (6E3 - s * (60 - f)) / 6E5 * 255);
      switch (Math.floor(hue / 60)) {
      case 0:
        return [br, t, p];
      case 1:
        return [q, br, p];
      case 2:
        return [p, br, t];
      case 3:
        return [p, q, br];
      case 4:
        return [t, p, br];
      case 5:
        return [br, p, q]
      }
    };

    function colorToHSB(colorInt) {
      var red, green, blue;
      red = ((colorInt >> 16) & 255) / 255;
      green = ((colorInt >> 8) & 255) / 255;
      blue = (colorInt & 255) / 255;
      var max = p.max(p.max(red, green), blue),
        min = p.min(p.min(red, green), blue),
        hue, saturation;
      if (min === max) return [0, 0, max * colorModeZ];
      saturation = (max - min) / max;
      if (red === max) hue = (green - blue) / (max - min);
      else if (green === max) hue = 2 + (blue - red) / (max - min);
      else hue = 4 + (red - green) / (max - min);
      hue /= 6;
      if (hue < 0) hue += 1;
      else if (hue > 1) hue -= 1;
      return [hue * colorModeX, saturation * colorModeY, max * colorModeZ]
    }
    p.brightness = function(colInt) {
      return colorToHSB(colInt)[2]
    };
    p.saturation = function(colInt) {
      return colorToHSB(colInt)[1]
    };
    p.hue = function(colInt) {
      return colorToHSB(colInt)[0]
    };
    p.red = function(aColor) {
      return ((aColor >> 16) & 255) / 255 * colorModeX
    };
    p.green = function(aColor) {
      return ((aColor >> 8) & 255) / 255 * colorModeY
    };
    p.blue = function(aColor) {
      return (aColor & 255) / 255 * colorModeZ
    };
    p.alpha = function(aColor) {
      return ((aColor >> 24) & 255) / 255 * colorModeA
    };
    p.lerpColor = function(c1, c2, amt) {
      var r, g, b, a, r1, g1, b1, a1, r2, g2, b2, a2;
      var hsb1, hsb2, rgb, h, s;
      var colorBits1 = p.color(c1);
      var colorBits2 = p.color(c2);
      if (curColorMode === 3) {
        hsb1 = colorToHSB(colorBits1);
        a1 = ((colorBits1 >> 24) & 255) / colorModeA;
        hsb2 = colorToHSB(colorBits2);
        a2 = ((colorBits2 >> 24) & 255) / colorModeA;
        h = p.lerp(hsb1[0], hsb2[0], amt);
        s = p.lerp(hsb1[1], hsb2[1], amt);
        b = p.lerp(hsb1[2], hsb2[2], amt);
        rgb = p.color.toRGB(h, s, b);
        a = p.lerp(a1, a2, amt) * colorModeA;
        return a << 24 & 4278190080 | (rgb[0] & 255) << 16 | (rgb[1] & 255) << 8 | rgb[2] & 255
      }
      r1 = (colorBits1 >> 16) & 255;
      g1 = (colorBits1 >> 8) & 255;
      b1 = colorBits1 & 255;
      a1 = ((colorBits1 >> 24) & 255) / colorModeA;
      r2 = (colorBits2 >> 16) & 255;
      g2 = (colorBits2 >> 8) & 255;
      b2 = colorBits2 & 255;
      a2 = ((colorBits2 & 4278190080) >>> 24) / colorModeA;
      r = p.lerp(r1, r2, amt) | 0;
      g = p.lerp(g1, g2, amt) | 0;
      b = p.lerp(b1, b2, amt) | 0;
      a = p.lerp(a1, a2, amt) * colorModeA;
      return a << 24 & 4278190080 | r << 16 & 16711680 | g << 8 & 65280 | b & 255
    };
    p.colorMode = function() {
      curColorMode = arguments[0];
      if (arguments.length > 1) {
        colorModeX = arguments[1];
        colorModeY = arguments[2] || arguments[1];
        colorModeZ = arguments[3] || arguments[1];
        colorModeA = arguments[4] || arguments[1]
      }
    };
    p.blendColor = function(c1, c2, mode) {
      if (mode === 0) return p.modes.replace(c1, c2);
      else if (mode === 1) return p.modes.blend(c1, c2);
      else if (mode === 2) return p.modes.add(c1, c2);
      else if (mode === 4) return p.modes.subtract(c1, c2);
      else if (mode === 8) return p.modes.lightest(c1, c2);
      else if (mode === 16) return p.modes.darkest(c1, c2);
      else if (mode === 32) return p.modes.difference(c1, c2);
      else if (mode === 64) return p.modes.exclusion(c1, c2);
      else if (mode === 128) return p.modes.multiply(c1, c2);
      else if (mode === 256) return p.modes.screen(c1, c2);
      else if (mode === 1024) return p.modes.hard_light(c1, c2);
      else if (mode === 2048) return p.modes.soft_light(c1, c2);
      else if (mode === 512) return p.modes.overlay(c1, c2);
      else if (mode === 4096) return p.modes.dodge(c1, c2);
      else if (mode === 8192) return p.modes.burn(c1, c2)
    };

    function saveContext() {
      curContext.save()
    }
    function restoreContext() {
      curContext.restore();
      isStrokeDirty = true;
      isFillDirty = true
    }
    p.printMatrix = function() {
      modelView.print()
    };
    Drawing2D.prototype.translate = function(x, y) {
      modelView.translate(x, y);
      modelViewInv.invTranslate(x, y);
      curContext.translate(x, y)
    };
    Drawing3D.prototype.translate = function(x, y, z) {
      modelView.translate(x, y, z);
      modelViewInv.invTranslate(x, y, z)
    };
    Drawing2D.prototype.scale = function(x, y) {
      modelView.scale(x, y);
      modelViewInv.invScale(x, y);
      curContext.scale(x, y || x)
    };
    Drawing3D.prototype.scale = function(x, y, z) {
      modelView.scale(x, y, z);
      modelViewInv.invScale(x, y, z)
    };
    Drawing2D.prototype.pushMatrix = function() {
      userMatrixStack.load(modelView);
      userReverseMatrixStack.load(modelViewInv);
      saveContext()
    };
    Drawing3D.prototype.pushMatrix = function() {
      userMatrixStack.load(modelView);
      userReverseMatrixStack.load(modelViewInv)
    };
    Drawing2D.prototype.popMatrix = function() {
      modelView.set(userMatrixStack.pop());
      modelViewInv.set(userReverseMatrixStack.pop());
      restoreContext()
    };
    Drawing3D.prototype.popMatrix = function() {
      modelView.set(userMatrixStack.pop());
      modelViewInv.set(userReverseMatrixStack.pop())
    };
    Drawing2D.prototype.resetMatrix = function() {
      modelView.reset();
      modelViewInv.reset();
      curContext.setTransform(1, 0, 0, 1, 0, 0)
    };
    Drawing3D.prototype.resetMatrix = function() {
      modelView.reset();
      modelViewInv.reset()
    };
    DrawingShared.prototype.applyMatrix = function() {
      var a = arguments;
      modelView.apply(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12], a[13], a[14], a[15]);
      modelViewInv.invApply(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12], a[13], a[14], a[15])
    };
    Drawing2D.prototype.applyMatrix = function() {
      var a = arguments;
      for (var cnt = a.length; cnt < 16; cnt++) a[cnt] = 0;
      a[10] = a[15] = 1;
      DrawingShared.prototype.applyMatrix.apply(this, a)
    };
    p.rotateX = function(angleInRadians) {
      modelView.rotateX(angleInRadians);
      modelViewInv.invRotateX(angleInRadians)
    };
    Drawing2D.prototype.rotateZ = function() {
      throw "rotateZ() is not supported in 2D mode. Use rotate(float) instead.";
    };
    Drawing3D.prototype.rotateZ = function(angleInRadians) {
      modelView.rotateZ(angleInRadians);
      modelViewInv.invRotateZ(angleInRadians)
    };
    p.rotateY = function(angleInRadians) {
      modelView.rotateY(angleInRadians);
      modelViewInv.invRotateY(angleInRadians)
    };
    Drawing2D.prototype.rotate = function(angleInRadians) {
      modelView.rotateZ(angleInRadians);
      modelViewInv.invRotateZ(angleInRadians);
      curContext.rotate(angleInRadians)
    };
    Drawing3D.prototype.rotate = function(angleInRadians) {
      p.rotateZ(angleInRadians)
    };
    p.pushStyle = function() {
      saveContext();
      p.pushMatrix();
      var newState = {
        "doFill": doFill,
        "currentFillColor": currentFillColor,
        "doStroke": doStroke,
        "currentStrokeColor": currentStrokeColor,
        "curTint": curTint,
        "curRectMode": curRectMode,
        "curColorMode": curColorMode,
        "colorModeX": colorModeX,
        "colorModeZ": colorModeZ,
        "colorModeY": colorModeY,
        "colorModeA": colorModeA,
        "curTextFont": curTextFont,
        "horizontalTextAlignment": horizontalTextAlignment,
        "verticalTextAlignment": verticalTextAlignment,
        "textMode": textMode,
        "curFontName": curFontName,
        "curTextSize": curTextSize,
        "curTextAscent": curTextAscent,
        "curTextDescent": curTextDescent,
        "curTextLeading": curTextLeading
      };
      styleArray.push(newState)
    };
    p.popStyle = function() {
      var oldState = styleArray.pop();
      if (oldState) {
        restoreContext();
        p.popMatrix();
        doFill = oldState.doFill;
        currentFillColor = oldState.currentFillColor;
        doStroke = oldState.doStroke;
        currentStrokeColor = oldState.currentStrokeColor;
        curTint = oldState.curTint;
        curRectMode = oldState.curRectmode;
        curColorMode = oldState.curColorMode;
        colorModeX = oldState.colorModeX;
        colorModeZ = oldState.colorModeZ;
        colorModeY = oldState.colorModeY;
        colorModeA = oldState.colorModeA;
        curTextFont = oldState.curTextFont;
        curFontName = oldState.curFontName;
        curTextSize = oldState.curTextSize;
        horizontalTextAlignment = oldState.horizontalTextAlignment;
        verticalTextAlignment = oldState.verticalTextAlignment;
        textMode = oldState.textMode;
        curTextAscent = oldState.curTextAscent;
        curTextDescent = oldState.curTextDescent;
        curTextLeading = oldState.curTextLeading
      } else throw "Too many popStyle() without enough pushStyle()";
    };
    p.year = function() {
      return (new Date).getFullYear()
    };
    p.month = function() {
      return (new Date).getMonth() + 1
    };
    p.day = function() {
      return (new Date).getDate()
    };
    p.hour = function() {
      return (new Date).getHours()
    };
    p.minute = function() {
      return (new Date).getMinutes()
    };
    p.second = function() {
      return (new Date).getSeconds()
    };
    p.millis = function() {
      return Date.now() - start
    };

    function redrawHelper() {
      var sec = (Date.now() - timeSinceLastFPS) / 1E3;
      framesSinceLastFPS++;
      var fps = framesSinceLastFPS / sec;
      if (sec > 0.5) {
        timeSinceLastFPS = Date.now();
        framesSinceLastFPS = 0;
        p.__frameRate = fps
      }
      p.frameCount++
    }
    Drawing2D.prototype.redraw = function() {
      redrawHelper();
      curContext.lineWidth = lineWidth;
      var pmouseXLastEvent = p.pmouseX,
        pmouseYLastEvent = p.pmouseY;
      p.pmouseX = pmouseXLastFrame;
      p.pmouseY = pmouseYLastFrame;
      saveContext();
      p.draw();
      restoreContext();
      pmouseXLastFrame = p.mouseX;
      pmouseYLastFrame = p.mouseY;
      p.pmouseX = pmouseXLastEvent;
      p.pmouseY = pmouseYLastEvent
    };
    Drawing3D.prototype.redraw = function() {
      redrawHelper();
      var pmouseXLastEvent = p.pmouseX,
        pmouseYLastEvent = p.pmouseY;
      p.pmouseX = pmouseXLastFrame;
      p.pmouseY = pmouseYLastFrame;
      curContext.clear(curContext.DEPTH_BUFFER_BIT);
      curContextCache = {
        attributes: {},
        locations: {}
      };
      p.noLights();
      p.lightFalloff(1, 0, 0);
      p.shininess(1);
      p.ambient(255, 255, 255);
      p.specular(0, 0, 0);
      p.emissive(0, 0, 0);
      p.camera();
      p.draw();
      pmouseXLastFrame = p.mouseX;
      pmouseYLastFrame = p.mouseY;
      p.pmouseX = pmouseXLastEvent;
      p.pmouseY = pmouseYLastEvent
    };
    p.noLoop = function() {
      doLoop = false;
      loopStarted = false;
      clearInterval(looping);
      curSketch.onPause()
    };
    p.loop = function() {
      if (loopStarted) return;
      timeSinceLastFPS = Date.now();
      framesSinceLastFPS = 0;
      looping = window.setInterval(function() {
        try {
          curSketch.onFrameStart();
          p.redraw();
          curSketch.onFrameEnd()
        } catch(e_loop) {
          window.clearInterval(looping);
          throw e_loop;
        }
      },
      curMsPerFrame);
      doLoop = true;
      loopStarted = true;
      curSketch.onLoop()
    };
    p.frameRate = function(aRate) {
      curFrameRate = aRate;
      curMsPerFrame = 1E3 / curFrameRate;
      if (doLoop) {
        p.noLoop();
        p.loop()
      }
    };
    var eventHandlers = [];

    function attachEventHandler(elem, type, fn) {
      if (elem.addEventListener) elem.addEventListener(type, fn, false);
      else elem.attachEvent("on" + type, fn);
      eventHandlers.push({
        elem: elem,
        type: type,
        fn: fn
      })
    }
    function detachEventHandler(eventHandler) {
      var elem = eventHandler.elem,
        type = eventHandler.type,
        fn = eventHandler.fn;
      if (elem.removeEventListener) elem.removeEventListener(type, fn, false);
      else if (elem.detachEvent) elem.detachEvent("on" + type, fn)
    }
    p.exit = function() {
      window.clearInterval(looping);
      removeInstance(p.externals.canvas.id);
      for (var lib in Processing.lib) if (Processing.lib.hasOwnProperty(lib)) if (Processing.lib[lib].hasOwnProperty("detach")) Processing.lib[lib].detach(p);
      var i = eventHandlers.length;
      while (i--) detachEventHandler(eventHandlers[i]);
      curSketch.onExit()
    };
    p.cursor = function() {
      if (arguments.length > 1 || arguments.length === 1 && arguments[0] instanceof p.PImage) {
        var image = arguments[0],
          x, y;
        if (arguments.length >= 3) {
          x = arguments[1];
          y = arguments[2];
          if (x < 0 || y < 0 || y >= image.height || x >= image.width) throw "x and y must be non-negative and less than the dimensions of the image";
        } else {
          x = image.width >>> 1;
          y = image.height >>> 1
        }
        var imageDataURL = image.toDataURL();
        var style = 'url("' + imageDataURL + '") ' + x + " " + y + ", default";
        curCursor = curElement.style.cursor = style
      } else if (arguments.length === 1) {
        var mode = arguments[0];
        curCursor = curElement.style.cursor = mode
      } else curCursor = curElement.style.cursor = oldCursor
    };
    p.noCursor = function() {
      curCursor = curElement.style.cursor = PConstants.NOCURSOR
    };
    p.link = function(href, target) {
      if (target !== undef) window.open(href, target);
      else window.location = href
    };
    p.beginDraw = nop;
    p.endDraw = nop;
    Drawing2D.prototype.toImageData = function(x, y, w, h) {
      x = x !== undef ? x : 0;
      y = y !== undef ? y : 0;
      w = w !== undef ? w : p.width;
      h = h !== undef ? h : p.height;
      return curContext.getImageData(x, y, w, h)
    };
    Drawing3D.prototype.toImageData = function(x, y, w, h) {
      x = x !== undef ? x : 0;
      y = y !== undef ? y : 0;
      w = w !== undef ? w : p.width;
      h = h !== undef ? h : p.height;
      var c = document.createElement("canvas"),
        ctx = c.getContext("2d"),
        obj = ctx.createImageData(w, h),
        uBuff = new Uint8Array(w * h * 4);
      curContext.readPixels(x, y, w, h, curContext.RGBA, curContext.UNSIGNED_BYTE, uBuff);
      for (var i = 0, ul = uBuff.length, obj_data = obj.data; i < ul; i++) obj_data[i] = uBuff[(h - 1 - Math.floor(i / 4 / w)) * w * 4 + i % (w * 4)];
      return obj
    };
    p.status = function(text) {
      window.status = text
    };
    p.binary = function(num, numBits) {
      var bit;
      if (numBits > 0) bit = numBits;
      else if (num instanceof Char) {
        bit = 16;
        num |= 0
      } else {
        bit = 32;
        while (bit > 1 && !(num >>> bit - 1 & 1)) bit--
      }
      var result = "";
      while (bit > 0) result += num >>> --bit & 1 ? "1" : "0";
      return result
    };
    p.unbinary = function(binaryString) {
      var i = binaryString.length - 1,
        mask = 1,
        result = 0;
      while (i >= 0) {
        var ch = binaryString[i--];
        if (ch !== "0" && ch !== "1") throw "the value passed into unbinary was not an 8 bit binary number";
        if (ch === "1") result += mask;
        mask <<= 1
      }
      return result
    };

    function nfCoreScalar(value, plus, minus, leftDigits, rightDigits, group) {
      var sign = value < 0 ? minus : plus;
      var autoDetectDecimals = rightDigits === 0;
      var rightDigitsOfDefault = rightDigits === undef || rightDigits < 0 ? 0 : rightDigits;
      var absValue = Math.abs(value);
      if (autoDetectDecimals) {
        rightDigitsOfDefault = 1;
        absValue *= 10;
        while (Math.abs(Math.round(absValue) - absValue) > 1.0E-6 && rightDigitsOfDefault < 7) {
          ++rightDigitsOfDefault;
          absValue *= 10
        }
      } else if (rightDigitsOfDefault !== 0) absValue *= Math.pow(10, rightDigitsOfDefault);
      var number, doubled = absValue * 2;
      if (Math.floor(absValue) === absValue) number = absValue;
      else if (Math.floor(doubled) === doubled) {
        var floored = Math.floor(absValue);
        number = floored + floored % 2
      } else number = Math.round(absValue);
      var buffer = "";
      var totalDigits = leftDigits + rightDigitsOfDefault;
      while (totalDigits > 0 || number > 0) {
        totalDigits--;
        buffer = "" + number % 10 + buffer;
        number = Math.floor(number / 10)
      }
      if (group !== undef) {
        var i = buffer.length - 3 - rightDigitsOfDefault;
        while (i > 0) {
          buffer = buffer.substring(0, i) + group + buffer.substring(i);
          i -= 3
        }
      }
      if (rightDigitsOfDefault > 0) return sign + buffer.substring(0, buffer.length - rightDigitsOfDefault) + "." + buffer.substring(buffer.length - rightDigitsOfDefault, buffer.length);
      return sign + buffer
    }
    function nfCore(value, plus, minus, leftDigits, rightDigits, group) {
      if (value instanceof Array) {
        var arr = [];
        for (var i = 0, len = value.length; i < len; i++) arr.push(nfCoreScalar(value[i], plus, minus, leftDigits, rightDigits, group));
        return arr
      }
      return nfCoreScalar(value, plus, minus, leftDigits, rightDigits, group)
    }
    p.nf = function(value, leftDigits, rightDigits) {
      return nfCore(value, "", "-", leftDigits, rightDigits)
    };
    p.nfs = function(value, leftDigits, rightDigits) {
      return nfCore(value, " ", "-", leftDigits, rightDigits)
    };
    p.nfp = function(value, leftDigits, rightDigits) {
      return nfCore(value, "+", "-", leftDigits, rightDigits)
    };
    p.nfc = function(value, leftDigits, rightDigits) {
      return nfCore(value, "", "-", leftDigits, rightDigits, ",")
    };
    var decimalToHex = function(d, padding) {
      padding = padding === undef || padding === null ? padding = 8 : padding;
      if (d < 0) d = 4294967295 + d + 1;
      var hex = Number(d).toString(16).toUpperCase();
      while (hex.length < padding) hex = "0" + hex;
      if (hex.length >= padding) hex = hex.substring(hex.length - padding, hex.length);
      return hex
    };
    p.hex = function(value, len) {
      if (arguments.length === 1) if (value instanceof Char) len = 4;
      else len = 8;
      return decimalToHex(value, len)
    };

    function unhexScalar(hex) {
      var value = parseInt("0x" + hex, 16);
      if (value > 2147483647) value -= 4294967296;
      return value
    }
    p.unhex = function(hex) {
      if (hex instanceof Array) {
        var arr = [];
        for (var i = 0; i < hex.length; i++) arr.push(unhexScalar(hex[i]));
        return arr
      }
      return unhexScalar(hex)
    };
    p.loadStrings = function(filename) {
      if (localStorage[filename]) return localStorage[filename].split("\n");
      var filecontent = ajax(filename);
      if (typeof filecontent !== "string" || filecontent === "") return [];
      filecontent = filecontent.replace(/(\r\n?)/g, "\n").replace(/\n$/, "");
      return filecontent.split("\n")
    };
    p.saveStrings = function(filename, strings) {
      localStorage[filename] = strings.join("\n")
    };
    p.loadBytes = function(url) {
      var string = ajax(url);
      var ret = [];
      for (var i = 0; i < string.length; i++) ret.push(string.charCodeAt(i));
      return ret
    };

    function removeFirstArgument(args) {
      return Array.prototype.slice.call(args, 1)
    }
    p.matchAll = function(aString, aRegExp) {
      var results = [],
        latest;
      var regexp = new RegExp(aRegExp, "g");
      while ((latest = regexp.exec(aString)) !== null) {
        results.push(latest);
        if (latest[0].length === 0)++regexp.lastIndex
      }
      return results.length > 0 ? results : null
    };
    p.__contains = function(subject, subStr) {
      if (typeof subject !== "string") return subject.contains.apply(subject, removeFirstArgument(arguments));
      return subject !== null && subStr !== null && typeof subStr === "string" && subject.indexOf(subStr) > -1
    };
    p.__replaceAll = function(subject, regex, replacement) {
      if (typeof subject !== "string") return subject.replaceAll.apply(subject, removeFirstArgument(arguments));
      return subject.replace(new RegExp(regex, "g"), replacement)
    };
    p.__replaceFirst = function(subject, regex, replacement) {
      if (typeof subject !== "string") return subject.replaceFirst.apply(subject, removeFirstArgument(arguments));
      return subject.replace(new RegExp(regex, ""), replacement)
    };
    p.__replace = function(subject, what, replacement) {
      if (typeof subject !== "string") return subject.replace.apply(subject, removeFirstArgument(arguments));
      if (what instanceof RegExp) return subject.replace(what, replacement);
      if (typeof what !== "string") what = what.toString();
      if (what === "") return subject;
      var i = subject.indexOf(what);
      if (i < 0) return subject;
      var j = 0,
        result = "";
      do {
        result += subject.substring(j, i) + replacement;
        j = i + what.length
      } while ((i = subject.indexOf(what, j)) >= 0);
      return result + subject.substring(j)
    };
    p.__equals = function(subject, other) {
      if (subject.equals instanceof Function) return subject.equals.apply(subject, removeFirstArgument(arguments));
      return subject.valueOf() === other.valueOf()
    };
    p.__equalsIgnoreCase = function(subject, other) {
      if (typeof subject !== "string") return subject.equalsIgnoreCase.apply(subject, removeFirstArgument(arguments));
      return subject.toLowerCase() === other.toLowerCase()
    };
    p.__toCharArray = function(subject) {
      if (typeof subject !== "string") return subject.toCharArray.apply(subject, removeFirstArgument(arguments));
      var chars = [];
      for (var i = 0, len = subject.length; i < len; ++i) chars[i] = new Char(subject.charAt(i));
      return chars
    };
    p.__split = function(subject, regex, limit) {
      if (typeof subject !== "string") return subject.split.apply(subject, removeFirstArgument(arguments));
      var pattern = new RegExp(regex);
      if (limit === undef || limit < 1) return subject.split(pattern);
      var result = [],
        currSubject = subject,
        pos;
      while ((pos = currSubject.search(pattern)) !== -1 && result.length < limit - 1) {
        var match = pattern.exec(currSubject).toString();
        result.push(currSubject.substring(0, pos));
        currSubject = currSubject.substring(pos + match.length)
      }
      if (pos !== -1 || currSubject !== "") result.push(currSubject);
      return result
    };
    p.__codePointAt = function(subject, idx) {
      var code = subject.charCodeAt(idx),
        hi, low;
      if (55296 <= code && code <= 56319) {
        hi = code;
        low = subject.charCodeAt(idx + 1);
        return (hi - 55296) * 1024 + (low - 56320) + 65536
      }
      return code
    };
    p.match = function(str, regexp) {
      return str.match(regexp)
    };
    p.__startsWith = function(subject, prefix, toffset) {
      if (typeof subject !== "string") return subject.startsWith.apply(subject, removeFirstArgument(arguments));
      toffset = toffset || 0;
      if (toffset < 0 || toffset > subject.length) return false;
      return prefix === "" || prefix === subject ? true : subject.indexOf(prefix) === toffset
    };
    p.__endsWith = function(subject, suffix) {
      if (typeof subject !== "string") return subject.endsWith.apply(subject, removeFirstArgument(arguments));
      var suffixLen = suffix ? suffix.length : 0;
      return suffix === "" || suffix === subject ? true : subject.indexOf(suffix) === subject.length - suffixLen
    };
    p.__hashCode = function(subject) {
      if (subject.hashCode instanceof Function) return subject.hashCode.apply(subject, removeFirstArgument(arguments));
      return virtHashCode(subject)
    };
    p.__printStackTrace = function(subject) {
      p.println("Exception: " + subject.toString())
    };
    var logBuffer = [];
    p.println = function(message) {
      var bufferLen = logBuffer.length;
      if (bufferLen) {
        Processing.logger.log(logBuffer.join(""));
        logBuffer.length = 0
      }
      if (arguments.length === 0 && bufferLen === 0) Processing.logger.log("");
      else if (arguments.length !== 0) Processing.logger.log(message)
    };
    p.print = function(message) {
      logBuffer.push(message)
    };
    p.str = function(val) {
      if (val instanceof Array) {
        var arr = [];
        for (var i = 0; i < val.length; i++) arr.push(val[i].toString() + "");
        return arr
      }
      return val.toString() + ""
    };
    p.trim = function(str) {
      if (str instanceof Array) {
        var arr = [];
        for (var i = 0; i < str.length; i++) arr.push(str[i].replace(/^\s*/, "").replace(/\s*$/, "").replace(/\r*$/, ""));
        return arr
      }
      return str.replace(/^\s*/, "").replace(/\s*$/, "").replace(/\r*$/, "")
    };

    function booleanScalar(val) {
      if (typeof val === "number") return val !== 0;
      if (typeof val === "boolean") return val;
      if (typeof val === "string") return val.toLowerCase() === "true";
      if (val instanceof Char) return val.code === 49 || val.code === 84 || val.code === 116
    }
    p.parseBoolean = function(val) {
      if (val instanceof Array) {
        var ret = [];
        for (var i = 0; i < val.length; i++) ret.push(booleanScalar(val[i]));
        return ret
      }
      return booleanScalar(val)
    };
    p.parseByte = function(what) {
      if (what instanceof
      Array) {
        var bytes = [];
        for (var i = 0; i < what.length; i++) bytes.push(0 - (what[i] & 128) | what[i] & 127);
        return bytes
      }
      return 0 - (what & 128) | what & 127
    };
    p.parseChar = function(key) {
      if (typeof key === "number") return new Char(String.fromCharCode(key & 65535));
      if (key instanceof Array) {
        var ret = [];
        for (var i = 0; i < key.length; i++) ret.push(new Char(String.fromCharCode(key[i] & 65535)));
        return ret
      }
      throw "char() may receive only one argument of type int, byte, int[], or byte[].";
    };

    function floatScalar(val) {
      if (typeof val === "number") return val;
      if (typeof val === "boolean") return val ? 1 : 0;
      if (typeof val === "string") return parseFloat(val);
      if (val instanceof Char) return val.code
    }
    p.parseFloat = function(val) {
      if (val instanceof Array) {
        var ret = [];
        for (var i = 0; i < val.length; i++) ret.push(floatScalar(val[i]));
        return ret
      }
      return floatScalar(val)
    };

    function intScalar(val, radix) {
      if (typeof val === "number") return val & 4294967295;
      if (typeof val === "boolean") return val ? 1 : 0;
      if (typeof val === "string") {
        var number = parseInt(val, radix || 10);
        return number & 4294967295
      }
      if (val instanceof
      Char) return val.code
    }
    p.parseInt = function(val, radix) {
      if (val instanceof Array) {
        var ret = [];
        for (var i = 0; i < val.length; i++) if (typeof val[i] === "string" && !/^\s*[+\-]?\d+\s*$/.test(val[i])) ret.push(0);
        else ret.push(intScalar(val[i], radix));
        return ret
      }
      return intScalar(val, radix)
    };
    p.__int_cast = function(val) {
      return 0 | val
    };
    p.__instanceof = function(obj, type) {
      if (typeof type !== "function") throw "Function is expected as type argument for instanceof operator";
      if (typeof obj === "string") return type === Object || type === String;
      if (obj instanceof type) return true;
      if (typeof obj !== "object" || obj === null) return false;
      var objType = obj.constructor;
      if (type.$isInterface) {
        var interfaces = [];
        while (objType) {
          if (objType.$interfaces) interfaces = interfaces.concat(objType.$interfaces);
          objType = objType.$base
        }
        while (interfaces.length > 0) {
          var i = interfaces.shift();
          if (i === type) return true;
          if (i.$interfaces) interfaces = interfaces.concat(i.$interfaces)
        }
        return false
      }
      while (objType.hasOwnProperty("$base")) {
        objType = objType.$base;
        if (objType === type) return true
      }
      return false
    };
    p.abs = Math.abs;
    p.ceil = Math.ceil;
    p.constrain = function(aNumber, aMin, aMax) {
      return aNumber > aMax ? aMax : aNumber < aMin ? aMin : aNumber
    };
    p.dist = function() {
      var dx, dy, dz;
      if (arguments.length === 4) {
        dx = arguments[0] - arguments[2];
        dy = arguments[1] - arguments[3];
        return Math.sqrt(dx * dx + dy * dy)
      }
      if (arguments.length === 6) {
        dx = arguments[0] - arguments[3];
        dy = arguments[1] - arguments[4];
        dz = arguments[2] - arguments[5];
        return Math.sqrt(dx * dx + dy * dy + dz * dz)
      }
    };
    p.exp = Math.exp;
    p.floor = Math.floor;
    p.lerp = function(value1, value2, amt) {
      return (value2 - value1) * amt + value1
    };
    p.log = Math.log;
    p.mag = function(a, b, c) {
      if (c) return Math.sqrt(a * a + b * b + c * c);
      return Math.sqrt(a * a + b * b)
    };
    p.map = function(value, istart, istop, ostart, ostop) {
      return ostart + (ostop - ostart) * ((value - istart) / (istop - istart))
    };
    p.max = function() {
      if (arguments.length === 2) return arguments[0] < arguments[1] ? arguments[1] : arguments[0];
      var numbers = arguments.length === 1 ? arguments[0] : arguments;
      if (! ("length" in numbers && numbers.length > 0)) throw "Non-empty array is expected";
      var max = numbers[0],
        count = numbers.length;
      for (var i = 1; i < count; ++i) if (max < numbers[i]) max = numbers[i];
      return max
    };
    p.min = function() {
      if (arguments.length === 2) return arguments[0] < arguments[1] ? arguments[0] : arguments[1];
      var numbers = arguments.length === 1 ? arguments[0] : arguments;
      if (! ("length" in numbers && numbers.length > 0)) throw "Non-empty array is expected";
      var min = numbers[0],
        count = numbers.length;
      for (var i = 1; i < count; ++i) if (min > numbers[i]) min = numbers[i];
      return min
    };
    p.norm = function(aNumber, low, high) {
      return (aNumber - low) / (high - low)
    };
    p.pow = Math.pow;
    p.round = Math.round;
    p.sq = function(aNumber) {
      return aNumber * aNumber
    };
    p.sqrt = Math.sqrt;
    p.acos = Math.acos;
    p.asin = Math.asin;
    p.atan = Math.atan;
    p.atan2 = Math.atan2;
    p.cos = Math.cos;
    p.degrees = function(aAngle) {
      return aAngle * 180 / Math.PI
    };
    p.radians = function(aAngle) {
      return aAngle / 180 * Math.PI
    };
    p.sin = Math.sin;
    p.tan = Math.tan;
    var currentRandom = Math.random;
    p.random = function() {
      if (arguments.length === 0) return currentRandom();
      if (arguments.length === 1) return currentRandom() * arguments[0];
      var aMin = arguments[0],
        aMax = arguments[1];
      return currentRandom() * (aMax - aMin) + aMin
    };

    function Marsaglia(i1, i2) {
      var z = i1 || 362436069,
        w = i2 || 521288629;
      var nextInt = function() {
        z = 36969 * (z & 65535) + (z >>> 16) & 4294967295;
        w = 18E3 * (w & 65535) + (w >>> 16) & 4294967295;
        return ((z & 65535) << 16 | w & 65535) & 4294967295
      };
      this.nextDouble = function() {
        var i = nextInt() / 4294967296;
        return i < 0 ? 1 + i : i
      };
      this.nextInt = nextInt
    }
    Marsaglia.createRandomized = function() {
      var now = new Date;
      return new Marsaglia(now / 6E4 & 4294967295, now & 4294967295)
    };
    p.randomSeed = function(seed) {
      currentRandom = (new Marsaglia(seed)).nextDouble
    };
    p.Random = function(seed) {
      var haveNextNextGaussian = false,
        nextNextGaussian, random;
      this.nextGaussian = function() {
        if (haveNextNextGaussian) {
          haveNextNextGaussian = false;
          return nextNextGaussian
        }
        var v1, v2, s;
        do {
          v1 = 2 * random() - 1;
          v2 = 2 * random() - 1;
          s = v1 * v1 + v2 * v2
        } while (s >= 1 || s === 0);
        var multiplier = Math.sqrt(-2 * Math.log(s) / s);
        nextNextGaussian = v2 * multiplier;
        haveNextNextGaussian = true;
        return v1 * multiplier
      };
      random = seed === undef ? Math.random : (new Marsaglia(seed)).nextDouble
    };

    function PerlinNoise(seed) {
      var rnd = seed !== undef ? new Marsaglia(seed) : Marsaglia.createRandomized();
      var i, j;
      var perm = new Uint8Array(512);
      for (i = 0; i < 256; ++i) perm[i] = i;
      for (i = 0; i < 256; ++i) {
        var t = perm[j = rnd.nextInt() & 255];
        perm[j] = perm[i];
        perm[i] = t
      }
      for (i = 0; i < 256; ++i) perm[i + 256] = perm[i];

      function grad3d(i, x, y, z) {
        var h = i & 15;
        var u = h < 8 ? x : y,
        v = h < 4 ? y : h === 12 || h === 14 ? x : z;
        return ((h & 1) === 0 ? u : -u) + ((h & 2) === 0 ? v : -v)
      }
      function grad2d(i, x, y) {
        var v = (i & 1) === 0 ? x : y;
        return (i & 2) === 0 ? -v : v
      }
      function grad1d(i, x) {
        return (i & 1) === 0 ? -x : x
      }
      function lerp(t, a, b) {
        return a + t * (b - a)
      }
      this.noise3d = function(x, y, z) {
        var X = Math.floor(x) & 255,
          Y = Math.floor(y) & 255,
          Z = Math.floor(z) & 255;
        x -= Math.floor(x);
        y -= Math.floor(y);
        z -= Math.floor(z);
        var fx = (3 - 2 * x) * x * x,
          fy = (3 - 2 * y) * y * y,
          fz = (3 - 2 * z) * z * z;
        var p0 = perm[X] + Y,
          p00 = perm[p0] + Z,
          p01 = perm[p0 + 1] + Z,
          p1 = perm[X + 1] + Y,
          p10 = perm[p1] + Z,
          p11 = perm[p1 + 1] + Z;
        return lerp(fz, lerp(fy, lerp(fx, grad3d(perm[p00], x, y, z), grad3d(perm[p10], x - 1, y, z)), lerp(fx, grad3d(perm[p01], x, y - 1, z), grad3d(perm[p11], x - 1, y - 1, z))), lerp(fy, lerp(fx, grad3d(perm[p00 + 1], x, y, z - 1), grad3d(perm[p10 + 1], x - 1, y, z - 1)), lerp(fx, grad3d(perm[p01 + 1], x, y - 1, z - 1), grad3d(perm[p11 + 1], x - 1, y - 1, z - 1))))
      };
      this.noise2d = function(x, y) {
        var X = Math.floor(x) & 255,
          Y = Math.floor(y) & 255;
        x -= Math.floor(x);
        y -= Math.floor(y);
        var fx = (3 - 2 * x) * x * x,
          fy = (3 - 2 * y) * y * y;
        var p0 = perm[X] + Y,
          p1 = perm[X + 1] + Y;
        return lerp(fy, lerp(fx, grad2d(perm[p0], x, y), grad2d(perm[p1], x - 1, y)), lerp(fx, grad2d(perm[p0 + 1], x, y - 1), grad2d(perm[p1 + 1], x - 1, y - 1)))
      };
      this.noise1d = function(x) {
        var X = Math.floor(x) & 255;
        x -= Math.floor(x);
        var fx = (3 - 2 * x) * x * x;
        return lerp(fx, grad1d(perm[X], x), grad1d(perm[X + 1], x - 1))
      }
    }
    var noiseProfile = {
      generator: undef,
      octaves: 4,
      fallout: 0.5,
      seed: undef
    };
    p.noise = function(x, y, z) {
      if (noiseProfile.generator === undef) noiseProfile.generator = new PerlinNoise(noiseProfile.seed);
      var generator = noiseProfile.generator;
      var effect = 1,
        k = 1,
        sum = 0;
      for (var i = 0; i < noiseProfile.octaves; ++i) {
        effect *= noiseProfile.fallout;
        switch (arguments.length) {
        case 1:
          sum += effect * (1 + generator.noise1d(k * x)) / 2;
          break;
        case 2:
          sum += effect * (1 + generator.noise2d(k * x, k * y)) / 2;
          break;
        case 3:
          sum += effect * (1 + generator.noise3d(k * x, k * y, k * z)) / 2;
          break
        }
        k *= 2
      }
      return sum
    };
    p.noiseDetail = function(octaves, fallout) {
      noiseProfile.octaves = octaves;
      if (fallout !== undef) noiseProfile.fallout = fallout
    };
    p.noiseSeed = function(seed) {
      noiseProfile.seed = seed;
      noiseProfile.generator = undef
    };
    DrawingShared.prototype.size = function(aWidth, aHeight, aMode) {
      if (doStroke) p.stroke(0);
      if (doFill) p.fill(255);
      var savedProperties = {
        fillStyle: curContext.fillStyle,
        strokeStyle: curContext.strokeStyle,
        lineCap: curContext.lineCap,
        lineJoin: curContext.lineJoin
      };
      if (curElement.style.length > 0) {
        curElement.style.removeProperty("width");
        curElement.style.removeProperty("height")
      }
      curElement.width = p.width = aWidth || 100;
      curElement.height = p.height = aHeight || 100;
      for (var prop in savedProperties) if (savedProperties.hasOwnProperty(prop)) curContext[prop] = savedProperties[prop];
      p.textFont(curTextFont);
      p.background();
      maxPixelsCached = Math.max(1E3, aWidth * aHeight * 0.05);
      p.externals.context = curContext;
      for (var i = 0; i < 720; i++) {
        sinLUT[i] = p.sin(i * (Math.PI / 180) * 0.5);
        cosLUT[i] = p.cos(i * (Math.PI / 180) * 0.5)
      }
    };
    Drawing2D.prototype.size = function(aWidth, aHeight, aMode) {
      if (curContext === undef) {
        curContext = curElement.getContext("2d");
        userMatrixStack = new PMatrixStack;
        userReverseMatrixStack = new PMatrixStack;
        modelView = new PMatrix2D;
        modelViewInv = new PMatrix2D
      }
      DrawingShared.prototype.size.apply(this, arguments)
    };
    Drawing3D.prototype.size = function() {
      var size3DCalled = false;
      return function size(aWidth, aHeight, aMode) {
        if (size3DCalled) throw "Multiple calls to size() for 3D renders are not allowed.";
        size3DCalled = true;

        function getGLContext(canvas) {
          var ctxNames = ["experimental-webgl", "webgl", "webkit-3d"],
            gl;
          for (var i = 0, l = ctxNames.length; i < l; i++) {
            gl = canvas.getContext(ctxNames[i], {
              antialias: false
            });
            if (gl) break
          }
          return gl
        }
        try {
          curElement.width = p.width = aWidth || 100;
          curElement.height = p.height = aHeight || 100;
          curContext = getGLContext(curElement);
          canTex = curContext.createTexture();
          textTex = curContext.createTexture()
        } catch(e_size) {
          Processing.debug(e_size)
        }
        if (!curContext) throw "WebGL context is not supported on this browser.";
        curContext.viewport(0, 0, curElement.width, curElement.height);
        curContext.enable(curContext.DEPTH_TEST);
        curContext.enable(curContext.BLEND);
        curContext.blendFunc(curContext.SRC_ALPHA, curContext.ONE_MINUS_SRC_ALPHA);
        programObject2D = createProgramObject(curContext, vertexShaderSource2D, fragmentShaderSource2D);
        programObjectUnlitShape = createProgramObject(curContext, vShaderSrcUnlitShape, fShaderSrcUnlitShape);
        p.strokeWeight(1);
        programObject3D = createProgramObject(curContext, vertexShaderSource3D, fragmentShaderSource3D);
        curContext.useProgram(programObject3D);
        uniformi("usingTexture3d", programObject3D, "usingTexture", usingTexture);
        p.lightFalloff(1, 0, 0);
        p.shininess(1);
        p.ambient(255, 255, 255);
        p.specular(0, 0, 0);
        p.emissive(0, 0, 0);
        boxBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ARRAY_BUFFER, boxBuffer);
        curContext.bufferData(curContext.ARRAY_BUFFER, boxVerts, curContext.STATIC_DRAW);
        boxNormBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ARRAY_BUFFER, boxNormBuffer);
        curContext.bufferData(curContext.ARRAY_BUFFER, boxNorms, curContext.STATIC_DRAW);
        boxOutlineBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ARRAY_BUFFER, boxOutlineBuffer);
        curContext.bufferData(curContext.ARRAY_BUFFER, boxOutlineVerts, curContext.STATIC_DRAW);
        rectBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ARRAY_BUFFER, rectBuffer);
        curContext.bufferData(curContext.ARRAY_BUFFER, rectVerts, curContext.STATIC_DRAW);
        rectNormBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ARRAY_BUFFER, rectNormBuffer);
        curContext.bufferData(curContext.ARRAY_BUFFER, rectNorms, curContext.STATIC_DRAW);
        sphereBuffer = curContext.createBuffer();
        lineBuffer = curContext.createBuffer();
        fillBuffer = curContext.createBuffer();
        fillColorBuffer = curContext.createBuffer();
        strokeColorBuffer = curContext.createBuffer();
        shapeTexVBO = curContext.createBuffer();
        pointBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ARRAY_BUFFER, pointBuffer);
        curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array([0, 0, 0]), curContext.STATIC_DRAW);
        textBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ARRAY_BUFFER, textBuffer);
        curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array([1, 1, 0, -1, 1, 0, -1, -1, 0, 1, -1, 0]), curContext.STATIC_DRAW);
        textureBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ARRAY_BUFFER, textureBuffer);
        curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 1, 1, 0, 1]), curContext.STATIC_DRAW);
        indexBuffer = curContext.createBuffer();
        curContext.bindBuffer(curContext.ELEMENT_ARRAY_BUFFER, indexBuffer);
        curContext.bufferData(curContext.ELEMENT_ARRAY_BUFFER, new Uint16Array([0,
          1, 2, 2, 3, 0]), curContext.STATIC_DRAW);
        cam = new PMatrix3D;
        cameraInv = new PMatrix3D;
        modelView = new PMatrix3D;
        modelViewInv = new PMatrix3D;
        projection = new PMatrix3D;
        p.camera();
        p.perspective();
        userMatrixStack = new PMatrixStack;
        userReverseMatrixStack = new PMatrixStack;
        curveBasisMatrix = new PMatrix3D;
        curveToBezierMatrix = new PMatrix3D;
        curveDrawMatrix = new PMatrix3D;
        bezierDrawMatrix = new PMatrix3D;
        bezierBasisInverse = new PMatrix3D;
        bezierBasisMatrix = new PMatrix3D;
        bezierBasisMatrix.set(-1, 3, -3, 1, 3, -6, 3, 0, -3, 3, 0, 0, 1, 0, 0, 0);
        DrawingShared.prototype.size.apply(this, arguments)
      }
    }();
    Drawing2D.prototype.ambientLight = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.ambientLight = function(r, g, b, x, y, z) {
      if (lightCount === 8) throw "can only create " + 8 + " lights";
      var pos = new PVector(x, y, z);
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.mult(pos, pos);
      var col = color$4(r, g, b, 0);
      var normalizedCol = [((col >> 16) & 255) / 255, ((col & 65280) >>> 8) / 255, (col & 255) / 255];
      curContext.useProgram(programObject3D);
      uniformf("lights.color.3d." + lightCount, programObject3D, "lights" + lightCount + ".color", normalizedCol);
      uniformf("lights.position.3d." + lightCount, programObject3D, "lights" + lightCount + ".position", pos.array());
      uniformi("lights.type.3d." + lightCount, programObject3D, "lights" + lightCount + ".type", 0);
      uniformi("lightCount3d", programObject3D, "lightCount", ++lightCount)
    };
    Drawing2D.prototype.directionalLight = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.directionalLight = function(r, g, b, nx, ny, nz) {
      if (lightCount === 8) throw "can only create " + 8 + " lights";
      curContext.useProgram(programObject3D);
      var mvm = new PMatrix3D;
      mvm.scale(1, -1, 1);
      mvm.apply(modelView.array());
      mvm = mvm.array();
      var dir = [mvm[0] * nx + mvm[4] * ny + mvm[8] * nz, mvm[1] * nx + mvm[5] * ny + mvm[9] * nz, mvm[2] * nx + mvm[6] * ny + mvm[10] * nz];
      var col = color$4(r, g, b, 0);
      var normalizedCol = [((col >> 16) & 255) / 255, ((col >> 8) & 255) / 255, (col & 255) / 255];
      uniformf("lights.color.3d." + lightCount, programObject3D, "lights" + lightCount + ".color", normalizedCol);
      uniformf("lights.position.3d." + lightCount, programObject3D, "lights" + lightCount + ".position", dir);
      uniformi("lights.type.3d." + lightCount, programObject3D, "lights" + lightCount + ".type", 1);
      uniformi("lightCount3d", programObject3D, "lightCount", ++lightCount)
    };
    Drawing2D.prototype.lightFalloff = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.lightFalloff = function(constant, linear, quadratic) {
      curContext.useProgram(programObject3D);
      uniformf("falloff3d", programObject3D, "falloff", [constant, linear, quadratic])
    };
    Drawing2D.prototype.lightSpecular = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.lightSpecular = function(r, g, b) {
      var col = color$4(r, g, b, 0);
      var normalizedCol = [((col >> 16) & 255) / 255, ((col >> 8) & 255) / 255, (col & 255) / 255];
      curContext.useProgram(programObject3D);
      uniformf("specular3d", programObject3D, "specular", normalizedCol)
    };
    p.lights = function() {
      p.ambientLight(128, 128, 128);
      p.directionalLight(128, 128, 128, 0, 0, -1);
      p.lightFalloff(1, 0, 0);
      p.lightSpecular(0, 0, 0)
    };
    Drawing2D.prototype.pointLight = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.pointLight = function(r, g, b, x, y, z) {
      if (lightCount === 8) throw "can only create " + 8 + " lights";
      var pos = new PVector(x, y, z);
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.mult(pos, pos);
      var col = color$4(r, g, b, 0);
      var normalizedCol = [((col >> 16) & 255) / 255, ((col >> 8) & 255) / 255, (col & 255) / 255];
      curContext.useProgram(programObject3D);
      uniformf("lights.color.3d." + lightCount, programObject3D, "lights" + lightCount + ".color", normalizedCol);
      uniformf("lights.position.3d." + lightCount, programObject3D, "lights" + lightCount + ".position", pos.array());
      uniformi("lights.type.3d." + lightCount, programObject3D, "lights" + lightCount + ".type", 2);
      uniformi("lightCount3d", programObject3D, "lightCount", ++lightCount)
    };
    Drawing2D.prototype.noLights = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.noLights = function() {
      lightCount = 0;
      curContext.useProgram(programObject3D);
      uniformi("lightCount3d", programObject3D, "lightCount", lightCount)
    };
    Drawing2D.prototype.spotLight = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.spotLight = function(r, g, b, x, y, z, nx, ny, nz, angle, concentration) {
      if (lightCount === 8) throw "can only create " + 8 + " lights";
      curContext.useProgram(programObject3D);
      var pos = new PVector(x, y, z);
      var mvm = new PMatrix3D;
      mvm.scale(1, -1, 1);
      mvm.apply(modelView.array());
      mvm.mult(pos, pos);
      mvm = mvm.array();
      var dir = [mvm[0] * nx + mvm[4] * ny + mvm[8] * nz, mvm[1] * nx + mvm[5] * ny + mvm[9] * nz, mvm[2] * nx + mvm[6] * ny + mvm[10] * nz];
      var col = color$4(r, g, b, 0);
      var normalizedCol = [((col >> 16) & 255) / 255, ((col >> 8) & 255) / 255, (col & 255) / 255];
      uniformf("lights.color.3d." + lightCount, programObject3D, "lights" + lightCount + ".color", normalizedCol);
      uniformf("lights.position.3d." + lightCount, programObject3D, "lights" + lightCount + ".position", pos.array());
      uniformf("lights.direction.3d." + lightCount, programObject3D, "lights" + lightCount + ".direction", dir);
      uniformf("lights.concentration.3d." + lightCount, programObject3D, "lights" + lightCount + ".concentration", concentration);
      uniformf("lights.angle.3d." + lightCount, programObject3D, "lights" + lightCount + ".angle", angle);
      uniformi("lights.type.3d." + lightCount, programObject3D, "lights" + lightCount + ".type", 3);
      uniformi("lightCount3d", programObject3D, "lightCount", ++lightCount)
    };
    Drawing2D.prototype.beginCamera = function() {
      throw "beginCamera() is not available in 2D mode";
    };
    Drawing3D.prototype.beginCamera = function() {
      if (manipulatingCamera) throw "You cannot call beginCamera() again before calling endCamera()";
      manipulatingCamera = true;
      modelView = cameraInv;
      modelViewInv = cam
    };
    Drawing2D.prototype.endCamera = function() {
      throw "endCamera() is not available in 2D mode";
    };
    Drawing3D.prototype.endCamera = function() {
      if (!manipulatingCamera) throw "You cannot call endCamera() before calling beginCamera()";
      modelView.set(cam);
      modelViewInv.set(cameraInv);
      manipulatingCamera = false
    };
    p.camera = function(eyeX, eyeY, eyeZ, centerX, centerY, centerZ, upX, upY, upZ) {
      if (eyeX === undef) {
        cameraX = p.width / 2;
        cameraY = p.height / 2;
        cameraZ = cameraY / Math.tan(cameraFOV / 2);
        eyeX = cameraX;
        eyeY = cameraY;
        eyeZ = cameraZ;
        centerX = cameraX;
        centerY = cameraY;
        centerZ = 0;
        upX = 0;
        upY = 1;
        upZ = 0
      }
      var z = new PVector(eyeX - centerX, eyeY - centerY, eyeZ - centerZ);
      var y = new PVector(upX, upY, upZ);
      z.normalize();
      var x = PVector.cross(y, z);
      y = PVector.cross(z, x);
      x.normalize();
      y.normalize();
      var xX = x.x,
        xY = x.y,
        xZ = x.z;
      var yX = y.x,
        yY = y.y,
        yZ = y.z;
      var zX = z.x,
        zY = z.y,
        zZ = z.z;
      cam.set(xX, xY, xZ, 0, yX, yY, yZ, 0, zX, zY, zZ, 0, 0, 0, 0, 1);
      cam.translate(-eyeX, -eyeY, -eyeZ);
      cameraInv.reset();
      cameraInv.invApply(xX, xY, xZ, 0, yX, yY, yZ, 0, zX, zY, zZ, 0, 0, 0, 0, 1);
      cameraInv.translate(eyeX, eyeY, eyeZ);
      modelView.set(cam);
      modelViewInv.set(cameraInv)
    };
    p.perspective = function(fov, aspect, near, far) {
      if (arguments.length === 0) {
        cameraY = curElement.height / 2;
        cameraZ = cameraY / Math.tan(cameraFOV / 2);
        cameraNear = cameraZ / 10;
        cameraFar = cameraZ * 10;
        cameraAspect = p.width / p.height;
        fov = cameraFOV;
        aspect = cameraAspect;
        near = cameraNear;
        far = cameraFar
      }
      var yMax, yMin, xMax, xMin;
      yMax = near * Math.tan(fov / 2);
      yMin = -yMax;
      xMax = yMax * aspect;
      xMin = yMin * aspect;
      p.frustum(xMin, xMax, yMin, yMax, near, far)
    };
    Drawing2D.prototype.frustum = function() {
      throw "Processing.js: frustum() is not supported in 2D mode";
    };
    Drawing3D.prototype.frustum = function(left, right, bottom, top, near, far) {
      frustumMode = true;
      projection = new PMatrix3D;
      projection.set(2 * near / (right - left), 0, (right + left) / (right - left), 0, 0, 2 * near / (top - bottom), (top + bottom) / (top - bottom), 0, 0, 0, -(far + near) / (far - near), -(2 * far * near) / (far - near), 0, 0, -1, 0);
      var proj = new PMatrix3D;
      proj.set(projection);
      proj.transpose();
      curContext.useProgram(programObject2D);
      uniformMatrix("projection2d", programObject2D, "projection", false, proj.array());
      curContext.useProgram(programObject3D);
      uniformMatrix("projection3d", programObject3D, "projection", false, proj.array());
      curContext.useProgram(programObjectUnlitShape);
      uniformMatrix("uProjectionUS", programObjectUnlitShape, "uProjection", false, proj.array())
    };
    p.ortho = function(left, right, bottom, top, near, far) {
      if (arguments.length === 0) {
        left = 0;
        right = p.width;
        bottom = 0;
        top = p.height;
        near = -10;
        far = 10
      }
      var x = 2 / (right - left);
      var y = 2 / (top - bottom);
      var z = -2 / (far - near);
      var tx = -(right + left) / (right - left);
      var ty = -(top + bottom) / (top - bottom);
      var tz = -(far + near) / (far - near);
      projection = new PMatrix3D;
      projection.set(x, 0, 0, tx, 0, y, 0, ty, 0, 0, z, tz, 0, 0, 0, 1);
      var proj = new PMatrix3D;
      proj.set(projection);
      proj.transpose();
      curContext.useProgram(programObject2D);
      uniformMatrix("projection2d", programObject2D, "projection", false, proj.array());
      curContext.useProgram(programObject3D);
      uniformMatrix("projection3d", programObject3D, "projection", false, proj.array());
      curContext.useProgram(programObjectUnlitShape);
      uniformMatrix("uProjectionUS", programObjectUnlitShape, "uProjection", false, proj.array());
      frustumMode = false
    };
    p.printProjection = function() {
      projection.print()
    };
    p.printCamera = function() {
      cam.print()
    };
    Drawing2D.prototype.box = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.box = function(w, h, d) {
      if (!h || !d) h = d = w;
      var model = new PMatrix3D;
      model.scale(w, h, d);
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      if (doFill) {
        curContext.useProgram(programObject3D);
        uniformMatrix("model3d", programObject3D, "model", false, model.array());
        uniformMatrix("view3d", programObject3D, "view", false, view.array());
        curContext.enable(curContext.POLYGON_OFFSET_FILL);
        curContext.polygonOffset(1, 1);
        uniformf("color3d", programObject3D, "color", fillStyle);
        if (lightCount > 0) {
          var v = new PMatrix3D;
          v.set(view);
          var m = new PMatrix3D;
          m.set(model);
          v.mult(m);
          var normalMatrix = new PMatrix3D;
          normalMatrix.set(v);
          normalMatrix.invert();
          normalMatrix.transpose();
          uniformMatrix("normalTransform3d", programObject3D, "normalTransform", false, normalMatrix.array());
          vertexAttribPointer("normal3d", programObject3D, "Normal", 3, boxNormBuffer)
        } else disableVertexAttribPointer("normal3d", programObject3D, "Normal");
        vertexAttribPointer("vertex3d", programObject3D, "Vertex", 3, boxBuffer);
        disableVertexAttribPointer("aColor3d", programObject3D, "aColor");
        disableVertexAttribPointer("aTexture3d", programObject3D, "aTexture");
        curContext.drawArrays(curContext.TRIANGLES, 0, boxVerts.length / 3);
        curContext.disable(curContext.POLYGON_OFFSET_FILL)
      }
      if (lineWidth > 0 && doStroke) {
        curContext.useProgram(programObject2D);
        uniformMatrix("model2d", programObject2D, "model", false, model.array());
        uniformMatrix("view2d", programObject2D, "view", false, view.array());
        uniformf("color2d", programObject2D, "color", strokeStyle);
        uniformi("picktype2d", programObject2D, "picktype", 0);
        vertexAttribPointer("vertex2d", programObject2D, "Vertex", 3, boxOutlineBuffer);
        disableVertexAttribPointer("aTextureCoord2d", programObject2D, "aTextureCoord");
        curContext.drawArrays(curContext.LINES, 0, boxOutlineVerts.length / 3)
      }
    };
    var initSphere = function() {
      var i;
      sphereVerts = [];
      for (i = 0; i < sphereDetailU; i++) {
        sphereVerts.push(0);
        sphereVerts.push(-1);
        sphereVerts.push(0);
        sphereVerts.push(sphereX[i]);
        sphereVerts.push(sphereY[i]);
        sphereVerts.push(sphereZ[i])
      }
      sphereVerts.push(0);
      sphereVerts.push(-1);
      sphereVerts.push(0);
      sphereVerts.push(sphereX[0]);
      sphereVerts.push(sphereY[0]);
      sphereVerts.push(sphereZ[0]);
      var v1, v11, v2;
      var voff = 0;
      for (i = 2; i < sphereDetailV; i++) {
        v1 = v11 = voff;
        voff += sphereDetailU;
        v2 = voff;
        for (var j = 0; j < sphereDetailU; j++) {
          sphereVerts.push(sphereX[v1]);
          sphereVerts.push(sphereY[v1]);
          sphereVerts.push(sphereZ[v1++]);
          sphereVerts.push(sphereX[v2]);
          sphereVerts.push(sphereY[v2]);
          sphereVerts.push(sphereZ[v2++])
        }
        v1 = v11;
        v2 = voff;
        sphereVerts.push(sphereX[v1]);
        sphereVerts.push(sphereY[v1]);
        sphereVerts.push(sphereZ[v1]);
        sphereVerts.push(sphereX[v2]);
        sphereVerts.push(sphereY[v2]);
        sphereVerts.push(sphereZ[v2])
      }
      for (i = 0; i < sphereDetailU; i++) {
        v2 = voff + i;
        sphereVerts.push(sphereX[v2]);
        sphereVerts.push(sphereY[v2]);
        sphereVerts.push(sphereZ[v2]);
        sphereVerts.push(0);
        sphereVerts.push(1);
        sphereVerts.push(0)
      }
      sphereVerts.push(sphereX[voff]);
      sphereVerts.push(sphereY[voff]);
      sphereVerts.push(sphereZ[voff]);
      sphereVerts.push(0);
      sphereVerts.push(1);
      sphereVerts.push(0);
      curContext.bindBuffer(curContext.ARRAY_BUFFER, sphereBuffer);
      curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(sphereVerts), curContext.STATIC_DRAW)
    };
    p.sphereDetail = function(ures, vres) {
      var i;
      if (arguments.length === 1) ures = vres = arguments[0];
      if (ures < 3) ures = 3;
      if (vres < 2) vres = 2;
      if (ures === sphereDetailU && vres === sphereDetailV) return;
      var delta = 720 / ures;
      var cx = new Float32Array(ures);
      var cz = new Float32Array(ures);
      for (i = 0; i < ures; i++) {
        cx[i] = cosLUT[i * delta % 720 | 0];
        cz[i] = sinLUT[i * delta % 720 | 0]
      }
      var vertCount = ures * (vres - 1) + 2;
      var currVert = 0;
      sphereX = new Float32Array(vertCount);
      sphereY = new Float32Array(vertCount);
      sphereZ = new Float32Array(vertCount);
      var angle_step = 720 * 0.5 / vres;
      var angle = angle_step;
      for (i = 1; i < vres; i++) {
        var curradius = sinLUT[angle % 720 | 0];
        var currY = -cosLUT[angle % 720 | 0];
        for (var j = 0; j < ures; j++) {
          sphereX[currVert] = cx[j] * curradius;
          sphereY[currVert] = currY;
          sphereZ[currVert++] = cz[j] * curradius
        }
        angle += angle_step
      }
      sphereDetailU = ures;
      sphereDetailV = vres;
      initSphere()
    };
    Drawing2D.prototype.sphere = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.sphere = function() {
      var sRad = arguments[0];
      if (sphereDetailU < 3 || sphereDetailV < 2) p.sphereDetail(30);
      var model = new PMatrix3D;
      model.scale(sRad, sRad, sRad);
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      if (doFill) {
        if (lightCount > 0) {
          var v = new PMatrix3D;
          v.set(view);
          var m = new PMatrix3D;
          m.set(model);
          v.mult(m);
          var normalMatrix = new PMatrix3D;
          normalMatrix.set(v);
          normalMatrix.invert();
          normalMatrix.transpose();
          uniformMatrix("normalTransform3d", programObject3D, "normalTransform", false, normalMatrix.array());
          vertexAttribPointer("normal3d", programObject3D, "Normal", 3, sphereBuffer)
        } else disableVertexAttribPointer("normal3d", programObject3D, "Normal");
        curContext.useProgram(programObject3D);
        disableVertexAttribPointer("aTexture3d", programObject3D, "aTexture");
        uniformMatrix("model3d", programObject3D, "model", false, model.array());
        uniformMatrix("view3d", programObject3D, "view", false, view.array());
        vertexAttribPointer("vertex3d", programObject3D, "Vertex", 3, sphereBuffer);
        disableVertexAttribPointer("aColor3d", programObject3D, "aColor");
        curContext.enable(curContext.POLYGON_OFFSET_FILL);
        curContext.polygonOffset(1, 1);
        uniformf("color3d", programObject3D, "color", fillStyle);
        curContext.drawArrays(curContext.TRIANGLE_STRIP, 0, sphereVerts.length / 3);
        curContext.disable(curContext.POLYGON_OFFSET_FILL)
      }
      if (lineWidth > 0 && doStroke) {
        curContext.useProgram(programObject2D);
        uniformMatrix("model2d", programObject2D, "model", false, model.array());
        uniformMatrix("view2d", programObject2D, "view", false, view.array());
        vertexAttribPointer("vertex2d", programObject2D, "Vertex", 3, sphereBuffer);
        disableVertexAttribPointer("aTextureCoord2d", programObject2D, "aTextureCoord");
        uniformf("color2d", programObject2D, "color", strokeStyle);
        uniformi("picktype2d", programObject2D, "picktype", 0);
        curContext.drawArrays(curContext.LINE_STRIP, 0, sphereVerts.length / 3)
      }
    };
    p.modelX = function(x, y, z) {
      var mv = modelView.array();
      var ci = cameraInv.array();
      var ax = mv[0] * x + mv[1] * y + mv[2] * z + mv[3];
      var ay = mv[4] * x + mv[5] * y + mv[6] * z + mv[7];
      var az = mv[8] * x + mv[9] * y + mv[10] * z + mv[11];
      var aw = mv[12] * x + mv[13] * y + mv[14] * z + mv[15];
      var ox = ci[0] * ax + ci[1] * ay + ci[2] * az + ci[3] * aw;
      var ow = ci[12] * ax + ci[13] * ay + ci[14] * az + ci[15] * aw;
      return ow !== 0 ? ox / ow : ox
    };
    p.modelY = function(x, y, z) {
      var mv = modelView.array();
      var ci = cameraInv.array();
      var ax = mv[0] * x + mv[1] * y + mv[2] * z + mv[3];
      var ay = mv[4] * x + mv[5] * y + mv[6] * z + mv[7];
      var az = mv[8] * x + mv[9] * y + mv[10] * z + mv[11];
      var aw = mv[12] * x + mv[13] * y + mv[14] * z + mv[15];
      var oy = ci[4] * ax + ci[5] * ay + ci[6] * az + ci[7] * aw;
      var ow = ci[12] * ax + ci[13] * ay + ci[14] * az + ci[15] * aw;
      return ow !== 0 ? oy / ow : oy
    };
    p.modelZ = function(x, y, z) {
      var mv = modelView.array();
      var ci = cameraInv.array();
      var ax = mv[0] * x + mv[1] * y + mv[2] * z + mv[3];
      var ay = mv[4] * x + mv[5] * y + mv[6] * z + mv[7];
      var az = mv[8] * x + mv[9] * y + mv[10] * z + mv[11];
      var aw = mv[12] * x + mv[13] * y + mv[14] * z + mv[15];
      var oz = ci[8] * ax + ci[9] * ay + ci[10] * az + ci[11] * aw;
      var ow = ci[12] * ax + ci[13] * ay + ci[14] * az + ci[15] * aw;
      return ow !== 0 ? oz / ow : oz
    };
    Drawing2D.prototype.ambient = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.ambient = function(v1, v2, v3) {
      curContext.useProgram(programObject3D);
      uniformi("usingMat3d", programObject3D, "usingMat", true);
      var col = p.color(v1, v2, v3);
      uniformf("mat_ambient3d", programObject3D, "mat_ambient", p.color.toGLArray(col).slice(0, 3))
    };
    Drawing2D.prototype.emissive = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.emissive = function(v1, v2, v3) {
      curContext.useProgram(programObject3D);
      uniformi("usingMat3d", programObject3D, "usingMat", true);
      var col = p.color(v1, v2, v3);
      uniformf("mat_emissive3d", programObject3D, "mat_emissive", p.color.toGLArray(col).slice(0, 3))
    };
    Drawing2D.prototype.shininess = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.shininess = function(shine) {
      curContext.useProgram(programObject3D);
      uniformi("usingMat3d", programObject3D, "usingMat", true);
      uniformf("shininess3d", programObject3D, "shininess", shine)
    };
    Drawing2D.prototype.specular = DrawingShared.prototype.a3DOnlyFunction;
    Drawing3D.prototype.specular = function(v1, v2, v3) {
      curContext.useProgram(programObject3D);
      uniformi("usingMat3d", programObject3D, "usingMat", true);
      var col = p.color(v1, v2, v3);
      uniformf("mat_specular3d", programObject3D, "mat_specular", p.color.toGLArray(col).slice(0, 3))
    };
    p.screenX = function(x, y, z) {
      var mv = modelView.array();
      if (mv.length === 16) {
        var ax = mv[0] * x + mv[1] * y + mv[2] * z + mv[3];
        var ay = mv[4] * x + mv[5] * y + mv[6] * z + mv[7];
        var az = mv[8] * x + mv[9] * y + mv[10] * z + mv[11];
        var aw = mv[12] * x + mv[13] * y + mv[14] * z + mv[15];
        var pj = projection.array();
        var ox = pj[0] * ax + pj[1] * ay + pj[2] * az + pj[3] * aw;
        var ow = pj[12] * ax + pj[13] * ay + pj[14] * az + pj[15] * aw;
        if (ow !== 0) ox /= ow;
        return p.width * (1 + ox) / 2
      }
      return modelView.multX(x, y)
    };
    p.screenY = function screenY(x, y, z) {
      var mv = modelView.array();
      if (mv.length === 16) {
        var ax = mv[0] * x + mv[1] * y + mv[2] * z + mv[3];
        var ay = mv[4] * x + mv[5] * y + mv[6] * z + mv[7];
        var az = mv[8] * x + mv[9] * y + mv[10] * z + mv[11];
        var aw = mv[12] * x + mv[13] * y + mv[14] * z + mv[15];
        var pj = projection.array();
        var oy = pj[4] * ax + pj[5] * ay + pj[6] * az + pj[7] * aw;
        var ow = pj[12] * ax + pj[13] * ay + pj[14] * az + pj[15] * aw;
        if (ow !== 0) oy /= ow;
        return p.height * (1 + oy) / 2
      }
      return modelView.multY(x, y)
    };
    p.screenZ = function screenZ(x, y, z) {
      var mv = modelView.array();
      if (mv.length !== 16) return 0;
      var pj = projection.array();
      var ax = mv[0] * x + mv[1] * y + mv[2] * z + mv[3];
      var ay = mv[4] * x + mv[5] * y + mv[6] * z + mv[7];
      var az = mv[8] * x + mv[9] * y + mv[10] * z + mv[11];
      var aw = mv[12] * x + mv[13] * y + mv[14] * z + mv[15];
      var oz = pj[8] * ax + pj[9] * ay + pj[10] * az + pj[11] * aw;
      var ow = pj[12] * ax + pj[13] * ay + pj[14] * az + pj[15] * aw;
      if (ow !== 0) oz /= ow;
      return (oz + 1) / 2
    };
    DrawingShared.prototype.fill = function() {
      var color = p.color(arguments[0], arguments[1], arguments[2], arguments[3]);
      if (color === currentFillColor && doFill) return;
      doFill = true;
      currentFillColor = color
    };
    Drawing2D.prototype.fill = function() {
      DrawingShared.prototype.fill.apply(this, arguments);
      isFillDirty = true
    };
    Drawing3D.prototype.fill = function() {
      DrawingShared.prototype.fill.apply(this, arguments);
      fillStyle = p.color.toGLArray(currentFillColor)
    };

    function executeContextFill() {
      if (doFill) {
        if (isFillDirty) {
          curContext.fillStyle = p.color.toString(currentFillColor);
          isFillDirty = false
        }
        curContext.fill()
      }
    }
    p.noFill = function() {
      doFill = false
    };
    DrawingShared.prototype.stroke = function() {
      var color = p.color(arguments[0], arguments[1], arguments[2], arguments[3]);
      if (color === currentStrokeColor && doStroke) return;
      doStroke = true;
      currentStrokeColor = color
    };
    Drawing2D.prototype.stroke = function() {
      DrawingShared.prototype.stroke.apply(this, arguments);
      isStrokeDirty = true
    };
    Drawing3D.prototype.stroke = function() {
      DrawingShared.prototype.stroke.apply(this, arguments);
      strokeStyle = p.color.toGLArray(currentStrokeColor)
    };

    function executeContextStroke() {
      if (doStroke) {
        if (isStrokeDirty) {
          curContext.strokeStyle = p.color.toString(currentStrokeColor);
          isStrokeDirty = false
        }
        curContext.stroke()
      }
    }
    p.noStroke = function() {
      doStroke = false
    };
    DrawingShared.prototype.strokeWeight = function(w) {
      lineWidth = w
    };
    Drawing2D.prototype.strokeWeight = function(w) {
      DrawingShared.prototype.strokeWeight.apply(this, arguments);
      curContext.lineWidth = w
    };
    Drawing3D.prototype.strokeWeight = function(w) {
      DrawingShared.prototype.strokeWeight.apply(this, arguments);
      curContext.useProgram(programObject2D);
      uniformf("pointSize2d", programObject2D, "pointSize", w);
      curContext.useProgram(programObjectUnlitShape);
      uniformf("pointSizeUnlitShape", programObjectUnlitShape, "pointSize", w);
      curContext.lineWidth(w)
    };
    p.strokeCap = function(value) {
      drawing.$ensureContext().lineCap = value
    };
    p.strokeJoin = function(value) {
      drawing.$ensureContext().lineJoin = value
    };
    Drawing2D.prototype.smooth = function() {
      renderSmooth = true;
      var style = curElement.style;
      style.setProperty("image-rendering", "optimizeQuality", "important");
      style.setProperty("-ms-interpolation-mode", "bicubic", "important");
      if (curContext.hasOwnProperty("mozImageSmoothingEnabled")) curContext.mozImageSmoothingEnabled = true
    };
    Drawing3D.prototype.smooth = nop;
    Drawing2D.prototype.noSmooth = function() {
      renderSmooth = false;
      var style = curElement.style;
      style.setProperty("image-rendering", "optimizeSpeed", "important");
      style.setProperty("image-rendering", "-moz-crisp-edges", "important");
      style.setProperty("image-rendering", "-webkit-optimize-contrast", "important");
      style.setProperty("image-rendering", "optimize-contrast", "important");
      style.setProperty("-ms-interpolation-mode", "nearest-neighbor", "important");
      if (curContext.hasOwnProperty("mozImageSmoothingEnabled")) curContext.mozImageSmoothingEnabled = false
    };
    Drawing3D.prototype.noSmooth = nop;
    Drawing2D.prototype.point = function(x, y) {
      if (!doStroke) return;
      x = Math.round(x);
      y = Math.round(y);
      curContext.fillStyle = p.color.toString(currentStrokeColor);
      isFillDirty = true;
      if (lineWidth > 1) {
        curContext.beginPath();
        curContext.arc(x, y, lineWidth / 2, 0, 6.283185307179586, false);
        curContext.fill()
      } else curContext.fillRect(x, y, 1, 1)
    };
    Drawing3D.prototype.point = function(x, y, z) {
      var model = new PMatrix3D;
      model.translate(x, y, z || 0);
      model.transpose();
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      curContext.useProgram(programObject2D);
      uniformMatrix("model2d", programObject2D, "model", false, model.array());
      uniformMatrix("view2d", programObject2D, "view", false, view.array());
      if (lineWidth > 0 && doStroke) {
        uniformf("color2d", programObject2D, "color", strokeStyle);
        uniformi("picktype2d", programObject2D, "picktype", 0);
        vertexAttribPointer("vertex2d", programObject2D, "Vertex", 3, pointBuffer);
        disableVertexAttribPointer("aTextureCoord2d", programObject2D, "aTextureCoord");
        curContext.drawArrays(curContext.POINTS, 0, 1)
      }
    };
    p.beginShape = function(type) {
      curShape = type;
      curvePoints = [];
      vertArray = []
    };
    Drawing2D.prototype.vertex = function(x, y, u, v) {
      var vert = [];
      if (firstVert) firstVert = false;
      vert["isVert"] = true;
      vert[0] = x;
      vert[1] = y;
      vert[2] = 0;
      vert[3] = u;
      vert[4] = v;
      vert[5] = currentFillColor;
      vert[6] = currentStrokeColor;
      vertArray.push(vert)
    };
    Drawing3D.prototype.vertex = function(x, y, z, u, v) {
      var vert = [];
      if (firstVert) firstVert = false;
      vert["isVert"] = true;
      if (v === undef && usingTexture) {
        v = u;
        u = z;
        z = 0
      }
      if (u !== undef && v !== undef) {
        if (curTextureMode === 2) {
          u /= curTexture.width;
          v /= curTexture.height
        }
        u = u > 1 ? 1 : u;
        u = u < 0 ? 0 : u;
        v = v > 1 ? 1 : v;
        v = v < 0 ? 0 : v
      }
      vert[0] = x;
      vert[1] = y;
      vert[2] = z || 0;
      vert[3] = u || 0;
      vert[4] = v || 0;
      vert[5] = fillStyle[0];
      vert[6] = fillStyle[1];
      vert[7] = fillStyle[2];
      vert[8] = fillStyle[3];
      vert[9] = strokeStyle[0];
      vert[10] = strokeStyle[1];
      vert[11] = strokeStyle[2];
      vert[12] = strokeStyle[3];
      vert[13] = normalX;
      vert[14] = normalY;
      vert[15] = normalZ;
      vertArray.push(vert)
    };
    var point3D = function(vArray, cArray) {
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      curContext.useProgram(programObjectUnlitShape);
      uniformMatrix("uViewUS", programObjectUnlitShape, "uView", false, view.array());
      vertexAttribPointer("aVertexUS", programObjectUnlitShape, "aVertex", 3, pointBuffer);
      curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(vArray), curContext.STREAM_DRAW);
      vertexAttribPointer("aColorUS", programObjectUnlitShape, "aColor", 4, fillColorBuffer);
      curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(cArray), curContext.STREAM_DRAW);
      curContext.drawArrays(curContext.POINTS, 0, vArray.length / 3)
    };
    var line3D = function(vArray, mode, cArray) {
      var ctxMode;
      if (mode === "LINES") ctxMode = curContext.LINES;
      else if (mode === "LINE_LOOP") ctxMode = curContext.LINE_LOOP;
      else ctxMode = curContext.LINE_STRIP;
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      curContext.useProgram(programObjectUnlitShape);
      uniformMatrix("uViewUS", programObjectUnlitShape, "uView", false, view.array());
      vertexAttribPointer("aVertexUS", programObjectUnlitShape, "aVertex", 3, lineBuffer);
      curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(vArray), curContext.STREAM_DRAW);
      vertexAttribPointer("aColorUS", programObjectUnlitShape, "aColor", 4, strokeColorBuffer);
      curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(cArray), curContext.STREAM_DRAW);
      curContext.drawArrays(ctxMode, 0, vArray.length / 3)
    };
    var fill3D = function(vArray, mode, cArray, tArray) {
      var ctxMode;
      if (mode === "TRIANGLES") ctxMode = curContext.TRIANGLES;
      else if (mode === "TRIANGLE_FAN") ctxMode = curContext.TRIANGLE_FAN;
      else ctxMode = curContext.TRIANGLE_STRIP;
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      curContext.useProgram(programObject3D);
      uniformMatrix("model3d", programObject3D, "model", false, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
      uniformMatrix("view3d", programObject3D, "view", false, view.array());
      curContext.enable(curContext.POLYGON_OFFSET_FILL);
      curContext.polygonOffset(1, 1);
      uniformf("color3d", programObject3D, "color", [-1, 0, 0, 0]);
      vertexAttribPointer("vertex3d", programObject3D, "Vertex", 3, fillBuffer);
      curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(vArray), curContext.STREAM_DRAW);
      if (usingTexture && curTint !== null) curTint3d(cArray);
      vertexAttribPointer("aColor3d", programObject3D, "aColor", 4, fillColorBuffer);
      curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(cArray), curContext.STREAM_DRAW);
      disableVertexAttribPointer("normal3d", programObject3D, "Normal");
      if (usingTexture) {
        uniformi("usingTexture3d", programObject3D, "usingTexture", usingTexture);
        vertexAttribPointer("aTexture3d", programObject3D, "aTexture", 2, shapeTexVBO);
        curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(tArray), curContext.STREAM_DRAW)
      }
      curContext.drawArrays(ctxMode, 0, vArray.length / 3);
      curContext.disable(curContext.POLYGON_OFFSET_FILL)
    };

    function fillStrokeClose() {
      executeContextFill();
      executeContextStroke();
      curContext.closePath()
    }
    Drawing2D.prototype.endShape = function(mode) {
      if (vertArray.length === 0) return;
      var closeShape = mode === 2;
      if (closeShape) vertArray.push(vertArray[0]);
      var lineVertArray = [];
      var fillVertArray = [];
      var colorVertArray = [];
      var strokeVertArray = [];
      var texVertArray = [];
      var cachedVertArray;
      firstVert = true;
      var i, j, k;
      var vertArrayLength = vertArray.length;
      for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        for (j = 0; j < 3; j++) fillVertArray.push(cachedVertArray[j])
      }
      for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        for (j = 5; j < 9; j++) colorVertArray.push(cachedVertArray[j])
      }
      for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        for (j = 9; j < 13; j++) strokeVertArray.push(cachedVertArray[j])
      }
      for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        texVertArray.push(cachedVertArray[3]);
        texVertArray.push(cachedVertArray[4])
      }
      if (isCurve && (curShape === 20 || curShape === undef)) {
        if (vertArrayLength > 3) {
          var b = [],
            s = 1 - curTightness;
          curContext.beginPath();
          curContext.moveTo(vertArray[1][0], vertArray[1][1]);
          for (i = 1; i + 2 < vertArrayLength; i++) {
            cachedVertArray = vertArray[i];
            b[0] = [cachedVertArray[0], cachedVertArray[1]];
            b[1] = [cachedVertArray[0] + (s * vertArray[i + 1][0] - s * vertArray[i - 1][0]) / 6, cachedVertArray[1] +
              (s * vertArray[i + 1][1] - s * vertArray[i - 1][1]) / 6];
            b[2] = [vertArray[i + 1][0] + (s * vertArray[i][0] - s * vertArray[i + 2][0]) / 6, vertArray[i + 1][1] + (s * vertArray[i][1] - s * vertArray[i + 2][1]) / 6];
            b[3] = [vertArray[i + 1][0], vertArray[i + 1][1]];
            curContext.bezierCurveTo(b[1][0], b[1][1], b[2][0], b[2][1], b[3][0], b[3][1])
          }
          fillStrokeClose()
        }
      } else if (isBezier && (curShape === 20 || curShape === undef)) {
        curContext.beginPath();
        for (i = 0; i < vertArrayLength; i++) {
          cachedVertArray = vertArray[i];
          if (vertArray[i]["isVert"]) if (vertArray[i]["moveTo"]) curContext.moveTo(cachedVertArray[0], cachedVertArray[1]);
          else curContext.lineTo(cachedVertArray[0], cachedVertArray[1]);
          else curContext.bezierCurveTo(vertArray[i][0], vertArray[i][1], vertArray[i][2], vertArray[i][3], vertArray[i][4], vertArray[i][5])
        }
        fillStrokeClose()
      } else if (curShape === 2) for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        if (doStroke) p.stroke(cachedVertArray[6]);
        p.point(cachedVertArray[0], cachedVertArray[1])
      } else if (curShape === 4) for (i = 0; i + 1 < vertArrayLength; i += 2) {
        cachedVertArray = vertArray[i];
        if (doStroke) p.stroke(vertArray[i + 1][6]);
        p.line(cachedVertArray[0], cachedVertArray[1], vertArray[i + 1][0], vertArray[i + 1][1])
      } else if (curShape === 9) for (i = 0; i + 2 < vertArrayLength; i += 3) {
        cachedVertArray = vertArray[i];
        curContext.beginPath();
        curContext.moveTo(cachedVertArray[0], cachedVertArray[1]);
        curContext.lineTo(vertArray[i + 1][0], vertArray[i + 1][1]);
        curContext.lineTo(vertArray[i + 2][0], vertArray[i + 2][1]);
        curContext.lineTo(cachedVertArray[0], cachedVertArray[1]);
        if (doFill) {
          p.fill(vertArray[i + 2][5]);
          executeContextFill()
        }
        if (doStroke) {
          p.stroke(vertArray[i + 2][6]);
          executeContextStroke()
        }
        curContext.closePath()
      } else if (curShape === 10) for (i = 0; i + 1 < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        curContext.beginPath();
        curContext.moveTo(vertArray[i + 1][0], vertArray[i + 1][1]);
        curContext.lineTo(cachedVertArray[0], cachedVertArray[1]);
        if (doStroke) p.stroke(vertArray[i + 1][6]);
        if (doFill) p.fill(vertArray[i + 1][5]);
        if (i + 2 < vertArrayLength) {
          curContext.lineTo(vertArray[i + 2][0], vertArray[i + 2][1]);
          if (doStroke) p.stroke(vertArray[i + 2][6]);
          if (doFill) p.fill(vertArray[i + 2][5])
        }
        fillStrokeClose()
      } else if (curShape === 11) {
        if (vertArrayLength > 2) {
          curContext.beginPath();
          curContext.moveTo(vertArray[0][0], vertArray[0][1]);
          curContext.lineTo(vertArray[1][0], vertArray[1][1]);
          curContext.lineTo(vertArray[2][0], vertArray[2][1]);
          if (doFill) {
            p.fill(vertArray[2][5]);
            executeContextFill()
          }
          if (doStroke) {
            p.stroke(vertArray[2][6]);
            executeContextStroke()
          }
          curContext.closePath();
          for (i = 3; i < vertArrayLength; i++) {
            cachedVertArray = vertArray[i];
            curContext.beginPath();
            curContext.moveTo(vertArray[0][0], vertArray[0][1]);
            curContext.lineTo(vertArray[i - 1][0], vertArray[i - 1][1]);
            curContext.lineTo(cachedVertArray[0], cachedVertArray[1]);
            if (doFill) {
              p.fill(cachedVertArray[5]);
              executeContextFill()
            }
            if (doStroke) {
              p.stroke(cachedVertArray[6]);
              executeContextStroke()
            }
            curContext.closePath()
          }
        }
      } else if (curShape === 16) for (i = 0; i + 3 < vertArrayLength; i += 4) {
        cachedVertArray = vertArray[i];
        curContext.beginPath();
        curContext.moveTo(cachedVertArray[0], cachedVertArray[1]);
        for (j = 1; j < 4; j++) curContext.lineTo(vertArray[i + j][0], vertArray[i + j][1]);
        curContext.lineTo(cachedVertArray[0], cachedVertArray[1]);
        if (doFill) {
          p.fill(vertArray[i + 3][5]);
          executeContextFill()
        }
        if (doStroke) {
          p.stroke(vertArray[i + 3][6]);
          executeContextStroke()
        }
        curContext.closePath()
      } else if (curShape === 17) {
        if (vertArrayLength > 3) for (i = 0; i + 1 < vertArrayLength; i += 2) {
          cachedVertArray = vertArray[i];
          curContext.beginPath();
          if (i + 3 < vertArrayLength) {
            curContext.moveTo(vertArray[i + 2][0], vertArray[i + 2][1]);
            curContext.lineTo(cachedVertArray[0], cachedVertArray[1]);
            curContext.lineTo(vertArray[i + 1][0], vertArray[i + 1][1]);
            curContext.lineTo(vertArray[i + 3][0], vertArray[i + 3][1]);
            if (doFill) p.fill(vertArray[i + 3][5]);
            if (doStroke) p.stroke(vertArray[i + 3][6])
          } else {
            curContext.moveTo(cachedVertArray[0], cachedVertArray[1]);
            curContext.lineTo(vertArray[i + 1][0], vertArray[i + 1][1])
          }
          fillStrokeClose()
        }
      } else {
        curContext.beginPath();
        curContext.moveTo(vertArray[0][0], vertArray[0][1]);
        for (i = 1; i < vertArrayLength; i++) {
          cachedVertArray = vertArray[i];
          if (cachedVertArray["isVert"]) if (cachedVertArray["moveTo"]) curContext.moveTo(cachedVertArray[0], cachedVertArray[1]);
          else curContext.lineTo(cachedVertArray[0], cachedVertArray[1])
        }
        fillStrokeClose()
      }
      isCurve = false;
      isBezier = false;
      curveVertArray = [];
      curveVertCount = 0;
      if (closeShape) vertArray.pop()
    };
    Drawing3D.prototype.endShape = function(mode) {
      if (vertArray.length === 0) return;
      var closeShape = mode === 2;
      var lineVertArray = [];
      var fillVertArray = [];
      var colorVertArray = [];
      var strokeVertArray = [];
      var texVertArray = [];
      var cachedVertArray;
      firstVert = true;
      var i, j, k;
      var vertArrayLength = vertArray.length;
      for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        for (j = 0; j < 3; j++) fillVertArray.push(cachedVertArray[j])
      }
      for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        for (j = 5; j < 9; j++) colorVertArray.push(cachedVertArray[j])
      }
      for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        for (j = 9; j < 13; j++) strokeVertArray.push(cachedVertArray[j])
      }
      for (i = 0; i < vertArrayLength; i++) {
        cachedVertArray = vertArray[i];
        texVertArray.push(cachedVertArray[3]);
        texVertArray.push(cachedVertArray[4])
      }
      if (closeShape) {
        fillVertArray.push(vertArray[0][0]);
        fillVertArray.push(vertArray[0][1]);
        fillVertArray.push(vertArray[0][2]);
        for (i = 5; i < 9; i++) colorVertArray.push(vertArray[0][i]);
        for (i = 9; i < 13; i++) strokeVertArray.push(vertArray[0][i]);
        texVertArray.push(vertArray[0][3]);
        texVertArray.push(vertArray[0][4])
      }
      if (isCurve && (curShape === 20 || curShape === undef)) {
        lineVertArray = fillVertArray;
        if (doStroke) line3D(lineVertArray, null, strokeVertArray);
        if (doFill) fill3D(fillVertArray, null, colorVertArray)
      } else if (isBezier && (curShape === 20 || curShape === undef)) {
        lineVertArray = fillVertArray;
        lineVertArray.splice(lineVertArray.length - 3);
        strokeVertArray.splice(strokeVertArray.length - 4);
        if (doStroke) line3D(lineVertArray, null, strokeVertArray);
        if (doFill) fill3D(fillVertArray, "TRIANGLES", colorVertArray)
      } else {
        if (curShape === 2) {
          for (i = 0; i < vertArrayLength; i++) {
            cachedVertArray = vertArray[i];
            for (j = 0; j < 3; j++) lineVertArray.push(cachedVertArray[j])
          }
          point3D(lineVertArray, strokeVertArray)
        } else if (curShape === 4) {
          for (i = 0; i < vertArrayLength; i++) {
            cachedVertArray = vertArray[i];
            for (j = 0; j < 3; j++) lineVertArray.push(cachedVertArray[j])
          }
          for (i = 0; i < vertArrayLength; i++) {
            cachedVertArray = vertArray[i];
            for (j = 5; j < 9; j++) colorVertArray.push(cachedVertArray[j])
          }
          line3D(lineVertArray, "LINES", strokeVertArray)
        } else if (curShape === 9) {
          if (vertArrayLength > 2) for (i = 0; i + 2 < vertArrayLength; i += 3) {
            fillVertArray = [];
            texVertArray = [];
            lineVertArray = [];
            colorVertArray = [];
            strokeVertArray = [];
            for (j = 0; j < 3; j++) for (k = 0; k < 3; k++) {
              lineVertArray.push(vertArray[i + j][k]);
              fillVertArray.push(vertArray[i + j][k])
            }
            for (j = 0; j < 3; j++) for (k = 3; k < 5; k++) texVertArray.push(vertArray[i + j][k]);
            for (j = 0; j < 3; j++) for (k = 5; k < 9; k++) {
              colorVertArray.push(vertArray[i + j][k]);
              strokeVertArray.push(vertArray[i + j][k + 4])
            }
            if (doStroke) line3D(lineVertArray, "LINE_LOOP", strokeVertArray);
            if (doFill || usingTexture) fill3D(fillVertArray, "TRIANGLES", colorVertArray, texVertArray)
          }
        } else if (curShape === 10) {
          if (vertArrayLength > 2) for (i = 0; i + 2 < vertArrayLength; i++) {
            lineVertArray = [];
            fillVertArray = [];
            strokeVertArray = [];
            colorVertArray = [];
            texVertArray = [];
            for (j = 0; j < 3; j++) for (k = 0; k < 3; k++) {
              lineVertArray.push(vertArray[i + j][k]);
              fillVertArray.push(vertArray[i + j][k])
            }
            for (j = 0; j < 3; j++) for (k = 3; k < 5; k++) texVertArray.push(vertArray[i + j][k]);
            for (j = 0; j < 3; j++) for (k = 5; k < 9; k++) {
              strokeVertArray.push(vertArray[i + j][k + 4]);
              colorVertArray.push(vertArray[i + j][k])
            }
            if (doFill || usingTexture) fill3D(fillVertArray, "TRIANGLE_STRIP", colorVertArray, texVertArray);
            if (doStroke) line3D(lineVertArray, "LINE_LOOP", strokeVertArray)
          }
        } else if (curShape === 11) {
          if (vertArrayLength > 2) {
            for (i = 0; i < 3; i++) {
              cachedVertArray = vertArray[i];
              for (j = 0; j < 3; j++) lineVertArray.push(cachedVertArray[j])
            }
            for (i = 0; i < 3; i++) {
              cachedVertArray = vertArray[i];
              for (j = 9; j < 13; j++) strokeVertArray.push(cachedVertArray[j])
            }
            if (doStroke) line3D(lineVertArray, "LINE_LOOP", strokeVertArray);
            for (i = 2; i + 1 < vertArrayLength; i++) {
              lineVertArray = [];
              strokeVertArray = [];
              lineVertArray.push(vertArray[0][0]);
              lineVertArray.push(vertArray[0][1]);
              lineVertArray.push(vertArray[0][2]);
              strokeVertArray.push(vertArray[0][9]);
              strokeVertArray.push(vertArray[0][10]);
              strokeVertArray.push(vertArray[0][11]);
              strokeVertArray.push(vertArray[0][12]);
              for (j = 0; j < 2; j++) for (k = 0; k < 3; k++) lineVertArray.push(vertArray[i + j][k]);
              for (j = 0; j < 2; j++) for (k = 9; k < 13; k++) strokeVertArray.push(vertArray[i + j][k]);
              if (doStroke) line3D(lineVertArray, "LINE_STRIP", strokeVertArray)
            }
            if (doFill || usingTexture) fill3D(fillVertArray, "TRIANGLE_FAN", colorVertArray, texVertArray)
          }
        } else if (curShape === 16) for (i = 0; i + 3 < vertArrayLength; i += 4) {
          lineVertArray = [];
          for (j = 0; j < 4; j++) {
            cachedVertArray = vertArray[i + j];
            for (k = 0; k < 3; k++) lineVertArray.push(cachedVertArray[k])
          }
          if (doStroke) line3D(lineVertArray, "LINE_LOOP", strokeVertArray);
          if (doFill) {
            fillVertArray = [];
            colorVertArray = [];
            texVertArray = [];
            for (j = 0; j < 3; j++) fillVertArray.push(vertArray[i][j]);
            for (j = 5; j < 9; j++) colorVertArray.push(vertArray[i][j]);
            for (j = 0; j < 3; j++) fillVertArray.push(vertArray[i + 1][j]);
            for (j = 5; j < 9; j++) colorVertArray.push(vertArray[i + 1][j]);
            for (j = 0; j < 3; j++) fillVertArray.push(vertArray[i + 3][j]);
            for (j = 5; j < 9; j++) colorVertArray.push(vertArray[i + 3][j]);
            for (j = 0; j < 3; j++) fillVertArray.push(vertArray[i + 2][j]);
            for (j = 5; j < 9; j++) colorVertArray.push(vertArray[i + 2][j]);
            if (usingTexture) {
              texVertArray.push(vertArray[i + 0][3]);
              texVertArray.push(vertArray[i + 0][4]);
              texVertArray.push(vertArray[i + 1][3]);
              texVertArray.push(vertArray[i + 1][4]);
              texVertArray.push(vertArray[i + 3][3]);
              texVertArray.push(vertArray[i + 3][4]);
              texVertArray.push(vertArray[i + 2][3]);
              texVertArray.push(vertArray[i + 2][4])
            }
            fill3D(fillVertArray, "TRIANGLE_STRIP", colorVertArray, texVertArray)
          }
        } else if (curShape === 17) {
          var tempArray = [];
          if (vertArrayLength > 3) {
            for (i = 0; i < 2; i++) {
              cachedVertArray = vertArray[i];
              for (j = 0; j < 3; j++) lineVertArray.push(cachedVertArray[j])
            }
            for (i = 0; i < 2; i++) {
              cachedVertArray = vertArray[i];
              for (j = 9; j < 13; j++) strokeVertArray.push(cachedVertArray[j])
            }
            line3D(lineVertArray, "LINE_STRIP", strokeVertArray);
            if (vertArrayLength > 4 && vertArrayLength % 2 > 0) {
              tempArray = fillVertArray.splice(fillVertArray.length - 3);
              vertArray.pop()
            }
            for (i = 0; i + 3 < vertArrayLength; i += 2) {
              lineVertArray = [];
              strokeVertArray = [];
              for (j = 0; j < 3; j++) lineVertArray.push(vertArray[i + 1][j]);
              for (j = 0; j < 3; j++) lineVertArray.push(vertArray[i + 3][j]);
              for (j = 0; j < 3; j++) lineVertArray.push(vertArray[i + 2][j]);
              for (j = 0; j < 3; j++) lineVertArray.push(vertArray[i + 0][j]);
              for (j = 9; j < 13; j++) strokeVertArray.push(vertArray[i + 1][j]);
              for (j = 9; j < 13; j++) strokeVertArray.push(vertArray[i + 3][j]);
              for (j = 9; j < 13; j++) strokeVertArray.push(vertArray[i + 2][j]);
              for (j = 9; j < 13; j++) strokeVertArray.push(vertArray[i + 0][j]);
              if (doStroke) line3D(lineVertArray, "LINE_STRIP", strokeVertArray)
            }
            if (doFill || usingTexture) fill3D(fillVertArray, "TRIANGLE_LIST", colorVertArray, texVertArray)
          }
        } else if (vertArrayLength === 1) {
          for (j = 0; j < 3; j++) lineVertArray.push(vertArray[0][j]);
          for (j = 9; j < 13; j++) strokeVertArray.push(vertArray[0][j]);
          point3D(lineVertArray, strokeVertArray)
        } else {
          for (i = 0; i < vertArrayLength; i++) {
            cachedVertArray = vertArray[i];
            for (j = 0; j < 3; j++) lineVertArray.push(cachedVertArray[j]);
            for (j = 5; j < 9; j++) strokeVertArray.push(cachedVertArray[j])
          }
          if (doStroke && closeShape) line3D(lineVertArray, "LINE_LOOP", strokeVertArray);
          else if (doStroke && !closeShape) line3D(lineVertArray, "LINE_STRIP", strokeVertArray);
          if (doFill || usingTexture) fill3D(fillVertArray, "TRIANGLE_FAN", colorVertArray, texVertArray)
        }
        usingTexture = false;
        curContext.useProgram(programObject3D);
        uniformi("usingTexture3d", programObject3D, "usingTexture", usingTexture)
      }
      isCurve = false;
      isBezier = false;
      curveVertArray = [];
      curveVertCount = 0
    };
    var splineForward = function(segments, matrix) {
      var f = 1 / segments;
      var ff = f * f;
      var fff = ff * f;
      matrix.set(0, 0, 0, 1, fff, ff, f, 0, 6 * fff, 2 * ff, 0, 0, 6 * fff, 0, 0, 0)
    };
    var curveInit = function() {
      if (!curveDrawMatrix) {
        curveBasisMatrix = new PMatrix3D;
        curveDrawMatrix = new PMatrix3D;
        curveInited = true
      }
      var s = curTightness;
      curveBasisMatrix.set((s - 1) / 2, (s + 3) / 2, (-3 - s) / 2, (1 - s) / 2, 1 - s, (-5 - s) / 2, s + 2, (s - 1) / 2, (s - 1) / 2, 0, (1 - s) / 2, 0, 0, 1, 0, 0);
      splineForward(curveDet, curveDrawMatrix);
      if (!bezierBasisInverse) curveToBezierMatrix = new PMatrix3D;
      curveToBezierMatrix.set(curveBasisMatrix);
      curveToBezierMatrix.preApply(bezierBasisInverse);
      curveDrawMatrix.apply(curveBasisMatrix)
    };
    Drawing2D.prototype.bezierVertex = function() {
      isBezier = true;
      var vert = [];
      if (firstVert) throw "vertex() must be used at least once before calling bezierVertex()";
      for (var i = 0; i < arguments.length; i++) vert[i] = arguments[i];
      vertArray.push(vert);
      vertArray[vertArray.length - 1]["isVert"] = false
    };
    Drawing3D.prototype.bezierVertex = function() {
      isBezier = true;
      var vert = [];
      if (firstVert) throw "vertex() must be used at least once before calling bezierVertex()";
      if (arguments.length === 9) {
        if (bezierDrawMatrix === undef) bezierDrawMatrix = new PMatrix3D;
        var lastPoint = vertArray.length - 1;
        splineForward(bezDetail, bezierDrawMatrix);
        bezierDrawMatrix.apply(bezierBasisMatrix);
        var draw = bezierDrawMatrix.array();
        var x1 = vertArray[lastPoint][0],
          y1 = vertArray[lastPoint][1],
          z1 = vertArray[lastPoint][2];
        var xplot1 = draw[4] * x1 + draw[5] * arguments[0] + draw[6] * arguments[3] + draw[7] * arguments[6];
        var xplot2 = draw[8] * x1 + draw[9] * arguments[0] + draw[10] * arguments[3] + draw[11] * arguments[6];
        var xplot3 = draw[12] * x1 + draw[13] * arguments[0] + draw[14] * arguments[3] + draw[15] * arguments[6];
        var yplot1 = draw[4] * y1 + draw[5] * arguments[1] + draw[6] * arguments[4] + draw[7] * arguments[7];
        var yplot2 = draw[8] * y1 + draw[9] * arguments[1] + draw[10] * arguments[4] + draw[11] * arguments[7];
        var yplot3 = draw[12] * y1 + draw[13] * arguments[1] + draw[14] * arguments[4] + draw[15] * arguments[7];
        var zplot1 = draw[4] * z1 + draw[5] * arguments[2] + draw[6] * arguments[5] + draw[7] * arguments[8];
        var zplot2 = draw[8] * z1 + draw[9] * arguments[2] + draw[10] * arguments[5] + draw[11] * arguments[8];
        var zplot3 = draw[12] * z1 + draw[13] * arguments[2] + draw[14] * arguments[5] + draw[15] * arguments[8];
        for (var j = 0; j < bezDetail; j++) {
          x1 += xplot1;
          xplot1 += xplot2;
          xplot2 += xplot3;
          y1 += yplot1;
          yplot1 += yplot2;
          yplot2 += yplot3;
          z1 += zplot1;
          zplot1 += zplot2;
          zplot2 += zplot3;
          p.vertex(x1, y1, z1)
        }
        p.vertex(arguments[6], arguments[7], arguments[8])
      }
    };
    p.texture = function(pimage) {
      var curContext = drawing.$ensureContext();
      if (pimage.__texture) curContext.bindTexture(curContext.TEXTURE_2D, pimage.__texture);
      else if (pimage.localName === "canvas") {
        curContext.bindTexture(curContext.TEXTURE_2D, canTex);
        curContext.texImage2D(curContext.TEXTURE_2D, 0, curContext.RGBA, curContext.RGBA, curContext.UNSIGNED_BYTE, pimage);
        curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_MAG_FILTER, curContext.LINEAR);
        curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_MIN_FILTER, curContext.LINEAR);
        curContext.generateMipmap(curContext.TEXTURE_2D);
        curTexture.width = pimage.width;
        curTexture.height = pimage.height
      } else {
        var texture = curContext.createTexture(),
          cvs = document.createElement("canvas"),
          cvsTextureCtx = cvs.getContext("2d"),
          pot;
        if (pimage.width & pimage.width - 1 === 0) cvs.width = pimage.width;
        else {
          pot = 1;
          while (pot < pimage.width) pot *= 2;
          cvs.width = pot
        }
        if (pimage.height & pimage.height - 1 === 0) cvs.height = pimage.height;
        else {
          pot = 1;
          while (pot < pimage.height) pot *= 2;
          cvs.height = pot
        }
        cvsTextureCtx.drawImage(pimage.sourceImg, 0, 0, pimage.width, pimage.height, 0, 0, cvs.width, cvs.height);
        curContext.bindTexture(curContext.TEXTURE_2D, texture);
        curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_MIN_FILTER, curContext.LINEAR_MIPMAP_LINEAR);
        curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_MAG_FILTER, curContext.LINEAR);
        curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_WRAP_T, curContext.CLAMP_TO_EDGE);
        curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_WRAP_S, curContext.CLAMP_TO_EDGE);
        curContext.texImage2D(curContext.TEXTURE_2D, 0, curContext.RGBA, curContext.RGBA, curContext.UNSIGNED_BYTE, cvs);
        curContext.generateMipmap(curContext.TEXTURE_2D);
        pimage.__texture = texture;
        curTexture.width = pimage.width;
        curTexture.height = pimage.height
      }
      usingTexture = true;
      curContext.useProgram(programObject3D);
      uniformi("usingTexture3d", programObject3D, "usingTexture", usingTexture)
    };
    p.textureMode = function(mode) {
      curTextureMode = mode
    };
    var curveVertexSegment = function(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4) {
      var x0 = x2;
      var y0 = y2;
      var z0 = z2;
      var draw = curveDrawMatrix.array();
      var xplot1 = draw[4] * x1 + draw[5] * x2 + draw[6] * x3 + draw[7] * x4;
      var xplot2 = draw[8] * x1 + draw[9] * x2 + draw[10] * x3 + draw[11] * x4;
      var xplot3 = draw[12] * x1 + draw[13] * x2 + draw[14] * x3 + draw[15] * x4;
      var yplot1 = draw[4] * y1 + draw[5] * y2 + draw[6] * y3 + draw[7] * y4;
      var yplot2 = draw[8] * y1 + draw[9] * y2 + draw[10] * y3 + draw[11] * y4;
      var yplot3 = draw[12] * y1 + draw[13] * y2 + draw[14] * y3 + draw[15] * y4;
      var zplot1 = draw[4] * z1 + draw[5] * z2 + draw[6] * z3 + draw[7] * z4;
      var zplot2 = draw[8] * z1 + draw[9] * z2 + draw[10] * z3 + draw[11] * z4;
      var zplot3 = draw[12] * z1 + draw[13] * z2 + draw[14] * z3 + draw[15] * z4;
      p.vertex(x0, y0, z0);
      for (var j = 0; j < curveDet; j++) {
        x0 += xplot1;
        xplot1 += xplot2;
        xplot2 += xplot3;
        y0 += yplot1;
        yplot1 += yplot2;
        yplot2 += yplot3;
        z0 += zplot1;
        zplot1 += zplot2;
        zplot2 += zplot3;
        p.vertex(x0, y0, z0)
      }
    };
    Drawing2D.prototype.curveVertex = function(x, y) {
      isCurve = true;
      p.vertex(x, y)
    };
    Drawing3D.prototype.curveVertex = function(x, y, z) {
      isCurve = true;
      if (!curveInited) curveInit();
      var vert = [];
      vert[0] = x;
      vert[1] = y;
      vert[2] = z;
      curveVertArray.push(vert);
      curveVertCount++;
      if (curveVertCount > 3) curveVertexSegment(curveVertArray[curveVertCount - 4][0], curveVertArray[curveVertCount - 4][1], curveVertArray[curveVertCount - 4][2], curveVertArray[curveVertCount - 3][0], curveVertArray[curveVertCount - 3][1], curveVertArray[curveVertCount - 3][2], curveVertArray[curveVertCount - 2][0], curveVertArray[curveVertCount - 2][1], curveVertArray[curveVertCount - 2][2], curveVertArray[curveVertCount - 1][0], curveVertArray[curveVertCount - 1][1], curveVertArray[curveVertCount - 1][2])
    };
    Drawing2D.prototype.curve = function() {
      if (arguments.length === 8) {
        p.beginShape();
        p.curveVertex(arguments[0], arguments[1]);
        p.curveVertex(arguments[2], arguments[3]);
        p.curveVertex(arguments[4], arguments[5]);
        p.curveVertex(arguments[6], arguments[7]);
        p.endShape()
      }
    };
    Drawing3D.prototype.curve = function() {
      if (arguments.length === 12) {
        p.beginShape();
        p.curveVertex(arguments[0], arguments[1], arguments[2]);
        p.curveVertex(arguments[3], arguments[4], arguments[5]);
        p.curveVertex(arguments[6], arguments[7], arguments[8]);
        p.curveVertex(arguments[9], arguments[10], arguments[11]);
        p.endShape()
      }
    };
    p.curveTightness = function(tightness) {
      curTightness = tightness
    };
    p.curveDetail = function(detail) {
      curveDet = detail;
      curveInit()
    };
    p.rectMode = function(aRectMode) {
      curRectMode = aRectMode
    };
    p.imageMode = function(mode) {
      switch (mode) {
      case 0:
        imageModeConvert = imageModeCorner;
        break;
      case 1:
        imageModeConvert = imageModeCorners;
        break;
      case 3:
        imageModeConvert = imageModeCenter;
        break;
      default:
        throw "Invalid imageMode";
      }
    };
    p.ellipseMode = function(aEllipseMode) {
      curEllipseMode = aEllipseMode
    };
    p.arc = function(x, y, width, height, start, stop) {
      if (width <= 0 || stop < start) return;
      if (curEllipseMode === 1) {
        width = width - x;
        height = height - y
      } else if (curEllipseMode === 2) {
        x = x - width;
        y = y - height;
        width = width * 2;
        height = height * 2
      } else if (curEllipseMode === 3) {
        x = x - width / 2;
        y = y - height / 2
      }
      while (start < 0) {
        start += 6.283185307179586;
        stop += 6.283185307179586
      }
      if (stop - start > 6.283185307179586) {
        start = 0;
        stop = 6.283185307179586
      }
      var hr = width / 2;
      var vr = height / 2;
      var centerX = x + hr;
      var centerY = y + vr;
      var startLUT = 0 | -0.5 + start * p.RAD_TO_DEG * 2;
      var stopLUT = 0 | 0.5 + stop * p.RAD_TO_DEG * 2;
      var i, j;
      if (doFill) {
        var savedStroke = doStroke;
        doStroke = false;
        p.beginShape();
        p.vertex(centerX, centerY);
        for (i = startLUT; i <= stopLUT; i++) {
          j = i % 720;
          p.vertex(centerX + cosLUT[j] * hr, centerY + sinLUT[j] * vr)
        }
        p.endShape(2);
        doStroke = savedStroke
      }
      if (doStroke) {
        var savedFill = doFill;
        doFill = false;
        p.beginShape();
        for (i = startLUT; i <= stopLUT; i++) {
          j = i % 720;
          p.vertex(centerX + cosLUT[j] * hr, centerY + sinLUT[j] * vr)
        }
        p.endShape();
        doFill = savedFill
      }
    };
    Drawing2D.prototype.line = function(x1, y1, x2, y2) {
      if (!doStroke) return;
      x1 = Math.round(x1);
      x2 = Math.round(x2);
      y1 = Math.round(y1);
      y2 = Math.round(y2);
      if (x1 === x2 && y1 === y2) {
        p.point(x1, y1);
        return
      }
      var swap = undef,
        lineCap = undef,
        drawCrisp = true,
        currentModelView = modelView.array(),
        identityMatrix = [1, 0, 0, 0, 1, 0];
      for (var i = 0; i < 6 && drawCrisp; i++) drawCrisp = currentModelView[i] === identityMatrix[i];
      if (drawCrisp) {
        if (x1 === x2) {
          if (y1 > y2) {
            swap = y1;
            y1 = y2;
            y2 = swap
          }
          y2++;
          if (lineWidth % 2 === 1) curContext.translate(0.5, 0)
        } else if (y1 === y2) {
          if (x1 > x2) {
            swap = x1;
            x1 = x2;
            x2 = swap
          }
          x2++;
          if (lineWidth % 2 === 1) curContext.translate(0, 0.5)
        }
        if (lineWidth === 1) {
          lineCap = curContext.lineCap;
          curContext.lineCap = "butt"
        }
      }
      curContext.beginPath();
      curContext.moveTo(x1 || 0, y1 || 0);
      curContext.lineTo(x2 || 0, y2 || 0);
      executeContextStroke();
      if (drawCrisp) {
        if (x1 === x2 && lineWidth % 2 === 1) curContext.translate(-0.5, 0);
        else if (y1 === y2 && lineWidth % 2 === 1) curContext.translate(0, -0.5);
        if (lineWidth === 1) curContext.lineCap = lineCap
      }
    };
    Drawing3D.prototype.line = function(x1, y1, z1, x2, y2, z2) {
      if (y2 === undef || z2 === undef) {
        z2 = 0;
        y2 = x2;
        x2 = z1;
        z1 = 0
      }
      if (x1 === x2 && y1 === y2 && z1 === z2) {
        p.point(x1, y1, z1);
        return
      }
      var lineVerts = [x1, y1, z1, x2, y2, z2];
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      if (lineWidth > 0 && doStroke) {
        curContext.useProgram(programObject2D);
        uniformMatrix("model2d", programObject2D, "model", false, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
        uniformMatrix("view2d", programObject2D, "view", false, view.array());
        uniformf("color2d", programObject2D, "color", strokeStyle);
        uniformi("picktype2d", programObject2D, "picktype", 0);
        vertexAttribPointer("vertex2d", programObject2D, "Vertex", 3, lineBuffer);
        disableVertexAttribPointer("aTextureCoord2d", programObject2D, "aTextureCoord");
        curContext.bufferData(curContext.ARRAY_BUFFER, new Float32Array(lineVerts), curContext.STREAM_DRAW);
        curContext.drawArrays(curContext.LINES, 0, 2)
      }
    };
    Drawing2D.prototype.bezier = function() {
      if (arguments.length !== 8) throw "You must use 8 parameters for bezier() in 2D mode";
      p.beginShape();
      p.vertex(arguments[0], arguments[1]);
      p.bezierVertex(arguments[2], arguments[3], arguments[4], arguments[5], arguments[6], arguments[7]);
      p.endShape()
    };
    Drawing3D.prototype.bezier = function() {
      if (arguments.length !== 12) throw "You must use 12 parameters for bezier() in 3D mode";
      p.beginShape();
      p.vertex(arguments[0], arguments[1], arguments[2]);
      p.bezierVertex(arguments[3], arguments[4], arguments[5], arguments[6], arguments[7], arguments[8], arguments[9], arguments[10], arguments[11]);
      p.endShape()
    };
    p.bezierDetail = function(detail) {
      bezDetail = detail
    };
    p.bezierPoint = function(a, b, c, d, t) {
      return (1 - t) * (1 - t) * (1 - t) * a + 3 * (1 - t) * (1 - t) * t * b + 3 * (1 - t) * t * t * c + t * t * t * d
    };
    p.bezierTangent = function(a, b, c, d, t) {
      return 3 * t * t * (-a + 3 * b - 3 * c + d) + 6 * t * (a - 2 * b + c) + 3 * (-a + b)
    };
    p.curvePoint = function(a, b, c, d, t) {
      return 0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
    };
    p.curveTangent = function(a, b, c, d, t) {
      return 0.5 * (-a + c + 2 * (2 * a - 5 * b + 4 * c - d) * t + 3 * (-a + 3 * b - 3 * c + d) * t * t)
    };
    p.triangle = function(x1, y1, x2, y2, x3, y3) {
      p.beginShape(9);
      p.vertex(x1, y1, 0);
      p.vertex(x2, y2, 0);
      p.vertex(x3, y3, 0);
      p.endShape()
    };
    p.quad = function(x1, y1, x2, y2, x3, y3, x4, y4) {
      p.beginShape(16);
      p.vertex(x1, y1, 0);
      p.vertex(x2, y2, 0);
      p.vertex(x3, y3, 0);
      p.vertex(x4, y4, 0);
      p.endShape()
    };
    var roundedRect$2d = function(x, y, width, height, tl, tr, br, bl) {
      if (bl === undef) {
        tr = tl;
        br = tl;
        bl = tl
      }
      var halfWidth = width / 2,
        halfHeight = height / 2;
      if (tl > halfWidth || tl > halfHeight) tl = Math.min(halfWidth, halfHeight);
      if (tr > halfWidth || tr > halfHeight) tr = Math.min(halfWidth, halfHeight);
      if (br > halfWidth || br > halfHeight) br = Math.min(halfWidth, halfHeight);
      if (bl > halfWidth || bl > halfHeight) bl = Math.min(halfWidth, halfHeight);
      if (!doFill || doStroke) curContext.translate(0.5, 0.5);
      curContext.beginPath();
      curContext.moveTo(x + tl, y);
      curContext.lineTo(x + width - tr, y);
      curContext.quadraticCurveTo(x + width, y, x + width, y + tr);
      curContext.lineTo(x + width, y + height - br);
      curContext.quadraticCurveTo(x + width, y + height, x + width - br, y + height);
      curContext.lineTo(x + bl, y + height);
      curContext.quadraticCurveTo(x, y + height, x, y + height - bl);
      curContext.lineTo(x, y + tl);
      curContext.quadraticCurveTo(x, y, x + tl, y);
      if (!doFill || doStroke) curContext.translate(-0.5, -0.5);
      executeContextFill();
      executeContextStroke()
    };
    Drawing2D.prototype.rect = function(x, y, width, height, tl, tr, br, bl) {
      if (!width && !height) return;
      if (curRectMode === 1) {
        width -= x;
        height -= y
      } else if (curRectMode === 2) {
        width *= 2;
        height *= 2;
        x -= width / 2;
        y -= height / 2
      } else if (curRectMode === 3) {
        x -= width / 2;
        y -= height / 2
      }
      x = Math.round(x);
      y = Math.round(y);
      width = Math.round(width);
      height = Math.round(height);
      if (tl !== undef) {
        roundedRect$2d(x, y, width, height, tl, tr, br, bl);
        return
      }
      if (doStroke && lineWidth % 2 === 1) curContext.translate(0.5, 0.5);
      curContext.beginPath();
      curContext.rect(x, y, width, height);
      executeContextFill();
      executeContextStroke();
      if (doStroke && lineWidth % 2 === 1) curContext.translate(-0.5, -0.5)
    };
    Drawing3D.prototype.rect = function(x, y, width, height, tl, tr, br, bl) {
      if (tl !== undef) throw "rect() with rounded corners is not supported in 3D mode";
      if (curRectMode === 1) {
        width -= x;
        height -= y
      } else if (curRectMode === 2) {
        width *= 2;
        height *= 2;
        x -= width / 2;
        y -= height / 2
      } else if (curRectMode === 3) {
        x -= width / 2;
        y -= height / 2
      }
      var model = new PMatrix3D;
      model.translate(x, y, 0);
      model.scale(width, height, 1);
      model.transpose();
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      if (lineWidth > 0 && doStroke) {
        curContext.useProgram(programObject2D);
        uniformMatrix("model2d", programObject2D, "model", false, model.array());
        uniformMatrix("view2d", programObject2D, "view", false, view.array());
        uniformf("color2d", programObject2D, "color", strokeStyle);
        uniformi("picktype2d", programObject2D, "picktype", 0);
        vertexAttribPointer("vertex2d", programObject2D, "Vertex", 3, rectBuffer);
        disableVertexAttribPointer("aTextureCoord2d", programObject2D, "aTextureCoord");
        curContext.drawArrays(curContext.LINE_LOOP, 0, rectVerts.length / 3)
      }
      if (doFill) {
        curContext.useProgram(programObject3D);
        uniformMatrix("model3d", programObject3D, "model", false, model.array());
        uniformMatrix("view3d", programObject3D, "view", false, view.array());
        curContext.enable(curContext.POLYGON_OFFSET_FILL);
        curContext.polygonOffset(1, 1);
        uniformf("color3d", programObject3D, "color", fillStyle);
        if (lightCount > 0) {
          var v = new PMatrix3D;
          v.set(view);
          var m = new PMatrix3D;
          m.set(model);
          v.mult(m);
          var normalMatrix = new PMatrix3D;
          normalMatrix.set(v);
          normalMatrix.invert();
          normalMatrix.transpose();
          uniformMatrix("normalTransform3d", programObject3D, "normalTransform", false, normalMatrix.array());
          vertexAttribPointer("normal3d", programObject3D, "Normal", 3, rectNormBuffer)
        } else disableVertexAttribPointer("normal3d", programObject3D, "Normal");
        vertexAttribPointer("vertex3d", programObject3D, "Vertex", 3, rectBuffer);
        curContext.drawArrays(curContext.TRIANGLE_FAN, 0, rectVerts.length / 3);
        curContext.disable(curContext.POLYGON_OFFSET_FILL)
      }
    };
    Drawing2D.prototype.ellipse = function(x, y, width, height) {
      x = x || 0;
      y = y || 0;
      if (width <= 0 && height <= 0) return;
      if (curEllipseMode === 2) {
        width *= 2;
        height *= 2
      } else if (curEllipseMode === 1) {
        width = width - x;
        height = height - y;
        x += width / 2;
        y += height / 2
      } else if (curEllipseMode === 0) {
        x += width / 2;
        y += height / 2
      }
      if (width === height) {
        curContext.beginPath();
        curContext.arc(x, y, width / 2, 0, 6.283185307179586, false);
        executeContextFill();
        executeContextStroke()
      } else {
        var w = width / 2,
          h = height / 2,
          C = 0.5522847498307933,
          c_x = C * w,
          c_y = C * h;
        p.beginShape();
        p.vertex(x + w, y);
        p.bezierVertex(x + w, y - c_y, x + c_x, y - h, x, y - h);
        p.bezierVertex(x - c_x, y - h, x - w, y - c_y, x - w, y);
        p.bezierVertex(x - w, y + c_y, x - c_x, y + h, x, y + h);
        p.bezierVertex(x + c_x, y + h, x + w, y + c_y, x + w, y);
        p.endShape()
      }
    };
    Drawing3D.prototype.ellipse = function(x, y, width, height) {
      x = x || 0;
      y = y || 0;
      if (width <= 0 && height <= 0) return;
      if (curEllipseMode === 2) {
        width *= 2;
        height *= 2
      } else if (curEllipseMode === 1) {
        width = width - x;
        height = height - y;
        x += width / 2;
        y += height / 2
      } else if (curEllipseMode === 0) {
        x += width / 2;
        y += height / 2
      }
      var w = width / 2,
        h = height / 2,
        C = 0.5522847498307933,
        c_x = C * w,
        c_y = C * h;
      p.beginShape();
      p.vertex(x + w, y);
      p.bezierVertex(x + w, y - c_y, 0, x + c_x, y - h, 0, x, y - h, 0);
      p.bezierVertex(x - c_x, y - h, 0, x - w, y - c_y, 0, x - w, y, 0);
      p.bezierVertex(x - w, y + c_y, 0, x - c_x, y + h, 0, x, y + h, 0);
      p.bezierVertex(x + c_x, y + h, 0, x + w, y + c_y, 0, x + w, y, 0);
      p.endShape();
      if (doFill) {
        var xAv = 0,
          yAv = 0,
          i, j;
        for (i = 0; i < vertArray.length; i++) {
          xAv += vertArray[i][0];
          yAv += vertArray[i][1]
        }
        xAv /= vertArray.length;
        yAv /= vertArray.length;
        var vert = [],
          fillVertArray = [],
          colorVertArray = [];
        vert[0] = xAv;
        vert[1] = yAv;
        vert[2] = 0;
        vert[3] = 0;
        vert[4] = 0;
        vert[5] = fillStyle[0];
        vert[6] = fillStyle[1];
        vert[7] = fillStyle[2];
        vert[8] = fillStyle[3];
        vert[9] = strokeStyle[0];
        vert[10] = strokeStyle[1];
        vert[11] = strokeStyle[2];
        vert[12] = strokeStyle[3];
        vert[13] = normalX;
        vert[14] = normalY;
        vert[15] = normalZ;
        vertArray.unshift(vert);
        for (i = 0; i < vertArray.length; i++) {
          for (j = 0; j < 3; j++) fillVertArray.push(vertArray[i][j]);
          for (j = 5; j < 9; j++) colorVertArray.push(vertArray[i][j])
        }
        fill3D(fillVertArray, "TRIANGLE_FAN", colorVertArray)
      }
    };
    p.normal = function(nx, ny, nz) {
      if (arguments.length !== 3 || !(typeof nx === "number" && typeof ny === "number" && typeof nz === "number")) throw "normal() requires three numeric arguments.";
      normalX = nx;
      normalY = ny;
      normalZ = nz;
      if (curShape !== 0) if (normalMode === 0) normalMode = 1;
      else if (normalMode === 1) normalMode = 2
    };
    p.save = function(file, img) {
      if (img !== undef) return window.open(img.toDataURL(), "_blank");
      return window.open(p.externals.canvas.toDataURL(), "_blank")
    };
    var saveNumber = 0;
    p.saveFrame = function(file) {
      if (file === undef) file = "screen-####.png";
      var frameFilename = file.replace(/#+/, function(all) {
        var s = "" + saveNumber++;
        while (s.length < all.length) s = "0" + s;
        return s
      });
      p.save(frameFilename)
    };
    var utilityContext2d = document.createElement("canvas").getContext("2d");
    var canvasDataCache = [undef, undef, undef];

    function getCanvasData(obj, w, h) {
      var canvasData = canvasDataCache.shift();
      if (canvasData === undef) {
        canvasData = {};
        canvasData.canvas = document.createElement("canvas");
        canvasData.context = canvasData.canvas.getContext("2d")
      }
      canvasDataCache.push(canvasData);
      var canvas = canvasData.canvas,
        context = canvasData.context,
        width = w || obj.width,
        height = h || obj.height;
      canvas.width = width;
      canvas.height = height;
      if (!obj) context.clearRect(0, 0, width, height);
      else if ("data" in obj) context.putImageData(obj, 0, 0);
      else {
        context.clearRect(0, 0, width, height);
        context.drawImage(obj, 0, 0, width, height)
      }
      return canvasData
    }
    function buildPixelsObject(pImage) {
      return {
        getLength: function(aImg) {
          return function() {
            if (aImg.isRemote) throw "Image is loaded remotely. Cannot get length.";
            else return aImg.imageData.data.length ? aImg.imageData.data.length / 4 : 0
          }
        }(pImage),
        getPixel: function(aImg) {
          return function(i) {
            var offset = i * 4,
              data = aImg.imageData.data;
            if (aImg.isRemote) throw "Image is loaded remotely. Cannot get pixels.";
            return (data[offset + 3] & 255) << 24 | (data[offset] & 255) << 16 | (data[offset + 1] & 255) << 8 | data[offset + 2] & 255
          }
        }(pImage),
        setPixel: function(aImg) {
          return function(i, c) {
            var offset = i * 4,
              data = aImg.imageData.data;
            if (aImg.isRemote) throw "Image is loaded remotely. Cannot set pixel.";
            data[offset + 0] = (c >> 16) & 255;
            data[offset + 1] = (c >> 8) & 255;
            data[offset + 2] = c & 255;
            data[offset + 3] = (c >> 24) & 255;
            aImg.__isDirty = true
          }
        }(pImage),
        toArray: function(aImg) {
          return function() {
            var arr = [],
              data = aImg.imageData.data,
              length = aImg.width * aImg.height;
            if (aImg.isRemote) throw "Image is loaded remotely. Cannot get pixels.";
            for (var i = 0, offset = 0; i < length; i++, offset += 4) arr.push((data[offset + 3] & 255) << 24 | (data[offset] & 255) << 16 | (data[offset + 1] & 255) << 8 | data[offset + 2] & 255);
            return arr
          }
        }(pImage),
        set: function(aImg) {
          return function(arr) {
            var offset, data, c;
            if (this.isRemote) throw "Image is loaded remotely. Cannot set pixels.";
            data = aImg.imageData.data;
            for (var i = 0, aL = arr.length; i < aL; i++) {
              c = arr[i];
              offset = i * 4;
              data[offset + 0] = (c >> 16) & 255;
              data[offset + 1] = (c >> 8) & 255;
              data[offset + 2] = c & 255;
              data[offset + 3] = (c >> 24) & 255
            }
            aImg.__isDirty = true
          }
        }(pImage)
      }
    }
    var PImage = function(aWidth, aHeight, aFormat) {
      this.__isDirty = false;
      if (aWidth instanceof HTMLImageElement) this.fromHTMLImageData(aWidth);
      else if (aHeight || aFormat) {
        this.width = aWidth || 1;
        this.height = aHeight || 1;
        var canvas = this.sourceImg = document.createElement("canvas");
        canvas.width = this.width;
        canvas.height = this.height;
        var imageData = this.imageData = canvas.getContext("2d").createImageData(this.width, this.height);
        this.format = aFormat === 2 || aFormat === 4 ? aFormat : 1;
        if (this.format === 1) for (var i = 3, data = this.imageData.data, len = data.length; i < len; i += 4) data[i] = 255;
        this.__isDirty = true;
        this.updatePixels()
      } else {
        this.width = 0;
        this.height = 0;
        this.imageData = utilityContext2d.createImageData(1, 1);
        this.format = 2
      }
      this.pixels = buildPixelsObject(this)
    };
    PImage.prototype = {
      __isPImage: true,
      updatePixels: function() {
        var canvas = this.sourceImg;
        if (canvas && canvas instanceof HTMLCanvasElement && this.__isDirty) canvas.getContext("2d").putImageData(this.imageData, 0, 0);
        this.__isDirty = false
      },
      fromHTMLImageData: function(htmlImg) {
        var canvasData = getCanvasData(htmlImg);
        try {
          var imageData = canvasData.context.getImageData(0, 0, htmlImg.width, htmlImg.height);
          this.fromImageData(imageData)
        } catch(e) {
          if (htmlImg.width && htmlImg.height) {
            this.isRemote = true;
            this.width = htmlImg.width;
            this.height = htmlImg.height
          }
        }
        this.sourceImg = htmlImg
      },
      "get": function(x, y, w, h) {
        if (!arguments.length) return p.get(this);
        if (arguments.length === 2) return p.get(x, y, this);
        if (arguments.length === 4) return p.get(x, y, w, h, this)
      },
      "set": function(x, y, c) {
        p.set(x, y, c, this);
        this.__isDirty = true
      },
      blend: function(srcImg, x, y, width, height, dx, dy, dwidth, dheight, MODE) {
        if (arguments.length === 9) p.blend(this, srcImg, x, y, width, height, dx, dy, dwidth, dheight, this);
        else if (arguments.length === 10) p.blend(srcImg, x, y, width, height, dx, dy, dwidth, dheight, MODE, this);
        delete this.sourceImg
      },
      copy: function(srcImg, sx, sy, swidth, sheight, dx, dy, dwidth, dheight) {
        if (arguments.length === 8) p.blend(this, srcImg, sx, sy, swidth, sheight, dx, dy, dwidth, 0, this);
        else if (arguments.length === 9) p.blend(srcImg, sx, sy, swidth, sheight, dx, dy, dwidth, dheight, 0, this);
        delete this.sourceImg
      },
      filter: function(mode, param) {
        if (arguments.length === 2) p.filter(mode, param, this);
        else if (arguments.length === 1) p.filter(mode, null, this);
        delete this.sourceImg
      },
      save: function(file) {
        p.save(file, this)
      },
      resize: function(w, h) {
        if (this.isRemote) throw "Image is loaded remotely. Cannot resize.";
        if (this.width !== 0 || this.height !== 0) {
          if (w === 0 && h !== 0) w = Math.floor(this.width / this.height * h);
          else if (h === 0 && w !== 0) h = Math.floor(this.height / this.width * w);
          var canvas = getCanvasData(this.imageData).canvas;
          var imageData = getCanvasData(canvas, w, h).context.getImageData(0, 0, w, h);
          this.fromImageData(imageData)
        }
      },
      mask: function(mask) {
        var obj = this.toImageData(),
          i, size;
        if (mask instanceof PImage || mask.__isPImage) if (mask.width === this.width && mask.height === this.height) {
          mask = mask.toImageData();
          for (i = 2, size = this.width * this.height * 4; i < size; i += 4) obj.data[i + 1] = mask.data[i]
        } else throw "mask must have the same dimensions as PImage.";
        else if (mask instanceof
        Array) if (this.width * this.height === mask.length) for (i = 0, size = mask.length; i < size; ++i) obj.data[i * 4 + 3] = mask[i];
        else throw "mask array must be the same length as PImage pixels array.";
        this.fromImageData(obj)
      },
      loadPixels: nop,
      toImageData: function() {
        if (this.isRemote) return this.sourceImg;
        if (!this.__isDirty) return this.imageData;
        var canvasData = getCanvasData(this.imageData);
        return canvasData.context.getImageData(0, 0, this.width, this.height)
      },
      toDataURL: function() {
        if (this.isRemote) throw "Image is loaded remotely. Cannot create dataURI.";
        var canvasData = getCanvasData(this.imageData);
        return canvasData.canvas.toDataURL()
      },
      fromImageData: function(canvasImg) {
        var w = canvasImg.width,
          h = canvasImg.height,
          canvas = document.createElement("canvas"),
          ctx = canvas.getContext("2d");
        this.width = canvas.width = w;
        this.height = canvas.height = h;
        ctx.putImageData(canvasImg, 0, 0);
        this.format = 2;
        this.imageData = canvasImg;
        this.sourceImg = canvas
      }
    };
    p.PImage = PImage;
    p.createImage = function(w, h, mode) {
      return new PImage(w, h, mode)
    };
    p.loadImage = function(file, type, callback) {
      if (type) file = file + "." + type;
      var pimg;
      if (curSketch.imageCache.images[file]) {
        pimg = new PImage(curSketch.imageCache.images[file]);
        pimg.loaded = true;
        return pimg
      }
      pimg = new PImage;
      var img = document.createElement("img");
      pimg.sourceImg = img;
      img.onload = function(aImage, aPImage, aCallback) {
        var image = aImage;
        var pimg = aPImage;
        var callback = aCallback;
        return function() {
          pimg.fromHTMLImageData(image);
          pimg.loaded = true;
          if (callback) callback()
        }
      }(img, pimg, callback);
      img.src = file;
      return pimg
    };
    p.requestImage = p.loadImage;

    function get$2(x, y) {
      var data;
      if (x >= p.width || x < 0 || y < 0 || y >= p.height) return 0;
      if (isContextReplaced) {
        var offset = ((0 | x) + p.width * (0 | y)) * 4;
        data = p.imageData.data;
        return (data[offset + 3] & 255) << 24 | (data[offset] & 255) << 16 | (data[offset + 1] & 255) << 8 | data[offset + 2] & 255
      }
      data = p.toImageData(0 | x, 0 | y, 1, 1).data;
      return (data[3] & 255) << 24 | (data[0] & 255) << 16 | (data[1] & 255) << 8 | data[2] & 255
    }
    function get$3(x, y, img) {
      if (img.isRemote) throw "Image is loaded remotely. Cannot get x,y.";
      var offset = y * img.width * 4 + x * 4,
        data = img.imageData.data;
      return (data[offset + 3] & 255) << 24 | (data[offset] & 255) << 16 | (data[offset + 1] & 255) << 8 | data[offset + 2] & 255
    }
    function get$4(x, y, w, h) {
      var c = new PImage(w, h, 2);
      c.fromImageData(p.toImageData(x, y, w, h));
      return c
    }
    function get$5(x, y, w, h, img) {
      if (img.isRemote) throw "Image is loaded remotely. Cannot get x,y,w,h.";
      var c = new PImage(w, h, 2),
        cData = c.imageData.data,
        imgWidth = img.width,
        imgHeight = img.height,
        imgData = img.imageData.data;
      var startRow = Math.max(0, -y),
        startColumn = Math.max(0, -x),
        stopRow = Math.min(h, imgHeight - y),
        stopColumn = Math.min(w, imgWidth - x);
      for (var i = startRow; i < stopRow; ++i) {
        var sourceOffset = ((y + i) * imgWidth + (x + startColumn)) * 4;
        var targetOffset = (i * w + startColumn) * 4;
        for (var j = startColumn; j < stopColumn; ++j) {
          cData[targetOffset++] = imgData[sourceOffset++];
          cData[targetOffset++] = imgData[sourceOffset++];
          cData[targetOffset++] = imgData[sourceOffset++];
          cData[targetOffset++] = imgData[sourceOffset++]
        }
      }
      c.__isDirty = true;
      return c
    }
    p.get = function(x, y, w, h, img) {
      if (img !== undefined) return get$5(x, y, w, h, img);
      if (h !== undefined) return get$4(x, y, w, h);
      if (w !== undefined) return get$3(x, y, w);
      if (y !== undefined) return get$2(x, y);
      if (x !== undefined) return get$5(0, 0, x.width, x.height, x);
      return get$4(0, 0, p.width, p.height)
    };
    p.createGraphics = function(w, h, render) {
      var pg = new Processing;
      pg.size(w, h, render);
      return pg
    };

    function resetContext() {
      if (isContextReplaced) {
        curContext = originalContext;
        isContextReplaced = false;
        p.updatePixels()
      }
    }
    function SetPixelContextWrapper() {
      function wrapFunction(newContext, name) {
        function wrapper() {
          resetContext();
          curContext[name].apply(curContext, arguments)
        }
        newContext[name] = wrapper
      }
      function wrapProperty(newContext, name) {
        function getter() {
          resetContext();
          return curContext[name]
        }
        function setter(value) {
          resetContext();
          curContext[name] = value
        }
        p.defineProperty(newContext, name, {
          get: getter,
          set: setter
        })
      }
      for (var n in curContext) if (typeof curContext[n] === "function") wrapFunction(this, n);
      else wrapProperty(this, n)
    }
    function replaceContext() {
      if (isContextReplaced) return;
      p.loadPixels();
      if (proxyContext === null) {
        originalContext = curContext;
        proxyContext = new SetPixelContextWrapper
      }
      isContextReplaced = true;
      curContext = proxyContext;
      setPixelsCached = 0
    }
    function set$3(x, y, c) {
      if (x < p.width && x >= 0 && y >= 0 && y < p.height) {
        replaceContext();
        p.pixels.setPixel((0 | x) + p.width * (0 | y), c);
        if (++setPixelsCached > maxPixelsCached) resetContext()
      }
    }
    function set$4(x, y, obj, img) {
      if (img.isRemote) throw "Image is loaded remotely. Cannot set x,y.";
      var c = p.color.toArray(obj);
      var offset = y * img.width * 4 + x * 4;
      var data = img.imageData.data;
      data[offset] = c[0];
      data[offset + 1] = c[1];
      data[offset + 2] = c[2];
      data[offset + 3] = c[3]
    }
    p.set = function(x, y, obj, img) {
      var color, oldFill;
      if (arguments.length === 3) if (typeof obj === "number") set$3(x, y, obj);
      else {
        if (obj instanceof PImage || obj.__isPImage) p.image(obj, x, y)
      } else if (arguments.length === 4) set$4(x, y, obj, img)
    };
    p.imageData = {};
    p.pixels = {
      getLength: function() {
        return p.imageData.data.length ? p.imageData.data.length / 4 : 0
      },
      getPixel: function(i) {
        var offset = i * 4,
          data = p.imageData.data;
        return data[offset + 3] << 24 & 4278190080 | data[offset + 0] << 16 & 16711680 | data[offset + 1] << 8 & 65280 | data[offset + 2] & 255
      },
      setPixel: function(i, c) {
        var offset = i * 4,
          data = p.imageData.data;
        data[offset + 0] = (c & 16711680) >>> 16;
        data[offset + 1] = (c & 65280) >>> 8;
        data[offset + 2] = c & 255;
        data[offset + 3] = (c & 4278190080) >>> 24
      },
      toArray: function() {
        var arr = [],
          length = p.imageData.width * p.imageData.height,
          data = p.imageData.data;
        for (var i = 0, offset = 0; i < length; i++, offset += 4) arr.push(data[offset + 3] << 24 & 4278190080 | data[offset + 0] << 16 & 16711680 | data[offset + 1] << 8 & 65280 | data[offset + 2] & 255);
        return arr
      },
      set: function(arr) {
        for (var i = 0, aL = arr.length; i < aL; i++) this.setPixel(i, arr[i])
      }
    };
    p.loadPixels = function() {
      p.imageData = drawing.$ensureContext().getImageData(0, 0, p.width, p.height)
    };
    p.updatePixels = function() {
      if (p.imageData) drawing.$ensureContext().putImageData(p.imageData, 0, 0)
    };
    p.hint = function(which) {
      var curContext = drawing.$ensureContext();
      if (which === 4) {
        curContext.disable(curContext.DEPTH_TEST);
        curContext.depthMask(false);
        curContext.clear(curContext.DEPTH_BUFFER_BIT)
      } else if (which === -4) {
        curContext.enable(curContext.DEPTH_TEST);
        curContext.depthMask(true)
      }
    };
    var backgroundHelper = function(arg1, arg2, arg3, arg4) {
      var obj;
      if (arg1 instanceof PImage || arg1.__isPImage) {
        obj = arg1;
        if (!obj.loaded) throw "Error using image in background(): PImage not loaded.";
        if (obj.width !== p.width || obj.height !== p.height) throw "Background image must be the same dimensions as the canvas.";
      } else obj = p.color(arg1, arg2, arg3, arg4);
      backgroundObj = obj
    };
    Drawing2D.prototype.background = function(arg1, arg2, arg3, arg4) {
      if (arg1 !== undef) backgroundHelper(arg1, arg2, arg3, arg4);
      if (backgroundObj instanceof PImage || backgroundObj.__isPImage) {
        saveContext();
        curContext.setTransform(1, 0, 0, 1, 0, 0);
        p.image(backgroundObj, 0, 0);
        restoreContext()
      } else {
        saveContext();
        curContext.setTransform(1, 0, 0, 1, 0, 0);
        if (p.alpha(backgroundObj) !== colorModeA) curContext.clearRect(0, 0, p.width, p.height);
        curContext.fillStyle = p.color.toString(backgroundObj);
        curContext.fillRect(0, 0, p.width, p.height);
        isFillDirty = true;
        restoreContext()
      }
    };
    Drawing3D.prototype.background = function(arg1, arg2, arg3, arg4) {
      if (arguments.length > 0) backgroundHelper(arg1, arg2, arg3, arg4);
      var c = p.color.toGLArray(backgroundObj);
      curContext.clearColor(c[0], c[1], c[2], c[3]);
      curContext.clear(curContext.COLOR_BUFFER_BIT | curContext.DEPTH_BUFFER_BIT)
    };
    Drawing2D.prototype.image = function(img, x, y, w, h) {
      x = Math.round(x);
      y = Math.round(y);
      if (img.width > 0) {
        var wid = w || img.width;
        var hgt = h || img.height;
        var bounds = imageModeConvert(x || 0, y || 0, w || img.width, h || img.height, arguments.length < 4);
        var fastImage = !!img.sourceImg && curTint === null;
        if (fastImage) {
          var htmlElement = img.sourceImg;
          if (img.__isDirty) img.updatePixels();
          curContext.drawImage(htmlElement, 0, 0, htmlElement.width, htmlElement.height, bounds.x, bounds.y, bounds.w, bounds.h)
        } else {
          var obj = img.toImageData();
          if (curTint !== null) {
            curTint(obj);
            img.__isDirty = true
          }
          curContext.drawImage(getCanvasData(obj).canvas, 0, 0, img.width, img.height, bounds.x, bounds.y, bounds.w, bounds.h)
        }
      }
    };
    Drawing3D.prototype.image = function(img, x, y, w, h) {
      if (img.width > 0) {
        x = Math.round(x);
        y = Math.round(y);
        w = w || img.width;
        h = h || img.height;
        p.beginShape(p.QUADS);
        p.texture(img);
        p.vertex(x, y, 0, 0, 0);
        p.vertex(x, y + h, 0, 0, h);
        p.vertex(x + w, y + h, 0, w, h);
        p.vertex(x + w, y, 0, w, 0);
        p.endShape()
      }
    };
    p.tint = function(a1, a2, a3, a4) {
      var tintColor = p.color(a1, a2, a3, a4);
      var r = p.red(tintColor) / colorModeX;
      var g = p.green(tintColor) / colorModeY;
      var b = p.blue(tintColor) / colorModeZ;
      var a = p.alpha(tintColor) / colorModeA;
      curTint = function(obj) {
        var data = obj.data,
          length = 4 * obj.width * obj.height;
        for (var i = 0; i < length;) {
          data[i++] *= r;
          data[i++] *= g;
          data[i++] *= b;
          data[i++] *= a
        }
      };
      curTint3d = function(data) {
        for (var i = 0; i < data.length;) {
          data[i++] = r;
          data[i++] = g;
          data[i++] = b;
          data[i++] = a
        }
      }
    };
    p.noTint = function() {
      curTint = null;
      curTint3d = null
    };
    p.copy = function(src, sx, sy, sw, sh, dx, dy, dw, dh) {
      if (dh === undef) {
        dh = dw;
        dw = dy;
        dy = dx;
        dx = sh;
        sh = sw;
        sw = sy;
        sy = sx;
        sx = src;
        src = p
      }
      p.blend(src, sx, sy, sw, sh, dx, dy, dw, dh, 0)
    };
    p.blend = function(src, sx, sy, sw, sh, dx, dy, dw, dh, mode, pimgdest) {
      if (src.isRemote) throw "Image is loaded remotely. Cannot blend image.";
      if (mode === undef) {
        mode = dh;
        dh = dw;
        dw = dy;
        dy = dx;
        dx = sh;
        sh = sw;
        sw = sy;
        sy = sx;
        sx = src;
        src = p
      }
      var sx2 = sx + sw,
        sy2 = sy + sh,
        dx2 = dx + dw,
        dy2 = dy + dh,
        dest = pimgdest || p;
      if (pimgdest === undef || mode === undef) p.loadPixels();
      src.loadPixels();
      if (src === p && p.intersect(sx, sy, sx2, sy2, dx, dy, dx2, dy2)) p.blit_resize(p.get(sx, sy, sx2 - sx, sy2 - sy), 0, 0, sx2 - sx - 1, sy2 - sy - 1, dest.imageData.data, dest.width, dest.height, dx, dy, dx2, dy2, mode);
      else p.blit_resize(src, sx, sy, sx2, sy2, dest.imageData.data, dest.width, dest.height, dx, dy, dx2, dy2, mode);
      if (pimgdest === undef) p.updatePixels()
    };
    var buildBlurKernel = function(r) {
      var radius = p.floor(r * 3.5),
        i, radiusi;
      radius = radius < 1 ? 1 : radius < 248 ? radius : 248;
      if (p.shared.blurRadius !== radius) {
        p.shared.blurRadius = radius;
        p.shared.blurKernelSize = 1 + (p.shared.blurRadius << 1);
        p.shared.blurKernel = new Float32Array(p.shared.blurKernelSize);
        var sharedBlurKernal = p.shared.blurKernel;
        var sharedBlurKernelSize = p.shared.blurKernelSize;
        var sharedBlurRadius = p.shared.blurRadius;
        for (i = 0; i < sharedBlurKernelSize; i++) sharedBlurKernal[i] = 0;
        var radiusiSquared = (radius - 1) * (radius - 1);
        for (i = 1; i < radius; i++) sharedBlurKernal[radius + i] = sharedBlurKernal[radiusi] = radiusiSquared;
        sharedBlurKernal[radius] = radius * radius
      }
    };
    var blurARGB = function(r, aImg) {
      var sum, cr, cg, cb, ca, c, m;
      var read, ri, ym, ymi, bk0;
      var wh = aImg.pixels.getLength();
      var r2 = new Float32Array(wh);
      var g2 = new Float32Array(wh);
      var b2 = new Float32Array(wh);
      var a2 = new Float32Array(wh);
      var yi = 0;
      var x, y, i, offset;
      buildBlurKernel(r);
      var aImgHeight = aImg.height;
      var aImgWidth = aImg.width;
      var sharedBlurKernelSize = p.shared.blurKernelSize;
      var sharedBlurRadius = p.shared.blurRadius;
      var sharedBlurKernal = p.shared.blurKernel;
      var pix = aImg.imageData.data;
      for (y = 0; y < aImgHeight; y++) {
        for (x = 0; x < aImgWidth; x++) {
          cb = cg = cr = ca = sum = 0;
          read = x - sharedBlurRadius;
          if (read < 0) {
            bk0 = -read;
            read = 0
          } else {
            if (read >= aImgWidth) break;
            bk0 = 0
          }
          for (i = bk0; i < sharedBlurKernelSize; i++) {
            if (read >= aImgWidth) break;
            offset = (read + yi) * 4;
            m = sharedBlurKernal[i];
            ca += m * pix[offset + 3];
            cr += m * pix[offset];
            cg += m * pix[offset + 1];
            cb += m * pix[offset + 2];
            sum += m;
            read++
          }
          ri = yi + x;
          a2[ri] = ca / sum;
          r2[ri] = cr / sum;
          g2[ri] = cg / sum;
          b2[ri] = cb / sum
        }
        yi += aImgWidth
      }
      yi = 0;
      ym = -sharedBlurRadius;
      ymi = ym * aImgWidth;
      for (y = 0; y < aImgHeight; y++) {
        for (x = 0; x < aImgWidth; x++) {
          cb = cg = cr = ca = sum = 0;
          if (ym < 0) {
            bk0 = ri = -ym;
            read = x
          } else {
            if (ym >= aImgHeight) break;
            bk0 = 0;
            ri = ym;
            read = x + ymi
          }
          for (i = bk0; i < sharedBlurKernelSize; i++) {
            if (ri >= aImgHeight) break;
            m = sharedBlurKernal[i];
            ca += m * a2[read];
            cr += m * r2[read];
            cg += m * g2[read];
            cb += m * b2[read];
            sum += m;
            ri++;
            read += aImgWidth
          }
          offset = (x + yi) * 4;
          pix[offset] = cr / sum;
          pix[offset + 1] = cg / sum;
          pix[offset + 2] = cb / sum;
          pix[offset + 3] = ca / sum
        }
        yi += aImgWidth;
        ymi += aImgWidth;
        ym++
      }
    };
    var dilate = function(isInverted, aImg) {
      var currIdx = 0;
      var maxIdx = aImg.pixels.getLength();
      var out = new Int32Array(maxIdx);
      var currRowIdx, maxRowIdx, colOrig, colOut, currLum;
      var idxRight, idxLeft, idxUp, idxDown, colRight, colLeft, colUp, colDown, lumRight, lumLeft, lumUp, lumDown;
      if (!isInverted) while (currIdx < maxIdx) {
        currRowIdx = currIdx;
        maxRowIdx = currIdx + aImg.width;
        while (currIdx < maxRowIdx) {
          colOrig = colOut = aImg.pixels.getPixel(currIdx);
          idxLeft = currIdx - 1;
          idxRight = currIdx + 1;
          idxUp = currIdx - aImg.width;
          idxDown = currIdx + aImg.width;
          if (idxLeft < currRowIdx) idxLeft = currIdx;
          if (idxRight >= maxRowIdx) idxRight = currIdx;
          if (idxUp < 0) idxUp = 0;
          if (idxDown >= maxIdx) idxDown = currIdx;
          colUp = aImg.pixels.getPixel(idxUp);
          colLeft = aImg.pixels.getPixel(idxLeft);
          colDown = aImg.pixels.getPixel(idxDown);
          colRight = aImg.pixels.getPixel(idxRight);
          currLum = 77 * (colOrig >> 16 & 255) + 151 * (colOrig >> 8 & 255) + 28 * (colOrig & 255);
          lumLeft = 77 * (colLeft >> 16 & 255) + 151 * (colLeft >> 8 & 255) + 28 * (colLeft & 255);
          lumRight = 77 * (colRight >> 16 & 255) + 151 * (colRight >> 8 & 255) + 28 * (colRight & 255);
          lumUp = 77 * (colUp >> 16 & 255) + 151 * (colUp >> 8 & 255) + 28 * (colUp & 255);
          lumDown = 77 * (colDown >> 16 & 255) + 151 * (colDown >> 8 & 255) + 28 * (colDown & 255);
          if (lumLeft > currLum) {
            colOut = colLeft;
            currLum = lumLeft
          }
          if (lumRight > currLum) {
            colOut = colRight;
            currLum = lumRight
          }
          if (lumUp > currLum) {
            colOut = colUp;
            currLum = lumUp
          }
          if (lumDown > currLum) {
            colOut = colDown;
            currLum = lumDown
          }
          out[currIdx++] = colOut
        }
      } else while (currIdx < maxIdx) {
        currRowIdx = currIdx;
        maxRowIdx = currIdx + aImg.width;
        while (currIdx < maxRowIdx) {
          colOrig = colOut = aImg.pixels.getPixel(currIdx);
          idxLeft = currIdx - 1;
          idxRight = currIdx + 1;
          idxUp = currIdx - aImg.width;
          idxDown = currIdx + aImg.width;
          if (idxLeft < currRowIdx) idxLeft = currIdx;
          if (idxRight >= maxRowIdx) idxRight = currIdx;
          if (idxUp < 0) idxUp = 0;
          if (idxDown >= maxIdx) idxDown = currIdx;
          colUp = aImg.pixels.getPixel(idxUp);
          colLeft = aImg.pixels.getPixel(idxLeft);
          colDown = aImg.pixels.getPixel(idxDown);
          colRight = aImg.pixels.getPixel(idxRight);
          currLum = 77 * (colOrig >> 16 & 255) + 151 * (colOrig >> 8 & 255) + 28 * (colOrig & 255);
          lumLeft = 77 * (colLeft >> 16 & 255) + 151 * (colLeft >> 8 & 255) + 28 * (colLeft & 255);
          lumRight = 77 * (colRight >> 16 & 255) + 151 * (colRight >> 8 & 255) + 28 * (colRight & 255);
          lumUp = 77 * (colUp >> 16 & 255) + 151 * (colUp >> 8 & 255) + 28 * (colUp & 255);
          lumDown = 77 * (colDown >> 16 & 255) + 151 * (colDown >> 8 & 255) + 28 * (colDown & 255);
          if (lumLeft < currLum) {
            colOut = colLeft;
            currLum = lumLeft
          }
          if (lumRight < currLum) {
            colOut = colRight;
            currLum = lumRight
          }
          if (lumUp < currLum) {
            colOut = colUp;
            currLum = lumUp
          }
          if (lumDown < currLum) {
            colOut = colDown;
            currLum = lumDown
          }
          out[currIdx++] = colOut
        }
      }
      aImg.pixels.set(out)
    };
    p.filter = function(kind, param, aImg) {
      var img, col, lum, i;
      if (arguments.length === 3) {
        aImg.loadPixels();
        img = aImg
      } else {
        p.loadPixels();
        img = p
      }
      if (param === undef) param = null;
      if (img.isRemote) throw "Image is loaded remotely. Cannot filter image.";
      var imglen = img.pixels.getLength();
      switch (kind) {
      case 11:
        var radius = param || 1;
        blurARGB(radius, img);
        break;
      case 12:
        if (img.format === 4) {
          for (i = 0; i < imglen; i++) {
            col = 255 - img.pixels.getPixel(i);
            img.pixels.setPixel(i, 4278190080 | col << 16 | col << 8 | col)
          }
          img.format = 1
        } else for (i = 0; i < imglen; i++) {
          col = img.pixels.getPixel(i);
          lum = 77 * (col >> 16 & 255) + 151 * (col >> 8 & 255) + 28 * (col & 255) >> 8;
          img.pixels.setPixel(i, col & 4278190080 | lum << 16 | lum << 8 | lum)
        }
        break;
      case 13:
        for (i = 0; i < imglen; i++) img.pixels.setPixel(i, img.pixels.getPixel(i) ^ 16777215);
        break;
      case 15:
        if (param === null) throw "Use filter(POSTERIZE, int levels) instead of filter(POSTERIZE)";
        var levels = p.floor(param);
        if (levels < 2 || levels > 255) throw "Levels must be between 2 and 255 for filter(POSTERIZE, levels)";
        var levels1 = levels - 1;
        for (i = 0; i < imglen; i++) {
          var rlevel = img.pixels.getPixel(i) >> 16 & 255;
          var glevel = img.pixels.getPixel(i) >> 8 & 255;
          var blevel = img.pixels.getPixel(i) & 255;
          rlevel = (rlevel * levels >> 8) * 255 / levels1;
          glevel = (glevel * levels >> 8) * 255 / levels1;
          blevel = (blevel * levels >> 8) * 255 / levels1;
          img.pixels.setPixel(i, 4278190080 & img.pixels.getPixel(i) | rlevel << 16 | glevel << 8 | blevel)
        }
        break;
      case 14:
        for (i = 0; i < imglen; i++) img.pixels.setPixel(i, img.pixels.getPixel(i) | 4278190080);
        img.format = 1;
        break;
      case 16:
        if (param === null) param = 0.5;
        if (param < 0 || param > 1) throw "Level must be between 0 and 1 for filter(THRESHOLD, level)";
        var thresh = p.floor(param * 255);
        for (i = 0; i < imglen; i++) {
          var max = p.max((img.pixels.getPixel(i) & 16711680) >> 16, p.max((img.pixels.getPixel(i) & 65280) >> 8, img.pixels.getPixel(i) & 255));
          img.pixels.setPixel(i, img.pixels.getPixel(i) & 4278190080 | (max < thresh ? 0 : 16777215))
        }
        break;
      case 17:
        dilate(true, img);
        break;
      case 18:
        dilate(false, img);
        break
      }
      img.updatePixels()
    };
    p.shared = {
      fracU: 0,
      ifU: 0,
      fracV: 0,
      ifV: 0,
      u1: 0,
      u2: 0,
      v1: 0,
      v2: 0,
      sX: 0,
      sY: 0,
      iw: 0,
      iw1: 0,
      ih1: 0,
      ul: 0,
      ll: 0,
      ur: 0,
      lr: 0,
      cUL: 0,
      cLL: 0,
      cUR: 0,
      cLR: 0,
      srcXOffset: 0,
      srcYOffset: 0,
      r: 0,
      g: 0,
      b: 0,
      a: 0,
      srcBuffer: null,
      blurRadius: 0,
      blurKernelSize: 0,
      blurKernel: null
    };
    p.intersect = function(sx1, sy1, sx2, sy2, dx1, dy1, dx2, dy2) {
      var sw = sx2 - sx1 + 1;
      var sh = sy2 - sy1 + 1;
      var dw = dx2 - dx1 + 1;
      var dh = dy2 - dy1 + 1;
      if (dx1 < sx1) {
        dw += dx1 - sx1;
        if (dw > sw) dw = sw
      } else {
        var w = sw + sx1 - dx1;
        if (dw > w) dw = w
      }
      if (dy1 < sy1) {
        dh += dy1 - sy1;
        if (dh > sh) dh = sh
      } else {
        var h = sh + sy1 - dy1;
        if (dh > h) dh = h
      }
      return ! (dw <= 0 || dh <= 0)
    };
    var blendFuncs = {};
    blendFuncs[1] = p.modes.blend;
    blendFuncs[2] = p.modes.add;
    blendFuncs[4] = p.modes.subtract;
    blendFuncs[8] = p.modes.lightest;
    blendFuncs[16] = p.modes.darkest;
    blendFuncs[0] = p.modes.replace;
    blendFuncs[32] = p.modes.difference;
    blendFuncs[64] = p.modes.exclusion;
    blendFuncs[128] = p.modes.multiply;
    blendFuncs[256] = p.modes.screen;
    blendFuncs[512] = p.modes.overlay;
    blendFuncs[1024] = p.modes.hard_light;
    blendFuncs[2048] = p.modes.soft_light;
    blendFuncs[4096] = p.modes.dodge;
    blendFuncs[8192] = p.modes.burn;
    p.blit_resize = function(img, srcX1, srcY1, srcX2, srcY2, destPixels, screenW, screenH, destX1, destY1, destX2, destY2, mode) {
      var x, y;
      if (srcX1 < 0) srcX1 = 0;
      if (srcY1 < 0) srcY1 = 0;
      if (srcX2 >= img.width) srcX2 = img.width - 1;
      if (srcY2 >= img.height) srcY2 = img.height - 1;
      var srcW = srcX2 - srcX1;
      var srcH = srcY2 - srcY1;
      var destW = destX2 - destX1;
      var destH = destY2 - destY1;
      if (destW <= 0 || destH <= 0 || srcW <= 0 || srcH <= 0 || destX1 >= screenW || destY1 >= screenH || srcX1 >= img.width || srcY1 >= img.height) return;
      var dx = Math.floor(srcW / destW * 32768);
      var dy = Math.floor(srcH / destH * 32768);
      var pshared = p.shared;
      pshared.srcXOffset = Math.floor(destX1 < 0 ? -destX1 * dx : srcX1 * 32768);
      pshared.srcYOffset = Math.floor(destY1 < 0 ? -destY1 * dy : srcY1 * 32768);
      if (destX1 < 0) {
        destW += destX1;
        destX1 = 0
      }
      if (destY1 < 0) {
        destH += destY1;
        destY1 = 0
      }
      destW = Math.min(destW, screenW - destX1);
      destH = Math.min(destH, screenH - destY1);
      var destOffset = destY1 * screenW + destX1;
      var destColor;
      pshared.srcBuffer = img.imageData.data;
      pshared.iw = img.width;
      pshared.iw1 = img.width - 1;
      pshared.ih1 = img.height - 1;
      var filterBilinear = p.filter_bilinear,
        filterNewScanline = p.filter_new_scanline,
        blendFunc = blendFuncs[mode],
        blendedColor, idx, cULoffset, cURoffset, cLLoffset, cLRoffset, ALPHA_MASK = 4278190080,
        RED_MASK = 16711680,
        GREEN_MASK = 65280,
        BLUE_MASK = 255,
        PREC_MAXVAL = 32767,
        PRECISIONB = 15,
        PREC_RED_SHIFT = 1,
        PREC_ALPHA_SHIFT = 9,
        srcBuffer = pshared.srcBuffer,
        min = Math.min;
      for (y = 0; y < destH; y++) {
        pshared.sX = pshared.srcXOffset;
        pshared.fracV = pshared.srcYOffset & PREC_MAXVAL;
        pshared.ifV = PREC_MAXVAL - pshared.fracV;
        pshared.v1 = (pshared.srcYOffset >> PRECISIONB) * pshared.iw;
        pshared.v2 = min((pshared.srcYOffset >> PRECISIONB) + 1, pshared.ih1) * pshared.iw;
        for (x = 0; x < destW; x++) {
          idx = (destOffset + x) * 4;
          destColor = destPixels[idx + 3] << 24 & ALPHA_MASK | destPixels[idx] << 16 & RED_MASK | destPixels[idx + 1] << 8 & GREEN_MASK | destPixels[idx + 2] & BLUE_MASK;
          pshared.fracU = pshared.sX & PREC_MAXVAL;
          pshared.ifU = PREC_MAXVAL - pshared.fracU;
          pshared.ul = pshared.ifU * pshared.ifV >> PRECISIONB;
          pshared.ll = pshared.ifU * pshared.fracV >> PRECISIONB;
          pshared.ur = pshared.fracU * pshared.ifV >> PRECISIONB;
          pshared.lr = pshared.fracU * pshared.fracV >> PRECISIONB;
          pshared.u1 = pshared.sX >> PRECISIONB;
          pshared.u2 = min(pshared.u1 + 1, pshared.iw1);
          cULoffset = (pshared.v1 + pshared.u1) * 4;
          cURoffset = (pshared.v1 + pshared.u2) * 4;
          cLLoffset = (pshared.v2 + pshared.u1) * 4;
          cLRoffset = (pshared.v2 + pshared.u2) * 4;
          pshared.cUL = srcBuffer[cULoffset + 3] << 24 & ALPHA_MASK | srcBuffer[cULoffset] << 16 & RED_MASK | srcBuffer[cULoffset + 1] << 8 & GREEN_MASK | srcBuffer[cULoffset + 2] & BLUE_MASK;
          pshared.cUR = srcBuffer[cURoffset + 3] << 24 & ALPHA_MASK | srcBuffer[cURoffset] << 16 & RED_MASK | srcBuffer[cURoffset + 1] << 8 & GREEN_MASK | srcBuffer[cURoffset + 2] & BLUE_MASK;
          pshared.cLL = srcBuffer[cLLoffset + 3] << 24 & ALPHA_MASK | srcBuffer[cLLoffset] << 16 & RED_MASK | srcBuffer[cLLoffset + 1] << 8 & GREEN_MASK | srcBuffer[cLLoffset + 2] & BLUE_MASK;
          pshared.cLR = srcBuffer[cLRoffset + 3] << 24 & ALPHA_MASK | srcBuffer[cLRoffset] << 16 & RED_MASK | srcBuffer[cLRoffset + 1] << 8 & GREEN_MASK | srcBuffer[cLRoffset + 2] & BLUE_MASK;
          pshared.r = pshared.ul * ((pshared.cUL & RED_MASK) >> 16) + pshared.ll * ((pshared.cLL & RED_MASK) >> 16) + pshared.ur * ((pshared.cUR & RED_MASK) >> 16) + pshared.lr * ((pshared.cLR & RED_MASK) >> 16) << PREC_RED_SHIFT & RED_MASK;
          pshared.g = pshared.ul * (pshared.cUL & GREEN_MASK) + pshared.ll * (pshared.cLL & GREEN_MASK) + pshared.ur * (pshared.cUR & GREEN_MASK) + pshared.lr * (pshared.cLR & GREEN_MASK) >>> PRECISIONB & GREEN_MASK;
          pshared.b = pshared.ul * (pshared.cUL & BLUE_MASK) + pshared.ll * (pshared.cLL & BLUE_MASK) + pshared.ur * (pshared.cUR & BLUE_MASK) + pshared.lr * (pshared.cLR & BLUE_MASK) >>> PRECISIONB;
          pshared.a = pshared.ul * ((pshared.cUL & ALPHA_MASK) >>> 24) + pshared.ll * ((pshared.cLL & ALPHA_MASK) >>> 24) + pshared.ur * ((pshared.cUR & ALPHA_MASK) >>> 24) + pshared.lr * ((pshared.cLR & ALPHA_MASK) >>> 24) << PREC_ALPHA_SHIFT & ALPHA_MASK;
          blendedColor = blendFunc(destColor, pshared.a | pshared.r | pshared.g | pshared.b);
          destPixels[idx] = (blendedColor & RED_MASK) >>> 16;
          destPixels[idx + 1] = (blendedColor & GREEN_MASK) >>> 8;
          destPixels[idx + 2] = blendedColor & BLUE_MASK;
          destPixels[idx + 3] = (blendedColor & ALPHA_MASK) >>> 24;
          pshared.sX += dx
        }
        destOffset += screenW;
        pshared.srcYOffset += dy
      }
    };
    p.loadFont = function(name, size) {
      if (name === undef) throw "font name required in loadFont.";
      if (name.indexOf(".svg") === -1) {
        if (size === undef) size = curTextFont.size;
        return PFont.get(name, size)
      }
      var font = p.loadGlyphs(name);
      return {
        name: name,
        css: "12px sans-serif",
        glyph: true,
        units_per_em: font.units_per_em,
        horiz_adv_x: 1 / font.units_per_em * font.horiz_adv_x,
        ascent: font.ascent,
        descent: font.descent,
        width: function(str) {
          var width = 0;
          var len = str.length;
          for (var i = 0; i < len; i++) try {
            width += parseFloat(p.glyphLook(p.glyphTable[name], str[i]).horiz_adv_x)
          } catch(e) {
            Processing.debug(e)
          }
          return width / p.glyphTable[name].units_per_em
        }
      }
    };
    p.createFont = function(name, size) {
      return p.loadFont(name, size)
    };
    p.textFont = function(pfont, size) {
      if (size !== undef) {
        if (!pfont.glyph) pfont = PFont.get(pfont.name, size);
        curTextSize = size
      }
      curTextFont = pfont;
      curFontName = curTextFont.name;
      curTextAscent = curTextFont.ascent;
      curTextDescent = curTextFont.descent;
      curTextLeading = curTextFont.leading;
      var curContext = drawing.$ensureContext();
      curContext.font = curTextFont.css
    };
    p.textSize = function(size) {
      if (size !== curTextSize) {
        curTextFont = PFont.get(curFontName, size);
        curTextSize = size;
        curTextAscent = curTextFont.ascent;
        curTextDescent = curTextFont.descent;
        curTextLeading = curTextFont.leading;
        var curContext = drawing.$ensureContext();
        curContext.font = curTextFont.css
      }
    };
    p.textAscent = function() {
      return curTextAscent
    };
    p.textDescent = function() {
      return curTextDescent
    };
    p.textLeading = function(leading) {
      curTextLeading = leading
    };
    p.textAlign = function(xalign, yalign) {
      horizontalTextAlignment = xalign;
      verticalTextAlignment = yalign || 0
    };

    function toP5String(obj) {
      if (obj instanceof String) return obj;
      if (typeof obj === "number") {
        if (obj === (0 | obj)) return obj.toString();
        return p.nf(obj, 0, 3)
      }
      if (obj === null || obj === undef) return "";
      return obj.toString()
    }
    Drawing2D.prototype.textWidth = function(str) {
      var lines = toP5String(str).split(/\r?\n/g),
        width = 0;
      var i, linesCount = lines.length;
      curContext.font = curTextFont.css;
      for (i = 0; i < linesCount; ++i) width = Math.max(width, curTextFont.measureTextWidth(lines[i]));
      return width | 0
    };
    Drawing3D.prototype.textWidth = function(str) {
      var lines = toP5String(str).split(/\r?\n/g),
        width = 0;
      var i, linesCount = lines.length;
      if (textcanvas === undef) textcanvas = document.createElement("canvas");
      var textContext = textcanvas.getContext("2d");
      textContext.font = curTextFont.css;
      for (i = 0; i < linesCount; ++i) width = Math.max(width, textContext.measureText(lines[i]).width);
      return width | 0
    };
    p.glyphLook = function(font, chr) {
      try {
        switch (chr) {
        case "1":
          return font.one;
        case "2":
          return font.two;
        case "3":
          return font.three;
        case "4":
          return font.four;
        case "5":
          return font.five;
        case "6":
          return font.six;
        case "7":
          return font.seven;
        case "8":
          return font.eight;
        case "9":
          return font.nine;
        case "0":
          return font.zero;
        case " ":
          return font.space;
        case "$":
          return font.dollar;
        case "!":
          return font.exclam;
        case '"':
          return font.quotedbl;
        case "#":
          return font.numbersign;
        case "%":
          return font.percent;
        case "&":
          return font.ampersand;
        case "'":
          return font.quotesingle;
        case "(":
          return font.parenleft;
        case ")":
          return font.parenright;
        case "*":
          return font.asterisk;
        case "+":
          return font.plus;
        case ",":
          return font.comma;
        case "-":
          return font.hyphen;
        case ".":
          return font.period;
        case "/":
          return font.slash;
        case "_":
          return font.underscore;
        case ":":
          return font.colon;
        case ";":
          return font.semicolon;
        case "<":
          return font.less;
        case "=":
          return font.equal;
        case ">":
          return font.greater;
        case "?":
          return font.question;
        case "@":
          return font.at;
        case "[":
          return font.bracketleft;
        case "\\":
          return font.backslash;
        case "]":
          return font.bracketright;
        case "^":
          return font.asciicircum;
        case "`":
          return font.grave;
        case "{":
          return font.braceleft;
        case "|":
          return font.bar;
        case "}":
          return font.braceright;
        case "~":
          return font.asciitilde;
        default:
          return font[chr]
        }
      } catch(e) {
        Processing.debug(e)
      }
    };
    Drawing2D.prototype.text$line = function(str, x, y, z, align) {
      var textWidth = 0,
        xOffset = 0;
      if (!curTextFont.glyph) {
        if (str && "fillText" in curContext) {
          if (isFillDirty) {
            curContext.fillStyle = p.color.toString(currentFillColor);
            isFillDirty = false
          }
          if (align === 39 || align === 3) {
            textWidth = curTextFont.measureTextWidth(str);
            if (align === 39) xOffset = -textWidth;
            else xOffset = -textWidth / 2
          }
          curContext.fillText(str, x + xOffset, y)
        }
      } else {
        var font = p.glyphTable[curFontName];
        saveContext();
        curContext.translate(x, y + curTextSize);
        if (align === 39 || align === 3) {
          textWidth = font.width(str);
          if (align === 39) xOffset = -textWidth;
          else xOffset = -textWidth / 2
        }
        var upem = font.units_per_em,
          newScale = 1 / upem * curTextSize;
        curContext.scale(newScale, newScale);
        for (var i = 0, len = str.length; i < len; i++) try {
          p.glyphLook(font, str[i]).draw()
        } catch(e) {
          Processing.debug(e)
        }
        restoreContext()
      }
    };
    Drawing3D.prototype.text$line = function(str, x, y, z, align) {
      if (textcanvas === undef) textcanvas = document.createElement("canvas");
      var oldContext = curContext;
      curContext = textcanvas.getContext("2d");
      curContext.font = curTextFont.css;
      var textWidth = curTextFont.measureTextWidth(str);
      textcanvas.width = textWidth;
      textcanvas.height = curTextSize;
      curContext = textcanvas.getContext("2d");
      curContext.font = curTextFont.css;
      curContext.textBaseline = "top";
      Drawing2D.prototype.text$line(str, 0, 0, 0, 37);
      var aspect = textcanvas.width / textcanvas.height;
      curContext = oldContext;
      curContext.bindTexture(curContext.TEXTURE_2D, textTex);
      curContext.texImage2D(curContext.TEXTURE_2D, 0, curContext.RGBA, curContext.RGBA, curContext.UNSIGNED_BYTE, textcanvas);
      curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_MAG_FILTER, curContext.LINEAR);
      curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_MIN_FILTER, curContext.LINEAR);
      curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_WRAP_T, curContext.CLAMP_TO_EDGE);
      curContext.texParameteri(curContext.TEXTURE_2D, curContext.TEXTURE_WRAP_S, curContext.CLAMP_TO_EDGE);
      var xOffset = 0;
      if (align === 39) xOffset = -textWidth;
      else if (align === 3) xOffset = -textWidth / 2;
      var model = new PMatrix3D;
      var scalefactor = curTextSize * 0.5;
      model.translate(x + xOffset - scalefactor / 2, y - scalefactor, z);
      model.scale(-aspect * scalefactor, -scalefactor, scalefactor);
      model.translate(-1, -1, -1);
      model.transpose();
      var view = new PMatrix3D;
      view.scale(1, -1, 1);
      view.apply(modelView.array());
      view.transpose();
      curContext.useProgram(programObject2D);
      vertexAttribPointer("vertex2d", programObject2D, "Vertex", 3, textBuffer);
      vertexAttribPointer("aTextureCoord2d", programObject2D, "aTextureCoord", 2, textureBuffer);
      uniformi("uSampler2d", programObject2D, "uSampler", [0]);
      uniformi("picktype2d", programObject2D, "picktype", 1);
      uniformMatrix("model2d", programObject2D, "model", false, model.array());
      uniformMatrix("view2d", programObject2D, "view", false, view.array());
      uniformf("color2d", programObject2D, "color", fillStyle);
      curContext.bindBuffer(curContext.ELEMENT_ARRAY_BUFFER, indexBuffer);
      curContext.drawElements(curContext.TRIANGLES, 6, curContext.UNSIGNED_SHORT, 0)
    };

    function text$4(str, x, y, z) {
      var lines, linesCount;
      if (str.indexOf("\n") < 0) {
        lines = [str];
        linesCount = 1
      } else {
        lines = str.split(/\r?\n/g);
        linesCount = lines.length
      }
      var yOffset = 0;
      if (verticalTextAlignment === 101) yOffset = curTextAscent + curTextDescent;
      else if (verticalTextAlignment === 3) yOffset = curTextAscent / 2 - (linesCount - 1) * curTextLeading / 2;
      else if (verticalTextAlignment === 102) yOffset = -(curTextDescent + (linesCount - 1) * curTextLeading);
      for (var i = 0; i < linesCount; ++i) {
        var line = lines[i];
        drawing.text$line(line, x, y + yOffset, z, horizontalTextAlignment);
        yOffset += curTextLeading
      }
    }
    function text$6(str, x, y, width, height, z) {
      if (str.length === 0 || width === 0 || height === 0) return;
      if (curTextSize > height) return;
      var spaceMark = -1;
      var start = 0;
      var lineWidth = 0;
      var drawCommands = [];
      for (var charPos = 0, len = str.length; charPos < len; charPos++) {
        var currentChar = str[charPos];
        var spaceChar = currentChar === " ";
        var letterWidth = curTextFont.measureTextWidth(currentChar);
        if (currentChar !== "\n" && lineWidth + letterWidth <= width) {
          if (spaceChar) spaceMark = charPos;
          lineWidth += letterWidth
        } else {
          if (spaceMark + 1 === start) if (charPos > 0) spaceMark = charPos;
          else return;
          if (currentChar === "\n") {
            drawCommands.push({
              text: str.substring(start, charPos),
              width: lineWidth
            });
            start = charPos + 1
          } else {
            drawCommands.push({
              text: str.substring(start, spaceMark + 1),
              width: lineWidth
            });
            start = spaceMark + 1
          }
          lineWidth = 0;
          charPos = start - 1
        }
      }
      if (start < len) drawCommands.push({
        text: str.substring(start),
        width: lineWidth
      });
      var xOffset = 1,
        yOffset = curTextAscent;
      if (horizontalTextAlignment === 3) xOffset = width / 2;
      else if (horizontalTextAlignment === 39) xOffset = width;
      var linesCount = drawCommands.length,
        visibleLines = Math.min(linesCount, Math.floor(height / curTextLeading));
      if (verticalTextAlignment === 101) yOffset = curTextAscent + curTextDescent;
      else if (verticalTextAlignment === 3) yOffset = height / 2 - curTextLeading * (visibleLines / 2 - 1);
      else if (verticalTextAlignment === 102) yOffset = curTextDescent + curTextLeading;
      var command, drawCommand, leading;
      for (command = 0; command < linesCount; command++) {
        leading = command * curTextLeading;
        if (yOffset + leading > height - curTextDescent) break;
        drawCommand = drawCommands[command];
        drawing.text$line(drawCommand.text, x + xOffset, y + yOffset + leading, z, horizontalTextAlignment)
      }
    }
    p.text = function() {
      if (textMode === 5) return;
      if (arguments.length === 3) text$4(toP5String(arguments[0]), arguments[1], arguments[2], 0);
      else if (arguments.length === 4) text$4(toP5String(arguments[0]), arguments[1], arguments[2], arguments[3]);
      else if (arguments.length === 5) text$6(toP5String(arguments[0]), arguments[1], arguments[2], arguments[3], arguments[4], 0);
      else if (arguments.length === 6) text$6(toP5String(arguments[0]), arguments[1], arguments[2], arguments[3], arguments[4], arguments[5])
    };
    p.textMode = function(mode) {
      textMode = mode
    };
    p.loadGlyphs = function(url) {
      var x, y, cx, cy, nx, ny, d, a, lastCom, lenC, horiz_adv_x, getXY = "[0-9\\-]+",
        path;
      var regex = function(needle, hay) {
        var i = 0,
          results = [],
          latest, regexp = new RegExp(needle, "g");
        latest = results[i] = regexp.exec(hay);
        while (latest) {
          i++;
          latest = results[i] = regexp.exec(hay)
        }
        return results
      };
      var buildPath = function(d) {
        var c = regex("[A-Za-z][0-9\\- ]+|Z", d);
        var beforePathDraw = function() {
          saveContext();
          return drawing.$ensureContext()
        };
        var afterPathDraw = function() {
          executeContextFill();
          executeContextStroke();
          restoreContext()
        };
        path = "return {draw:function(){var curContext=beforePathDraw();curContext.beginPath();";
        x = 0;
        y = 0;
        cx = 0;
        cy = 0;
        nx = 0;
        ny = 0;
        d = 0;
        a = 0;
        lastCom = "";
        lenC = c.length - 1;
        for (var j = 0; j < lenC; j++) {
          var com = c[j][0],
            xy = regex(getXY, com);
          switch (com[0]) {
          case "M":
            x = parseFloat(xy[0][0]);
            y = parseFloat(xy[1][0]);
            path += "curContext.moveTo(" + x + "," + -y + ");";
            break;
          case "L":
            x = parseFloat(xy[0][0]);
            y = parseFloat(xy[1][0]);
            path += "curContext.lineTo(" + x + "," + -y + ");";
            break;
          case "H":
            x = parseFloat(xy[0][0]);
            path += "curContext.lineTo(" + x + "," + -y + ");";
            break;
          case "V":
            y = parseFloat(xy[0][0]);
            path += "curContext.lineTo(" + x + "," + -y + ");";
            break;
          case "T":
            nx = parseFloat(xy[0][0]);
            ny = parseFloat(xy[1][0]);
            if (lastCom === "Q" || lastCom === "T") {
              d = Math.sqrt(Math.pow(x - cx, 2) + Math.pow(cy - y, 2));
              a = Math.PI + Math.atan2(cx - x, cy - y);
              cx = x + Math.sin(a) * d;
              cy = y + Math.cos(a) * d
            } else {
              cx = x;
              cy = y
            }
            path += "curContext.quadraticCurveTo(" + cx + "," + -cy + "," + nx + "," + -ny + ");";
            x = nx;
            y = ny;
            break;
          case "Q":
            cx = parseFloat(xy[0][0]);
            cy = parseFloat(xy[1][0]);
            nx = parseFloat(xy[2][0]);
            ny = parseFloat(xy[3][0]);
            path += "curContext.quadraticCurveTo(" + cx + "," + -cy + "," + nx + "," + -ny + ");";
            x = nx;
            y = ny;
            break;
          case "Z":
            path += "curContext.closePath();";
            break
          }
          lastCom = com[0]
        }
        path += "afterPathDraw();";
        path += "curContext.translate(" + horiz_adv_x + ",0);";
        path += "}}";
        return (new Function("beforePathDraw", "afterPathDraw", path))(beforePathDraw, afterPathDraw)
      };
      var parseSVGFont = function(svg) {
        var font = svg.getElementsByTagName("font");
        p.glyphTable[url].horiz_adv_x = font[0].getAttribute("horiz-adv-x");
        var font_face = svg.getElementsByTagName("font-face")[0];
        p.glyphTable[url].units_per_em = parseFloat(font_face.getAttribute("units-per-em"));
        p.glyphTable[url].ascent = parseFloat(font_face.getAttribute("ascent"));
        p.glyphTable[url].descent = parseFloat(font_face.getAttribute("descent"));
        var glyph = svg.getElementsByTagName("glyph"),
          len = glyph.length;
        for (var i = 0; i < len; i++) {
          var unicode = glyph[i].getAttribute("unicode");
          var name = glyph[i].getAttribute("glyph-name");
          horiz_adv_x = glyph[i].getAttribute("horiz-adv-x");
          if (horiz_adv_x === null) horiz_adv_x = p.glyphTable[url].horiz_adv_x;
          d = glyph[i].getAttribute("d");
          if (d !== undef) {
            path = buildPath(d);
            p.glyphTable[url][name] = {
              name: name,
              unicode: unicode,
              horiz_adv_x: horiz_adv_x,
              draw: path.draw
            }
          }
        }
      };
      var loadXML = function() {
        var xmlDoc;
        try {
          xmlDoc = document.implementation.createDocument("", "", null)
        } catch(e_fx_op) {
          Processing.debug(e_fx_op.message);
          return
        }
        try {
          xmlDoc.async = false;
          xmlDoc.load(url);
          parseSVGFont(xmlDoc.getElementsByTagName("svg")[0])
        } catch(e_sf_ch) {
          Processing.debug(e_sf_ch);
          try {
            var xmlhttp = new window.XMLHttpRequest;
            xmlhttp.open("GET", url, false);
            xmlhttp.send(null);
            parseSVGFont(xmlhttp.responseXML.documentElement)
          } catch(e) {
            Processing.debug(e_sf_ch)
          }
        }
      };
      p.glyphTable[url] = {};
      loadXML(url);
      return p.glyphTable[url]
    };
    p.param = function(name) {
      var attributeName = "data-processing-" + name;
      if (curElement.hasAttribute(attributeName)) return curElement.getAttribute(attributeName);
      for (var i = 0, len = curElement.childNodes.length; i < len; ++i) {
        var item = curElement.childNodes.item(i);
        if (item.nodeType !== 1 || item.tagName.toLowerCase() !== "param") continue;
        if (item.getAttribute("name") === name) return item.getAttribute("value")
      }
      if (curSketch.params.hasOwnProperty(name)) return curSketch.params[name];
      return null
    };

    function wireDimensionalFunctions(mode) {
      if (mode === "3D") drawing = new Drawing3D;
      else if (mode === "2D") drawing = new Drawing2D;
      else drawing = new DrawingPre;
      for (var i in DrawingPre.prototype) if (DrawingPre.prototype.hasOwnProperty(i) && i.indexOf("$") < 0) p[i] = drawing[i];
      drawing.$init()
    }
    function createDrawingPreFunction(name) {
      return function() {
        wireDimensionalFunctions("2D");
        return drawing[name].apply(this, arguments)
      }
    }
    DrawingPre.prototype.translate = createDrawingPreFunction("translate");
    DrawingPre.prototype.scale = createDrawingPreFunction("scale");
    DrawingPre.prototype.pushMatrix = createDrawingPreFunction("pushMatrix");
    DrawingPre.prototype.popMatrix = createDrawingPreFunction("popMatrix");
    DrawingPre.prototype.resetMatrix = createDrawingPreFunction("resetMatrix");
    DrawingPre.prototype.applyMatrix = createDrawingPreFunction("applyMatrix");
    DrawingPre.prototype.rotate = createDrawingPreFunction("rotate");
    DrawingPre.prototype.rotateZ = createDrawingPreFunction("rotateZ");
    DrawingPre.prototype.redraw = createDrawingPreFunction("redraw");
    DrawingPre.prototype.toImageData = createDrawingPreFunction("toImageData");
    DrawingPre.prototype.ambientLight = createDrawingPreFunction("ambientLight");
    DrawingPre.prototype.directionalLight = createDrawingPreFunction("directionalLight");
    DrawingPre.prototype.lightFalloff = createDrawingPreFunction("lightFalloff");
    DrawingPre.prototype.lightSpecular = createDrawingPreFunction("lightSpecular");
    DrawingPre.prototype.pointLight = createDrawingPreFunction("pointLight");
    DrawingPre.prototype.noLights = createDrawingPreFunction("noLights");
    DrawingPre.prototype.spotLight = createDrawingPreFunction("spotLight");
    DrawingPre.prototype.beginCamera = createDrawingPreFunction("beginCamera");
    DrawingPre.prototype.endCamera = createDrawingPreFunction("endCamera");
    DrawingPre.prototype.frustum = createDrawingPreFunction("frustum");
    DrawingPre.prototype.box = createDrawingPreFunction("box");
    DrawingPre.prototype.sphere = createDrawingPreFunction("sphere");
    DrawingPre.prototype.ambient = createDrawingPreFunction("ambient");
    DrawingPre.prototype.emissive = createDrawingPreFunction("emissive");
    DrawingPre.prototype.shininess = createDrawingPreFunction("shininess");
    DrawingPre.prototype.specular = createDrawingPreFunction("specular");
    DrawingPre.prototype.fill = createDrawingPreFunction("fill");
    DrawingPre.prototype.stroke = createDrawingPreFunction("stroke");
    DrawingPre.prototype.strokeWeight = createDrawingPreFunction("strokeWeight");
    DrawingPre.prototype.smooth = createDrawingPreFunction("smooth");
    DrawingPre.prototype.noSmooth = createDrawingPreFunction("noSmooth");
    DrawingPre.prototype.point = createDrawingPreFunction("point");
    DrawingPre.prototype.vertex = createDrawingPreFunction("vertex");
    DrawingPre.prototype.endShape = createDrawingPreFunction("endShape");
    DrawingPre.prototype.bezierVertex = createDrawingPreFunction("bezierVertex");
    DrawingPre.prototype.curveVertex = createDrawingPreFunction("curveVertex");
    DrawingPre.prototype.curve = createDrawingPreFunction("curve");
    DrawingPre.prototype.line = createDrawingPreFunction("line");
    DrawingPre.prototype.bezier = createDrawingPreFunction("bezier");
    DrawingPre.prototype.rect = createDrawingPreFunction("rect");
    DrawingPre.prototype.ellipse = createDrawingPreFunction("ellipse");
    DrawingPre.prototype.background = createDrawingPreFunction("background");
    DrawingPre.prototype.image = createDrawingPreFunction("image");
    DrawingPre.prototype.textWidth = createDrawingPreFunction("textWidth");
    DrawingPre.prototype.text$line = createDrawingPreFunction("text$line");
    DrawingPre.prototype.$ensureContext = createDrawingPreFunction("$ensureContext");
    DrawingPre.prototype.$newPMatrix = createDrawingPreFunction("$newPMatrix");
    DrawingPre.prototype.size = function(aWidth, aHeight, aMode) {
      wireDimensionalFunctions(aMode === 2 ? "3D" : "2D");
      p.size(aWidth, aHeight, aMode)
    };
    DrawingPre.prototype.$init = nop;
    Drawing2D.prototype.$init = function() {
      p.size(p.width, p.height);
      curContext.lineCap = "round";
      p.noSmooth();
      p.disableContextMenu()
    };
    Drawing3D.prototype.$init = function() {
      p.use3DContext = true
    };
    DrawingShared.prototype.$ensureContext = function() {
      return curContext
    };

    function calculateOffset(curElement, event) {
      var element = curElement,
        offsetX = 0,
        offsetY = 0;
      p.pmouseX = p.mouseX;
      p.pmouseY = p.mouseY;
      if (element.offsetParent) {
        do {
          offsetX += element.offsetLeft;
          offsetY += element.offsetTop
        } while ( !! (element = element.offsetParent))
      }
      element = curElement;
      do {
        offsetX -= element.scrollLeft || 0;
        offsetY -= element.scrollTop || 0
      } while ( !! (element = element.parentNode));
      offsetX += stylePaddingLeft;
      offsetY += stylePaddingTop;
      offsetX += styleBorderLeft;
      offsetY += styleBorderTop;
      offsetX += window.pageXOffset;
      offsetY += window.pageYOffset;
      return {
        "X": offsetX,
        "Y": offsetY
      }
    }
    function updateMousePosition(curElement, event) {
      var offset = calculateOffset(curElement, event);
      p.mouseX = event.pageX - offset.X;
      p.mouseY = event.pageY - offset.Y
    }
    function addTouchEventOffset(t) {
      var offset = calculateOffset(t.changedTouches[0].target, t.changedTouches[0]),
        i;
      for (i = 0; i < t.touches.length; i++) {
        var touch = t.touches[i];
        touch.offsetX = touch.pageX - offset.X;
        touch.offsetY = touch.pageY - offset.Y
      }
      for (i = 0; i < t.targetTouches.length; i++) {
        var targetTouch = t.targetTouches[i];
        targetTouch.offsetX = targetTouch.pageX - offset.X;
        targetTouch.offsetY = targetTouch.pageY - offset.Y
      }
      for (i = 0; i < t.changedTouches.length; i++) {
        var changedTouch = t.changedTouches[i];
        changedTouch.offsetX = changedTouch.pageX - offset.X;
        changedTouch.offsetY = changedTouch.pageY - offset.Y
      }
      return t
    }
    attachEventHandler(curElement, "touchstart", function(t) {
      curElement.setAttribute("style", "-webkit-user-select: none");
      curElement.setAttribute("onclick", "void(0)");
      curElement.setAttribute("style", "-webkit-tap-highlight-color:rgba(0,0,0,0)");
      for (var i = 0, ehl = eventHandlers.length; i < ehl; i++) {
        var type = eventHandlers[i].type;
        if (type === "mouseout" || type === "mousemove" || type === "mousedown" || type === "mouseup" || type === "DOMMouseScroll" || type === "mousewheel" || type === "touchstart") detachEventHandler(eventHandlers[i])
      }
      if (p.touchStart !== undef || p.touchMove !== undef || p.touchEnd !== undef || p.touchCancel !== undef) {
        attachEventHandler(curElement, "touchstart", function(t) {
          if (p.touchStart !== undef) {
            t = addTouchEventOffset(t);
            p.touchStart(t)
          }
        });
        attachEventHandler(curElement, "touchmove", function(t) {
          if (p.touchMove !== undef) {
            t.preventDefault();
            t = addTouchEventOffset(t);
            p.touchMove(t)
          }
        });
        attachEventHandler(curElement, "touchend", function(t) {
          if (p.touchEnd !== undef) {
            t = addTouchEventOffset(t);
            p.touchEnd(t)
          }
        });
        attachEventHandler(curElement, "touchcancel", function(t) {
          if (p.touchCancel !== undef) {
            t = addTouchEventOffset(t);
            p.touchCancel(t)
          }
        })
      } else {
        attachEventHandler(curElement, "touchstart", function(e) {
          updateMousePosition(curElement, e.touches[0]);
          p.__mousePressed = true;
          p.mouseDragging = false;
          p.mouseButton = 37;
          if (typeof p.mousePressed === "function") p.mousePressed()
        });
        attachEventHandler(curElement, "touchmove", function(e) {
          e.preventDefault();
          updateMousePosition(curElement, e.touches[0]);
          if (typeof p.mouseMoved === "function" && !p.__mousePressed) p.mouseMoved();
          if (typeof p.mouseDragged === "function" && p.__mousePressed) {
            p.mouseDragged();
            p.mouseDragging = true
          }
        });
        attachEventHandler(curElement, "touchend", function(e) {
          p.__mousePressed = false;
          if (typeof p.mouseClicked === "function" && !p.mouseDragging) p.mouseClicked();
          if (typeof p.mouseReleased === "function") p.mouseReleased()
        })
      }
      curElement.dispatchEvent(t)
    });
    (function() {
      var enabled = true,
        contextMenu = function(e) {
        e.preventDefault();
        e.stopPropagation()
      };
      p.disableContextMenu = function() {
        if (!enabled) return;
        attachEventHandler(curElement, "contextmenu", contextMenu);
        enabled = false
      };
      p.enableContextMenu = function() {
        if (enabled) return;
        detachEventHandler({
          elem: curElement,
          type: "contextmenu",
          fn: contextMenu
        });
        enabled = true
      }
    })();
    attachEventHandler(curElement, "mousemove", function(e) {
      updateMousePosition(curElement, e);
      if (typeof p.mouseMoved === "function" && !p.__mousePressed) p.mouseMoved();
      if (typeof p.mouseDragged === "function" && p.__mousePressed) {
        p.mouseDragged();
        p.mouseDragging = true
      }
    });
    attachEventHandler(curElement, "mouseout", function(e) {
      if (typeof p.mouseOut === "function") p.mouseOut()
    });
    attachEventHandler(curElement, "mouseover", function(e) {
      updateMousePosition(curElement, e);
      if (typeof p.mouseOver === "function") p.mouseOver()
    });
    attachEventHandler(curElement, "mousedown", function(e) {
      p.__mousePressed = true;
      p.mouseDragging = false;
      switch (e.which) {
      case 1:
        p.mouseButton = 37;
        break;
      case 2:
        p.mouseButton = 3;
        break;
      case 3:
        p.mouseButton = 39;
        break
      }
      if (typeof p.mousePressed === "function") p.mousePressed()
    });
    attachEventHandler(curElement, "mouseup", function(e) {
      p.__mousePressed = false;
      if (typeof p.mouseClicked === "function" && !p.mouseDragging) p.mouseClicked();
      if (typeof p.mouseReleased === "function") p.mouseReleased()
    });
    var mouseWheelHandler = function(e) {
      var delta = 0;
      if (e.wheelDelta) {
        delta = e.wheelDelta / 120;
        if (window.opera) delta = -delta
      } else if (e.detail) delta = -e.detail / 3;
      p.mouseScroll = delta;
      if (delta && typeof p.mouseScrolled === "function") p.mouseScrolled()
    };
    attachEventHandler(document, "DOMMouseScroll", mouseWheelHandler);
    attachEventHandler(document, "mousewheel", mouseWheelHandler);
    if (typeof curElement === "string") curElement = document.getElementById(curElement);
    if (!curElement.getAttribute("tabindex")) curElement.setAttribute("tabindex", 0);

    function getKeyCode(e) {
      var code = e.which || e.keyCode;
      switch (code) {
      case 13:
        return 10;
      case 91:
      case 93:
      case 224:
        return 157;
      case 57392:
        return 17;
      case 46:
        return 127;
      case 45:
        return 155
      }
      return code
    }
    function getKeyChar(e) {
      var c = e.which || e.keyCode;
      var anyShiftPressed = e.shiftKey || e.ctrlKey || e.altKey || e.metaKey;
      switch (c) {
      case 13:
        c = anyShiftPressed ? 13 : 10;
        break;
      case 8:
        c = anyShiftPressed ? 127 : 8;
        break
      }
      return new Char(c)
    }
    function suppressKeyEvent(e) {
      if (typeof e.preventDefault === "function") e.preventDefault();
      else if (typeof e.stopPropagation === "function") e.stopPropagation();
      return false
    }
    function updateKeyPressed() {
      var ch;
      for (ch in pressedKeysMap) if (pressedKeysMap.hasOwnProperty(ch)) {
        p.__keyPressed = true;
        return
      }
      p.__keyPressed = false
    }
    function resetKeyPressed() {
      p.__keyPressed = false;
      pressedKeysMap = [];
      lastPressedKeyCode = null
    }
    function simulateKeyTyped(code, c) {
      pressedKeysMap[code] = c;
      lastPressedKeyCode = null;
      p.key = c;
      p.keyCode = code;
      p.keyPressed();
      p.keyCode = 0;
      p.keyTyped();
      updateKeyPressed()
    }
    function handleKeydown(e) {
      var code = getKeyCode(e);
      if (code === 127) {
        simulateKeyTyped(code, new Char(127));
        return
      }
      if (codedKeys.indexOf(code) < 0) {
        lastPressedKeyCode = code;
        return
      }
      var c = new Char(65535);
      p.key = c;
      p.keyCode = code;
      pressedKeysMap[code] = c;
      p.keyPressed();
      lastPressedKeyCode = null;
      updateKeyPressed();
      return suppressKeyEvent(e)
    }
    function handleKeypress(e) {
      if (lastPressedKeyCode === null) return;
      var code = lastPressedKeyCode,
        c = getKeyChar(e);
      simulateKeyTyped(code, c);
      return suppressKeyEvent(e)
    }
    function handleKeyup(e) {
      var code = getKeyCode(e),
        c = pressedKeysMap[code];
      if (c === undef) return;
      p.key = c;
      p.keyCode = code;
      p.keyReleased();
      delete pressedKeysMap[code];
      updateKeyPressed()
    }
    if (!pgraphicsMode) {
      if (aCode instanceof Processing.Sketch) curSketch = aCode;
      else if (typeof aCode === "function") curSketch = new Processing.Sketch(aCode);
      else if (!aCode) curSketch = new Processing.Sketch(function() {});
      else curSketch = Processing.compile(aCode);
      p.externals.sketch = curSketch;
      wireDimensionalFunctions();
      curElement.onfocus = function() {
        p.focused = true
      };
      curElement.onblur = function() {
        p.focused = false;
        if (!curSketch.options.globalKeyEvents) resetKeyPressed()
      };
      if (curSketch.options.pauseOnBlur) {
        attachEventHandler(window, "focus", function() {
          if (doLoop) p.loop()
        });
        attachEventHandler(window, "blur", function() {
          if (doLoop && loopStarted) {
            p.noLoop();
            doLoop = true
          }
          resetKeyPressed()
        })
      }
      var keyTrigger = curSketch.options.globalKeyEvents ? window : curElement;
      attachEventHandler(keyTrigger, "keydown", handleKeydown);
      attachEventHandler(keyTrigger, "keypress", handleKeypress);
      attachEventHandler(keyTrigger, "keyup", handleKeyup);
      for (var i in Processing.lib) if (Processing.lib.hasOwnProperty(i)) if (Processing.lib[i].hasOwnProperty("attach")) Processing.lib[i].attach(p);
      else if (Processing.lib[i] instanceof Function) Processing.lib[i].call(this);
      var retryInterval = 100;
      var executeSketch = function(processing) {
        if (! (curSketch.imageCache.pending || PFont.preloading.pending(retryInterval))) {
          if (window.opera) {
            var link, element, operaCache = curSketch.imageCache.operaCache;
            for (link in operaCache) if (operaCache.hasOwnProperty(link)) {
              element = operaCache[link];
              if (element !== null) document.body.removeChild(element);
              delete operaCache[link]
            }
          }
          curSketch.attach(processing, defaultScope);
          curSketch.onLoad(processing);
          if (processing.setup) {
            processing.setup();
            processing.resetMatrix();
            curSketch.onSetup()
          }
          resetContext();
          if (processing.draw) if (!doLoop) processing.redraw();
          else processing.loop()
        } else window.setTimeout(function() {
          executeSketch(processing)
        },
        retryInterval)
      };
      addInstance(this);
      executeSketch(p)
    } else {
      curSketch = new Processing.Sketch;
      wireDimensionalFunctions();
      p.size = function(w, h, render) {
        if (render && render === 2) wireDimensionalFunctions("3D");
        else wireDimensionalFunctions("2D");
        p.size(w, h, render)
      }
    }
  };
  Processing.debug = debug;
  Processing.prototype = defaultScope;

  function getGlobalMembers() {
    var names = ["abs", "acos", "alpha", "ambient", "ambientLight", "append", "applyMatrix", "arc", "arrayCopy", "asin", "atan", "atan2", "background", "beginCamera", "beginDraw", "beginShape", "bezier", "bezierDetail", "bezierPoint", "bezierTangent", "bezierVertex", "binary", "blend", "blendColor", "blit_resize", "blue", "box", "breakShape", "brightness", "camera", "ceil", "Character", "color", "colorMode", "concat", "constrain", "copy", "cos", "createFont",
      "createGraphics", "createImage", "cursor", "curve", "curveDetail", "curvePoint", "curveTangent", "curveTightness", "curveVertex", "day", "degrees", "directionalLight", "disableContextMenu", "dist", "draw", "ellipse", "ellipseMode", "emissive", "enableContextMenu", "endCamera", "endDraw", "endShape", "exit", "exp", "expand", "externals", "fill", "filter", "floor", "focused", "frameCount", "frameRate", "frustum", "get", "glyphLook", "glyphTable", "green", "height", "hex", "hint", "hour", "hue", "image", "imageMode", "intersect", "join", "key",
      "keyCode", "keyPressed", "keyReleased", "keyTyped", "lerp", "lerpColor", "lightFalloff", "lights", "lightSpecular", "line", "link", "loadBytes", "loadFont", "loadGlyphs", "loadImage", "loadPixels", "loadShape", "loadStrings", "log", "loop", "mag", "map", "match", "matchAll", "max", "millis", "min", "minute", "mix", "modelX", "modelY", "modelZ", "modes", "month", "mouseButton", "mouseClicked", "mouseDragged", "mouseMoved", "mouseOut", "mouseOver", "mousePressed", "mouseReleased", "mouseScroll", "mouseScrolled", "mouseX", "mouseY", "name", "nf",
      "nfc", "nfp", "nfs", "noCursor", "noFill", "noise", "noiseDetail", "noiseSeed", "noLights", "noLoop", "norm", "normal", "noSmooth", "noStroke", "noTint", "ortho", "param", "parseBoolean", "parseByte", "parseChar", "parseFloat", "parseInt", "peg", "perspective", "PImage", "pixels", "PMatrix2D", "PMatrix3D", "PMatrixStack", "pmouseX", "pmouseY", "point", "pointLight", "popMatrix", "popStyle", "pow", "print", "printCamera", "println", "printMatrix", "printProjection", "PShape", "PShapeSVG", "pushMatrix", "pushStyle", "quad", "radians", "random",
      "Random", "randomSeed", "rect", "rectMode", "red", "redraw", "requestImage", "resetMatrix", "reverse", "rotate", "rotateX", "rotateY", "rotateZ", "round", "saturation", "save", "saveFrame", "saveStrings", "scale", "screenX", "screenY", "screenZ", "second", "set", "setup", "shape", "shapeMode", "shared", "shininess", "shorten", "sin", "size", "smooth", "sort", "specular", "sphere", "sphereDetail", "splice", "split", "splitTokens", "spotLight", "sq", "sqrt", "status", "str", "stroke", "strokeCap", "strokeJoin", "strokeWeight", "subset", "tan", "text",
      "textAlign", "textAscent", "textDescent", "textFont", "textLeading", "textMode", "textSize", "texture", "textureMode", "textWidth", "tint", "toImageData", "touchCancel", "touchEnd", "touchMove", "touchStart", "translate", "triangle", "trim", "unbinary", "unhex", "updatePixels", "use3DContext", "vertex", "width", "XMLElement", "year", "__contains", "__equals", "__equalsIgnoreCase", "__frameRate", "__hashCode", "__int_cast", "__instanceof", "__keyPressed", "__mousePressed", "__printStackTrace", "__replace", "__replaceAll", "__replaceFirst",
      "__toCharArray", "__split", "__codePointAt", "__startsWith", "__endsWith"];
    var members = {};
    var i, l;
    for (i = 0, l = names.length; i < l; ++i) members[names[i]] = null;
    for (var lib in Processing.lib) if (Processing.lib.hasOwnProperty(lib)) if (Processing.lib[lib].exports) {
      var exportedNames = Processing.lib[lib].exports;
      for (i = 0, l = exportedNames.length; i < l; ++i) members[exportedNames[i]] = null
    }
    return members
  }
  function parseProcessing(code) {
    var globalMembers = getGlobalMembers();

    function splitToAtoms(code) {
      var atoms = [];
      var items = code.split(/([\{\[\(\)\]\}])/);
      var result = items[0];
      var stack = [];
      for (var i = 1; i < items.length; i += 2) {
        var item = items[i];
        if (item === "[" || item === "{" || item === "(") {
          stack.push(result);
          result = item
        } else if (item === "]" || item === "}" || item === ")") {
          var kind = item === "}" ? "A" : item === ")" ? "B" : "C";
          var index = atoms.length;
          atoms.push(result + item);
          result = stack.pop() + '"' + kind + (index + 1) + '"'
        }
        result += items[i + 1]
      }
      atoms.unshift(result);
      return atoms
    }
    function injectStrings(code, strings) {
      return code.replace(/'(\d+)'/g, function(all, index) {
        var val = strings[index];
        if (val.charAt(0) === "/") return val;
        return /^'((?:[^'\\\n])|(?:\\.[0-9A-Fa-f]*))'$/.test(val) ? "(new $p.Character(" + val + "))" : val
      })
    }
    function trimSpaces(string) {
      var m1 = /^\s*/.exec(string),
        result;
      if (m1[0].length === string.length) result = {
        left: m1[0],
        middle: "",
        right: ""
      };
      else {
        var m2 = /\s*$/.exec(string);
        result = {
          left: m1[0],
          middle: string.substring(m1[0].length, m2.index),
          right: m2[0]
        }
      }
      result.untrim = function(t) {
        return this.left + t + this.right
      };
      return result
    }
    function trim(string) {
      return string.replace(/^\s+/, "").replace(/\s+$/, "")
    }
    function appendToLookupTable(table, array) {
      for (var i = 0, l = array.length; i < l; ++i) table[array[i]] = null;
      return table
    }
    function isLookupTableEmpty(table) {
      for (var i in table) if (table.hasOwnProperty(i)) return false;
      return true
    }
    function getAtomIndex(templ) {
      return templ.substring(2, templ.length - 1)
    }
    var codeWoExtraCr = code.replace(/\r\n?|\n\r/g, "\n");
    var strings = [];
    var codeWoStrings = codeWoExtraCr.replace(/("(?:[^"\\\n]|\\.)*")|('(?:[^'\\\n]|\\.)*')|(([\[\(=|&!\^:?]\s*)(\/(?![*\/])(?:[^\/\\\n]|\\.)*\/[gim]*)\b)|(\/\/[^\n]*\n)|(\/\*(?:(?!\*\/)(?:.|\n))*\*\/)/g, function(all, quoted, aposed, regexCtx, prefix, regex, singleComment, comment) {
      var index;
      if (quoted || aposed) {
        index = strings.length;
        strings.push(all);
        return "'" + index + "'"
      }
      if (regexCtx) {
        index = strings.length;
        strings.push(regex);
        return prefix + "'" + index + "'"
      }
      return comment !== "" ? " " : "\n"
    });
    var genericsWereRemoved;
    var codeWoGenerics = codeWoStrings;
    var replaceFunc = function(all, before, types, after) {
      if ( !! before || !!after) return all;
      genericsWereRemoved = true;
      return ""
    };
    do {
      genericsWereRemoved = false;
      codeWoGenerics = codeWoGenerics.replace(/([<]?)<\s*((?:\?|[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)(?:\s+(?:extends|super)\s+[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)?(?:\s*,\s*(?:\?|[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)(?:\s+(?:extends|super)\s+[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)?)*)\s*>([=]?)/g, replaceFunc)
    } while (genericsWereRemoved);
    var atoms = splitToAtoms(codeWoGenerics);
    var replaceContext;
    var declaredClasses = {},
      currentClassId, classIdSeed = 0;

    function addAtom(text, type) {
      var lastIndex = atoms.length;
      atoms.push(text);
      return '"' + type + lastIndex + '"'
    }
    function generateClassId() {
      return "class" + ++classIdSeed
    }
    function appendClass(class_, classId, scopeId) {
      class_.classId = classId;
      class_.scopeId = scopeId;
      declaredClasses[classId] = class_
    }
    var transformClassBody, transformInterfaceBody, transformStatementsBlock, transformStatements, transformMain, transformExpression;
    var classesRegex = /\b((?:(?:public|private|final|protected|static|abstract)\s+)*)(class|interface)\s+([A-Za-z_$][\w$]*\b)(\s+extends\s+[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*(?:\s*,\s*[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*\b)*)?(\s+implements\s+[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*(?:\s*,\s*[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*\b)*)?\s*("A\d+")/g;
    var methodsRegex = /\b((?:(?:public|private|final|protected|static|abstract|synchronized)\s+)*)((?!(?:else|new|return|throw|function|public|private|protected)\b)[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*(?:\s*"C\d+")*)\s*([A-Za-z_$][\w$]*\b)\s*("B\d+")(\s*throws\s+[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*(?:\s*,\s*[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)*)?\s*("A\d+"|;)/g;
    var fieldTest = /^((?:(?:public|private|final|protected|static)\s+)*)((?!(?:else|new|return|throw)\b)[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*(?:\s*"C\d+")*)\s*([A-Za-z_$][\w$]*\b)\s*(?:"C\d+"\s*)*([=,]|$)/;
    var cstrsRegex = /\b((?:(?:public|private|final|protected|static|abstract)\s+)*)((?!(?:new|return|throw)\b)[A-Za-z_$][\w$]*\b)\s*("B\d+")(\s*throws\s+[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*(?:\s*,\s*[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)*)?\s*("A\d+")/g;
    var attrAndTypeRegex = /^((?:(?:public|private|final|protected|static)\s+)*)((?!(?:new|return|throw)\b)[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*(?:\s*"C\d+")*)\s*/;
    var functionsRegex = /\bfunction(?:\s+([A-Za-z_$][\w$]*))?\s*("B\d+")\s*("A\d+")/g;

    function extractClassesAndMethods(code) {
      var s = code;
      s = s.replace(classesRegex, function(all) {
        return addAtom(all, "E")
      });
      s = s.replace(methodsRegex, function(all) {
        return addAtom(all, "D")
      });
      s = s.replace(functionsRegex, function(all) {
        return addAtom(all, "H")
      });
      return s
    }
    function extractConstructors(code, className) {
      var result = code.replace(cstrsRegex, function(all, attr, name, params, throws_, body) {
        if (name !== className) return all;
        return addAtom(all, "G")
      });
      return result
    }
    function AstParam(name) {
      this.name = name
    }
    AstParam.prototype.toString = function() {
      return this.name
    };

    function AstParams(params) {
      this.params = params
    }
    AstParams.prototype.getNames = function() {
      var names = [];
      for (var i = 0, l = this.params.length; i < l; ++i) names.push(this.params[i].name);
      return names
    };
    AstParams.prototype.toString = function() {
      if (this.params.length === 0) return "()";
      var result = "(";
      for (var i = 0, l = this.params.length; i < l; ++i) result += this.params[i] + ", ";
      return result.substring(0, result.length - 2) + ")"
    };

    function transformParams(params) {
      var paramsWoPars = trim(params.substring(1, params.length - 1));
      var result = [];
      if (paramsWoPars !== "") {
        var paramList = paramsWoPars.split(",");
        for (var i = 0; i < paramList.length; ++i) {
          var param = /\b([A-Za-z_$][\w$]*\b)(\s*"[ABC][\d]*")*\s*$/.exec(paramList[i]);
          result.push(new AstParam(param[1]))
        }
      }
      return new AstParams(result)
    }
    function preExpressionTransform(expr) {
      var s = expr;
      s = s.replace(/\bnew\s+([A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)(?:\s*"C\d+")+\s*("A\d+")/g, function(all, type, init) {
        return init
      });
      s = s.replace(/\bnew\s+([A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)(?:\s*"B\d+")\s*("A\d+")/g, function(all, type, init) {
        return addAtom(all, "F")
      });
      s = s.replace(functionsRegex, function(all) {
        return addAtom(all, "H")
      });
      s = s.replace(/\bnew\s+([A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)\s*("C\d+"(?:\s*"C\d+")*)/g, function(all, type, index) {
        var args = index.replace(/"C(\d+)"/g, function(all, j) {
          return atoms[j]
        }).replace(/\[\s*\]/g, "[null]").replace(/\s*\]\s*\[\s*/g, ", ");
        var arrayInitializer = "{" + args.substring(1, args.length - 1) + "}";
        var createArrayArgs = "('" + type + "', " + addAtom(arrayInitializer, "A") + ")";
        return "$p.createJavaArray" + addAtom(createArrayArgs, "B")
      });
      s = s.replace(/(\.\s*length)\s*"B\d+"/g, "$1");
      s = s.replace(/#([0-9A-Fa-f]{6})\b/g, function(all, digits) {
        return "0xFF" + digits
      });
      s = s.replace(/"B(\d+)"(\s*(?:[\w$']|"B))/g, function(all, index, next) {
        var atom = atoms[index];
        if (!/^\(\s*[A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*\s*(?:"C\d+"\s*)*\)$/.test(atom)) return all;
        if (/^\(\s*int\s*\)$/.test(atom)) return "(int)" + next;
        var indexParts = atom.split(/"C(\d+)"/g);
        if (indexParts.length > 1) if (!/^\[\s*\]$/.test(atoms[indexParts[1]])) return all;
        return "" + next
      });
      s = s.replace(/\(int\)([^,\]\)\}\?\:\*\+\-\/\^\|\%\&\~<\>\=]+)/g, function(all, arg) {
        var trimmed = trimSpaces(arg);
        return trimmed.untrim("__int_cast(" + trimmed.middle + ")")
      });
      s = s.replace(/\bsuper(\s*"B\d+")/g, "$$superCstr$1").replace(/\bsuper(\s*\.)/g, "$$super$1");
      s = s.replace(/\b0+((\d*)(?:\.[\d*])?(?:[eE][\-\+]?\d+)?[fF]?)\b/, function(all, numberWo0, intPart) {
        if (numberWo0 === intPart) return all;
        return intPart === "" ? "0" + numberWo0 : numberWo0
      });
      s = s.replace(/\b(\.?\d+\.?)[fF]\b/g, "$1");
      s = s.replace(/([^\s])%([^=\s])/g, "$1 % $2");
      s = s.replace(/\b(frameRate|keyPressed|mousePressed)\b(?!\s*"B)/g, "__$1");
      s = s.replace(/\b(boolean|byte|char|float|int)\s*"B/g, function(all, name) {
        return "parse" + name.substring(0, 1).toUpperCase() + name.substring(1) + '"B'
      });
      s = s.replace(/\bpixels\b\s*(("C(\d+)")|\.length)?(\s*=(?!=)([^,\]\)\}]+))?/g, function(all, indexOrLength, index, atomIndex, equalsPart, rightSide) {
        if (index) {
          var atom = atoms[atomIndex];
          if (equalsPart) return "pixels.setPixel" + addAtom("(" + atom.substring(1, atom.length - 1) + "," + rightSide + ")", "B");
          return "pixels.getPixel" + addAtom("(" + atom.substring(1, atom.length - 1) + ")", "B")
        }
        if (indexOrLength) return "pixels.getLength" + addAtom("()", "B");
        if (equalsPart) return "pixels.set" + addAtom("(" + rightSide + ")", "B");
        return "pixels.toArray" + addAtom("()", "B")
      });
      var repeatJavaReplacement;

      function replacePrototypeMethods(all, subject, method, atomIndex) {
        var atom = atoms[atomIndex];
        repeatJavaReplacement = true;
        var trimmed = trimSpaces(atom.substring(1, atom.length - 1));
        return "__" + method + (trimmed.middle === "" ? addAtom("(" + subject.replace(/\.\s*$/, "") + ")", "B") : addAtom("(" + subject.replace(/\.\s*$/, "") + "," + trimmed.middle + ")", "B"))
      }
      do {
        repeatJavaReplacement = false;
        s = s.replace(/((?:'\d+'|\b[A-Za-z_$][\w$]*\s*(?:"[BC]\d+")*)\s*\.\s*(?:[A-Za-z_$][\w$]*\s*(?:"[BC]\d+"\s*)*\.\s*)*)(replace|replaceAll|replaceFirst|contains|equals|equalsIgnoreCase|hashCode|toCharArray|printStackTrace|split|startsWith|endsWith|codePointAt)\s*"B(\d+)"/g, replacePrototypeMethods)
      } while (repeatJavaReplacement);

      function replaceInstanceof(all, subject, type) {
        repeatJavaReplacement = true;
        return "__instanceof" + addAtom("(" + subject + ", " + type + ")", "B")
      }
      do {
        repeatJavaReplacement = false;
        s = s.replace(/((?:'\d+'|\b[A-Za-z_$][\w$]*\s*(?:"[BC]\d+")*)\s*(?:\.\s*[A-Za-z_$][\w$]*\s*(?:"[BC]\d+"\s*)*)*)instanceof\s+([A-Za-z_$][\w$]*\s*(?:\.\s*[A-Za-z_$][\w$]*)*)/g, replaceInstanceof)
      } while (repeatJavaReplacement);
      s = s.replace(/\bthis(\s*"B\d+")/g, "$$constr$1");
      return s
    }
    function AstInlineClass(baseInterfaceName, body) {
      this.baseInterfaceName = baseInterfaceName;
      this.body = body;
      body.owner = this
    }
    AstInlineClass.prototype.toString = function() {
      return "new (" + this.body + ")"
    };

    function transformInlineClass(class_) {
      var m = (new RegExp(/\bnew\s*([A-Za-z_$][\w$]*\s*(?:\.\s*[A-Za-z_$][\w$]*)*)\s*"B\d+"\s*"A(\d+)"/)).exec(class_);
      var oldClassId = currentClassId,
        newClassId = generateClassId();
      currentClassId = newClassId;
      var uniqueClassName = m[1] + "$" + newClassId;
      var inlineClass = new AstInlineClass(uniqueClassName, transformClassBody(atoms[m[2]], uniqueClassName, "", "implements " + m[1]));
      appendClass(inlineClass, newClassId, oldClassId);
      currentClassId = oldClassId;
      return inlineClass
    }
    function AstFunction(name, params, body) {
      this.name = name;
      this.params = params;
      this.body = body
    }
    AstFunction.prototype.toString = function() {
      var oldContext = replaceContext;
      var names = appendToLookupTable({
        "this": null
      },
      this.params.getNames());
      replaceContext = function(subject) {
        return names.hasOwnProperty(subject.name) ? subject.name : oldContext(subject)
      };
      var result = "function";
      if (this.name) result += " " + this.name;
      result += this.params + " " + this.body;
      replaceContext = oldContext;
      return result
    };

    function transformFunction(class_) {
      var m = (new RegExp(/\b([A-Za-z_$][\w$]*)\s*"B(\d+)"\s*"A(\d+)"/)).exec(class_);
      return new AstFunction(m[1] !== "function" ? m[1] : null, transformParams(atoms[m[2]]), transformStatementsBlock(atoms[m[3]]))
    }
    function AstInlineObject(members) {
      this.members = members
    }
    AstInlineObject.prototype.toString = function() {
      var oldContext = replaceContext;
      replaceContext = function(subject) {
        return subject.name === "this" ? "this" : oldContext(subject)
      };
      var result = "";
      for (var i = 0, l = this.members.length; i < l; ++i) {
        if (this.members[i].label) result += this.members[i].label + ": ";
        result += this.members[i].value.toString() + ", "
      }
      replaceContext = oldContext;
      return result.substring(0, result.length - 2)
    };

    function transformInlineObject(obj) {
      var members = obj.split(",");
      for (var i = 0; i < members.length; ++i) {
        var label = members[i].indexOf(":");
        if (label < 0) members[i] = {
          value: transformExpression(members[i])
        };
        else members[i] = {
          label: trim(members[i].substring(0, label)),
          value: transformExpression(trim(members[i].substring(label + 1)))
        }
      }
      return new AstInlineObject(members)
    }
    function expandExpression(expr) {
      if (expr.charAt(0) === "(" || expr.charAt(0) === "[") return expr.charAt(0) + expandExpression(expr.substring(1, expr.length - 1)) + expr.charAt(expr.length - 1);
      if (expr.charAt(0) === "{") {
        if (/^\{\s*(?:[A-Za-z_$][\w$]*|'\d+')\s*:/.test(expr)) return "{" + addAtom(expr.substring(1, expr.length - 1), "I") + "}";
        return "[" + expandExpression(expr.substring(1, expr.length - 1)) + "]"
      }
      var trimmed = trimSpaces(expr);
      var result = preExpressionTransform(trimmed.middle);
      result = result.replace(/"[ABC](\d+)"/g, function(all, index) {
        return expandExpression(atoms[index])
      });
      return trimmed.untrim(result)
    }
    function replaceContextInVars(expr) {
      return expr.replace(/(\.\s*)?((?:\b[A-Za-z_]|\$)[\w$]*)(\s*\.\s*([A-Za-z_$][\w$]*)(\s*\()?)?/g, function(all, memberAccessSign, identifier, suffix, subMember, callSign) {
        if (memberAccessSign) return all;
        var subject = {
          name: identifier,
          member: subMember,
          callSign: !!callSign
        };
        return replaceContext(subject) + (suffix === undef ? "" : suffix)
      })
    }
    function AstExpression(expr, transforms) {
      this.expr = expr;
      this.transforms = transforms
    }
    AstExpression.prototype.toString = function() {
      var transforms = this.transforms;
      var expr = replaceContextInVars(this.expr);
      return expr.replace(/"!(\d+)"/g, function(all, index) {
        return transforms[index].toString()
      })
    };
    transformExpression = function(expr) {
      var transforms = [];
      var s = expandExpression(expr);
      s = s.replace(/"H(\d+)"/g, function(all, index) {
        transforms.push(transformFunction(atoms[index]));
        return '"!' + (transforms.length - 1) + '"'
      });
      s = s.replace(/"F(\d+)"/g, function(all, index) {
        transforms.push(transformInlineClass(atoms[index]));
        return '"!' + (transforms.length - 1) + '"'
      });
      s = s.replace(/"I(\d+)"/g, function(all, index) {
        transforms.push(transformInlineObject(atoms[index]));
        return '"!' + (transforms.length - 1) + '"'
      });
      return new AstExpression(s, transforms)
    };

    function AstVarDefinition(name, value, isDefault) {
      this.name = name;
      this.value = value;
      this.isDefault = isDefault
    }
    AstVarDefinition.prototype.toString = function() {
      return this.name + " = " + this.value
    };

    function transformVarDefinition(def, defaultTypeValue) {
      var eqIndex = def.indexOf("=");
      var name, value, isDefault;
      if (eqIndex < 0) {
        name = def;
        value = defaultTypeValue;
        isDefault = true
      } else {
        name = def.substring(0, eqIndex);
        value = transformExpression(def.substring(eqIndex + 1));
        isDefault = false
      }
      return new AstVarDefinition(trim(name.replace(/(\s*"C\d+")+/g, "")), value, isDefault)
    }
    function getDefaultValueForType(type) {
      if (type === "int" || type === "float") return "0";
      if (type === "boolean") return "false";
      if (type === "color") return "0x00000000";
      return "null"
    }
    function AstVar(definitions, varType) {
      this.definitions = definitions;
      this.varType = varType
    }
    AstVar.prototype.getNames = function() {
      var names = [];
      for (var i = 0, l = this.definitions.length; i < l; ++i) names.push(this.definitions[i].name);
      return names
    };
    AstVar.prototype.toString = function() {
      return "var " + this.definitions.join(",")
    };

    function AstStatement(expression) {
      this.expression = expression
    }
    AstStatement.prototype.toString = function() {
      return this.expression.toString()
    };

    function transformStatement(statement) {
      if (fieldTest.test(statement)) {
        var attrAndType = attrAndTypeRegex.exec(statement);
        var definitions = statement.substring(attrAndType[0].length).split(",");
        var defaultTypeValue = getDefaultValueForType(attrAndType[2]);
        for (var i = 0; i < definitions.length; ++i) definitions[i] = transformVarDefinition(definitions[i], defaultTypeValue);
        return new AstVar(definitions, attrAndType[2])
      }
      return new AstStatement(transformExpression(statement))
    }
    function AstForExpression(initStatement, condition, step) {
      this.initStatement = initStatement;
      this.condition = condition;
      this.step = step
    }
    AstForExpression.prototype.toString = function() {
      return "(" + this.initStatement + "; " + this.condition + "; " + this.step + ")"
    };

    function AstForInExpression(initStatement, container) {
      this.initStatement = initStatement;
      this.container = container
    }
    AstForInExpression.prototype.toString = function() {
      var init = this.initStatement.toString();
      if (init.indexOf("=") >= 0) init = init.substring(0, init.indexOf("="));
      return "(" + init + " in " + this.container + ")"
    };

    function AstForEachExpression(initStatement, container) {
      this.initStatement = initStatement;
      this.container = container
    }
    AstForEachExpression.iteratorId = 0;
    AstForEachExpression.prototype.toString = function() {
      var init = this.initStatement.toString();
      var iterator = "$it" + AstForEachExpression.iteratorId++;
      var variableName = init.replace(/^\s*var\s*/, "").split("=")[0];
      var initIteratorAndVariable = "var " + iterator + " = new $p.ObjectIterator(" + this.container + "), " + variableName + " = void(0)";
      var nextIterationCondition = iterator + ".hasNext() && ((" + variableName + " = " + iterator + ".next()) || true)";
      return "(" + initIteratorAndVariable + "; " + nextIterationCondition + ";)"
    };

    function transformForExpression(expr) {
      var content;
      if (/\bin\b/.test(expr)) {
        content = expr.substring(1, expr.length - 1).split(/\bin\b/g);
        return new AstForInExpression(transformStatement(trim(content[0])), transformExpression(content[1]))
      }
      if (expr.indexOf(":") >= 0 && expr.indexOf(";") < 0) {
        content = expr.substring(1, expr.length - 1).split(":");
        return new AstForEachExpression(transformStatement(trim(content[0])), transformExpression(content[1]))
      }
      content = expr.substring(1, expr.length - 1).split(";");
      return new AstForExpression(transformStatement(trim(content[0])), transformExpression(content[1]), transformExpression(content[2]))
    }
    function sortByWeight(array) {
      array.sort(function(a, b) {
        return b.weight - a.weight
      })
    }
    function AstInnerInterface(name, body, isStatic) {
      this.name = name;
      this.body = body;
      this.isStatic = isStatic;
      body.owner = this
    }
    AstInnerInterface.prototype.toString = function() {
      return "" + this.body
    };

    function AstInnerClass(name, body, isStatic) {
      this.name = name;
      this.body = body;
      this.isStatic = isStatic;
      body.owner = this
    }
    AstInnerClass.prototype.toString = function() {
      return "" + this.body
    };

    function transformInnerClass(class_) {
      var m = classesRegex.exec(class_);
      classesRegex.lastIndex = 0;
      var isStatic = m[1].indexOf("static") >= 0;
      var body = atoms[getAtomIndex(m[6])],
        innerClass;
      var oldClassId = currentClassId,
        newClassId = generateClassId();
      currentClassId = newClassId;
      if (m[2] === "interface") innerClass = new AstInnerInterface(m[3], transformInterfaceBody(body, m[3], m[4]), isStatic);
      else innerClass = new AstInnerClass(m[3], transformClassBody(body, m[3], m[4], m[5]), isStatic);
      appendClass(innerClass, newClassId, oldClassId);
      currentClassId = oldClassId;
      return innerClass
    }
    function AstClassMethod(name, params, body, isStatic) {
      this.name = name;
      this.params = params;
      this.body = body;
      this.isStatic = isStatic
    }
    AstClassMethod.prototype.toString = function() {
      var paramNames = appendToLookupTable({},
      this.params.getNames());
      var oldContext = replaceContext;
      replaceContext = function(subject) {
        return paramNames.hasOwnProperty(subject.name) ? subject.name : oldContext(subject)
      };
      var result = "function " + this.methodId + this.params + " " + this.body + "\n";
      replaceContext = oldContext;
      return result
    };

    function transformClassMethod(method) {
      var m = methodsRegex.exec(method);
      methodsRegex.lastIndex = 0;
      var isStatic = m[1].indexOf("static") >= 0;
      var body = m[6] !== ";" ? atoms[getAtomIndex(m[6])] : "{}";
      return new AstClassMethod(m[3], transformParams(atoms[getAtomIndex(m[4])]), transformStatementsBlock(body), isStatic)
    }
    function AstClassField(definitions, fieldType, isStatic) {
      this.definitions = definitions;
      this.fieldType = fieldType;
      this.isStatic = isStatic
    }
    AstClassField.prototype.getNames = function() {
      var names = [];
      for (var i = 0, l = this.definitions.length; i < l; ++i) names.push(this.definitions[i].name);
      return names
    };
    AstClassField.prototype.toString = function() {
      var thisPrefix = replaceContext({
        name: "[this]"
      });
      if (this.isStatic) {
        var className = this.owner.name;
        var staticDeclarations = [];
        for (var i = 0, l = this.definitions.length; i < l; ++i) {
          var definition = this.definitions[i];
          var name = definition.name,
            staticName = className + "." + name;
          var declaration = "if(" + staticName + " === void(0)) {\n" + " " + staticName + " = " + definition.value + "; }\n" + "$p.defineProperty(" + thisPrefix + ", " + "'" + name + "', { get: function(){return " + staticName + ";}, " + "set: function(val){" + staticName + " = val;} });\n";
          staticDeclarations.push(declaration)
        }
        return staticDeclarations.join("")
      }
      return thisPrefix + "." + this.definitions.join("; " + thisPrefix + ".")
    };

    function transformClassField(statement) {
      var attrAndType = attrAndTypeRegex.exec(statement);
      var isStatic = attrAndType[1].indexOf("static") >= 0;
      var definitions = statement.substring(attrAndType[0].length).split(/,\s*/g);
      var defaultTypeValue = getDefaultValueForType(attrAndType[2]);
      for (var i = 0; i < definitions.length; ++i) definitions[i] = transformVarDefinition(definitions[i], defaultTypeValue);
      return new AstClassField(definitions, attrAndType[2], isStatic)
    }
    function AstConstructor(params, body) {
      this.params = params;
      this.body = body
    }
    AstConstructor.prototype.toString = function() {
      var paramNames = appendToLookupTable({},
      this.params.getNames());
      var oldContext = replaceContext;
      replaceContext = function(subject) {
        return paramNames.hasOwnProperty(subject.name) ? subject.name : oldContext(subject)
      };
      var prefix = "function $constr_" + this.params.params.length + this.params.toString();
      var body = this.body.toString();
      if (!/\$(superCstr|constr)\b/.test(body)) body = "{\n$superCstr();\n" + body.substring(1);
      replaceContext = oldContext;
      return prefix + body + "\n"
    };

    function transformConstructor(cstr) {
      var m = (new RegExp(/"B(\d+)"\s*"A(\d+)"/)).exec(cstr);
      var params = transformParams(atoms[m[1]]);
      return new AstConstructor(params, transformStatementsBlock(atoms[m[2]]))
    }
    function AstInterfaceBody(name, interfacesNames, methodsNames, fields, innerClasses, misc) {
      var i, l;
      this.name = name;
      this.interfacesNames = interfacesNames;
      this.methodsNames = methodsNames;
      this.fields = fields;
      this.innerClasses = innerClasses;
      this.misc = misc;
      for (i = 0, l = fields.length; i < l; ++i) fields[i].owner = this
    }
    AstInterfaceBody.prototype.getMembers = function(classFields, classMethods, classInners) {
      if (this.owner.base) this.owner.base.body.getMembers(classFields, classMethods, classInners);
      var i, j, l, m;
      for (i = 0, l = this.fields.length; i < l; ++i) {
        var fieldNames = this.fields[i].getNames();
        for (j = 0, m = fieldNames.length; j < m; ++j) classFields[fieldNames[j]] = this.fields[i]
      }
      for (i = 0, l = this.methodsNames.length; i < l; ++i) {
        var methodName = this.methodsNames[i];
        classMethods[methodName] = true
      }
      for (i = 0, l = this.innerClasses.length; i < l; ++i) {
        var innerClass = this.innerClasses[i];
        classInners[innerClass.name] = innerClass
      }
    };
    AstInterfaceBody.prototype.toString = function() {
      function getScopeLevel(p) {
        var i = 0;
        while (p) {
          ++i;
          p = p.scope
        }
        return i
      }
      var scopeLevel = getScopeLevel(this.owner);
      var className = this.name;
      var staticDefinitions = "";
      var metadata = "";
      var thisClassFields = {},
        thisClassMethods = {},
        thisClassInners = {};
      this.getMembers(thisClassFields, thisClassMethods, thisClassInners);
      var i, l, j, m;
      if (this.owner.interfaces) {
        var resolvedInterfaces = [],
          resolvedInterface;
        for (i = 0, l = this.interfacesNames.length; i < l; ++i) {
          if (!this.owner.interfaces[i]) continue;
          resolvedInterface = replaceContext({
            name: this.interfacesNames[i]
          });
          resolvedInterfaces.push(resolvedInterface);
          staticDefinitions += "$p.extendInterfaceMembers(" + className + ", " + resolvedInterface + ");\n"
        }
        metadata += className + ".$interfaces = [" + resolvedInterfaces.join(", ") + "];\n"
      }
      metadata += className + ".$isInterface = true;\n";
      metadata += className + ".$methods = ['" + this.methodsNames.join("', '") + "'];\n";
      sortByWeight(this.innerClasses);
      for (i = 0, l = this.innerClasses.length; i < l; ++i) {
        var innerClass = this.innerClasses[i];
        if (innerClass.isStatic) staticDefinitions += className + "." + innerClass.name + " = " + innerClass + ";\n"
      }
      for (i = 0, l = this.fields.length; i < l; ++i) {
        var field = this.fields[i];
        if (field.isStatic) staticDefinitions += className + "." + field.definitions.join(";\n" + className + ".") + ";\n"
      }
      return "(function() {\n" + "function " + className + "() { throw 'Unable to create the interface'; }\n" + staticDefinitions + metadata + "return " + className + ";\n" + "})()"
    };
    transformInterfaceBody = function(body, name, baseInterfaces) {
      var declarations = body.substring(1, body.length - 1);
      declarations = extractClassesAndMethods(declarations);
      declarations = extractConstructors(declarations, name);
      var methodsNames = [],
        classes = [];
      declarations = declarations.replace(/"([DE])(\d+)"/g, function(all, type, index) {
        if (type === "D") methodsNames.push(index);
        else if (type === "E") classes.push(index);
        return ""
      });
      var fields = declarations.split(/;(?:\s*;)*/g);
      var baseInterfaceNames;
      var i, l;
      if (baseInterfaces !== undef) baseInterfaceNames = baseInterfaces.replace(/^\s*extends\s+(.+?)\s*$/g, "$1").split(/\s*,\s*/g);
      for (i = 0, l = methodsNames.length; i < l; ++i) {
        var method = transformClassMethod(atoms[methodsNames[i]]);
        methodsNames[i] = method.name
      }
      for (i = 0, l = fields.length - 1; i < l; ++i) {
        var field = trimSpaces(fields[i]);
        fields[i] = transformClassField(field.middle)
      }
      var tail = fields.pop();
      for (i = 0, l = classes.length; i < l; ++i) classes[i] = transformInnerClass(atoms[classes[i]]);
      return new AstInterfaceBody(name, baseInterfaceNames, methodsNames, fields, classes, {
        tail: tail
      })
    };

    function AstClassBody(name, baseClassName, interfacesNames, functions, methods, fields, cstrs, innerClasses, misc) {
      var i, l;
      this.name = name;
      this.baseClassName = baseClassName;
      this.interfacesNames = interfacesNames;
      this.functions = functions;
      this.methods = methods;
      this.fields = fields;
      this.cstrs = cstrs;
      this.innerClasses = innerClasses;
      this.misc = misc;
      for (i = 0, l = fields.length; i < l; ++i) fields[i].owner = this
    }
    AstClassBody.prototype.getMembers = function(classFields, classMethods, classInners) {
      if (this.owner.base) this.owner.base.body.getMembers(classFields, classMethods, classInners);
      var i, j, l, m;
      for (i = 0, l = this.fields.length; i < l; ++i) {
        var fieldNames = this.fields[i].getNames();
        for (j = 0, m = fieldNames.length; j < m; ++j) classFields[fieldNames[j]] = this.fields[i]
      }
      for (i = 0, l = this.methods.length; i < l; ++i) {
        var method = this.methods[i];
        classMethods[method.name] = method
      }
      for (i = 0, l = this.innerClasses.length; i < l; ++i) {
        var innerClass = this.innerClasses[i];
        classInners[innerClass.name] = innerClass
      }
    };
    AstClassBody.prototype.toString = function() {
      function getScopeLevel(p) {
        var i = 0;
        while (p) {
          ++i;
          p = p.scope
        }
        return i
      }
      var scopeLevel = getScopeLevel(this.owner);
      var selfId = "$this_" + scopeLevel;
      var className = this.name;
      var result = "var " + selfId + " = this;\n";
      var staticDefinitions = "";
      var metadata = "";
      var thisClassFields = {},
        thisClassMethods = {},
        thisClassInners = {};
      this.getMembers(thisClassFields, thisClassMethods, thisClassInners);
      var oldContext = replaceContext;
      replaceContext = function(subject) {
        var name = subject.name;
        if (name === "this") return subject.callSign || !subject.member ? selfId + ".$self" : selfId;
        if (thisClassFields.hasOwnProperty(name)) return thisClassFields[name].isStatic ? className + "." + name : selfId + "." + name;
        if (thisClassInners.hasOwnProperty(name)) return selfId + "." + name;
        if (thisClassMethods.hasOwnProperty(name)) return thisClassMethods[name].isStatic ? className + "." + name : selfId + ".$self." + name;
        return oldContext(subject)
      };
      var resolvedBaseClassName;
      if (this.baseClassName) {
        resolvedBaseClassName = oldContext({
          name: this.baseClassName
        });
        result += "var $super = { $upcast: " + selfId + " };\n";
        result += "function $superCstr(){" + resolvedBaseClassName + ".apply($super,arguments);if(!('$self' in $super)) $p.extendClassChain($super)}\n";
        metadata += className + ".$base = " + resolvedBaseClassName + ";\n"
      } else result += "function $superCstr(){$p.extendClassChain(" + selfId + ")}\n";
      if (this.owner.base) staticDefinitions += "$p.extendStaticMembers(" + className + ", " + resolvedBaseClassName + ");\n";
      var i, l, j, m;
      if (this.owner.interfaces) {
        var resolvedInterfaces = [],
          resolvedInterface;
        for (i = 0, l = this.interfacesNames.length; i < l; ++i) {
          if (!this.owner.interfaces[i]) continue;
          resolvedInterface = oldContext({
            name: this.interfacesNames[i]
          });
          resolvedInterfaces.push(resolvedInterface);
          staticDefinitions += "$p.extendInterfaceMembers(" + className + ", " + resolvedInterface + ");\n"
        }
        metadata += className + ".$interfaces = [" + resolvedInterfaces.join(", ") + "];\n"
      }
      if (this.functions.length > 0) result += this.functions.join("\n") + "\n";
      sortByWeight(this.innerClasses);
      for (i = 0, l = this.innerClasses.length; i < l; ++i) {
        var innerClass = this.innerClasses[i];
        if (innerClass.isStatic) {
          staticDefinitions += className + "." + innerClass.name + " = " + innerClass + ";\n";
          result += selfId + "." + innerClass.name + " = " + className + "." + innerClass.name + ";\n"
        } else result += selfId + "." + innerClass.name + " = " + innerClass + ";\n"
      }
      for (i = 0, l = this.fields.length; i < l; ++i) {
        var field = this.fields[i];
        if (field.isStatic) {
          staticDefinitions += className + "." + field.definitions.join(";\n" + className + ".") + ";\n";
          for (j = 0, m = field.definitions.length; j < m; ++j) {
            var fieldName = field.definitions[j].name,
              staticName = className + "." + fieldName;
            result += "$p.defineProperty(" + selfId + ", '" + fieldName + "', {" + "get: function(){return " + staticName + "}, " + "set: function(val){" + staticName + " = val}});\n"
          }
        } else result += selfId + "." + field.definitions.join(";\n" + selfId + ".") + ";\n"
      }
      var methodOverloads = {};
      for (i = 0, l = this.methods.length; i < l; ++i) {
        var method = this.methods[i];
        var overload = methodOverloads[method.name];
        var methodId = method.name + "$" + method.params.params.length;
        if (overload) {
          ++overload;
          methodId += "_" + overload
        } else overload = 1;
        method.methodId = methodId;
        methodOverloads[method.name] = overload;
        if (method.isStatic) {
          staticDefinitions += method;
          staticDefinitions += "$p.addMethod(" + className + ", '" + method.name + "', " + methodId + ");\n";
          result += "$p.addMethod(" + selfId + ", '" + method.name + "', " + methodId + ");\n"
        } else {
          result += method;
          result += "$p.addMethod(" + selfId + ", '" + method.name + "', " + methodId + ");\n"
        }
      }
      result += trim(this.misc.tail);
      if (this.cstrs.length > 0) result += this.cstrs.join("\n") + "\n";
      result += "function $constr() {\n";
      var cstrsIfs = [];
      for (i = 0, l = this.cstrs.length; i < l; ++i) {
        var paramsLength = this.cstrs[i].params.params.length;
        cstrsIfs.push("if(arguments.length === " + paramsLength + ") { " + "$constr_" + paramsLength + ".apply(" + selfId + ", arguments); }")
      }
      if (cstrsIfs.length > 0) result += cstrsIfs.join(" else ") + " else ";
      result += "$superCstr();\n}\n";
      result += "$constr.apply(null, arguments);\n";
      replaceContext = oldContext;
      return "(function() {\n" + "function " + className + "() {\n" + result + "}\n" + staticDefinitions + metadata + "return " + className + ";\n" + "})()"
    };
    transformClassBody = function(body, name, baseName, interfaces) {
      var declarations = body.substring(1, body.length - 1);
      declarations = extractClassesAndMethods(declarations);
      declarations = extractConstructors(declarations, name);
      var methods = [],
        classes = [],
        cstrs = [],
        functions = [];
      declarations = declarations.replace(/"([DEGH])(\d+)"/g, function(all, type, index) {
        if (type === "D") methods.push(index);
        else if (type === "E") classes.push(index);
        else if (type === "H") functions.push(index);
        else cstrs.push(index);
        return ""
      });
      var fields = declarations.replace(/^(?:\s*;)+/, "").split(/;(?:\s*;)*/g);
      var baseClassName, interfacesNames;
      var i;
      if (baseName !== undef) baseClassName = baseName.replace(/^\s*extends\s+([A-Za-z_$][\w$]*\b(?:\s*\.\s*[A-Za-z_$][\w$]*\b)*)\s*$/g, "$1");
      if (interfaces !== undef) interfacesNames = interfaces.replace(/^\s*implements\s+(.+?)\s*$/g, "$1").split(/\s*,\s*/g);
      for (i = 0; i < functions.length; ++i) functions[i] = transformFunction(atoms[functions[i]]);
      for (i = 0; i < methods.length; ++i) methods[i] = transformClassMethod(atoms[methods[i]]);
      for (i = 0; i < fields.length - 1; ++i) {
        var field = trimSpaces(fields[i]);
        fields[i] = transformClassField(field.middle)
      }
      var tail = fields.pop();
      for (i = 0; i < cstrs.length; ++i) cstrs[i] = transformConstructor(atoms[cstrs[i]]);
      for (i = 0; i < classes.length; ++i) classes[i] = transformInnerClass(atoms[classes[i]]);
      return new AstClassBody(name, baseClassName, interfacesNames, functions, methods, fields, cstrs, classes, {
        tail: tail
      })
    };

    function AstInterface(name, body) {
      this.name = name;
      this.body = body;
      body.owner = this
    }
    AstInterface.prototype.toString = function() {
      return "var " + this.name + " = " + this.body + ";\n" + "$p." + this.name + " = " + this.name + ";\n"
    };

    function AstClass(name, body) {
      this.name = name;
      this.body = body;
      body.owner = this
    }
    AstClass.prototype.toString = function() {
      return "var " + this.name + " = " + this.body + ";\n" + "$p." + this.name + " = " + this.name + ";\n"
    };

    function transformGlobalClass(class_) {
      var m = classesRegex.exec(class_);
      classesRegex.lastIndex = 0;
      var body = atoms[getAtomIndex(m[6])];
      var oldClassId = currentClassId,
        newClassId = generateClassId();
      currentClassId = newClassId;
      var globalClass;
      if (m[2] === "interface") globalClass = new AstInterface(m[3], transformInterfaceBody(body, m[3], m[4]));
      else globalClass = new AstClass(m[3], transformClassBody(body, m[3], m[4], m[5]));
      appendClass(globalClass, newClassId, oldClassId);
      currentClassId = oldClassId;
      return globalClass
    }
    function AstMethod(name, params, body) {
      this.name = name;
      this.params = params;
      this.body = body
    }
    AstMethod.prototype.toString = function() {
      var paramNames = appendToLookupTable({},
      this.params.getNames());
      var oldContext = replaceContext;
      replaceContext = function(subject) {
        return paramNames.hasOwnProperty(subject.name) ? subject.name : oldContext(subject)
      };
      var result = "function " + this.name + this.params + " " + this.body + "\n" + "$p." + this.name + " = " + this.name + ";";
      replaceContext = oldContext;
      return result
    };

    function transformGlobalMethod(method) {
      var m = methodsRegex.exec(method);
      var result = methodsRegex.lastIndex = 0;
      return new AstMethod(m[3], transformParams(atoms[getAtomIndex(m[4])]), transformStatementsBlock(atoms[getAtomIndex(m[6])]))
    }
    function preStatementsTransform(statements) {
      var s = statements;
      s = s.replace(/\b(catch\s*"B\d+"\s*"A\d+")(\s*catch\s*"B\d+"\s*"A\d+")+/g, "$1");
      return s
    }
    function AstForStatement(argument, misc) {
      this.argument = argument;
      this.misc = misc
    }
    AstForStatement.prototype.toString = function() {
      return this.misc.prefix + this.argument.toString()
    };

    function AstCatchStatement(argument, misc) {
      this.argument = argument;
      this.misc = misc
    }
    AstCatchStatement.prototype.toString = function() {
      return this.misc.prefix + this.argument.toString()
    };

    function AstPrefixStatement(name, argument, misc) {
      this.name = name;
      this.argument = argument;
      this.misc = misc
    }
    AstPrefixStatement.prototype.toString = function() {
      var result = this.misc.prefix;
      if (this.argument !== undef) result += this.argument.toString();
      return result
    };

    function AstSwitchCase(expr) {
      this.expr = expr
    }
    AstSwitchCase.prototype.toString = function() {
      return "case " + this.expr + ":"
    };

    function AstLabel(label) {
      this.label = label
    }
    AstLabel.prototype.toString = function() {
      return this.label
    };
    transformStatements = function(statements, transformMethod, transformClass) {
      var nextStatement = new RegExp(/\b(catch|for|if|switch|while|with)\s*"B(\d+)"|\b(do|else|finally|return|throw|try|break|continue)\b|("[ADEH](\d+)")|\b(case)\s+([^:]+):|\b([A-Za-z_$][\w$]*\s*:)|(;)/g);
      var res = [];
      statements = preStatementsTransform(statements);
      var lastIndex = 0,
        m, space;
      while ((m = nextStatement.exec(statements)) !== null) {
        if (m[1] !== undef) {
          var i = statements.lastIndexOf('"B', nextStatement.lastIndex);
          var statementsPrefix = statements.substring(lastIndex, i);
          if (m[1] === "for") res.push(new AstForStatement(transformForExpression(atoms[m[2]]), {
            prefix: statementsPrefix
          }));
          else if (m[1] === "catch") res.push(new AstCatchStatement(transformParams(atoms[m[2]]), {
            prefix: statementsPrefix
          }));
          else res.push(new AstPrefixStatement(m[1], transformExpression(atoms[m[2]]), {
            prefix: statementsPrefix
          }))
        } else if (m[3] !== undef) res.push(new AstPrefixStatement(m[3], undef, {
          prefix: statements.substring(lastIndex, nextStatement.lastIndex)
        }));
        else if (m[4] !== undef) {
          space = statements.substring(lastIndex, nextStatement.lastIndex - m[4].length);
          if (trim(space).length !== 0) continue;
          res.push(space);
          var kind = m[4].charAt(1),
            atomIndex = m[5];
          if (kind === "D") res.push(transformMethod(atoms[atomIndex]));
          else if (kind === "E") res.push(transformClass(atoms[atomIndex]));
          else if (kind === "H") res.push(transformFunction(atoms[atomIndex]));
          else res.push(transformStatementsBlock(atoms[atomIndex]))
        } else if (m[6] !== undef) res.push(new AstSwitchCase(transformExpression(trim(m[7]))));
        else if (m[8] !== undef) {
          space = statements.substring(lastIndex, nextStatement.lastIndex - m[8].length);
          if (trim(space).length !== 0) continue;
          res.push(new AstLabel(statements.substring(lastIndex, nextStatement.lastIndex)))
        } else {
          var statement = trimSpaces(statements.substring(lastIndex, nextStatement.lastIndex - 1));
          res.push(statement.left);
          res.push(transformStatement(statement.middle));
          res.push(statement.right + ";")
        }
        lastIndex = nextStatement.lastIndex
      }
      var statementsTail = trimSpaces(statements.substring(lastIndex));
      res.push(statementsTail.left);
      if (statementsTail.middle !== "") {
        res.push(transformStatement(statementsTail.middle));
        res.push(";" + statementsTail.right)
      }
      return res
    };

    function getLocalNames(statements) {
      var localNames = [];
      for (var i = 0, l = statements.length; i < l; ++i) {
        var statement = statements[i];
        if (statement instanceof AstVar) localNames = localNames.concat(statement.getNames());
        else if (statement instanceof AstForStatement && statement.argument.initStatement instanceof AstVar) localNames = localNames.concat(statement.argument.initStatement.getNames());
        else if (statement instanceof AstInnerInterface || statement instanceof AstInnerClass || statement instanceof AstInterface || statement instanceof AstClass || statement instanceof AstMethod || statement instanceof AstFunction) localNames.push(statement.name)
      }
      return appendToLookupTable({},
      localNames)
    }
    function AstStatementsBlock(statements) {
      this.statements = statements
    }
    AstStatementsBlock.prototype.toString = function() {
      var localNames = getLocalNames(this.statements);
      var oldContext = replaceContext;
      if (!isLookupTableEmpty(localNames)) replaceContext = function(subject) {
        return localNames.hasOwnProperty(subject.name) ? subject.name : oldContext(subject)
      };
      var result = "{\n" + this.statements.join("") + "\n}";
      replaceContext = oldContext;
      return result
    };
    transformStatementsBlock = function(block) {
      var content = trimSpaces(block.substring(1, block.length - 1));
      return new AstStatementsBlock(transformStatements(content.middle))
    };

    function AstRoot(statements) {
      this.statements = statements
    }
    AstRoot.prototype.toString = function() {
      var classes = [],
        otherStatements = [],
        statement;
      for (var i = 0, len = this.statements.length; i < len; ++i) {
        statement = this.statements[i];
        if (statement instanceof AstClass || statement instanceof AstInterface) classes.push(statement);
        else otherStatements.push(statement)
      }
      sortByWeight(classes);
      var localNames = getLocalNames(this.statements);
      replaceContext = function(subject) {
        var name = subject.name;
        if (localNames.hasOwnProperty(name)) return name;
        if (globalMembers.hasOwnProperty(name) || PConstants.hasOwnProperty(name) || defaultScope.hasOwnProperty(name)) return "$p." + name;
        return name
      };
      var result = "// this code was autogenerated from PJS\n" + "(function($p) {\n" + classes.join("") + "\n" + otherStatements.join("") + "\n})";
      replaceContext = null;
      return result
    };
    transformMain = function() {
      var statements = extractClassesAndMethods(atoms[0]);
      statements = statements.replace(/\bimport\s+[^;]+;/g, "");
      return new AstRoot(transformStatements(statements, transformGlobalMethod, transformGlobalClass))
    };

    function generateMetadata(ast) {
      var globalScope = {};
      var id, class_;
      for (id in declaredClasses) if (declaredClasses.hasOwnProperty(id)) {
        class_ = declaredClasses[id];
        var scopeId = class_.scopeId,
          name = class_.name;
        if (scopeId) {
          var scope = declaredClasses[scopeId];
          class_.scope = scope;
          if (scope.inScope === undef) scope.inScope = {};
          scope.inScope[name] = class_
        } else globalScope[name] = class_
      }
      function findInScopes(class_, name) {
        var parts = name.split(".");
        var currentScope = class_.scope,
          found;
        while (currentScope) {
          if (currentScope.hasOwnProperty(parts[0])) {
            found = currentScope[parts[0]];
            break
          }
          currentScope = currentScope.scope
        }
        if (found === undef) found = globalScope[parts[0]];
        for (var i = 1, l = parts.length; i < l && found; ++i) found = found.inScope[parts[i]];
        return found
      }
      for (id in declaredClasses) if (declaredClasses.hasOwnProperty(id)) {
        class_ = declaredClasses[id];
        var baseClassName = class_.body.baseClassName;
        if (baseClassName) {
          var parent = findInScopes(class_, baseClassName);
          if (parent) {
            class_.base = parent;
            if (!parent.derived) parent.derived = [];
            parent.derived.push(class_)
          }
        }
        var interfacesNames = class_.body.interfacesNames,
          interfaces = [],
          i, l;
        if (interfacesNames && interfacesNames.length > 0) {
          for (i = 0, l = interfacesNames.length; i < l; ++i) {
            var interface_ = findInScopes(class_, interfacesNames[i]);
            interfaces.push(interface_);
            if (!interface_) continue;
            if (!interface_.derived) interface_.derived = [];
            interface_.derived.push(class_)
          }
          if (interfaces.length > 0) class_.interfaces = interfaces
        }
      }
    }
    function setWeight(ast) {
      var queue = [],
        tocheck = {};
      var id, scopeId, class_;
      for (id in declaredClasses) if (declaredClasses.hasOwnProperty(id)) {
        class_ = declaredClasses[id];
        if (!class_.inScope && !class_.derived) {
          queue.push(id);
          class_.weight = 0
        } else {
          var dependsOn = [];
          if (class_.inScope) for (scopeId in class_.inScope) if (class_.inScope.hasOwnProperty(scopeId)) dependsOn.push(class_.inScope[scopeId]);
          if (class_.derived) dependsOn = dependsOn.concat(class_.derived);
          tocheck[id] = dependsOn
        }
      }
      function removeDependentAndCheck(targetId, from) {
        var dependsOn = tocheck[targetId];
        if (!dependsOn) return false;
        var i = dependsOn.indexOf(from);
        if (i < 0) return false;
        dependsOn.splice(i, 1);
        if (dependsOn.length > 0) return false;
        delete tocheck[targetId];
        return true
      }
      while (queue.length > 0) {
        id = queue.shift();
        class_ = declaredClasses[id];
        if (class_.scopeId && removeDependentAndCheck(class_.scopeId, class_)) {
          queue.push(class_.scopeId);
          declaredClasses[class_.scopeId].weight = class_.weight + 1
        }
        if (class_.base && removeDependentAndCheck(class_.base.classId, class_)) {
          queue.push(class_.base.classId);
          class_.base.weight = class_.weight + 1
        }
        if (class_.interfaces) {
          var i, l;
          for (i = 0, l = class_.interfaces.length; i < l; ++i) {
            if (!class_.interfaces[i] || !removeDependentAndCheck(class_.interfaces[i].classId, class_)) continue;
            queue.push(class_.interfaces[i].classId);
            class_.interfaces[i].weight = class_.weight + 1
          }
        }
      }
    }
    var transformed = transformMain();
    generateMetadata(transformed);
    setWeight(transformed);
    var redendered = transformed.toString();
    redendered = redendered.replace(/\s*\n(?:[\t ]*\n)+/g, "\n\n");
    return injectStrings(redendered, strings)
  }
  function preprocessCode(aCode, sketch) {
    var dm = (new RegExp(/\/\*\s*@pjs\s+((?:[^\*]|\*+[^\*\/])*)\*\//g)).exec(aCode);
    if (dm && dm.length === 2) {
      var jsonItems = [],
        directives = dm.splice(1, 2)[0].replace(/\{([\s\S]*?)\}/g, function() {
        return function(all, item) {
          jsonItems.push(item);
          return "{" + (jsonItems.length - 1) + "}"
        }
      }()).replace("\n", "").replace("\r", "").split(";");
      var clean = function(s) {
        return s.replace(/^\s*["']?/, "").replace(/["']?\s*$/, "")
      };
      for (var i = 0, dl = directives.length; i < dl; i++) {
        var pair = directives[i].split("=");
        if (pair && pair.length === 2) {
          var key = clean(pair[0]),
            value = clean(pair[1]),
            list = [];
          if (key === "preload") {
            list = value.split(",");
            for (var j = 0, jl = list.length; j < jl; j++) {
              var imageName = clean(list[j]);
              sketch.imageCache.add(imageName)
            }
          } else if (key === "font") {
            list = value.split(",");
            for (var x = 0, xl = list.length; x < xl; x++) {
              var fontName = clean(list[x]),
                index = /^\{(\d*?)\}$/.exec(fontName);
              PFont.preloading.add(index ? JSON.parse("{" + jsonItems[index[1]] + "}") : fontName)
            }
          } else if (key === "pauseOnBlur") sketch.options.pauseOnBlur = value === "true";
          else if (key === "globalKeyEvents") sketch.options.globalKeyEvents = value === "true";
          else if (key.substring(0, 6) === "param-") sketch.params[key.substring(6)] = value;
          else sketch.options[key] = value
        }
      }
    }
    return aCode
  }
  Processing.compile = function(pdeCode) {
    var sketch = new Processing.Sketch;
    var code = preprocessCode(pdeCode, sketch);
    var compiledPde = parseProcessing(code);
    sketch.sourceCode = compiledPde;
    return sketch
  };
  var tinylogLite = function() {
    var tinylogLite = {},
      undef = "undefined",
      func = "function",
      False = !1,
      True = !0,
      logLimit = 512,
      log = "log";
    if (typeof tinylog !== undef && typeof tinylog[log] === func) tinylogLite[log] = tinylog[log];
    else if (typeof document !== undef && !document.fake)(function() {
      var doc = document,
        $div = "div",
        $style = "style",
        $title = "title",
        containerStyles = {
        zIndex: 1E4,
        position: "fixed",
        bottom: "0px",
        width: "100%",
        height: "15%",
        fontFamily: "sans-serif",
        color: "#ccc",
        backgroundColor: "black"
      },
        outputStyles = {
        position: "relative",
        fontFamily: "monospace",
        overflow: "auto",
        height: "100%",
        paddingTop: "5px"
      },
        resizerStyles = {
        height: "5px",
        marginTop: "-5px",
        cursor: "n-resize",
        backgroundColor: "darkgrey"
      },
        closeButtonStyles = {
        position: "absolute",
        top: "5px",
        right: "20px",
        color: "#111",
        MozBorderRadius: "4px",
        webkitBorderRadius: "4px",
        borderRadius: "4px",
        cursor: "pointer",
        fontWeight: "normal",
        textAlign: "center",
        padding: "3px 5px",
        backgroundColor: "#333",
        fontSize: "12px"
      },
        entryStyles = {
        minHeight: "16px"
      },
        entryTextStyles = {
        fontSize: "12px",
        margin: "0 8px 0 8px",
        maxWidth: "100%",
        whiteSpace: "pre-wrap",
        overflow: "auto"
      },
        view = doc.defaultView,
        docElem = doc.documentElement,
        docElemStyle = docElem[$style],
        setStyles = function() {
        var i = arguments.length,
          elemStyle, styles, style;
        while (i--) {
          styles = arguments[i--];
          elemStyle = arguments[i][$style];
          for (style in styles) if (styles.hasOwnProperty(style)) elemStyle[style] = styles[style]
        }
      },
        observer = function(obj, event, handler) {
        if (obj.addEventListener) obj.addEventListener(event, handler, False);
        else if (obj.attachEvent) obj.attachEvent("on" + event, handler);
        return [obj, event, handler]
      },
        unobserve = function(obj, event, handler) {
        if (obj.removeEventListener) obj.removeEventListener(event, handler, False);
        else if (obj.detachEvent) obj.detachEvent("on" + event, handler)
      },
        clearChildren = function(node) {
        var children = node.childNodes,
          child = children.length;
        while (child--) node.removeChild(children.item(0))
      },
        append = function(to, elem) {
        return to.appendChild(elem)
      },
        createElement = function(localName) {
        return doc.createElement(localName)
      },
        createTextNode = function(text) {
        return doc.createTextNode(text)
      },
        createLog = tinylogLite[log] = function(message) {
        var uninit, originalPadding = docElemStyle.paddingBottom,
          container = createElement($div),
          containerStyle = container[$style],
          resizer = append(container, createElement($div)),
          output = append(container, createElement($div)),
          closeButton = append(container, createElement($div)),
          resizingLog = False,
          previousHeight = False,
          previousScrollTop = False,
          messages = 0,
          updateSafetyMargin = function() {
          docElemStyle.paddingBottom = container.clientHeight + "px"
        },
          setContainerHeight = function(height) {
          var viewHeight = view.innerHeight,
            resizerHeight = resizer.clientHeight;
          if (height < 0) height = 0;
          else if (height + resizerHeight > viewHeight) height = viewHeight - resizerHeight;
          containerStyle.height = height / viewHeight * 100 + "%";
          updateSafetyMargin()
        },
          observers = [observer(doc, "mousemove", function(evt) {
          if (resizingLog) {
            setContainerHeight(view.innerHeight - evt.clientY);
            output.scrollTop = previousScrollTop
          }
        }), observer(doc, "mouseup", function() {
          if (resizingLog) resizingLog = previousScrollTop = False
        }), observer(resizer, "dblclick", function(evt) {
          evt.preventDefault();
          if (previousHeight) {
            setContainerHeight(previousHeight);
            previousHeight = False
          } else {
            previousHeight = container.clientHeight;
            containerStyle.height = "0px"
          }
        }), observer(resizer, "mousedown", function(evt) {
          evt.preventDefault();
          resizingLog = True;
          previousScrollTop = output.scrollTop
        }), observer(resizer, "contextmenu", function() {
          resizingLog = False
        }), observer(closeButton, "click", function() {
          uninit()
        })];
        uninit = function() {
          var i = observers.length;
          while (i--) unobserve.apply(tinylogLite, observers[i]);
          docElem.removeChild(container);
          docElemStyle.paddingBottom = originalPadding;
          clearChildren(output);
          clearChildren(container);
          tinylogLite[log] = createLog
        };
        setStyles(container, containerStyles, output, outputStyles, resizer, resizerStyles, closeButton, closeButtonStyles);
        closeButton[$title] = "Close Log";
        append(closeButton, createTextNode("\u2716"));
        resizer[$title] = "Double-click to toggle log minimization";
        docElem.insertBefore(container, docElem.firstChild);
        tinylogLite[log] = function(message) {
          if (messages === logLimit) output.removeChild(output.firstChild);
          else messages++;
          var entry = append(output, createElement($div)),
            entryText = append(entry, createElement($div));
          entry[$title] = (new Date).toLocaleTimeString();
          setStyles(entry, entryStyles, entryText, entryTextStyles);
          append(entryText, createTextNode(message));
          output.scrollTop = output.scrollHeight
        };
        tinylogLite[log](message);
        updateSafetyMargin()
      }
    })();
    else if (typeof print === func) tinylogLite[log] = print;
    return tinylogLite
  }();
  Processing.logger = tinylogLite;
  Processing.version = "1.3.6";
  Processing.lib = {};
  Processing.registerLibrary = function(name, desc) {
    Processing.lib[name] = desc;
    if (desc.hasOwnProperty("init")) desc.init(defaultScope)
  };
  Processing.instances = processingInstances;
  Processing.getInstanceById = function(name) {
    return processingInstances[processingInstanceIds[name]]
  };
  Processing.Sketch = function(attachFunction) {
    this.attachFunction = attachFunction;
    this.options = {
      pauseOnBlur: false,
      globalKeyEvents: false
    };
    this.onLoad = nop;
    this.onSetup = nop;
    this.onPause = nop;
    this.onLoop = nop;
    this.onFrameStart = nop;
    this.onFrameEnd = nop;
    this.onExit = nop;
    this.params = {};
    this.imageCache = {
      pending: 0,
      images: {},
      operaCache: {},
      add: function(href, img) {
        if (this.images[href]) return;
        if (!isDOMPresent) this.images[href] = null;
        if (!img) {
          img = new Image;
          img.onload = function(owner) {
            return function() {
              owner.pending--
            }
          }(this);
          this.pending++;
          img.src = href
        }
        this.images[href] = img;
        if (window.opera) {
          var div = document.createElement("div");
          div.appendChild(img);
          div.style.position = "absolute";
          div.style.opacity = 0;
          div.style.width = "1px";
          div.style.height = "1px";
          if (!this.operaCache[href]) {
            document.body.appendChild(div);
            this.operaCache[href] = div
          }
        }
      }
    };
    this.sourceCode = undefined;
    this.attach = function(processing) {
      if (typeof this.attachFunction === "function") this.attachFunction(processing);
      else if (this.sourceCode) {
        var func = (new Function("return (" + this.sourceCode + ");"))();
        func(processing);
        this.attachFunction = func
      } else throw "Unable to attach sketch to the processing instance";
    };
    this.toString = function() {
      var i;
      var code = "((function(Sketch) {\n";
      code += "var sketch = new Sketch(\n" + this.sourceCode + ");\n";
      for (i in this.options) if (this.options.hasOwnProperty(i)) {
        var value = this.options[i];
        code += "sketch.options." + i + " = " + (typeof value === "string" ? '"' + value + '"' : "" + value) + ";\n"
      }
      for (i in this.imageCache) if (this.options.hasOwnProperty(i)) code += 'sketch.imageCache.add("' + i + '");\n';
      code += "return sketch;\n})(Processing.Sketch))";
      return code
    }
  };
  var loadSketchFromSources = function(canvas, sources) {
    var code = [],
      errors = [],
      sourcesCount = sources.length,
      loaded = 0;

    function ajaxAsync(url, callback) {
      var xhr = new XMLHttpRequest;
      xhr.onreadystatechange = function() {
        if (xhr.readyState === 4) {
          var error;
          if (xhr.status !== 200 && xhr.status !== 0) error = "Invalid XHR status " + xhr.status;
          else if (xhr.responseText === "") if ("withCredentials" in new XMLHttpRequest && (new XMLHttpRequest).withCredentials === false && window.location.protocol === "file:") error = "XMLHttpRequest failure, possibly due to a same-origin policy violation. You can try loading this page in another browser, or load it from http://localhost using a local webserver. See the Processing.js README for a more detailed explanation of this problem and solutions.";
          else error = "File is empty.";
          callback(xhr.responseText, error)
        }
      };
      xhr.open("GET", url, true);
      if (xhr.overrideMimeType) xhr.overrideMimeType("application/json");
      xhr.setRequestHeader("If-Modified-Since", "Fri, 01 Jan 1960 00:00:00 GMT");
      xhr.send(null)
    }
    function loadBlock(index, filename) {
      function callback(block, error) {
        code[index] = block;
        ++loaded;
        if (error) errors.push(filename + " ==> " + error);
        if (loaded === sourcesCount) if (errors.length === 0) try {
          return new Processing(canvas, code.join("\n"))
        } catch(e) {
          throw "Processing.js: Unable to execute pjs sketch: " + e;
        } else throw "Processing.js: Unable to load pjs sketch files: " + errors.join("\n");
      }
      if (filename.charAt(0) === "#") {
        var scriptElement = document.getElementById(filename.substring(1));
        if (scriptElement) callback(scriptElement.text || scriptElement.textContent);
        else callback("", "Unable to load pjs sketch: element with id '" + filename.substring(1) + "' was not found");
        return
      }
      ajaxAsync(filename, callback)
    }
    for (var i = 0; i < sourcesCount; ++i) loadBlock(i, sources[i])
  };
  var init = function() {
    document.removeEventListener("DOMContentLoaded", init, false);
    var canvas = document.getElementsByTagName("canvas"),
      filenames;
    for (var i = 0, l = canvas.length; i < l; i++) {
      var processingSources = canvas[i].getAttribute("data-processing-sources");
      if (processingSources === null) {
        processingSources = canvas[i].getAttribute("data-src");
        if (processingSources === null) processingSources = canvas[i].getAttribute("datasrc")
      }
      if (processingSources) {
        filenames = processingSources.split(" ");
        for (var j = 0; j < filenames.length;) if (filenames[j]) j++;
        else filenames.splice(j, 1);
        loadSketchFromSources(canvas[i], filenames)
      }
    }
    var scripts = document.getElementsByTagName("script");
    var s, source, instance;
    for (s = 0; s < scripts.length; s++) {
      var script = scripts[s];
      if (!script.getAttribute) continue;
      var type = script.getAttribute("type");
      if (type && (type.toLowerCase() === "text/processing" || type.toLowerCase() === "application/processing")) {
        var target = script.getAttribute("data-processing-target");
        canvas = undef;
        if (target) canvas = document.getElementById(target);
        else {
          var nextSibling = script.nextSibling;
          while (nextSibling && nextSibling.nodeType !== 1) nextSibling = nextSibling.nextSibling;
          if (nextSibling.nodeName.toLowerCase() === "canvas") canvas = nextSibling
        }
        if (canvas) {
          if (script.getAttribute("src")) {
            filenames = script.getAttribute("src").split(/\s+/);
            loadSketchFromSources(canvas, filenames);
            continue
          }
          source = script.textContent || script.text;
          instance = new Processing(canvas, source)
        }
      }
    }
  };
  Processing.loadSketchFromSources = loadSketchFromSources;
  Processing.disableInit = function() {
    if (isDOMPresent) document.removeEventListener("DOMContentLoaded", init, false)
  };
  if (isDOMPresent) {
    window["Processing"] = Processing;
    document.addEventListener("DOMContentLoaded", init, false)
  } else this.Processing = Processing
})(window, window.document, Math);

