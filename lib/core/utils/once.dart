/// Returns a function that calls its operand function only once
T Function(T Function()) once<T>() {
  var didIt = false;
  late T result;

  return (Function() fn) {
    if (!didIt) {
      didIt = true;
      result = fn();
    }
    return result;
  };
}
