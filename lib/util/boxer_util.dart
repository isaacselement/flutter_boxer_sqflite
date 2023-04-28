/// List Extensions
extension ListEx<E> on List<E> {
  // E? get firstSafe => atSafe(0);
  //
  // E? get lastSafe => atSafe(length - 1);
  //
  // E? atSafe(int index) => (isEmpty || index < 0 || index >= length) ? null : elementAt(index);

  /// [1, 2, 3] join in a 'so' => [1, so, 2, so, 3]
  void joinIn(E object) {
    Iterator<E> iterator = this.iterator;
    if (!iterator.moveNext()) return;
    List<E> list = [];
    list.add(iterator.current);
    while (iterator.moveNext()) {
      list.add(object);
      list.add(iterator.current);
    }
    this.clear();
    this.insertAll(0, list);
  }
}

/// Iterable Extensions
extension IterableEx<E> on Iterable<E> {
  /// Safely get first
  E? get firstSafe {
    Iterator<E> it = iterator;
    if (!it.moveNext()) {
      return null;
    }
    return it.current;
  }

  /// Safely get last
  E? get lastSafe {
    Iterator<E> it = iterator;
    if (!it.moveNext()) {
      return null;
    }
    E result;
    do {
      result = it.current;
    } while (it.moveNext());
    return result;
  }

  /// Safely get element at specified index
  E? atSafe(int index) {
    int elementIndex = 0;
    for (E element in this) {
      if (index == elementIndex) return element;
      if (elementIndex > index) return null;
      elementIndex++;
    }
    return null;
  }

  /// Not null only one element in iterator
  E? get singleSafe {
    Iterator<E> it = iterator;
    if (!it.moveNext()) return null;
    E result = it.current;
    if (it.moveNext()) return null;
    return result;
  }
}

/// String Extensions
extension StringEx on String {
  String removeLast(String s) => this.endsWith(s) ? this.substring(0, this.length - 1) : this;
}

class BxLoG {
  /// debug log
  static void d(String message, {String? tag}) {
    assert(() {
      print('${DateTime.now()}: [${tag ?? BxLoG}] $message');
      return true;
    }());
  }

  /// https://dart.dev/guides/language/language-tour#assert
  /// Only print and evaluate the expression function on debug mode, will omit in production/profile mode
  static void console(String Function() expr) {
    assert(() {
      print('${DateTime.now()}: ${expr()}');
      return true;
    }());
  }
}
