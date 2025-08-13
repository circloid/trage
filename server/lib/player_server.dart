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
import 'package:shared/shared.dart';
import './entity.dart';

class PlayerServer extends Entity {
  PlayerServer(super.vect, this.connection);

  double speed = 1.0;
  int direction = 0; // 0=right, 1=down, 2=left, 3=up
  ClientConnection connection;

  // Player stats
  int health = 100;
  int maxHealth = 100;
  int score = 0;
  int lastShotFrame = 0;
  int shotCooldown = 30; // Frames between shots

  // Movement tracking
  Vect lastPosition = Vect.zero;
  int framesSinceLastMove = 0;

  void move(int newDirection) {
    direction = newDirection;
    lastPosition = vect.copy;

    // Calculate movement vector
    final moveVector = _getDirectionVector(direction) * speed;
    vect += moveVector;

    framesSinceLastMove = 0;
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

  bool canShoot(int currentFrame) {
    return currentFrame - lastShotFrame >= shotCooldown;
  }

  void shoot(int currentFrame) {
    if (canShoot(currentFrame)) {
      lastShotFrame = currentFrame;
    }
  }

  void takeDamage(int damage) {
    health -= damage;
    if (health < 0) health = 0;
  }

  void heal(int amount) {
    health += amount;
    if (health > maxHealth) health = maxHealth;
  }

  bool get isAlive => health > 0;

  void respawn(Vect spawnPosition) {
    vect = spawnPosition;
    health = maxHealth;
    direction = 0;
    framesSinceLastMove = 0;
  }

  void update() {
    framesSinceLastMove++;

    // Apply any continuous effects here
    // For example, regeneration or status effects
  }

  // Get direction as radians for bullet spawning
  double get directionRadians => direction * pi / 2;

  // Get position in front of player for bullet spawning
  Vect get frontPosition => vect + _getDirectionVector(direction) * 2;

  @override
  String toString() {
    return 'PlayerServer(id: ${connection.id}, pos: $vect, health: $health, direction: $direction)';
  }
}
