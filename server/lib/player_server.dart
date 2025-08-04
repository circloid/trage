import 'package:server/network/client_connection.dart';
import 'package:shared/shared.dart';

class PlayerServer {
  PlayerServer(this.position, this.connection);
  Vect position;
  ClientConnection connection;
  double speed = 1;

  void move(int direction) {
    position += Vect.fromAngle(direction / 2) * speed;
  }
}
