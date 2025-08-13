// TEMPORARY DEBUG VERSION - Use this to see what's happening with IDs

import 'dart:async';

import 'package:client/entity/enemy.dart';
import 'package:client/entity/entity.dart';
import 'package:client/network/network.dart';
import 'package:shared/shared.dart';

import 'entity/player_client.dart';
import 'renderer.dart';
import 'ui/dartboard.dart';

enum GamePhase { menu, waiting, playing, gameOver }

class GameState {
  GameState(this.ui, [this.fps = 30]);

  final int fps;
  final Dartboard ui;
  final Semaphore _lock = Semaphore();
  late PlayerClient player;
  late Renderer renderer;

  GamePhase currentPhase = GamePhase.menu;
  int score = 0;
  int enemiesDestroyed = 0;
  bool isConnected = false;
  final Map<int, Enemy> enemies = {};
  final Map<int, PlayerClient> otherPlayers = {};

  // Debug info
  final List<String> debugLog = [];
  static const int maxDebugLines = 3;

  void _addDebugLog(String message) {
    debugLog.add(message);
    if (debugLog.length > maxDebugLines) {
      debugLog.removeAt(0);
    }
  }

  String get uid => identityHashCode(this).toString();

  Future<void> setup() async {
    renderer = global.get<Renderer>();
    renderer.setup();

    ui.clear();
    ui.hide();

    await menu();

    final network = global.get<Network>();
    network.listen(_incomingPacket);

    player = PlayerClient(Vect(10, 10), isLocalPlayer: true);
    player.id = 12345; // Fixed ID for testing
    _addDebugLog('Local player ID: ${player.id}');
    renderer.put(player);

    currentPhase = GamePhase.waiting;
  }

  void loop() {
    Timer.periodic(
      Duration(milliseconds: (1000 / fps).round()),
      (_) => _internalLoop(),
    );
  }

  void _incomingPacket(Packet p) {
    switch (p.cmd) {
      case PacketCommand.tick:
        _handleServerTick(p.body);
        break;
      case PacketCommand.playerJoined:
        _handlePlayerJoined(p.body);
        break;
      case PacketCommand.playerLeft:
        _handlePlayerLeft(p.body);
        break;
      case PacketCommand.gameStart:
        _handleGameStart();
        break;
      case PacketCommand.gameEnd:
        _handleGameEnd(p.body);
        break;
      default:
        break;
    }
  }

  void _handleServerTick(String body) {
    if (body.isEmpty) return;

    final entities = body.split(';');
    for (final entity in entities) {
      if (entity.isNotEmpty) {
        _handleEntityUpdate(entity);
      }
    }
  }

  void _handleEntityUpdate(String entity) {
    try {
      if (entity.length < 3) return;

      final idBytes = entity.substring(0, 2).codeUnits;
      final id = _bytesToInt(idBytes);
      final type = entity.codeUnitAt(2);
      final data = entity.substring(3);

      _addDebugLog('Update ID:$id Type:$type (Local:${player.id})');

      // CRITICAL: Skip if this is our own player
      if (id == player.id) {
        _addDebugLog('Skipped self-update');
        return;
      }

      switch (type) {
        case 1: // Position update
          _updateEntityPosition(id, data);
          break;
        case 2: // Entity spawn
          _spawnEntity(id, data);
          break;
        case 3: // Entity destroy
          _destroyEntity(id);
          break;
      }
    } catch (e) {
      _addDebugLog('Parse error: $e');
    }
  }

  void _updateEntityPosition(int id, String posData) {
    try {
      final vect = Vect.deserialize(posData);

      if (otherPlayers.containsKey(id)) {
        otherPlayers[id]!.position = vect;
        _addDebugLog('Updated other player $id');
      } else if (enemies.containsKey(id)) {
        enemies[id]!.position = vect;
        _addDebugLog('Updated enemy $id');
      } else if (renderer.containsId(id)) {
        final entity = renderer.get(id);
        if (entity != player) {
          entity.position = vect;
          _addDebugLog('Updated entity $id');
        }
      }
    } catch (e) {
      _addDebugLog('Update error: $e');
    }
  }

  void _spawnEntity(int id, String data) {
    if (id == player.id) return;

    if (otherPlayers.containsKey(id) ||
        enemies.containsKey(id) ||
        renderer.containsId(id)) {
      _addDebugLog('Entity $id already exists');
      return;
    }

    try {
      final vect = Vect.deserialize(data);

      if (vect.distance(player.position) < 5) {
        vect.x += 10;
      }

      final otherPlayer = PlayerClient(vect, isLocalPlayer: false);
      otherPlayer.id = id;
      otherPlayers[id] = otherPlayer;
      renderer.put(otherPlayer);
      _addDebugLog('Spawned player $id');
    } catch (e) {
      _addDebugLog('Spawn error: $e');
    }
  }

  void _destroyEntity(int id) {
    if (otherPlayers.containsKey(id)) {
      final otherPlayer = otherPlayers.remove(id)!;
      renderer.del(otherPlayer);
      _addDebugLog('Destroyed player $id');
      return;
    }

    if (enemies.containsKey(id)) {
      final enemy = enemies.remove(id)!;
      renderer.del(enemy);
      enemiesDestroyed++;
      score += 10;
      _addDebugLog('Destroyed enemy $id');
    }
  }

  void _handlePlayerJoined(String playerInfo) {}
  void _handlePlayerLeft(String playerInfo) {}
  void _handleGameStart() {
    currentPhase = GamePhase.playing;
  }

  void _handleGameEnd(String result) {
    currentPhase = GamePhase.gameOver;
  }

  int _bytesToInt(List<int> bytes) {
    int res = 0;
    for (int i = 0; i < bytes.length; i++) {
      res = (res << 8) | bytes[i];
    }
    return res;
  }

  Future<void> _internalLoop() async {
    await _lock.acquire();

    try {
      ui.clear();
      ui.move(Vect(1, 1));

      final gameArea = Rect(Vect(1, 3), ui.width - 2, ui.height - 8);
      ui.rectangle(gameArea);

      _drawUI();
      _cleanupEntities();

      for (final entity in renderer.sortedEntities) {
        if (entity.state.name == 'active') {
          if (_isEntityInBounds(entity, gameArea)) {
            entity.draw(this);
          }
        }
        entity.update();
      }

      // Draw debug info
      _drawDebugPanel();

      ui.move(Vect(1, ui.height));
    } finally {
      _lock.release();
    }
  }

  void _drawDebugPanel() {
    final debugY = ui.height - 5;

    ui.move(Vect(1, debugY));
    ui.out(ui.style.secondary('DEBUG:'));

    for (int i = 0; i < debugLog.length; i++) {
      ui.move(Vect(2, debugY + 1 + i));
      ui.out(ui.style.info(debugLog[i]));
    }
  }

  bool _isEntityInBounds(Entity entity, Rect gameArea) {
    return entity.position.x >= gameArea.vect.x &&
        entity.position.x < gameArea.vect.x + gameArea.width &&
        entity.position.y >= gameArea.vect.y &&
        entity.position.y < gameArea.vect.y + gameArea.height;
  }

  void _cleanupEntities() {
    final toRemove = <Entity>[];

    for (final entity in renderer.sortedEntities) {
      if (entity.shouldRemove) {
        toRemove.add(entity);
        if (entity is Enemy) {
          enemies.remove(entity.id);
        } else if (entity is PlayerClient && entity.id != player.id) {
          otherPlayers.remove(entity.id);
        }
      }
    }

    for (final entity in toRemove) {
      renderer.del(entity);
    }
  }

  void _drawUI() {
    ui.move(Vect(2, 1));
    ui.out(ui.style.primary('TRAGE'));

    ui.move(Vect(10, 1));
    ui.out(ui.style.warning('Score: $score'));

    ui.move(Vect(25, 1));
    ui.out(ui.style.secondary('Players: ${otherPlayers.length}'));

    ui.move(Vect(ui.width - 20, 1));
    final statusStyle = isConnected ? ui.style.success : ui.style.error;
    ui.out(statusStyle(isConnected ? 'ONLINE' : 'OFFLINE'));

    ui.move(Vect(2, ui.height - 1));
    ui.out(ui.style.info('WASD: Move | SPACE: Shoot'));
  }

  void quick() {
    final p = Packet(PacketCommand.join);
    final net = global.get<Network>();
    net.send(p);
    isConnected = true;
  }

  void join() {}
  void create() {}

  Future<void> menu() async {
    ui.clear();

    final String title = ui.style.primary('\$ TRAGE - Terminal Battle Arena');
    final List<FutureOr<void> Function()> funcs = [quick, join, create];
    final List<String> choices = [
      ui.style.warning('  Quick Play (Debug Mode)  '),
      ui.style.secondary('  Join Room (Coming Soon)   '),
      ui.style.error('  Create Room (Coming Soon) '),
    ];

    final menuRect = Rect(
      Vect(ui.width / 4, ui.height / 4),
      ui.width / 2,
      ui.height / 2,
    );

    final choice = await ui.dialog(choices, menuRect, title: title);
    await funcs[choice]();
  }
}
