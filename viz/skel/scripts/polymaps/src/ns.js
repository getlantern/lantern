po.ns = {
  svg: "http://www.w3.org/2000/svg",
  xlink: "http://www.w3.org/1999/xlink"
};

function ns(name) {
  var i = name.indexOf(":");
  return i < 0 ? name : {
    space: po.ns[name.substring(0, i)],
    local: name.substring(i + 1)
  };
}
