import 'package:artham/features/onboarding/getting_started_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Skip opens the final onboarding page and Get started invokes callback',
    (tester) async {
      var callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: GettingStartedScreen(onGetStarted: () => callbackCount++),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      // The onboarding has a looping background animation, so advance the
      // PageView in bounded frames rather than using pumpAndSettle().
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Your data stays on your phone.'), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await tester.pump();

      expect(callbackCount, 1);
    },
  );
}
