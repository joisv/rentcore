import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/services/qris_service.dart';

void main() {
  group('QrisService Dart Unit Tests', () {
    test('calculateCrc16 produces standard CCITT-FALSE vector', () {
      final crc = QrisService.calculateCrc16('123456789');
      expect(crc, equals('29B1'));
    });

    test('isValidQrisPayload correctly checks EMVCo format', () {
      const valid = '00020101021126580014ID.LINKAJA.WWW0118936009180000000001020712345675204581253033605802ID5911RENTCORE POS6007JAKARTA6105123406304A1B2';
      expect(QrisService.isValidQrisPayload(valid), isTrue);

      expect(QrisService.isValidQrisPayload(''), isFalse);
      expect(QrisService.isValidQrisPayload(null), isFalse);
      expect(QrisService.isValidQrisPayload('000201test_without_id'), isFalse);
      expect(QrisService.isValidQrisPayload('5802ID_without_000201'), isFalse);
    });

    test('generateDynamicQris converts Tag 01, injects Tag 54, and calculates valid CRC', () {
      const staticPayload = '00020101021126580014ID.LINKAJA.WWW0118936009180000000001020712345675204581253033605802ID5911RENTCORE POS6007JAKARTA6105123406304A1B2';

      final dynamicPayload = QrisService.generateDynamicQris(staticPayload, 50000);

      expect(dynamicPayload.contains('010212'), isTrue);
      expect(dynamicPayload.contains('010211'), isFalse);
      expect(dynamicPayload.contains('540550000'), isTrue);

      final payloadUpToCrc = dynamicPayload.substring(0, dynamicPayload.length - 4);
      final checksum = dynamicPayload.substring(dynamicPayload.length - 4);
      expect(QrisService.calculateCrc16(payloadUpToCrc), equals(checksum));
    });

    test('generateDynamicQris reactively replaces existing Tag 54 on amount change', () {
      const staticPayload = '00020101021126580014ID.LINKAJA.WWW0118936009180000000001020712345675204581253033605802ID5911RENTCORE POS6007JAKARTA6105123406304A1B2';

      final first = QrisService.generateDynamicQris(staticPayload, 50000);
      expect(first.contains('540550000'), isTrue);

      final updated = QrisService.generateDynamicQris(first, 120000);
      expect(updated.contains('5406120000'), isTrue);
      expect(updated.contains('540550000'), isFalse);

      final payloadUpToCrc = updated.substring(0, updated.length - 4);
      final checksum = updated.substring(updated.length - 4);
      expect(QrisService.calculateCrc16(payloadUpToCrc), equals(checksum));
    });
  });
}
