import 'dart:typed_data';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:blockchain_utils/cbor/utils/float_utils.dart';
import 'package:blockchain_utils/cbor/core/tags.dart';

class CborUtils {
  /// Decode a CBOR (Concise Binary Object Representation) data stream represented by a List<int>.
  /// The method decodes the CBOR data and returns the resulting CborObject.
  static CborObject decodeCbor(List<int> cborBytes) {
    return _decode(cborBytes).item1;
  }

  /// Parse a datetime string in RFC3339 format and return a corresponding DateTime object.
  /// The method checks if the input string contains a timezone offset. If it does, it splits the string
  /// into date and offset parts, parses the date part, and returns it. If there's no offset, it parses
  /// the input string as a UTC time.
  static DateTime parseRFC3339DateTime(String dateTimeString) {
    // Check if the input string contains a timezone offset
    if (dateTimeString.contains('+')) {
      // Split the string into the date and offset parts
      final parts = dateTimeString.split('+');
      if (parts.length != 2) {
        throw MessageException("Invalid format: $dateTimeString");
      }
      final datePart = DateTime.parse(parts[0]);
      return datePart;
    } else {
      // Parse the input string as a UTC time
      return DateTime.parse(dateTimeString).toUtc();
    }
  }

  static Tuple<CborObject, int> _decode(List<int> cborBytes) {
    final List<int> tags = [];
    for (int i = 0; i < cborBytes.length;) {
      final int first = cborBytes[i];

      final majorTag = first >> 5;
      final info = first & 0x1f;
      switch (majorTag) {
        case MajorTags.map:
          if (info == NumBytes.indefinite) {
            return _decodeDynamicMap(cborBytes, i, info, tags);
          }
          return _decodeMap(cborBytes, i, info, tags);
        case MajorTags.negInt:
        case MajorTags.posInt:
          return _parseInt(majorTag, info, i, cborBytes, tags);
        case MajorTags.tag:
          final data = _decodeLength(info, cborBytes.sublist(i));
          tags.add(data.item1);
          i += data.item2;
          continue;
        case MajorTags.byteString:
          return _decodeBytesString(info, i, cborBytes, tags);
        case MajorTags.utf8String:
          return _decodeUtf8String(info, i, cborBytes, tags);
        case MajorTags.simpleOrFloat:
          return _parseSimpleValue(i, info, cborBytes, tags);
        case MajorTags.array:
          if (info == NumBytes.indefinite) {
            return _decodeDynamicArray(cborBytes, i, info, tags);
          }
          return _decodeArray(cborBytes, i, info, tags);
        default:
          throw ArgumentException(
              "invalid or unsuported cbor tag major: $majorTag ");
      }
    }
    throw ArgumentException("invalid or unsuported cbor tag");
  }

  static Tuple<List<int>, int> _parsBytes(int info, List<int> cborBytes) {
    final len = _decodeLength(info, cborBytes);
    final int end = (len.item2 + len.item1 as int);
    final bytes = cborBytes.sublist(len.item2, end);
    return Tuple(bytes, end);
  }

  static Tuple<dynamic, int> _decodeLength(int info, List<int> cborBytes) {
    if (info < 24) {
      return Tuple(info, 1);
    }
    final int len = 1 << (info - 24);
    ByteData buf =
        ByteData.view(Uint8List.fromList(cborBytes.sublist(1, len + 1)).buffer);
    const int shift32 = 0x100000000; // 2^32
    const int maxSafeHigh = 0x1fffff;
    switch (info) {
      case NumBytes.one:
        return Tuple(buf.getUint8(0), 2);
      case NumBytes.two:
        return Tuple(buf.getUint16(0, Endian.big), 3);
      case NumBytes.four:
        return Tuple(buf.getUint32(0, Endian.big), 5);
      case NumBytes.eight:
        final f = buf.getUint32(0, Endian.big);
        final g = buf.getUint32(4, Endian.big);
        if (f > maxSafeHigh) {
          final big = (BigInt.from(f) * BigInt.from(shift32)) + BigInt.from(g);
          if (big.isValidInt) {
            return Tuple(big.toInt(), 9);
          }
          return Tuple(big, 9);
        }
        return Tuple((f * shift32) + g, 9);
      default:
        throw ArgumentException('Invalid additional info for int: $info');
    }
  }

  static Tuple<CborObject, int> _decodeUtf8String(
      int info, int i, List<int> cborBytes, List<int> tags) {
    if (info == NumBytes.indefinite) {
      final toList = _decodeDynamicArray(cborBytes, i, info, tags);
      final stringList = (toList.item1 as CborListValue)
          .value
          .whereType<CborStringValue>()
          .map((e) => e.value)
          .toList();
      if (tags.isNotEmpty) {
        return Tuple(CborTagValue(CborIndefiniteStringValue(stringList), tags),
            toList.item2);
      }
      return Tuple(CborIndefiniteStringValue(stringList), toList.item2);
    }

    final bytes = _parsBytes(info, cborBytes.sublist(i));

    return Tuple(_toStringObject(bytes.item1, tags), (bytes.item2 + i));
  }

  static CborObject _toStringObject(List<int> utf8Bytes, List<int> tags) {
    final toString = StringUtils.decode(utf8Bytes);
    CborObject? toObj;
    if (tags.isEmpty) {
      toObj = CborStringValue(toString);
    } else if (CborBase64Types.values
        .any((element) => bytesEqual(tags, element.tag))) {
      final baseType = CborBase64Types.values
          .firstWhere((element) => bytesEqual(tags, element.tag));
      tags.clear();
      toObj = CborBaseUrlValue(toString, baseType);
    } else if (bytesEqual(tags, CborTags.mime)) {
      tags.clear();
      toObj = CborMimeValue(toString);
    } else if (bytesEqual(tags, CborTags.uri)) {
      tags.clear();
      toObj = CborUriValue(toString);
    } else if (bytesEqual(tags, CborTags.regexp)) {
      tags.clear();
      toObj = CborRegxpValue(toString);
    } else if (bytesEqual(tags, CborTags.dateString)) {
      tags.clear();
      final time = parseRFC3339DateTime(toString);
      toObj = CborStringDateValue(time);
    }
    toObj ??= CborStringValue(toString);
    return tags.isEmpty ? toObj : CborTagValue(toObj, tags);
  }

  static Tuple<CborObject, int> _decodeBytesString(
      int info, int i, List<int> cborBytes, List<int> tags) {
    if (info == NumBytes.indefinite) {
      final toList = _decodeDynamicArray(cborBytes, i, info, tags);
      final bytesList = toList.item1.value
          .whereType<CborBytesValue>()
          .map((e) => e.value)
          .toList();
      if (tags.isNotEmpty) {
        return Tuple(
            CborTagValue(CborDynamicBytesValue(bytesList), tags), toList.item2);
      }
      return Tuple(CborDynamicBytesValue(bytesList), toList.item2);
    }
    final bytes = _parsBytes(info, cborBytes.sublist(i));
    CborObject? val;
    if (bytesEqual(tags, CborTags.negBigInt) ||
        bytesEqual(tags, CborTags.posBigInt)) {
      BigInt big = BigintUtils.fromBytes(bytes.item1);
      if (bytesEqual(tags, CborTags.negBigInt)) {
        big = ~big;
      }
      tags.clear();
      val = CborBigIntValue(big);
    }
    val ??= CborBytesValue(bytes.item1);
    return Tuple(tags.isEmpty ? val : CborTagValue(val, tags), bytes.item2 + i);
  }

  static Tuple<CborObject, int> _decodeMap(
      List<int> cborBytes, int offset, int info, List<int> tags) {
    // s
    // int index = offset + 1;

    final decodeLen = _decodeLength(info, cborBytes);
    int index = offset + decodeLen.item2;
    final int length = decodeLen.item1;
    Map<CborObject, CborObject> objects = {};
    for (int lI = 0; lI < length; lI++) {
      final decodeKey = _decode(cborBytes.sublist(index));
      index += decodeKey.item2;
      final decodeValue = _decode(cborBytes.sublist(index));
      objects[decodeKey.item1] = decodeValue.item1;
      index += decodeValue.item2;
    }
    final toMap = CborMapValue.fixedLength(objects);
    return Tuple(tags.isEmpty ? toMap : CborTagValue(toMap, tags), index);
  }

  static Tuple<CborObject, int> _decodeDynamicMap(
      List<int> cborBytes, int offset, int info, List<int> tags) {
    int index = offset + 1;
    Map<CborObject, CborObject> objects = {};
    while (cborBytes[index] != 0xff) {
      final decodeKey = _decode(cborBytes.sublist(index));
      index += decodeKey.item2;
      final decodeValue = _decode(cborBytes.sublist(index));
      objects[decodeKey.item1] = decodeValue.item1;
      index += decodeValue.item2;
    }
    final toMap = CborMapValue.dynamicLength(objects);
    return Tuple(tags.isEmpty ? toMap : CborTagValue(toMap, tags), index + 1);
  }

  static Tuple<CborObject, int> _decodeArray(
      List<int> cborBytes, int offset, int info, List<int> tags) {
    final decodeLen = _decodeLength(info, cborBytes);
    int index = offset + decodeLen.item2;
    final int length = decodeLen.item1;
    List<CborObject> objects = [];
    for (int lI = 0; lI < length; lI++) {
      final decodeData = _decode(cborBytes.sublist(index));
      objects.add(decodeData.item1);
      index += decodeData.item2;
    }
    if (bytesEqual(tags, CborTags.bigFloat) ||
        bytesEqual(tags, CborTags.decimalFrac)) {
      return Tuple(_decodeCborBigfloatOrDecimal(objects, tags), index);
    }
    if (bytesEqual(tags, CborTags.set)) {
      tags.clear();
      final toObj = CborSetValue(objects.toSet());
      return Tuple(tags.isEmpty ? toObj : CborTagValue(toObj, tags), index);
    }
    final toObj = CborListValue.fixedLength(objects);
    return Tuple(tags.isEmpty ? toObj : CborTagValue(toObj, tags), index);
  }

  static Tuple<CborObject, int> _decodeDynamicArray(
      List<int> cborBytes, int offset, int info, List<int> tags) {
    int index = offset + 1;
    List<CborObject> objects = [];
    while (cborBytes[index] != 0xff) {
      final decodeData = _decode(cborBytes.sublist(index));
      objects.add(decodeData.item1);
      index += decodeData.item2;
    }
    final toObj = CborListValue.dynamicLength(objects);
    return Tuple(tags.isEmpty ? toObj : CborTagValue(toObj, tags), index + 1);
  }

  static CborObject _decodeCborBigfloatOrDecimal(
      List<CborObject> objects, List<int> tags) {
    objects = objects.whereType<CborNumeric>().toList();
    if (objects.length != 2) {
      throw MessageException("invalid bigFloat array length");
    }
    if (bytesEqual(tags, CborTags.decimalFrac)) {
      tags.clear();
      final toObj = CborDecimalFracValue.fromCborNumeric(
          objects[0] as CborNumeric, objects[1] as CborNumeric);
      return tags.isEmpty ? toObj : CborTagValue(toObj, tags);
    }
    tags.clear();
    final toObj = CborBigFloatValue.fromCborNumeric(
        objects[0] as CborNumeric, objects[1] as CborNumeric);
    return tags.isEmpty ? toObj : CborTagValue(toObj, tags);
  }

  static Tuple<CborObject, int> _parseSimpleValue(
      int i, int info, List<int> bytes, List<int> tags) {
    int offset = i + 1;
    CborObject? obj;
    switch (info) {
      case SimpleTags.simpleFalse:
        obj = CborBoleanValue(false);
        break;
      case SimpleTags.simpleTrue:
        obj = CborBoleanValue(true);
        break;
      case SimpleTags.simpleNull:
        obj = CborNullValue();
        break;
      case SimpleTags.simpleUndefined:
        obj = CborUndefinedValue();
        break;
      default:
    }
    if (obj != null) {
      if (tags.isEmpty) {
        return Tuple(obj, offset);
      }
      return Tuple(CborTagValue(obj, tags), offset);
    }

    double val;
    switch (info) {
      case NumBytes.two:
        val = FloatUtils.floatFromBytes16(bytes.sublist(offset, offset + 2));
        offset = offset + 2;
        break;
      case NumBytes.four:
        val = ByteData.view(
                Uint8List.fromList(bytes.sublist(offset, offset + 4)).buffer)
            .getFloat32(0, Endian.big);
        offset = offset + 4;
        break;
      case NumBytes.eight:
        val = ByteData.view(
                Uint8List.fromList(bytes.sublist(offset, offset + 8)).buffer)
            .getFloat64(0, Endian.big);
        offset = offset + 8;
        break;
      default:
        throw MessageException("Invalid simpleOrFloatTags");
    }
    if (bytesEqual(tags, CborTags.dateEpoch)) {
      final dt = DateTime.fromMillisecondsSinceEpoch((val * 1000).round());
      tags.clear();
      obj = CborEpochFloatValue(dt);
    }
    obj ??= CborFloatValue(val);
    return Tuple(tags.isEmpty ? obj : CborTagValue(obj, tags), offset);
  }

  static Tuple<CborObject, int> _parseInt(
      int mt, int info, int i, List<int> cborBytes, List<int> tags) {
    final data = _decodeLength(info, cborBytes.sublist(i));
    final val = data.item1;
    CborNumeric? numericValue;
    final index = data.item2 + i;
    if (val is BigInt) {
      if (val.bitLength > 64) {
        throw MessageException("invalid int value");
      }
      if (val.isValidInt) {
        numericValue = CborInt64Value(mt == MajorTags.negInt ? ~val : val);
      }
    }
    numericValue ??= CborIntValue(mt == MajorTags.negInt ? ~val : val);
    if (bytesEqual(tags, CborTags.dateEpoch)) {
      final dt =
          DateTime.fromMillisecondsSinceEpoch(numericValue.toInt() * 1000);
      tags.clear();
      final toObj = CborEpochIntValue(dt);
      return Tuple(tags.isEmpty ? toObj : CborTagValue(toObj, tags), index);
    }
    return Tuple(
        tags.isEmpty ? numericValue : CborTagValue(numericValue, tags), index);
  }
}
