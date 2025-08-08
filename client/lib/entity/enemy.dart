import 'package:client/entity/entity.dart';
import 'package:client/game_state.dart';
import 'package:shared/shared.dart';

class Enemy extends Entity {
  Enemy(super.position);
  int direction = 0;
  static final _chars = ['▶', '▼', '◀', '▲'];

  void fire() {}

  void draw(GameState state) {
    final r = Rect(position, 5, 3);
    final ui = state.ui;
    ui.rectangle(r, ui.style.primary);
    ui.move(r.center - Vect(1, 1));
    ui.out(_chars[direction]);
  }

  void update() {}
}
