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
OF THIS SOFTWARE, EXCEPTION IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'package:client/entity/entity.dart';
import 'package:client/game_state.dart';
import 'package:gesso/gesso.dart';
import 'package:shared/shared.dart';

class Bullet extends Entity {
  Bullet(
    super.position,
    this.direction, {
    this.style,
    this.speed = 2.0,
    this.ownerId,
    int maxLifetime = 300, // 5 seconds at 60fps
  }) : super(maxLifetime: maxLifetime);

  final num direction; // Direction in radians
  final double speed;
  final int? ownerId; // ID of the entity that fired this bullet
  Gesso? style;

  static const String _char = '●';

  @override
  void draw(GameState state) {
    final ui = state.ui;

    // Draw bullet as a simple character
    String out = _char;
    if (style != null) out = style!(out);

    ui.move(position);
    ui.out(out);
  }

  @override
  void update() {
    super.update();

    // Move bullet based on direction and speed
    final velocity = Vect.fromAngle(direction) * speed;
    position += velocity;

    // Remove bullet if it goes out of bounds
    if (position.x < 2 ||
        position.x > 150 ||
        position.y < 5 ||
        position.y > 50) {
      markForRemoval();
    }

    // Check collision with enemies (client-side prediction)
    final gameState = global.get<GameState>();
    for (final enemy in gameState.enemies.values) {
      if (hits(enemy)) {
        // Hit an enemy!
        enemy.takeDamage(25);
        markForRemoval();
        gameState.score += 5; // Local score update
        break;
      }
    }
  }

  // Check collision with another entity
  bool hits(Entity target, {double hitRadius = 1.0}) {
    if (target.id == ownerId) return false; // Can't hit owner
    return position.distance(target.position) <= hitRadius;
  }
}

// Bullet manager to handle bullet spawning and collision
class BulletManager {
  final List<Bullet> bullets = [];

  void addBullet(Bullet bullet) {
    bullets.add(bullet);
  }

  void update(GameState state) {
    bullets.removeWhere((bullet) => bullet.shouldRemove);

    // Check for collisions between bullets and other entities
    for (final bullet in bullets) {
      for (final entity in state.renderer.sortedEntities) {
        if (entity is! Bullet && bullet.hits(entity)) {
          // Handle collision
          bullet.markForRemoval();
          // Could add damage/destruction logic here
          break;
        }
      }
    }
  }

  void clear() {
    bullets.clear();
  }
}
