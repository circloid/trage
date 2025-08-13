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

import 'package:server/player_server.dart';
import 'package:shared/shared.dart';

import '../game_room.dart';
import 'client_connection.dart';

class Network {
  Network({required this.socket, required this.host, required this.port});

  static Future<Network> bind(InternetAddress host, int port) async {
    final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    s.broadcastEnabled = true;
    final net = Network(socket: s, host: host, port: port);
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
    for (final client in clients) {
      send(p, client);
    }
  }

  void send(Packet p, ClientConnection client) {
    try {
      socket.send(p.serialize(), client.addr, client.port);
    } catch (e) {
      _handleClientDisconnect(client);
    }
  }

  void _handleClientDisconnect(ClientConnection client) {
    _clients.remove(client.id);

    // Remove from all rooms
    for (final room in _rooms.values) {
      if (room.removePlayer(client.id)) {
        // Notify other players
        final leavePacket = Packet(PacketCommand.playerLeft, body: client.id);
        multicast(leavePacket, room.connections);
      }
    }
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

        try {
          final client = _createClientIfAbsent(datagram);
          final p = Packet.deserialize(datagram.data);
          await _handleRequest(client, p);
        } catch (e, stack) {
          // Silent error handling - don't print to avoid UI issues
        }
        break;

      default:
        break;
    }
  }

  Future<void> _handleRequest(ClientConnection sender, Packet packet) async {
    try {
      switch (packet.cmd) {
        case PacketCommand.join:
          await joinRoom(sender, packet);
          break;
        case PacketCommand.move:
          await movePlayer(sender, packet);
          break;
        case PacketCommand.shot:
          await handleShot(sender, packet);
          break;
        case PacketCommand.leave:
          await handleLeave(sender, packet);
          break;
        default:
          print('Unhandled packet command: ${packet.cmd.name}');
          break;
      }
    } catch (e, stack) {
      print('Error handling request: $e');
      print(stack);
    }
  }

  Future<void> joinRoom(ClientConnection sender, Packet packet) async {
    final roomId = packet.body.trim();
    Room room;

    if (roomId.isEmpty) {
      room = quickJoin();
    } else {
      if (!_rooms.containsKey(roomId)) {
        // Send error back to client
        final errorPacket = Packet(
          PacketCommand.leave,
          body: 'Room not found: $roomId',
        );
        send(errorPacket, sender);
        return;
      }
      room = _rooms[roomId]!;
    }

    final player = room.join(sender);
    if (player != null) {
      // Send existing players to new player
      for (final existingPlayer in room.clients.values) {
        if (existingPlayer.connection.id != sender.id) {
          final spawnPacket = Packet(
            PacketCommand.tick,
            body: _createPlayerSpawnUpdate(existingPlayer),
          );
          send(spawnPacket, sender);
        }
      }

      // Send new player to existing players
      final newPlayerSpawn = Packet(
        PacketCommand.tick,
        body: _createPlayerSpawnUpdate(player),
      );
      for (final existingPlayer in room.clients.values) {
        if (existingPlayer.connection.id != sender.id) {
          send(newPlayerSpawn, existingPlayer.connection);
        }
      }

      // Start game if enough players
      if (room.canStart() && !room.gameStarted) {
        room.startGame();
        final startPacket = Packet(PacketCommand.gameStart);
        multicast(startPacket, room.connections);
      }
    }
  }

  String _createPlayerSpawnUpdate(PlayerServer player) {
    // Create spawn update: ID(2bytes) + Type(2=spawn) + position data
    final idBytes = player.id.bit(2);
    final typeBytes = [2]; // Type 2 = spawn
    final posData = player.vect.serialize();

    return String.fromCharCodes([...idBytes, ...typeBytes]) + posData;
  }

  Room quickJoin() {
    Room? freeRoom = firstFreeRoom();
    if (freeRoom == null) {
      freeRoom = Room.quick();
      print('Created new room: ${freeRoom.id}');
      _rooms[freeRoom.id] = freeRoom;
    }
    return freeRoom;
  }

  Room? firstFreeRoom() {
    for (final room in _rooms.values) {
      if (room.open && !room.isFull) return room;
    }
    return null;
  }

  Future<void> movePlayer(ClientConnection sender, Packet packet) async {
    final room = getRoomByClientId(sender);
    if (room == null) {
      return;
    }

    try {
      // Parse movement data: "direction:x:y:playerID" or just "direction"
      final parts = packet.body.split(':');
      if (parts.length >= 3) {
        final direction = int.parse(parts[0]);
        final x = int.parse(parts[1]);
        final y = int.parse(parts[2]);

        // Only update this specific player
        room.updatePlayerPosition(
          sender.id,
          direction,
          Vect(x.toDouble(), y.toDouble()),
        );
      } else {
        // Fallback to old format
        final direction = int.parse(packet.body);
        room.updatePlayerDirection(sender.id, direction);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> handleShot(ClientConnection sender, Packet packet) async {
    final room = getRoomByClientId(sender);
    if (room == null) {
      print('Player ${sender.id} not found in any rooms for shooting');
      return;
    }

    try {
      final direction = int.parse(packet.body);
      room.handlePlayerShot(sender.id, direction);
    } catch (e) {
      print('Error handling shot: $e');
    }
  }

  Future<void> handleLeave(ClientConnection sender, Packet packet) async {
    final room = getRoomByClientId(sender);
    if (room != null) {
      room.removePlayer(sender.id);

      // Notify other players
      final leavePacket = Packet(PacketCommand.playerLeft, body: sender.id);
      multicast(leavePacket, room.connections);

      // Remove empty rooms
      if (room.isEmpty) {
        _rooms.remove(room.id);
        print('Removed empty room: ${room.id}');
      }
    }

    _clients.remove(sender.id);
  }

  Room? getRoomByClientId(ClientConnection sender) {
    for (final room in _rooms.values) {
      if (room.participate(sender.id)) return room;
    }
    return null;
  }

  // Cleanup method for server shutdown
  void cleanup() {
    death();
    socket.close();
    _clients.clear();
    _rooms.clear();
  }
}
