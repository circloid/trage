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

import 'dart:io';

import 'package:shared/shared.dart';

typedef NetworkListenerCallback = void Function(Packet);

class NetworkListener {
  NetworkListener(this.callback, [this.id = const Object()]);

  final NetworkListenerCallback callback;
  final Object id;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
  }
}

class Network {
  Network(this.socket, this.host, this.port);

  static Future<Network> bind(String address, int port) async {
    final host = InternetAddress(address);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final net = Network(socket, host, port);
    socket.listen(net._listenRawSocket);
    return net;
  }

  final Map<Object, NetworkListener> _listeners = {};

  final InternetAddress host;
  final RawDatagramSocket socket;
  final int port;

  void _listenRawSocket(RawSocketEvent e) {
    final Datagram? d = socket.receive();
    if (d == null) return;
    try {
      final p = Packet.deserialize(d.data);
      for (final listener in _listeners.values) {
        listener.callback(p);
      }
    } catch (e, stack) {
      print(e);
      print(stack);
      exit(1);
    }
  }

  void send(Packet packet) {
    socket.send(packet.serialize(), host, port);
  }

  void listen(NetworkListenerCallback callback, [Object? watcher]) {
    watcher ??= Object();
    final listener = new NetworkListener(callback);
    _listeners[watcher] = listener;
  }

  bool pop(Object id) {
    if (!_listeners.containsKey(id)) return false;

    _listeners.remove(id);

    return true;
  }
}
