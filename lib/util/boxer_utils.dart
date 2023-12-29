class BoxerUtils {
  // Usage:
  // 1. check T is int or int? ---> isType<int>(T) || isTypeNull<int>(T)
  // 2. check T is Map or Map? ---> isType<Map>(T) || isTypeNull<Map>(T)
  // 3. check T is List or List? ---> isTypeIgnoreNull<List>(T)
  static bool isType<T>(Type type) => type == T;

  static bool isTypeNull<T>(Type type) => isType<T?>(type);

  static bool isTypeIgnoreNull<T>(Type type) => isType<T>(type) || isTypeNull<T>(type);

  // Usage:
  // 1. check T is List or List? ---> isTypeSimilar<T, List> or isTypeSimilar<List, T>
  static bool isTypeSame<T, S>() => T == S;

  static bool isTypeSimilar<T, S>() => isTypeSame<T, S>() || isTypeSame<T?, S?>();
}

void main() {
  checkType<int>(0);
  checkType<int?>(0);

  checkType<Map>({});
  checkType<Map?>({});

  checkType<List>([]);
  checkType<List?>([]);

  checkType<double>(0);
  checkType<double?>(0);
}

void checkType<T>(T value) {
  print('my T is ------>>>> ${T.toString()}');

  if (BoxerUtils.isType<int>(T)) {
    print('I am int');
  }
  if (BoxerUtils.isTypeNull<int>(T)) {
    print('I am int?');
  }
  if (BoxerUtils.isTypeIgnoreNull<int>(T)) {
    print('💯I am int or int?');
  }

  if (BoxerUtils.isType<Map>(T)) {
    print('I am Map');
  }
  if (BoxerUtils.isTypeNull<Map>(T)) {
    print('I am Map?');
  }
  if (BoxerUtils.isTypeIgnoreNull<Map>(T)) {
    print('💯I am Map or Map?');
  }

  if (BoxerUtils.isTypeSimilar<List, T>()) {
    print('✅ I am List or List?');
  }

  if (BoxerUtils.isTypeSimilar<T, double>()) {
    print('🚸🚸 I am double or double?');
  }
}
