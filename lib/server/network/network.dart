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

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:trage/server/network/client_connection.dart';

class Network {
  Network({required this.socket, required this.host, required this.port});

  static Future<Network> bind(String host, int port) async {
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    final net = new Network(socket: s, host: InternetAddress(host), port: port);
    s.listen(net._listenSocketDatagram);
    return net;
  }

  final InternetAddress host;
  final RawDatagramSocket socket;
  final int port;
  Timer? _timer;

  void heartbeat(int fps) {
    final delta = Duration(milliseconds: (1000 / fps).round());
    _timer = Timer.periodic(delta, (_) {
      _checkChanges();
      _publishChanges();
    });
  }

  void death() => _timer?.cancel();

  void _checkChanges() {}
  void _publishChanges() {}

  void send(Uint8List buffer, ClientConnection client) {
    print('PUB:' + String.fromCharCodes(buffer));
    socket.send(buffer, client.addr, client.port);
  }

  Future<void> _listenSocketDatagram(RawSocketEvent? e) async {
    switch (e) {
      case RawSocketEvent.read:
        final datagram = socket.receive();
        if (datagram == null) break;
        print('REC:' + String.fromCharCodes(datagram.data));
        send(datagram.data, ClientConnection(datagram.address, datagram.port));
        break;
      case RawSocketEvent.write:
        break;
      case RawSocketEvent.readClosed:
        break;
      case RawSocketEvent.closed:
        break;
      default:
        break;
    }
  }
}
