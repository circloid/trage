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

import 'package:server/network/client_connection.dart';
import 'package:server/player_server.dart';
import 'package:server/update.dart';
import 'package:shared/shared.dart';

class Room {
  Room(this.id);
  factory Room.quick() => Room(identityHashCode(Object()).toString());
  static const int _maxPlayerCount = 8;
  final String id;
  bool open = true;
  final Map<String, PlayerServer> clients = {};
  final List<Update> updates = [];

  Iterable<ClientConnection> get connections {
    return clients.values.map((v) => v.connection);
  }

  bool get isFull => open && clients.length >= _maxPlayerCount;

  bool isValidClient(String uid) => clients.containsKey(uid);

  bool canStart() => clients.length > 0;

  void start() {
    open = true;
    // send packets and stuff
  }

  bool partecipate(String uid) => clients.containsKey(uid);

  PlayerServer join(ClientConnection conn) {
    if (!clients.containsKey(conn.id)) {
      print('added to room $id player ${conn.id}');
      clients[conn.id] = PlayerServer(Vect.random(), conn);
    }
    return clients[conn.id]!;
  }

  void updatePlayerPosition(String uid, int direction) {
    if (!partecipate(uid)) {
      print('Player $uid not found in the room $id');
      return;
    }
    final player = clients[uid]!;

    player.move(direction);
    final update = Update(player, 1, player.vect.serialize());
    updates.add(update);
  }

  List<Update> maximiseLength(int max) {
    final List<Update> res = [];
    int len = 0;
    for (final u in updates) {
      len += u.serialize().length;
      if (len > max) {
        return res;
      }
      res.add(u);
    }
    return res;
  }

  Packet? getUpdates() {
    final up = maximiseLength(Packet.bodyLength);

    if (up.isEmpty) return null;

    final body = up.map((e) => e.serialize()).join(';');

    updates.removeRange(0, up.length);
    final Packet p = Packet(PacketCommand.tick, body: body);

    return p;
  }
}
