import 'package:flutter/material.dart';
import 'auth/auth_session.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BeautyClinicApp(authSession: AuthSession.production()));
}
