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
import 'package:shared/shared.dart';

import '../game_state.dart';
import '../renderer.dart';

class PlayerClient extends Entity {
  PlayerClient(super.position);
  int direction = 0;
  static final _chars = ['▶', '▼', '◀', '▲'];

  @override
  void onInit(Renderer renderer) {
    super.onInit(renderer);
    final movements = {'d': 0, 'w': -1 / 2, 'a': 1, 's': 1 / 2};

    for (final MapEntry(:key, :value) in movements.entries) {
      renderer.registerKeyMap(key, () => _move(value));
    }
    renderer.registerRawKey((buf) {});
  }

  void _move(num angle) {
    // final net = global.get<Network>();
    direction = (angle * 2).floor();
    if (direction < 0) direction = direction + 4;
    direction %= 4;
    position += Vect.fromAngle(angle);
    _sendMovement();
  }

  void draw(GameState state) {
    final r = new Rect(position, 5, 3);
    final ui = state.ui;
    ui.rectangle(r, ui.style.primary);
    ui.move(r.center - Vect(1, 1));
    ui.out(_chars[direction]);
  }

  void update() {}

  void _sendMovement() {
    // final net = global.get<Network>();
    // final p = Packet(Command.move, body: direction.toString());
    // net.send(p);
  }
}
