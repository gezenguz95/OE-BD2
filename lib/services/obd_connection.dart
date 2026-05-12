abstract class ObdConnection {
  Future<String> sendAndWait(String command, {Duration timeout});
  Future<void> sendCommand(String command);
  Future<void> close();
  bool get isConnected;
}