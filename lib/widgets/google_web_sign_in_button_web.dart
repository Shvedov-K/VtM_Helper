import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

Widget buildGoogleWebSignInButton() {
  return gsi.renderButton(
    configuration: gsi.GSIButtonConfiguration(
      type: gsi.GSIButtonType.standard,
      theme: gsi.GSIButtonTheme.filledBlack,
      size: gsi.GSIButtonSize.large,
      text: gsi.GSIButtonText.signinWith,
      locale: 'en',
      minimumWidth: 240,
    ),
  );
}
