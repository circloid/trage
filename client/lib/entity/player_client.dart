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
import 'package:client/entity/bullet.dart';
import 'package:client/entity/entity.dart';
import 'package:client/network/network.dart';
import 'package:shared/shared.dart';

import '../game_state.dart';
import '../renderer.dart';

class PlayerClient extends Entity {
  PlayerClient(super.position, {this.isLocalPlayer = false});

  int direction = 0; // 0=right, 1=down, 2=left, 3=up
  double speed = 1.0;
  int lastShotFrame = 0;
  int shotCooldown = 30; // 30 frames between shots (0.5 seconds at 60fps)
  bool isLocalPlayer; // Distinguish local player from other players

  static final _chars = ['▶', '▼', '◀', '▲'];
  static final _otherPlayerChars = [
    '→',
    '↓',
    '←',
    '↑',
  ]; // Different arrows for other players
  static final _directions = [
    0,
    pi / 2,
    pi,
    3 * pi / 2,
  ]; // Radians for each direction

  @override
  void onInit(Renderer renderer) {
    super.onInit(renderer);

    // Movement keys
    final movements = {
      'd': 0, // Right
      's': 1, // Down
      'a': 2, // Left
      'w': 3, // Up
    };

    for (final MapEntry(:key, :value) in movements.entries) {
      renderer.registerKeyMap(key, () => _move(value));
    }

    // Shooting
    renderer.registerKeyMap(' ', fire);

    // Alternative shooting keys
    renderer.registerKeyMap('j', fire);
  }

  void fire() {
    // Check cooldown
    if (currentFrameCount - lastShotFrame < shotCooldown) return;

    lastShotFrame = currentFrameCount;

    // Send shot command to server
    final net = global.get<Network>();
    final p = Packet(PacketCommand.shot, body: direction.toString());
    net.send(p);

    // Create local bullet for immediate feedback
    _createLocalBullet();
  }

  void _createLocalBullet() {
    final gameState = global.get<GameState>();
    final bulletDirection = _directions[direction];

    // Spawn bullet slightly in front of player
    final spawnOffset = Vect.fromAngle(bulletDirection) * 2;
    final bulletPosition = position + spawnOffset;

    final bullet = Bullet(
      bulletPosition,
      bulletDirection,
      ownerId: id,
      style: gameState.ui.style.warning,
    );

    gameState.renderer.put(bullet);
  }

  void _move(int newDirection) {
    direction = newDirection;

    // Calculate new position
    final moveVector = _getDirectionVector(direction) * speed;
    final newPos = position + moveVector;

    // Get game bounds
    final gameState = global.get<GameState>();
    final bounds = gameState.ui.rect;

    // Apply boundary checking
    final clampedPos = newPos.clamp(
      Vect(2, 2), // Leave space for UI borders
      Vect(bounds.width - 7, bounds.height - 5), // Account for player size
    );

    position = clampedPos;
    _sendMovement();
  }

  Vect _getDirectionVector(int dir) {
    switch (dir) {
      case 0:
        return Vect(1, 0); // Right
      case 1:
        return Vect(0, 1); // Down
      case 2:
        return Vect(-1, 0); // Left
      case 3:
        return Vect(0, -1); // Up
      default:
        return Vect.zero;
    }
  }

  @override
  void draw(GameState state) {
    final ui = state.ui;

    if (isLocalPlayer) {
      // Draw local player as 3x3 green triangles
      ui.move(position);
      ui.out(ui.style.success('▲'));
      ui.move(position + Vect(-1, 1));
      ui.out(ui.style.success('▲'));
      ui.move(position + Vect(1, 1));
      ui.out(ui.style.success('▲'));
      ui.move(position + Vect(0, 1));
      ui.out(ui.style.success('▲'));
    } else {
      // Draw other players as 3x3 yellow arrows
      final char = _otherPlayerChars[direction];
      ui.move(position);
      ui.out(ui.style.warning(char));
      ui.move(position + Vect(-1, 1));
      ui.out(ui.style.warning(char));
      ui.move(position + Vect(1, 1));
      ui.out(ui.style.warning(char));
      ui.move(position + Vect(0, 1));
      ui.out(ui.style.warning(char));
    }
  }

  @override
  void update() {
    super.update();
    // Any continuous updates for the player
  }

  void _sendMovement() {
    final net = global.get<Network>();
    // Send position data with player ID to avoid conflicts
    final positionData = '${direction}:${position.serialize()}:${id}';
    final p = Packet(PacketCommand.move, body: positionData);
    net.send(p);
  }
}
