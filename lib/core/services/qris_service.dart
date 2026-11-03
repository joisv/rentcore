class QrisService {
  /// Validates that the payload follows EMVCo QRIS standards:
  /// Starts with '000201' and contains '5802ID'.
  static bool isValidQrisPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return false;
    }
    final trimmed = payload.trim();
    return trimmed.startsWith('000201') && trimmed.contains('5802ID');
  }

  /// Calculates CRC-16/CCITT-FALSE checksum.
  /// Polynomial: 0x1021, Initial: 0xFFFF, Reflect: false, XOR Out: 0x0000.
  static String calculateCrc16(String data) {
    int crc = 0xFFFF;
    final codeUnits = data.codeUnits;

    for (int i = 0; i < codeUnits.length; i++) {
      crc ^= (codeUnits[i] << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Converts a static QRIS payload into a dynamic QRIS payload by:
  /// 1. Converting Tag 01 (Initiation Method) from 010211 (Static) to 010212 (Dynamic).
  /// 2. Formatting and injecting/replacing Tag 54 (Transaction Amount).
  /// 3. Recalculating the Tag 63 CRC-16/CCITT-FALSE checksum.
  static String generateDynamicQris(String rawStaticPayload, int payableAmount) {
    String payload = rawStaticPayload.trim();

    // 1. Convert Initiation Method (Tag 01):
    // Replace '010211' (Static initiation) with '010212' (Dynamic initiation).
    if (payload.contains('010211')) {
      payload = payload.replaceAll('010211', '010212');
    } else if (!payload.contains('010212') && payload.startsWith('000201')) {
      payload = '000201010212${payload.substring(6)}';
    }

    // 2. Inject Dynamic Bill Amount (Tag 54):
    // Format $payableAmount into a whole integer string without punctuation
    final amountInt = payableAmount < 0 ? 0 : payableAmount;
    final amountStr = amountInt.toString();
    final lengthStr = amountStr.length.toString().padLeft(2, '0');
    final tag54 = '54$lengthStr$amountStr';

    // Check if Tag 54 already exists in payload: Tag 54 + 2-digit length
    final tag54Regex = RegExp(r'54(\d{2})');
    final match = tag54Regex.firstMatch(payload);

    if (match != null) {
      final offset = match.start;
      final existingLen = int.tryParse(match.group(1) ?? '0') ?? 0;
      final totalTagLen = 4 + existingLen; // '54' (2) + len (2) + value (existingLen)
      payload = payload.replaceRange(offset, offset + totalTagLen, tag54);
    } else {
      // Insert Tag 54 immediately before Tag 5802ID (Country Code) or Tag 5303360 (Currency Code)
      if (payload.contains('5802ID')) {
        final pos = payload.indexOf('5802ID');
        payload = payload.substring(0, pos) + tag54 + payload.substring(pos);
      } else if (payload.contains('5303360')) {
        final pos = payload.indexOf('5303360');
        payload = payload.substring(0, pos) + tag54 + payload.substring(pos);
      } else {
        final pos63 = payload.lastIndexOf('6304');
        if (pos63 != -1) {
          payload = payload.substring(0, pos63) + tag54 + payload.substring(pos63);
        } else {
          payload += tag54;
        }
      }
    }

    // 3. Recalculate Checksum (Tag 63):
    // Strip old 4-character checksum following '6304' at the end of the payload.
    // Extract entire substring up to and including '...6304'.
    final pos63 = payload.lastIndexOf('6304');
    final String payloadUpTo6304;
    if (pos63 != -1) {
      payloadUpTo6304 = payload.substring(0, pos63 + 4);
    } else {
      payloadUpTo6304 = '${payload}6304';
    }

    final checksum = calculateCrc16(payloadUpTo6304);

    return '$payloadUpTo6304$checksum';
  }
}
