// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:yesopc_app/main.dart';

void main() {
  testWidgets('App smoke test renders YesOPC branding', (WidgetTester tester) async {
    await tester.pumpWidget(const YesOPCApp());

    // 未登录时进入登录页；已登录时进入首页。两者均包含品牌名。
    expect(find.textContaining('YesOPC'), findsWidgets);
  });
}
