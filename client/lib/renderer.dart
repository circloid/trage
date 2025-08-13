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
import 'dart:io';

import 'package:client/entity/entity.dart';
import 'package:client/entity/entity_state.dart';
import 'package:shared/shared.dart';

import 'game_state.dart';
import 'keymap.dart';

class Renderer {
  /// It represents the entire objects that should be rendered in the canvas
  final Map<int, Entity> _entities = {};
  final List<Entity> sortedEntities = [];
  final Map<Object, KeymapListener> _keymaps = {};
  final List<RawkeyListener> _rawkeyListener = [];

  void setup() {
    stdin.echoMode = false;
    stdin.lineMode = false;
    stdin.listen(_onKeyboardInput);
  }

  void put(Entity e) {
    if (_entities.containsKey(e.id)) return;

    _entities[e.id] = e;

    e.onInit(this);
    e.transition(EntityState.active);

    _insertSortedKey(e);
  }

  Entity get(int id) => _entities[id]!;

  bool contains(Entity e) => containsId(e.id);

  bool containsId(int id) => _entities.containsKey(id);

  void render(GameState state) {
    // Clean up entities marked for removal first
    _cleanupMarkedEntities();

    // Render all active entities
    for (final entity in sortedEntities) {
      if (entity.state == EntityState.active) {
        try {
          entity.draw(state);
          entity.update();
        } catch (e) {
          print('Error rendering entity ${entity.id}: $e');
          entity.markForRemoval();
        }
      }
    }
  }

  void _cleanupMarkedEntities() {
    final toRemove = <Entity>[];

    for (final entity in sortedEntities) {
      if (entity.shouldRemove || entity.state == EntityState.disposed) {
        toRemove.add(entity);
      }
    }

    for (final entity in toRemove) {
      _removeEntity(entity);
    }
  }

  bool del(Entity entity) {
    final removed = _entities.remove(entity.id);
    if (removed == null) return false;
    _removeEntity(entity);
    return true;
  }

  Future<void> _insertSortedKey(Entity e) async {
    int index = 0;

    _entities[e.id] = e;

    for (; index < sortedEntities.length; index++) {
      if (sortedEntities[index].priority >= e.priority) break;
    }
    sortedEntities.insert(index, e);
  }

  Future<void> _removeEntity(Entity entity) async {
    _entities.remove(entity.id);
    sortedEntities.remove(entity);

    if (entity.state != EntityState.disposed) {
      entity.dispose();
    }
  }

  Object registerKeyMap(String char, KeymapCallback on) {
    if (char.length != 1) {
      throw Exception('\'$char\' must contain only 1 character');
    }
    return newKeyMap(char.codeUnits, on);
  }

  Object newKeyMap(List<int> key, KeymapCallback on) {
    final id = Object();
    _keymaps[id] = (KeymapListener(key, on));
    return id;
  }

  void removeKeyMap(Object id) {
    _keymaps.remove(id);
  }

  Future<void> onceKeyCode(List<int> code, KeymapCallback on) async {
    final c = Completer<void>();
    final obj = newKeyMap(code, () {
      on();
      c.complete();
    });
    await c.future;
    removeKeyMap(obj);
  }

  void registerRawKey(RawkeyListener listener) => _rawkeyListener.add(listener);

  Future<void> _onKeyboardInput(List<int> buffer) async {
    try {
      buffer = List.unmodifiable(buffer);

      // Handle raw key listeners first
      for (final raw in _rawkeyListener) {
        try {
          raw(buffer);
        } catch (e) {
          print('Error in raw key listener: $e');
        }
      }

      // Handle keymap listeners
      for (final keymap in _keymaps.values) {
        if (!keymap.equals(buffer)) continue;
        try {
          keymap.on();
        } catch (e) {
          print('Error in keymap callback: $e');
        }
      }
    } catch (e) {
      print('Error processing keyboard input: $e');
    }
  }

  void onReceivePacket(Packet packet) {
    // Handle any renderer-specific packet processing here
    // This could include entity spawn/destroy commands
  }

  void dispose() {
    // Clean up all entities
    for (final entity in sortedEntities.toList()) {
      entity.dispose();
    }

    _rawkeyListener.clear();
    _keymaps.clear();
    _entities.clear();
    sortedEntities.clear();
  }

  // Helper methods for debugging and monitoring
  int get entityCount => _entities.length;

  List<Entity> getEntitiesByType<T>() {
    return sortedEntities.whereType<T>().cast<Entity>().toList();
  }

  void printEntityStats() {
    print('Renderer Stats:');
    print('  Total entities: ${_entities.length}');
    print(
      '  Active entities: ${sortedEntities.where((e) => e.state == EntityState.active).length}',
    );
    print(
      '  Disposed entities: ${sortedEntities.where((e) => e.state == EntityState.disposed).length}',
    );
  }
}
