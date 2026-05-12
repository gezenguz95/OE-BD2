//
// Demo OBD kapcsolat — valódi adapter nélkül nyitja meg az ObdDataPage-et.
// Célja az alkalmazás felületének és navigációjának böngészése eszköz nélkül.
//
// Viselkedés:
//   – AT Z → 'ELM327 v1.5'  (init sikeres, polling elindul)
//   – Egyéb AT → 'OK'
//   – Adat-lekérdezések → '' (üres: UI '--'-eket mutat, "Nincs adat" állapot)
//   – isConnected → mindig true (loop nem szakad meg)
//   – close() → lezárja az állapotot

import 'dart:async';

import 'obd_connection.dart';

class DemoObdConnection implements ObdConnection {
  bool _closed = false;

  @override
  bool get isConnected => !_closed;

  @override
  Future<String> sendAndWait(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_closed) throw StateError('Demo connection closed');
    // Rövid szimulált késleltetés — ne blokkolja az event loop-ot
    await Future.delayed(const Duration(milliseconds: 40));
    final cmd = command.trim().toUpperCase();
    if (cmd == 'AT Z') return 'ELM327 v1.5';
    if (cmd.startsWith('AT')) return 'OK';
    // Adat-parancsokra üres válasz → MultiframeParser.parse('') = []
    // → UI '--' értékeket mutat, státusz: 'Nincs adat – gyújtás?'
    return '';
  }

  @override
  Future<void> sendCommand(String command) async {}

  @override
  Future<void> close() async {
    _closed = true;
  }
}
