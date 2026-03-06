import 'dart:typed_data';

Uint8List readCffTable(Uint8List otfBytes) {
  final data = ByteData.sublistView(otfBytes);
  final numTables = data.getUint16(4);
  for (var index = 0; index < numTables; index += 1) {
    final recordOffset = 12 + index * 16;
    final tag = String.fromCharCodes(
      otfBytes.sublist(recordOffset, recordOffset + 4),
    );
    if (tag == 'CFF ') {
      final offset = data.getUint32(recordOffset + 8);
      final length = data.getUint32(recordOffset + 12);
      return otfBytes.sublist(offset, offset + length);
    }
  }
  throw StateError('CFF table not found');
}

CffIndex readCffIndex(Uint8List cff, int offset) {
  final data = ByteData.sublistView(cff);
  final count = data.getUint16(offset);
  var cursor = offset + 2;

  if (count == 0) {
    return CffIndex(objects: const [], nextOffset: cursor, offSize: 0);
  }

  final offSize = cff[cursor];
  cursor += 1;

  final offsets = <int>[];
  for (var index = 0; index < count + 1; index += 1) {
    var value = 0;
    for (var byteIndex = 0; byteIndex < offSize; byteIndex += 1) {
      value = (value << 8) | cff[cursor + byteIndex];
    }
    offsets.add(value);
    cursor += offSize;
  }

  final dataStart = cursor;
  final objects = <Uint8List>[];
  for (var index = 0; index < count; index += 1) {
    final start = dataStart + offsets[index] - 1;
    final end = dataStart + offsets[index + 1] - 1;
    objects.add(cff.sublist(start, end));
  }

  final nextOffset = dataStart + offsets.last - 1;
  return CffIndex(objects: objects, nextOffset: nextOffset, offSize: offSize);
}

int readCffInt32BeforeOperator(Uint8List dictData, int operator) {
  for (var index = 0; index < dictData.length - 5; index += 1) {
    if (dictData[index] == 29 && dictData[index + 5] == operator) {
      return ByteData.sublistView(dictData, index + 1, index + 5).getInt32(0);
    }
  }
  throw StateError('Operator $operator not found in Top DICT');
}

List<int> readCharsetSids(
  Uint8List cff,
  int charsetOffset, {
  required int glyphCount,
}) {
  final data = ByteData.sublistView(cff);
  final format = cff[charsetOffset];
  if (format != 0) {
    throw StateError('Unsupported charset format: $format');
  }

  final sids = <int>[];
  var cursor = charsetOffset + 1;
  for (var index = 1; index < glyphCount; index += 1) {
    sids.add(data.getUint16(cursor));
    cursor += 2;
  }
  return sids;
}

class CffIndex {
  const CffIndex({
    required this.objects,
    required this.nextOffset,
    required this.offSize,
  });

  final List<Uint8List> objects;
  final int nextOffset;
  final int offSize;
}
