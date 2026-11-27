import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrCodeService {
  static final QrCodeService instance = QrCodeService._init();
  QrCodeService._init();

  static const String secretSalt = 'DAWAMI:QR:SECURE:TOKEN:2026';

  String generateStaticStudentQr(String universityId) {
    return 'DAWAMI:STUDENT:$universityId';
  }

  String generateDynamicTimedQr(String universityId, {int intervalSeconds = 30}) {
    final currentEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeStep = currentEpoch ~/ intervalSeconds;
    final payload = '$universityId:$timeStep:$secretSalt';
    final token = sha256.convert(utf8.encode(payload)).toString().substring(0, 16);
    return 'DAWAMI:DYN:$universityId:$timeStep:$token';
  }

  bool validateDynamicQr(String qrContent, {int intervalSeconds = 30}) {
    if (!qrContent.startsWith('DAWAMI:DYN:')) {
      return qrContent.startsWith('DAWAMI:STUDENT:') || !qrContent.contains(':');
    }

    final parts = qrContent.split(':');
    if (parts.length < 5) return false;

    final universityId = parts[2];
    final tokenTimeStep = int.tryParse(parts[3]);
    final clientToken = parts[4];

    if (tokenTimeStep == null) return false;

    final currentEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final currentTimeStep = currentEpoch ~/ intervalSeconds;

    if ((currentTimeStep - tokenTimeStep).abs() > 1) {
      return false; // Token expired
    }

    final expectedPayload = '$universityId:$tokenTimeStep:$secretSalt';
    final expectedToken = sha256.convert(utf8.encode(expectedPayload)).toString().substring(0, 16);

    return clientToken == expectedToken;
  }

  String extractUniversityId(String scannedCode) {
    final trimmed = scannedCode.trim();
    if (trimmed.startsWith('DAWAMI:DYN:')) {
      final parts = trimmed.split(':');
      if (parts.length >= 3) return parts[2];
    }
    if (trimmed.startsWith('DAWAMI:STUDENT:')) {
      return trimmed.replaceFirst('DAWAMI:STUDENT:', '');
    }
    return trimmed;
  }
}
