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

import 'dart:math';

class Vect {
  Vect(this.x, this.y);

  // Fixed: angle should be in radians, not multiplied by pi
  factory Vect.fromAngle(num angle) => Vect(cos(angle), sin(angle));

  factory Vect.random() {
    final r = Random();
    return Vect(
      r.nextDouble() * 100,
      r.nextDouble() * 50,
    ); // Better random bounds
  }

  factory Vect.deserialize(String value) {
    final Iterable<num> l = value.split(_separator).map(num.parse);
    return Vect(l.elementAt(0), l.elementAt(1));
  }

  static const String _separator = ':';
  static Vect get zero => Vect(0, 0);

  num x;
  num y;

  Vect get copy => Vect(this.x, this.y);

  String serialize() => '${x.toInt()}$_separator${y.toInt()}';

  Vect operator +(dynamic other) {
    return operation(other, (a, b) => a + b);
  }

  Vect operator -(dynamic other) {
    return operation(other, (a, b) => a - b);
  }

  Vect operator *(dynamic other) {
    return operation(other, (a, b) => a * b);
  }

  Vect operator /(dynamic other) {
    return operation(other, (a, b) => a / b);
  }

  double distance(Vect other) {
    final dy = y - other.y;
    final dx = x - other.x;
    return sqrt(dx * dx + dy * dy);
  }

  double angle(Vect other) {
    final dy = other.y - y; // Fixed: direction matters for angle
    final dx = other.x - x;
    return atan2(dy, dx);
  }

  double get magnitude => sqrt(x * x + y * y);

  Vect normalize() {
    final mag = magnitude;
    if (mag == 0) return Vect.zero;
    return Vect(x / mag, y / mag);
  }

  Vect operation(dynamic other, num Function(num, num) func) {
    if (other is Vect) return Vect(func(x, other.x), func(y, other.y));
    if (other is int || other is double || other is num) {
      return Vect(func(x, other), func(y, other));
    }
    throw Exception('Unsupported operator with type ${other.runtimeType}');
  }

  Vect vector(Vect other) => Vect(other.x - x, other.y - y);

  Vect center(Vect other) => (this + other) / 2;

  // Add bounds checking for game boundaries
  Vect clamp(Vect min, Vect max) {
    return Vect(x.clamp(min.x, max.x), y.clamp(min.y, max.y));
  }

  @override
  String toString() => 'Vect($x, $y)';

  @override
  bool operator ==(Object other) {
    if (other is! Vect) return false;
    return x == other.x && y == other.y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}
