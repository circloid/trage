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

import 'package:trage/shared/semaphore.dart';

typedef KeymapCallback = void Function();
typedef RawkeyListener = void Function(List<int>);

class KeymapListener {
  KeymapListener(this.key, this.on);

  final List<int> key;
  final KeymapCallback on;

  bool equals(List<int> buffer) {
    if (buffer.length != key.length) return false;

    for (int i = 0; i < key.length; i++) {
      if (key[i] != buffer[i]) return false;
    }

    return true;
  }
}

enum KeymapMode { listening, setting, disposed, disabled }

/// The approach of setup: use a completer and a method map that should return the key pressed
/// the method set the mode to setting and wait the incoming buffer
class Keymap {
  Keymap();

  KeymapMode mode = KeymapMode.listening;

  final Semaphore _lock = Semaphore();

  void setup() {
    stdin.echoMode = false;
    stdin.lineMode = false;
    stdin.listen(_listen);
  }

  void _setup(List<int> buffer) {}
  void _listening(List<int> buffer) {}

  Future<void> _listen(List<int> buffer) async {
    await _lock.acquire();
    switch (mode) {
      case KeymapMode.listening:
        _listening(buffer);
        break;
      case KeymapMode.setting:
        _setup(buffer);
        break;
      default:
        break;
    }
    _lock.release();
  }

  Future<KeymapMode> transit(KeymapMode newMode) async {
    await _lock.acquire();
    final old = mode;
    mode = newMode;
    _lock.release();
    return old;
  }
}
