// lib/services/obd_connection.dart
//
// Egységes interfész mind a Classic Bluetooth (SPP),
// mind a BLE ELM327 adapterekhez.

abstract class ObdConnection {
  /// Parancs küldése és válaszra várakozás.
  /// A visszatérési érték a teljes ELM327 válasz (a '>' prompt előtti szöveg).
  /// [timeout] után TimeoutException-t dob.
  Future<String> sendAndWait(String command, {Duration timeout});

  /// Alacsony szintű küldés (válaszra várakozás nélkül).
  Future<void> sendCommand(String command);

  /// Kapcsolat bontása.
  Future<void> close();

  /// Kapcsolat aktív-e?
  bool get isConnected;
}