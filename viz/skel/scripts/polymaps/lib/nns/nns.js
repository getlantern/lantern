(function(_) {

  function create(n) {
    if (/^#/.test(n)) return document.getElementById(n.substring(1));
    n = qualify(n);
    return n.space == null
        ? document.createElement(n.local)
        : document.createElementNS(n.space, n.local);
  }

  function qualify(n) {
    var i = n.indexOf(":");
    return {
      space: n$.prefix[n.substring(0, i)],
      local: n.substring(i + 1)
    };
  }

  function N$(e) {
    this.element = e;
  }

  N$.prototype = {

    add: function(c, s) {
      return n$(this.element.insertBefore(
          typeof c == "string" ? create(c) : $n(c),
          arguments.length == 1 ? null : $n(s)));
    },

    remove: function(c) {
      this.element.removeChild($n(c));
      return this;
    },

    parent: function() {
      return n$(this.element.parentNode);
    },

    child: function(i) {
      var children = this.element.childNodes;
      return n$(children[i < 0 ? children.length - i - 1 : i]);
    },

    previous: function() {
      return n$(this.element.previousSibling);
    },

    next: function() {
      return n$(this.element.nextSibling);
    },

    attr: function(n, v) {
      var e = this.element;
      n = qualify(n);
      if (arguments.length == 1) {
        return n.space == null
            ? e.getAttribute(n.local)
            : e.getAttributeNS(n.space, n.local);
      }
      if (n.space == null) {
        if (v == null) e.removeAttribute(n.local);
        else e.setAttribute(n.local, v);
      } else {
        if (v == null) e.removeAttributeNS(n.space, n.local);
        else e.setAttributeNS(n.space, n.local, v);
      }
      return this;
    },

    style: function(n, v, p) {
      var style = this.element.style;
      if (arguments.length == 1) return style.getPropertyValue(n);
      if (v == null) style.removeProperty(n);
      else style.setProperty(n, v, arguments.length == 3 ? p : null);
      return this;
    },

    on: function(t, l, c) {
      this.element.addEventListener(t, l, arguments.length == 3 ? c : false);
      return this;
    },

    off: function(t, l, c) {
      this.element.removeEventListener(t, l, arguments.length == 3 ? c : false);
      return this;
    },

    text: function(v) {
      var t = this.element.firstChild;
      if (!arguments.length) return t && t.nodeValue;
      if (t) t.nodeValue = v;
      else if (v != null) t = this.element.appendChild(document.createTextNode(v));
      return this;
    }
  }

  function n$(e) {
    return e == null || e.element ? e : new N$(typeof e == "string" ? create(e) : e);
  }

  function $n(o) {
    return o && o.element || o;
  }

  n$.prefix = {
    svg: "http://www.w3.org/2000/svg",
    xlink: "http://www.w3.org/1999/xlink",
    xml: "http://www.w3.org/XML/1998/namespace",
    xmlns: "http://www.w3.org/2000/xmlns/"
  };

  n$.version = "1.1.0";

  _.n$ = n$;
  _.$n = $n;
})(this);
