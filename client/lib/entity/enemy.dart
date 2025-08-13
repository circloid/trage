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

import 'package:client/entity/entity.dart';
import 'package:client/game_state.dart';
import 'package:shared/shared.dart';

class Enemy extends Entity {
  Enemy(super.position);
  int direction = 0;
  int health = 100;
  static final _chars = ['R', 'D', 'L', 'U']; // Right, Down, Left, Up

  void fire() {}

  @override
  void draw(GameState state) {
    final ui = state.ui;

    // Draw enemy as 3x3 red arrows
    final char = _chars[direction];
    if (health > 50) {
      // Healthy enemy - solid red
      ui.move(position);
      ui.out(ui.style.error(char));
      ui.move(position + Vect(-1, 1));
      ui.out(ui.style.error(char));
      ui.move(position + Vect(1, 1));
      ui.out(ui.style.error(char));
      ui.move(position + Vect(0, 1));
      ui.out(ui.style.error(char));
    } else if (health > 0) {
      // Damaged enemy - yellow
      ui.move(position);
      ui.out(ui.style.warning(char));
      ui.move(position + Vect(-1, 1));
      ui.out(ui.style.warning(char));
      ui.move(position + Vect(1, 1));
      ui.out(ui.style.warning(char));
      ui.move(position + Vect(0, 1));
      ui.out(ui.style.warning(char));
    } else {
      // Dead enemy - gray X
      ui.move(position);
      ui.out(ui.style.secondary('X'));
    }
  }

  void takeDamage(int damage) {
    health -= damage;
    if (health < 0) health = 0;

    if (health <= 0) {
      markForRemoval();
    }
  }

  @override
  void update() {
    super.update();
    // Add any enemy-specific update logic here
  }
}
