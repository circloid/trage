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

extension BitOperations on int {
  List<int> bit(int length) {
    final res = <int>[];
    int char;

    for (int i = 0; i < length; i++) {
      char = (this << i) & 0x100;
      res.add(char);
    }

    return res;
  }
}

/// PacketCommand is a 1 byte integer (256 combination) that is the first field of the UDP Packet
enum PacketCommand {
  // Player actions
  join(1),
  leave(2),
  move(3),
  shot(4),
  tick(5);

  const PacketCommand(this.value);
  factory PacketCommand.deserialize(List<int> buffer) {
    if (buffer.length != 2) {
      throw PacketException(
        'Invalid command length',
        'It should be 2 bytes but given ${buffer.length}',
      );
    }
    final value = (buffer[0] << 8) | buffer[1];
    for (final cmd in PacketCommand.values) {
      if (cmd.value == value) return cmd;
    }
    throw Exception('Command with code \'$value\' not found');
  }
  final int value;

  List<int> serialize() {
    return [value >> 8 % 256, value % 256];
  }
}

enum PacketFlag {
  compressed(0x1), // Body is compressed in base64
  encrypted(0x2),
  broadcast(0x4),
  priorityze(0x8);

  const PacketFlag(this.value);

  final int value;

  static int serialize(List<PacketFlag> flags) {
    int res = 0;
    for (final flag in flags) {
      res |= flag.value;
    }
    return res;
  }

  static List<PacketFlag> deserialize(int buffer) {
    final res = <PacketFlag>[];
    final flags = [compressed, encrypted, broadcast, priorityze];
    for (int i = 0; i < 8; i++) {
      if (((buffer >> i) & 1) == 1) {
        res.add(flags[i]);
      }
    }
    return res;
  }
}

/// The packet is composed by
/// +--------------------------------------------+
/// CMD: 2 byte
/// Flag: 1 byte
/// Body length: 2 bytes
/// Body: variable length
/// +--------------------------------------------+
class Packet {
  Packet(this.cmd, {this.flags = const [], this.body = ''});

  factory Packet.deserialize(List<int> buffer) {
    if (buffer.length < 4) {
      throw PacketException(
        'Invalid buffer length',
        'It should be at least 4 bytes, given ${buffer.length}',
      );
    }
    final cmd = PacketCommand.deserialize(buffer.sublist(0, 2));
    final flags = PacketFlag.deserialize(buffer[2]);
    final body = String.fromCharCodes(buffer.sublist(5));

    return Packet(cmd, flags: flags, body: body);
  }
  static const int bodyLength = 0x10000;
  final PacketCommand cmd;
  final List<PacketFlag> flags;
  final String body;

  List<int> serialize() {
    final bytes = body.codeUnits.length;
    if (bytes >= bodyLength) {
      throw const PacketException(
        'Error during serialization',
        'Body length oversized',
      );
    }

    final int flag = PacketFlag.serialize(flags);

    return [...cmd.serialize(), flag, ...bytes.bit(2), ...body.codeUnits];
  }

  @override
  String toString() {
    final lines = [];
    lines.add('CMD      : ${cmd.name}');
    lines.add('FLAGS    : ${flags.map((f) => f.name).join(',')}');
    lines.add('BODY LEN : ${body.length}');
    lines.add('BODY     : ${body}');
    return lines.join('\n');
  }
}

class PacketException implements Exception {
  const PacketException(this.message, [this.cause]);
  final String message;
  final String? cause;

  Map<String, String> get json => {
    'message': message,
    if (cause != null) 'cause': cause!,
  };

  @override
  String toString() => '''PacketException: $json''';
}
