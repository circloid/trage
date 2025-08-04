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

import 'vect.dart';

class Rect {
  Rect(this.vect, this.width, this.height);
  Vect vect;
  double width;
  double height;

  Rect get copy => Rect(vect.copy, width, height);

  Vect get topLeft => vect;
  Vect get topRight => vect + Vect(width - 1, 0);
  Vect get bottomLeft => vect + Vect(0, height - 1);
  Vect get bottomRight => vect + Vect(width - 1, height - 1);

  Vect get center => vect.center(vect + Vect(width, height));

  double get diagonal => topLeft.distance(bottomRight);

  Vect getCenterInside(Rect rect) {
    final angle = rect.center.angle(rect.topLeft);
    return center + Vect.fromAngle(angle) * (rect.diagonal / 2);
  }

  Rect operator +(num value) {
    final Rect copy = this.copy;
    copy.vect -= Vect(value * 2, value);
    copy.width += value * 4;
    copy.height += value * 2;
    return copy;
  }

  Rect operator -(num value) {
    final Rect copy = this.copy;
    copy.vect += Vect(value * 2, value);
    copy.width -= value * 4;
    copy.height -= value * 2;
    return copy;
  }
}
