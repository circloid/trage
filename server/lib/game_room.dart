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

import 'dart:math';
import 'package:server/network/client_connection.dart';
import 'package:server/player_server.dart';
import 'package:server/update.dart';
import 'package:server/entity.dart';
import 'package:shared/shared.dart';

class ServerBullet extends Entity {
  ServerBullet(super.vect, this.direction, this.ownerId, {this.speed = 2.0});

  final double direction; // In radians
  final String ownerId;
  final double speed;
  bool shouldRemove = false;

  void update() {
    // Move bullet
    final velocity = Vect.fromAngle(direction) * speed;
    vect += velocity;

    // Remove if out of bounds
    if (vect.x < 0 || vect.x > 200 || vect.y < 0 || vect.y > 60) {
      shouldRemove = true;
    }
  }
}

class Room {
  Room(this.id);
  factory Room.quick() => Room(identityHashCode(Object()).toString());

  static const int _maxPlayerCount = 8;
  static final Vect _mapSize = Vect(200, 60);

  final String id;
  bool open = true;
  bool gameStarted = false;
  final Map<String, PlayerServer> clients = {};
  final List<Update> updates = [];
  final List<ServerBullet> bullets = [];

  int _gameFrame = 0;

  Iterable<ClientConnection> get connections {
    return clients.values.map((v) => v.connection);
  }

  bool get isFull => clients.length >= _maxPlayerCount;
  bool get isEmpty => clients.isEmpty;

  bool isValidClient(String uid) => clients.containsKey(uid);

  bool canStart() => clients.length > 0;

  void startGame() {
    gameStarted = true;
    print('Game started in room $id with ${clients.length} players');
  }

  bool participate(String uid) => clients.containsKey(uid);

  PlayerServer? join(ClientConnection conn) {
    if (isFull) {
      return null;
    }

    if (!clients.containsKey(conn.id)) {
      // Spawn player at random safe position
      final spawnPos = _getRandomSpawnPosition();
      final player = PlayerServer(spawnPos, conn);

      // Create a unique, deterministic ID for this player
      // Use connection string hash to ensure consistency
      final connectionHash = conn.id.hashCode.abs();
      player.id = (connectionHash % 60000) + 1000; // Range: 1000-61000

      clients[conn.id] = player;

      // Add spawn update for this specific player
      final spawnUpdate = Update(
        player,
        2,
        player.vect.serialize(),
      ); // Type 2 = spawn
      updates.add(spawnUpdate);
    }
    return clients[conn.id]!;
  }

  Vect _getRandomSpawnPosition() {
    final random = Random();
    // Keep players away from edges
    return Vect(
      10 + random.nextDouble() * (_mapSize.x - 20),
      10 + random.nextDouble() * (_mapSize.y - 20),
    );
  }

  bool removePlayer(String uid) {
    if (!clients.containsKey(uid)) return false;

    final player = clients.remove(uid)!;

    // Add destroy update for all other players
    final destroyUpdate = Update(player, 3, ''); // Type 3 = destroy
    updates.add(destroyUpdate);

    return true;
  }

  void updatePlayerPosition(String uid, int direction, Vect position) {
    if (!participate(uid)) return;

    // CRITICAL: Only update the player that corresponds to this UID
    final player = clients[uid]!;

    // Store old values to check for changes
    final oldPos = player.vect.copy;
    final oldDir = player.direction;

    // Validate and clamp position
    final clampedPos = position.clamp(Vect(2, 2), _mapSize - Vect(7, 5));

    // Update ONLY this specific player
    player.vect = clampedPos;
    player.direction = direction;

    // Only add update if something actually changed
    if (oldPos.x != clampedPos.x ||
        oldPos.y != clampedPos.y ||
        oldDir != direction) {
      // Create update ONLY for this specific player
      final update = Update(player, 1, player.vect.serialize());
      updates.add(update);
    }
  }

  void updatePlayerDirection(String uid, int direction) {
    if (!participate(uid)) return;

    // CRITICAL: Only update the player that corresponds to this UID
    final player = clients[uid]!;
    final oldPos = player.vect.copy;
    final oldDirection = player.direction;

    // Update direction and move
    player.move(direction);

    // Clamp to map bounds
    player.vect = player.vect.clamp(Vect(2, 2), _mapSize - Vect(7, 5));

    // Only add update if position or direction changed
    if (oldPos.x != player.vect.x ||
        oldPos.y != player.vect.y ||
        oldDirection != player.direction) {
      // Create update ONLY for this specific player
      final update = Update(player, 1, player.vect.serialize());
      updates.add(update);
    }
  }

  void handlePlayerShot(String uid, int direction) {
    if (!participate(uid)) return;

    final player = clients[uid]!;

    // Create bullet
    final directionRadians = (direction * pi / 2); // Convert 0-3 to radians
    final bulletPos = player.vect + Vect.fromAngle(directionRadians) * 3;

    final bullet = ServerBullet(bulletPos, directionRadians, uid);
    bullets.add(bullet);

    print('Player $uid shot bullet in direction $direction');
  }

  void update() {
    _gameFrame++;

    // Update bullets
    bullets.removeWhere((bullet) => bullet.shouldRemove);
    for (final bullet in bullets) {
      bullet.update();

      // Check bullet collisions with players
      for (final player in clients.values) {
        if (player.connection.id != bullet.ownerId &&
            bullet.vect.distance(player.vect) < 3.0) {
          // Hit! Remove bullet and handle damage
          bullet.shouldRemove = true;
          _handlePlayerHit(player, bullet);
          break;
        }
      }
    }

    // Add bullet updates
    for (final bullet in bullets) {
      if (!bullet.shouldRemove) {
        final update = Update(bullet, 1, bullet.vect.serialize());
        updates.add(update);
      }
    }
  }

  void _handlePlayerHit(PlayerServer player, ServerBullet bullet) {
    print(
      'Player ${player.connection.id} hit by bullet from ${bullet.ownerId}',
    );

    // For now, just respawn the player at a new location
    player.vect = _getRandomSpawnPosition();
    final respawnUpdate = Update(player, 1, player.vect.serialize());
    updates.add(respawnUpdate);
  }

  List<Update> maximizeLength(int max) {
    final List<Update> res = [];
    int len = 0;
    for (final u in updates) {
      final serialized = u.serialize();
      len += serialized.length + 1; // +1 for separator
      if (len > max) {
        return res;
      }
      res.add(u);
    }
    return res;
  }

  Packet? getUpdates() {
    // Run game update
    if (gameStarted) {
      update();
    }

    final up = maximizeLength(Packet.bodyLength - 100); // Leave some buffer

    if (up.isEmpty) return null;

    final body = up.map((e) => e.serialize()).join(';');

    // Remove processed updates
    updates.removeRange(0, up.length);

    final Packet p = Packet(PacketCommand.tick, body: body);
    return p;
  }
}
