// lib/services/biometric_service.dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canAuthenticateWithBiometrics && !isDeviceSupported) {
        return true; // Bypass on devices/emulators without biometrics
      }

      return await _auth.authenticate(
        localizedReason: 'Unlock Fintor to view your financial transactions',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return true; // Fallback to PIN / skip if hardware unavailable
    }
  }
}
