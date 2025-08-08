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

import 'package:shared/shared.dart';

import '../game_room.dart';
import 'client_connection.dart';

class Network {
  Network({required this.socket, required this.host, required this.port});
  static Future<Network> bind(InternetAddress host, int port) async {
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    s.broadcastEnabled = true;
    final net = new Network(socket: s, host: host, port: port);
    s.listen(net._listenSocketDatagram);
    return net;
  }

  final InternetAddress host;
  final RawDatagramSocket socket;
  final Map<String, ClientConnection> _clients = {};
  final Map<String, Room> _rooms = {};
  final int port;
  Timer? _timer;

  void heartbeat(int fps) {
    final delta = Duration(milliseconds: (1000 / fps).round());
    _timer = Timer.periodic(delta, _publishChanges);
  }

  void death() => _timer?.cancel();

  void _publishChanges(_) {
    for (final room in _rooms.values) {
      final packet = room.getUpdates();
      if (packet == null) continue;
      multicast(packet, room.connections);
    }
  }

  void multicast(Packet p, Iterable<ClientConnection> clients) {
    print('******* MULTICAST *******');
    for (final client in clients) {
      send(p, client);
    }
    print('***** END MULTICAST *****');
  }

  void send(Packet p, ClientConnection client) {
    print(p);
    socket.send(p.serialize(), client.addr, client.port);
  }

  ClientConnection _createClientIfAbsent(Datagram datagram) {
    final id = '${datagram.address.address}:${datagram.port}';
    if (!_clients.containsKey(id)) {
      _clients[id] = ClientConnection(datagram.address, datagram.port);
    }
    return _clients[id]!;
  }

  Future<void> _listenSocketDatagram(RawSocketEvent? e) async {
    switch (e) {
      case RawSocketEvent.read:
        final datagram = socket.receive();
        if (datagram == null) break;
        final client = _createClientIfAbsent(datagram);
        final p = Packet.deserialize(datagram.data);

        print('Deserialized packet from ${client.id}');
        print(p);

        await _handleRequest(client, p);
        break;

      default:
        break;
    }
  }

  Future<void> _handleRequest(ClientConnection sender, Packet packet) async {
    switch (packet.cmd) {
      case PacketCommand.join:
        joinRoom(sender, packet);
        break;
      case PacketCommand.move:
        movePlayer(sender, packet);
        break;
      default:
        break;
    }
  }

  void joinRoom(ClientConnection sender, Packet packet) {
    final roomId = packet.body;
    print(roomId);
    Room room;
    if (roomId.isEmpty) {
      room = quickJoin();
    } else {
      if (!_rooms.containsKey(roomId)) {
        throw Exception('Room id not found. Try again...');
      }
      room = _rooms[roomId]!;
      print('Room: $roomId created');
    }
    room.join(sender);
  }

  Room quickJoin() {
    Room? freeRoom = firstFreeRoom();
    if (freeRoom == null) {
      freeRoom = Room.quick();
      print(freeRoom.id);
      _rooms[freeRoom.id] = freeRoom;
    }
    return freeRoom;
  }

  Room? firstFreeRoom() {
    for (final room in _rooms.values) {
      print(room.id);
      if (room.open && !room.isFull) return room;
    }
    return null;
  }

  Future<void> movePlayer(ClientConnection sender, Packet packet) async {
    final room = getRoomByClientId(sender);
    if (room == null) {
      print('Player ${sender.id} not found in any rooms');
      return;
    }
    if (packet.body.length != 1) {
      print('Missing direction in the packet');
      return;
    }
    final direction = packet.body.codeUnitAt(0);
    room.updatePlayerPosition(sender.id, direction);
  }

  Room? getRoomByClientId(ClientConnection sender) {
    for (final room in _rooms.values) {
      if (room.partecipate(sender.id)) return room;
    }
    return null;
  }
}
