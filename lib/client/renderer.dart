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

import 'dart:io';

import 'package:trage/client/game_state.dart';
import 'package:trage/client/keymap.dart';
import 'package:trage/shared/models/entity/entity.dart';
import 'package:trage/shared/models/entity/entity_state.dart';

class Renderer {
  /// It represents the entire objects that should be rendered in the canvas
  final Set<Entity> _entities = {};
  final List<Entity> _sortedEntities = [];
  final List<KeymapListener> _keymaps = [];
  final List<RawkeyListener> _rawkeyListener = [];

  void setup() {
    stdin.lineMode = false;
    stdin.echoMode = false;
    stdin.listen(_onKeyboardInput);
  }

  void put(Entity e) {
    e.onInit(this);
    e.transition(EntityState.active);

    if (_entities.contains(e)) return;

    _insertSortedKey(e);
  }

  T? get<T extends Entity>() {
    for (final e in _entities) {
      if (e is T) return e;
    }
    return null;
  }

  bool contains<T extends Entity>() => get<T>() != null;

  void render(GameState state) {
    for (final entity in _sortedEntities) {
      entity.draw(state);
      entity.update();
    }
  }

  bool del(Entity entity) {
    final removed = _entities.remove(entity);
    if (!removed) return false;
    _removeEntity(entity);
    return true;
  }

  Future<void> _insertSortedKey(Entity e) async {
    int index = 0;

    _entities.add(e);

    for (; index < _sortedEntities.length; index++) {
      if (_entities.elementAt(index).priority >= e.priority) break;
    }
    _sortedEntities.insert(index, e);
  }

  Future<void> _removeEntity(Entity entity) async {
    final removed = _entities.remove(entity);
    if (removed) {
      entity.dispose();
    }
    _sortedEntities.remove(entity);
  }

  void registerKeyMap(String char, KeymapCallback on) {
    if (char.length != 1) {
      throw Exception('\'$char\' must be contains only 1 character');
    }
    newKeyMap(char.codeUnits, on);
  }

  void newKeyMap(List<int> key, KeymapCallback on) {
    _keymaps.add(KeymapListener(key, on));
  }

  void registerRawKey(RawkeyListener listener) => _rawkeyListener.add(listener);

  Future<void> _onKeyboardInput(List<int> buffer) async {
    // await _lock.acquire();
    try {
      buffer = List.unmodifiable(buffer);
      for (final raw in _rawkeyListener) {
        raw(buffer);
      }
      for (final keymap in _keymaps) {
        if (!keymap.equals(buffer)) continue;
        keymap.on();
      }
    } finally {}
  }

  void dispose() {
    _rawkeyListener.clear();
    _keymaps.clear();
    _entities.clear();
    _sortedEntities.clear();
  }
}
