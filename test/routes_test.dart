import 'package:flutter_test/flutter_test.dart';

import '../tool/check_routes.dart';

void main() {
  test('every context.push/go target has a GoRoute (sign-up regression)', () {
    expect(findMissingRoutes('lib'), isEmpty);
  });
}
