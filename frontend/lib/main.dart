import 'package:flutter/material.dart';
import 'app.dart';
import 'auth/auth_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BeautyClinicApp(authSession: AuthSession.production()));
}
