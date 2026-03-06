import 'dart:math' as math;
import 'dart:typed_data';

class SfntTable {
  SfntTable({required this.tag, required this.data}) {
    final isAsciiTag = tag.codeUnits.every((codeUnit) => codeUnit <= 0x7f);
    if (tag.length != 4 || !isAsciiTag) {
      throw ArgumentError.value(tag, 'tag', 'tag must be 4 ASCII chars');
    }
  }

  final String tag;
  final Uint8List data;
}

class SfntWriter {
  const SfntWriter({this.scalerType = 0x00010000});

  final int scalerType;

  Uint8List write(List<SfntTable> inputTables) {
    final tables = List<SfntTable>.from(inputTables)
      ..sort((left, right) => left.tag.compareTo(right.tag));

    final numTables = tables.length;
    final maxPowerOfTwo = _maxPowerOfTwo(numTables);
    final searchRange = maxPowerOfTwo * 16;
    final entrySelector = maxPowerOfTwo == 0 ? 0 : _log2(maxPowerOfTwo);
    final rangeShift = numTables * 16 - searchRange;

    final headerSize = 12;
    final recordSize = 16;
    final directorySize = headerSize + (recordSize * numTables);

    final recordsBytes = BytesBuilder();
    final tableDataBytes = BytesBuilder();

    var currentOffset = directorySize;
    for (final table in tables) {
      final paddedData = _pad4(table.data);
      final checksum = _checksum(paddedData);

      _writeTag(recordsBytes, table.tag);
      _writeUint32(recordsBytes, checksum);
      _writeUint32(recordsBytes, currentOffset);
      _writeUint32(recordsBytes, table.data.length);

      tableDataBytes.add(paddedData);
      currentOffset += paddedData.length;
    }

    final bytes = BytesBuilder();
    _writeUint32(bytes, scalerType);
    _writeUint16(bytes, numTables);
    _writeUint16(bytes, searchRange);
    _writeUint16(bytes, entrySelector);
    _writeUint16(bytes, rangeShift);
    bytes.add(recordsBytes.takeBytes());
    bytes.add(tableDataBytes.takeBytes());

    return bytes.takeBytes();
  }

  int _maxPowerOfTwo(int value) {
    if (value <= 0) {
      return 0;
    }

    var power = 1;
    while (power * 2 <= value) {
      power *= 2;
    }
    return power;
  }

  int _log2(int value) => (math.log(value) / math.ln2).floor();

  Uint8List _pad4(Uint8List data) {
    final remainder = data.length % 4;
    if (remainder == 0) {
      return data;
    }

    final padded = Uint8List(data.length + (4 - remainder));
    padded.setRange(0, data.length, data);
    return padded;
  }

  int _checksum(Uint8List paddedData) {
    final byteData = ByteData.sublistView(paddedData);
    var sum = 0;
    for (var offset = 0; offset < paddedData.length; offset += 4) {
      sum = (sum + byteData.getUint32(offset)) & 0xffffffff;
    }
    return sum;
  }

  void _writeTag(BytesBuilder builder, String tag) {
    builder.add(tag.codeUnits);
  }

  void _writeUint16(BytesBuilder builder, int value) {
    final byteData = ByteData(2)..setUint16(0, value);
    builder.add(byteData.buffer.asUint8List());
  }

  void _writeUint32(BytesBuilder builder, int value) {
    final byteData = ByteData(4)..setUint32(0, value);
    builder.add(byteData.buffer.asUint8List());
  }
}
