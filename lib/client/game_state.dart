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

import 'package:trage/client/entity/player.dart';
import 'package:trage/client/network/network.dart';
import 'package:trage/client/renderer.dart';
import 'package:trage/client/ui/dartboard.dart';
import 'package:trage/shared/semaphore.dart';

import 'package:trage/shared/shapes/vect.dart';

class GameState {
  GameState(this.net, this.ui, [this.fps = 100]);

  final int fps;
  final Dartboard ui;
  final Network net;
  final Renderer renderer = Renderer();

  final Semaphore _lock = Semaphore();

  Player? get player => renderer.get<Player>();

  void setup() {
    ui.hide();
    ui.clear();
    renderer.setup();
    renderer.put(new Player(Vect(2, 2)));
  }

  void loop() {
    final r = ui.rect.copy;
    r.vect += Vect(1, 1);
    ui.rectangle(r);

    Timer.periodic(Duration(milliseconds: (1000 / fps).round()), _internalLoop);
  }

  Future<void> _internalLoop(Timer t) async {
    await _lock.acquire();
    ui.bg(Vect(2, 2), ui.width.toInt() - 2, ui.height.toInt() - 1);
    renderer.render(this);
    _lock.release();
  }
}
