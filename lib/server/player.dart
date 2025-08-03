import 'package:trage/server/network/client_connection.dart';
import 'package:trage/shared/shapes/vect.dart';

class Player {
  Player(this.position, this.connection);
  Vect position;
  ClientConnection connection;
  double speed = 1;

  void move(int direction) {
    position += Vect.fromAngle(direction / 2) * speed;
  }
}
