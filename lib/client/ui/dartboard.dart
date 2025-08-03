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

import 'package:gesso/gesso.dart';
import 'package:trage/client/ui/border.dart';
import 'package:trage/client/ui/style.dart';
import 'package:trage/shared/semaphore.dart';
import 'package:trage/shared/shapes/rect.dart';
import 'package:trage/shared/shapes/vect.dart';

class Dartboard {
  Dartboard(this.style);
  static const String _esc = '\x1B';
  Style style;
  final Semaphore _lock = Semaphore();

  Rect get rect => Rect(Vect.zero, width, height);

  double get width => stdout.terminalColumns.toDouble();
  double get height => stdout.terminalLines.toDouble();

  void clear() => out('$_esc[2J');

  void show() => out('$_esc[?25h');
  void hide() => out('$_esc[?25l');

  Future<void> out(Object? obj) async {
    await _lock.acquire();
    stdout.write(obj);
    _lock.release();
  }

  void move(Vect v) {
    out('$_esc[${v.y.round()};${v.x.round()}H');
  }

  void horizontal(Vect start, int length, {String? char, Gesso? g}) {
    char ??= style.border.horizontal;
    if (g != null) char = g(char);

    start = start.copy;
    move(start);
    for (int i = 0; i < length; i++) {
      out(char);
    }
  }

  void vertical(Vect start, int length, {String? char, Gesso? g}) {
    char ??= style.border.vertical;
    if (g != null) char = g(char);

    start = start.copy;
    move(start);
    for (int i = 0; i < length; i++) {
      out(char);
      start.y++;
      move(start);
    }
  }

  void bg(Vect start, int width, int height, [Gesso? g]) {
    move(start);
    g ??= Gesso();
    final char = g(' ' * width);
    for (int i = 0; i < height; i++) {
      out(char);
      move(start + Vect(0, i.toDouble()));
    }
  }

  void rectangle(Rect r, [Gesso? g]) {
    final w = r.width.round();
    final h = r.height.round();
    horizontal(r.vect + Vect(1, 0), w - 2, g: g);
    horizontal(r.vect + Vect(1, h - 1), w - 2, g: g);
    vertical(r.vect + Vect(0, 1), h - 2, g: g);
    vertical(r.vect + Vect(w - 1, 1), h - 2, g: g);

    Border colored = style.border;
    if (g != null) colored = colored.wrap(g);

    // Corner
    move(r.vect);
    out(colored.topLeft);
    move(r.vect + Vect(w - 1, 0));
    out(colored.topRight);

    move(r.vect + Vect(0, h - 1));
    out(colored.bottomLeft);
    move(r.vect + Vect(w - 1, h - 1));
    out(colored.bottomRight);
  }
}
