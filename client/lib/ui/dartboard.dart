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

import 'package:client/renderer.dart';
import 'package:gesso/gesso.dart';
import 'package:shared/shared.dart';
import 'border.dart';
import 'style.dart';

class Dartboard {
  Dartboard(this.style);
  static const String _esc = '\x1B';
  Style style;
  Vect? _lastCursorPos; // Track cursor position to minimize moves

  Rect get rect => Rect(Vect.zero, width, height);

  double get width => stdout.terminalColumns.toDouble();
  double get height => stdout.terminalLines.toDouble();

  void clear() {
    out('$_esc[2J'); // Clear entire screen
    out('$_esc[H'); // Move cursor to home position (1,1)
    _lastCursorPos = Vect(1, 1);
  }

  void show() => out('$_esc[?25h');
  void hide() => out('$_esc[?25l');

  void out(Object? obj) {
    stdout.write(obj);
  }

  void move(Vect v) {
    // Clamp coordinates to screen bounds
    final clampedX = v.x.clamp(1, width).round();
    final clampedY = v.y.clamp(1, height).round();
    final newPos = Vect(clampedX.toDouble(), clampedY.toDouble());

    // Only move cursor if position actually changed
    if (_lastCursorPos == null ||
        _lastCursorPos!.x != newPos.x ||
        _lastCursorPos!.y != newPos.y) {
      out('$_esc[${clampedY};${clampedX}H');
      _lastCursorPos = newPos;
    }
  }

  void horizontal(Vect start, int length, {String? char, Gesso? g}) {
    char ??= style.border.horizontal;
    if (g != null) char = g(char);

    move(start);
    // Draw entire horizontal line at once to reduce flicker
    final line = char * length;
    out(line);
  }

  void vertical(Vect start, int length, {String? char, Gesso? g}) {
    char ??= style.border.vertical;
    if (g != null) char = g(char);

    // Draw vertical line more efficiently
    for (int i = 0; i < length; i++) {
      move(start + Vect(0, i.toDouble()));
      out(char);
    }
  }

  void bg(Vect start, int width, int height, [Gesso? g]) {
    g ??= Gesso();
    final char = g(' ');

    // Draw background more efficiently
    for (int i = 0; i < height; i++) {
      move(start + Vect(0, i.toDouble()));
      out(char * width);
    }
  }

  void rectangle(Rect r, [Gesso? g]) {
    final w = r.width.round();
    final h = r.height.round();

    // Draw border more efficiently by drawing full lines
    Border colored = style.border;
    if (g != null) colored = colored.wrap(g);

    // Top border
    move(r.vect);
    out(colored.topLeft + (colored.horizontal * (w - 2)) + colored.topRight);

    // Side borders
    for (int i = 1; i < h - 1; i++) {
      move(r.vect + Vect(0, i.toDouble()));
      out(colored.vertical);
      move(r.vect + Vect(w - 1, i.toDouble()));
      out(colored.vertical);
    }

    // Bottom border
    move(r.vect + Vect(0, h - 1));
    out(
      colored.bottomLeft + (colored.horizontal * (w - 2)) + colored.bottomRight,
    );
  }

  void drawOptions(
    List<String> choices,
    Rect surround, {
    String? title,
    int? active,
  }) {
    rectangle(surround);
    final Vect newPos = surround.vect + Vect(2, 2);

    if (title != null) {
      move(newPos);
      out(title);
      newPos.y += 2;
    }

    for (final (index, choice) in choices.indexed) {
      move(newPos + Vect(0, index * 2));
      if (index == active) {
        out(choice.reversed);
      } else {
        out(choice);
      }
    }
  }

  Future<int> dialog(
    List<String> choices,
    Rect surround, {
    String? title,
  }) async {
    int active = 0;
    void draw() => drawOptions(choices, surround, title: title, active: active);

    // Initial draw
    draw();

    final r = global.get<Renderer>();
    final c = Completer<int>();

    // Register key handlers
    final arrUp = r.registerKeyMap('w', () {
      if (active <= 0) return;
      active--;
      draw();
    });

    final arrDown = r.registerKeyMap('s', () {
      if (active >= choices.length - 1) return;
      active++;
      draw();
    });

    final enter = r.newKeyMap([13], () => c.complete(active));
    final enterUnix = r.newKeyMap([10], () => c.complete(active));
    final space = r.newKeyMap([32], () => c.complete(active));

    final res = await c.future;

    // Cleanup
    r.removeKeyMap(arrUp);
    r.removeKeyMap(arrDown);
    r.removeKeyMap(enter);
    r.removeKeyMap(enterUnix);
    r.removeKeyMap(space);

    return res;
  }
}
