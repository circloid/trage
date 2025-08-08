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

import 'package:client/entity/enemy.dart';
import 'package:client/network/network.dart';
import 'package:shared/shared.dart';

import 'entity/player_client.dart';
import 'renderer.dart';
import 'ui/dartboard.dart';

class GameState {
  GameState(this.ui, [this.fps = 100]);

  final int fps;
  final Dartboard ui;
  final Semaphore _lock = Semaphore();
  late PlayerClient player;
  late Renderer renderer;

  String get uid => identityHashCode(this).toString();

  Future<void> setup() async {
    renderer = global.get<Renderer>();

    renderer.setup();

    ui.clear();
    ui.hide();

    await menu();

    global.get<Network>().listen(_incomingPacket);

    player = PlayerClient(Vect(2, 2));
    renderer.put(player);
  }

  void loop() {
    final r = ui.rect.copy;
    r.vect += Vect(1, 1);
    // ui.rectangle(r);

    Timer.periodic(
      Duration(milliseconds: (1000 / fps).round()),
      (_) => _internalLoop(renderer),
    );
  }

  void _incomingPacket(Packet p) {
    ui.move(ui.rect.bottomLeft - Vect(-2, 10));
    ui.out(p.body);
    switch (p.cmd) {
      case PacketCommand.tick:
        _handleServerTick(p.body);
        break;
      default:
        break;
    }
  }

  void _handleServerTick(String body) {
    // print(body);
    final entities = body.split(';');
    for (final entity in entities) {
      print(entity);
      _handleEntityUpdate(entity);
    }
  }

  void _handleEntityUpdate(String entity) {
    // print('Dai entity $entity');
    final id = toInt(entity.substring(0, 2).codeUnits);
    final pos = entity.substring(3);
    if (!renderer.containsId(id)) {
      final e = Enemy(Vect.deserialize(pos));
      e.id = id;
      renderer.put(e);
    }
  }

  int toInt(List<int> bytes) {
    int res = 0;
    for (int i = 0; i < bytes.length; i++) {
      res += (bytes[i] | 0x100) << (bytes.length - i - 1);
    }
    return res;
  }

  Future<void> _internalLoop(Renderer renderer) async {
    await _lock.acquire();
    // ui.bg(Vect(2, 2), ui.width.toInt() - 2, ui.height.toInt() - 30);
    renderer.render(this);
    _lock.release();
  }

  void quick() {
    final p = Packet(PacketCommand.join);
    final net = global.get<Network>();
    net.send(p);
  }

  void join() {}
  void create() {}

  Future<void> menu() async {
    final String title = ui.style.primary('\$ trage');
    final List<FutureOr<void> Function()> funcs = [quick, join, create];
    final List<String> choices = [
      ui.style.warning('  1 - Quick Play  '),
      ui.style.secondary('  2 -Join Room  '),
      ui.style.error('  3 - Create Room  '),
    ];
    final choice = await ui.dialog(choices, ui.rect - 10, title: title);
    funcs[choice]();
  }
}
