/*
BSD 3-Clause License

Copyright (c) 2025, circloid

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:trage/shared/utils.dart';

enum Command {
  join(1),
  leave(2),
  action(3),
  move(4);

  const Command(this.value);
  factory Command.deserialize(int value) {
    for (final cmd in Command.values) {
      if (cmd.value == value) return cmd;
    }
    throw Exception('Command with code \'$value\' not found');
  }
  final int value;
}

/// The packet is composed by
/// +--------------------------------------------+
/// CMD: 1 byte
/// Header entries length: 1 byte
/// Header raw length: 2 bytes
/// Header entries: variable length
/// Body length: 2 bytes
/// Body: variable length
/// Checksum: 4 bytes
/// +--------------------------------------------+
class Packet {
  Packet(this.cmd, {this.body = '', this.header = const {}});

  factory Packet.deserialize(List<int> buffer) {
    if (buffer.length < 10) {
      throw Exception('Invalid packet');
    }
    final cmd = Command.deserialize(buffer[0]);

    final headerLen = (buffer[2] << 8) + buffer[3];
    final header = _deserializeHeader(buffer);

    final bodyIdx = 4 + headerLen;
    final bodyLen = (buffer[bodyIdx] << 8) | buffer[bodyIdx + 1];
    final body = buffer.sublist(bodyIdx + 2, bodyIdx + 2 + bodyLen);
    // final crc = buffer.sublist(buffer.length - 4);
    // print(crc.map((e) => e.toRadixString(16)));
    // final packetCrc = (crc[0] << 24) | (crc[1] << 16) | (crc[2] << 8) | crc[3];
    // final computedCrc = Utils().crc32(buffer.sublist(0, buffer.length - 4));
    // if (packetCrc != computedCrc) {
    //   throw Exception('Packet is corrupted, invalid CRC');
    // }
    return Packet(cmd, header: header, body: String.fromCharCodes(body));
  }

  static const String _headerSeparator = ';';
  static const String _headerAssignSeparator = ':';
  static Map<String, String> defaultHeader = {};

  static Map<String, String> _deserializeHeader(List<int> buffer) {
    final entriesCount = buffer[1];
    final rawLen = (buffer[2] << 8) | buffer[3];

    if (entriesCount == 0) return {};

    final headerData = String.fromCharCodes(buffer.sublist(4, 4 + rawLen));
    final entries = headerData.split(_headerSeparator);

    final result = <String, String>{};
    for (final entry in entries) {
      if (entry.isNotEmpty) {
        final (key, value) = _deserializeHeaderEntry(entry);
        result[key] = value;
      }
    }

    return result;
  }

  static (String, String) _deserializeHeaderEntry(String str) {
    final entry = str.split(_headerAssignSeparator);
    if (entry.length < 2) {
      throw Exception('Invalid header entry during deserialization');
    }
    return (entry[0], entry[1]);
  }

  final Command cmd;
  final Map<String, String> header;
  final String body;

  List<int> get serializedHeader {
    final res = [header.length + defaultHeader.length];
    final h = {...header, ...defaultHeader};
    final List<String> newHeader = [];
    for (final MapEntry(:key, :value) in h.entries) {
      newHeader.add('$key$_headerAssignSeparator$value');
    }
    final serialized = newHeader.join(_headerSeparator);
    final len = serialized.length;
    res.add((len >> 8) & 0xFF);
    res.add(len & 0xFF);
    res.addAll(serialized.codeUnits);
    return res;
  }

  List<int> get serializedBody {
    final res = <int>[];
    final len = body.length;
    res.add((len >> 8) & 0xFF);
    res.add(len & 0xFF);
    res.addAll(body.codeUnits);
    return res;
  }

  List<int> serialize() {
    final List<int> res = [];
    res.add(cmd.value);
    res.addAll(serializedHeader);
    res.addAll(serializedBody);

    final crc = Utils().crc32(res);
    res.add((crc >> 24) & 0xFF);
    res.add((crc >> 16) & 0xFF);
    res.add((crc >> 8) & 0xFF);
    res.add(crc & 0xFF);

    return res;
  }

  int crc32() {
    final List<int> res = [];
    res.add(cmd.value);
    res.addAll(serializedHeader);
    res.addAll(serializedBody);
    return Utils().crc32(res);
  }

  @override
  String toString() {
    final combinedHeader = {...defaultHeader, ...header};
    final frames = [cmd.name];
    frames.add(combinedHeader.length.toString());
    frames.add(serializedHeader.length.toString());
    frames.add(String.fromCharCodes(serializedHeader));
    frames.add(serializedBody.length.toString());
    frames.add(String.fromCharCodes(serializedBody));
    frames.add(crc32().toString());
    return '''
+--PACKET--+
${frames.join('|')}
+----------+
    ''';
  }
}
