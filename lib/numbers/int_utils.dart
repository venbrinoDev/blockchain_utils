import 'dart:typed_data';

import 'package:blockchain_utils/binary/binary_operation.dart';
import 'package:blockchain_utils/tuple/tuple.dart';
import 'package:blockchain_utils/exception/exception.dart';
import 'package:blockchain_utils/numbers/bigint_utils.dart';

/// Utility class for integer-related operations and conversions.
class IntUtils {
  /// Decodes a variable-length byte array into an integer value according to Bitcoin's variable-length integer encoding scheme.
  ///
  /// [byteint] The list of bytes representing the encoded variable-length integer.
  /// Returns a tuple containing the decoded integer value and the number of bytes consumed from the input.
  ///
  /// If the first byte is less than 253, a single byte is used, returning the value and consuming 1 byte.
  /// If the first byte is 253, a 2-byte encoding is used, returning the value and consuming 2 bytes.
  /// If the first byte is 254, a 4-byte encoding is used, returning the value and consuming 4 bytes.
  /// If the first byte is 255, an 8-byte encoding is used, returning the value and consuming 8 bytes.
  ///
  /// Throws a MessageException if the decoded value cannot fit into an integer in the current environment.
  static Tuple<int, int> decodeVarint(List<int> byteint) {
    int ni = byteint[0];
    int size = 0;

    if (ni < 253) {
      return Tuple(ni, 1);
    }

    if (ni == 253) {
      size = 2;
    } else if (ni == 254) {
      size = 4;
    } else {
      size = 8;
    }

    BigInt value = BigintUtils.fromBytes(byteint.sublist(1, 1 + size),
        byteOrder: Endian.little);
    if (!value.isValidInt) {
      throw MessageException("cannot read variable-length in this environment");
    }
    return Tuple(value.toInt(), size + 1);
  }

  /// Encodes an integer into a variable-length byte array according to Bitcoin's variable-length integer encoding scheme.
  ///
  /// [i] The integer to be encoded.
  /// Returns a list of bytes representing the encoded variable-length integer.
  ///
  /// If the integer is less than 253, a single byte is used.
  /// If the integer is less than 0x10000, a 3-byte encoding is used with the first byte set to 0xfd.
  /// If the integer is less than 0x100000000, a 5-byte encoding is used with the first byte set to 0xfe.
  /// For integers larger than or equal to 0x100000000, an ArgumentException is thrown since they are not supported in Bitcoin's encoding.
  static List<int> encodeVarint(int i) {
    if (i < 253) {
      return [i];
    } else if (i < 0x10000) {
      final bytes = List<int>.filled(3, 0);
      bytes[0] = 0xfd;
      writeUint16LE(i, bytes, 1);
      return bytes;
    } else if (i < 0x100000000) {
      final bytes = List<int>.filled(5, 0);
      bytes[0] = 0xfe;
      writeUint32LE(i, bytes, 1);
      return bytes;
    } else {
      throw ArgumentException("Integer is too large: $i");
    }
  }

  /// Prepends a variable-length integer encoding of the given data length to the provided data.
  ///
  /// [data] The list of bytes representing the data.
  /// Returns a new list of bytes with the variable-length integer encoding prepended to the data.
  static List<int> prependVarint(List<int> data) {
    final varintBytes = encodeVarint(data.length);
    return [...varintBytes, ...data];
  }

  /// Calculates the number of bytes required to represent the bit length of an integer value.
  ///
  /// [val] The integer value for which to calculate the bit length in bytes.
  /// Returns the number of bytes required to represent the bit length of the integer value.
  static int bitlengthInBytes(int val) {
    return ((val > 0 ? val.bitLength : 1) + 7) ~/ 8;
  }

  /// Converts an integer to a byte list with the specified length and endianness.
  ///
  /// If the [length] is not provided, it is calculated based on the bit length
  /// of the integer, ensuring minimal byte usage. The [byteOrder] determines
  /// whether the most significant bytes are at the beginning (big-endian) or end
  /// (little-endian) of the resulting byte list.
  static List<int> toBytes(int val,
      {required int length, Endian byteOrder = Endian.big}) {
    List<int> byteList = List<int>.filled(length, 0);

    for (var i = 0; i < length; i++) {
      byteList[length - i - 1] = val & mask8;
      val = val >> 8;
    }

    if (byteOrder == Endian.little) {
      return byteList.reversed.toList();
    }

    return byteList;
  }

  /// Converts a list of bytes to an integer, following the specified byte order.
  ///
  /// [bytes] The list of bytes representing the integer value.
  /// [byteOrder] The byte order, defaults to Endian.big.
  /// Returns the corresponding integer value.
  static int fromBytes(List<int> bytes, {Endian byteOrder = Endian.big}) {
    if (byteOrder == Endian.little) {
      bytes = List<int>.from(bytes.reversed.toList());
    }

    int result = 0;
    for (var i = 0; i < bytes.length; i++) {
      result |= (bytes[bytes.length - i - 1] << (8 * i));
    }
    return result;
  }
}
