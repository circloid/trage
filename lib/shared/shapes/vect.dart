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

  factory Vect.fromAngle(num angle) => Vect(cos(angle * pi), sin(angle * pi));

  static Vect get zero => Vect(0, 0);

  double x;
  double y;

  Vect get copy => Vect(this.x, this.y);

  Vect operator +(covariant Vect other) {
    return Vect(x + other.x, y + other.y);
  }

  Vect operator -(covariant Vect other) {
    return Vect(x - other.x, y - other.y);
  }

  Vect operator *(dynamic other) {
    if (other is int || other is double) {
      return Vect(x * other, y * other);
    }
    if (other is! Vect) throw Exception('Unsupported operator /');
    return Vect(x * other.x, y * other.y);
  }

  Vect operator /(dynamic other) {
    if (other is int || other is double) {
      return Vect(x / other, y / other);
    }
    if (other is! Vect) throw Exception('Unsupported operator /');
    return Vect(x / other.x, y / other.y);
  }

  double distance(Vect other) {
    final dy = y - other.y;
    final dx = x - other.x;
    return sqrt(dx * dx + dy * dy);
  }

  double angle(Vect other) {
    final dy = y - other.y;
    final dx = x - other.x;
    return atan2(dy, dx);
  }

  Vect vector(Vect other) => Vect(x - other.x, y - other.y);

  Vect center(Vect other) => (this + other) / 2;
}
