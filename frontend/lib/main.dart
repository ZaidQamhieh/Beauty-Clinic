import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'auth/auth_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(BeautyClinicApp(authSession: AuthSession.production()));
}
