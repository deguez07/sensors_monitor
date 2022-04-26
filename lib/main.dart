import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_periphery/dart_periphery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:intl/intl.dart';
import 'package:sensors_monitor/data_measurement.dart';
import 'package:sensors_monitor/utilities.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor de monitores Ubuntu',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: const TextTheme(
          bodyText1: TextStyle(fontSize: 18),
          bodyText2: TextStyle(fontSize: 16)
        )
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  /// The max number of entries to display in a chart
  static const maxEntries = 10;

  /// The data read through the serial port
  String _serialData = '';

  /// The port name currently selected
  String? _selectedPortName;

  /// The port from which data is being extracted
  Serial? _activePort;

  /// Mock timer used for testing purposes
  Timer? _mockTimer;

  final List<DataMeasurement> _oxygenData = [];

  final List<DataMeasurement> _co2Data = [];

  final List<DataMeasurement> _flowData = [];

  final List<DataMeasurement> _m25Data = [];

  /// Returns the list of available ports as a list of [DropdownMenuItem]s
  List<DropdownMenuItem<String>> get _availablePortsMenuItems {
    return SerialPort.availablePorts.map((portName) => DropdownMenuItem(
      child: Text(portName),
      value: portName,
    )).toList();
  }

  /// Builds a chart with the given parameters
  Widget _buildChart(String title, String xAxisTitle, String yAxisTitle, List<DataMeasurement> chartData) {

    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: DateTimeCategoryAxis(
        dateFormat: DateFormat('hh:mm:ss'),
        title: AxisTitle(
          text: xAxisTitle
        )
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: yAxisTitle
        )
      ),
      series: <SplineSeries<DataMeasurement, DateTime>> [
        SplineSeries<DataMeasurement, DateTime>(
          dataSource: chartData, 
          xValueMapper: (data, _) => data.timestamp, 
          yValueMapper: (data, _) => data.value,
          animationDuration: 500
        )
      ]
    );
  }

  /// Adds the given [value] to the given [dataList] 
  /// Constraints the length of the data list to the [maxEntries]
  /// This function calls setState()
  _appendValue(DataMeasurement value, List<DataMeasurement> dataList) {
    if (dataList.length < maxEntries) {
      setState(() {
        while (dataList.length < maxEntries) {
          dataList.add(value);
        }
        
      });
    } else {
      setState(() {
        dataList.removeAt(0);
        dataList.add(value);
      });
    }
  }

  /// Adds the list of measurements to their respective lists
  /// TODO: finish implmentation and look for optimizations
  _addDataMeasurements(double o2, double co2, double flow, double m25, DateTime timestamp) {
    _appendValue(DataMeasurement(o2, timestamp), _oxygenData);
    _appendValue(DataMeasurement(co2, timestamp), _co2Data);
    _appendValue(DataMeasurement(flow, timestamp), _flowData);
    _appendValue(DataMeasurement(m25, timestamp), _m25Data);
  }

  _startReadingPort() {
    if (_selectedPortName == null || _activePort != null || !Platform.isLinux) {
      return;
    }

    final port = Serial(_selectedPortName!, Baudrate.b9600);

    setState(() {
      _activePort = port;
    });
  }

  _stopReadingPort() {
    if (_activePort == null || !Platform.isLinux) {
      return null;
    }

    _activePort?.dispose();
    
    setState(() {
      _activePort = null;
    });
  }

  @override
  void initState() {

    _mockTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) { 
      // final mockO2Value = Random().nextDouble() * 100;
      // _addDataMeasurements(mockO2Value, mockO2Value, mockO2Value, mockO2Value, DateTime.now()); 

      // Read the port if it is available
      if (_activePort != null) {
        final serialData = _activePort!.read(64, 200);
        if (serialData.count != 0) {
          final utf8Data = serialData.uf8ToString();
          setState(() {
            _serialData += utf8Data;
          });
          print('${DateTime.now()} - ${serialData.uf8ToString()}');

        }
      }
    });

    final arduinoPort = getFirstProbableArduinoPort();
    if (arduinoPort != null) {
      _selectedPortName = arduinoPort;
      print('Arduino is connected to port: $arduinoPort');
    }

    super.initState();
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
    _activePort?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(text: 'O',),
              Tab(text: 'CO2',),
              Tab(text: 'Flujo',),
              Tab(text: 'M2.5',)
            ],
          ),
          toolbarHeight: 0,
        ),
        body: Column(
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: TabBarView(
                  children: [
                    Column(
                      children: [
                        Text('Oxygen chart'),
                        Spacer(),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(_serialData),
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                    Text('CO2 Chart'),
                    Text('Flow chart'),
                    Text('M25 chart'),
                    // _buildChart('O2', 'Tiempo', 'PPM', _oxygenData),
                    // _buildChart('CO2', 'Tiempo', 'PPM', _co2Data),
                    // _buildChart('Flujo', 'Tiempo', 'ml/s', _flowData),
                    // _buildChart('M2.5', 'Tiempo', 'Otra Unidad', _m25Data),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: 8
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0
                ),
                child: Builder(
                  builder: (context) {
                    final hasAvailablePorts = SerialPort.availablePorts.isNotEmpty;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if (hasAvailablePorts) Padding(
                              padding: const EdgeInsets.only(
                                right: 8
                              ),
                              child: Text('Port:',
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                            ),
                            if (hasAvailablePorts) DropdownButton<String>(
                              hint: const Text('Select a port'),
                              value: _selectedPortName,
                              items: _availablePortsMenuItems,
                              onChanged: _activePort != null ? null : (value) {
                                setState(() {
                                  _selectedPortName = value;
                                });
                              },
                            ),
                            if (!hasAvailablePorts) const Text('No devices dectected... Connect a device and try again')
                          ],
                        ),
                        if (hasAvailablePorts) IconButton(
                          icon: Icon(_activePort == null ? Icons.play_circle : Icons.stop_circle),
                          onPressed: _selectedPortName == null ? null : () {
                            if (_activePort != null) {
                              _stopReadingPort();
                            } else {
                              _startReadingPort();
                            }
                          },
                        )
                      ],
                    );
                  }
                ),
              ),
            )
          ],
        )
      ),
    );
  }
}
