var Stream = function(sequence, bits) {
  bits = bits || (sequence instanceof Buffer ? 8 : 1);
  var binary = '', b, i, n;

  for (i = 0, n = sequence.length; i < n; i++) {
    b = sequence[i].toString(2);
    while (b.length < bits) b = '0' + b;
    binary = binary + b;
  }
  binary = binary.split('').map(function(b) { return parseInt(b, 2) });

  this._bases = {'2': binary};
};

Stream.prototype.generate = function(n, base, inner) {
  base = base || 2;

  var value = n,
      k = Math.ceil(Math.log(n) / Math.log(base)),
      r = Math.pow(base, k) - n,
      chunk;

  loop: while (value >= n) {
    chunk = this._shift(base, k);
    if (!chunk) return inner ? n : null;

    value = this._evaluate(chunk, base);

    if (value >= n) {
      if (r === 1) continue loop;
      this._push(r, value - n);
      value = this.generate(n, r, true);
    }
  }
  return value;
};

Stream.prototype._evaluate = function(chunk, base) {
  var sum = 0,
      i   = chunk.length;

  while (i--) sum += chunk[i] * Math.pow(base, chunk.length - (i+1));
  return sum;
};

Stream.prototype._push = function(base, value) {
  this._bases[base] = this._bases[base] || [];
  this._bases[base].push(value);
};

Stream.prototype._shift = function(base, k) {
  var list = this._bases[base];
  if (!list || list.length < k) return null;
  else return list.splice(0,k);
};

module.exports = Stream;

