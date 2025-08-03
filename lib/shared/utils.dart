class Utils {
  int crc32(List<int> buffer) {
    final polynomial = 0x04C11DB7;
    int crc = 0xFFFFFFFF;
    for (final item in buffer) {
      crc ^= item << 24;
      for (int i = 0; i < 8; i++) {
        if (crc >> 31 == 1) {
          crc = (crc << 1) ^ polynomial;
        } else {
          crc <<= 1;
        }
      }
    }
    return crc ^ 0xFFFFFFFF;
  }
}
