import 'package:flutter/widgets.dart';
import 'google_web_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_web_sign_in_button_web.dart'
    if (dart.library.html) 'google_web_sign_in_button_web.dart';

Widget googleWebSignInButton() => buildGoogleWebSignInButton();
