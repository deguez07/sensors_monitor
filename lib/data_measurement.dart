
/// Class used to model a measurement taken in a given time
class DataMeasurement {

  /// The value to be measured
  final double value;

  /// The date and time at which the value was recorded
  final DateTime timestamp;

  const DataMeasurement(this.value, this.timestamp);
}