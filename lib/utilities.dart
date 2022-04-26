
import 'dart:io';

import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Returns the first port that is probably the connected arduino
/// Note this function might fail (or maybe there are no connected devices), in which case null is returned
String? getFirstProbableArduinoPort() {

  // Check if there are available ports
  final availablePorts = SerialPort.availablePorts;

  if (availablePorts.isEmpty) {
    return null;
  }

  try {

    // Check the different platforms with custom logic
    if (Platform.isWindows){
      return availablePorts.firstWhere((port) => port.contains('COM'));
    } else if (Platform.isMacOS) {
      return availablePorts.firstWhere((port) => port.contains('/dev/tty.usbserial'));
    } else if (Platform.isLinux) {
      return availablePorts.firstWhere((port) => port.contains('/dev/ttyUSB'));
    } 

  } catch (err) {
    return null;
  }

  return null;
}