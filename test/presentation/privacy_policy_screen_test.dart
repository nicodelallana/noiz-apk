import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizkaia_transit/presentation/screens/legal/legal_texts.dart';
import 'package:bizkaia_transit/presentation/screens/legal/privacy_policy_screen.dart';

void main() {
  group('PrivacyPolicyScreen Tests', () {
    testWidgets('renders title, public web URL and required legal copy',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacyPolicyScreen(),
        ),
      );

      // Verify title is rendered
      expect(find.text('Política de Privacidad'), findsOneWidget);

      // Verify public URL is displayed and accessible
      expect(find.text(LegalTexts.privacyPolicyUrl), findsOneWidget);

      // Verify key data sections are present
      expect(find.text('Ubicación (GPS / Red)'), findsOneWidget);

      // Scroll down to verify email and bottom cards
      await tester.scrollUntilVisible(
        find.textContaining(LegalTexts.developerEmail),
        300,
      );
      expect(find.textContaining(LegalTexts.developerEmail), findsOneWidget);
    });
  });
}
