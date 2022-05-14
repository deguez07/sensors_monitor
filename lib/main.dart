import 'dart:async';
import 'dart:io';

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

  /// The line of data read by the serial interface
  String _dataLine = '';

  /// Timer used to fetch data from the serial port
  Timer? _dataFetchTimer;

  // The serial port where data is being read
  Serial? _serialPort;


  final List<DataMeasurement> _oxygenData = [];

  final List<DataMeasurement> _co2Data = [];

  final List<DataMeasurement> _smf3200Data = [];

  final List<DataMeasurement> _smf3019Data = [];

  final List<DataMeasurement> _pm25Data = [];

  /// Builds a chart with the given parameters
  Widget _buildChart(String title, String xAxisTitle, String yAxisTitle, List<DataMeasurement> chartData) {

    return SfCartesianChart(
      title: ChartTitle(text: title),
      primaryXAxis: DateTimeCategoryAxis(
        dateFormat: DateFormat('hh:mm:ss.S'),
        title: AxisTitle(
          text: xAxisTitle
        )
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: yAxisTitle
        ),
        rangePadding: ChartRangePadding.additional
      ),
      series: <SplineSeries<DataMeasurement, DateTime>> [
        SplineSeries<DataMeasurement, DateTime>(
          dataSource: chartData, 
          xValueMapper: (data, _) => data.timestamp, 
          yValueMapper: (data, _) => data.value,
          animationDuration: 0
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
  _addDataMeasurements(double o2, double co2, double smf3200, double smf3019, double pm25, DateTime timestamp) {
    _appendValue(DataMeasurement(o2, timestamp), _oxygenData);
    _appendValue(DataMeasurement(co2, timestamp), _co2Data);
    _appendValue(DataMeasurement(smf3200, timestamp), _smf3200Data);
    _appendValue(DataMeasurement(pm25, timestamp), _pm25Data);
    _appendValue(DataMeasurement(smf3019, timestamp), _smf3019Data);
  }

  _parseAndAppendData(String incomingData) {
    // print('Adding new data');

    // Terminate changes if there is no data in the serial buffer
    if (incomingData.isEmpty) {
      return;
    }

    final newData = incomingData.split(',');
    if (newData.length != 6) {
      print('Could not add new data');
      return; //Something went wrong
    }

    // Parse the data and add it if valid
    try {
      final o2 = double.parse(newData[0]);
      final co2 = double.parse(newData[1]);
      final flowSmf3019 = double.parse(newData[2]);
      final flowSmf3200 = double.parse(newData[3]);
      final pm25 = double.parse(newData[4]);

      _addDataMeasurements(o2, co2, flowSmf3200, flowSmf3019, pm25, DateTime.now());
    } catch (err) {
      print(err);
    }
  }

  @override
  void initState() {

    try {
      _serialPort = Serial('/dev/ttyUSB0', Baudrate.b9600);
    } catch(err) {
      print(err);
      print('Error could not open /dev/ttyUSB0');
    }

    _dataFetchTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_serialPort == null) {
        return;
      }

      try {
        final serialEvent = _serialPort!.read(1, 5);

        for (final byteData in serialEvent.data) {
          final byteChar = String.fromCharCode(byteData);

          if (byteChar == '\n') {
            print(_dataLine);
            _parseAndAppendData(_dataLine);
            _dataLine = '';
          } else {
            _dataLine += byteChar;
          }
        }
      } catch (err) {
        // LIBRARY HAS A BUG... Will throw an
        // print(err);
        // print('Failed to read data');
      }

      
    });

    super.initState();
  }

  @override
  void dispose() {
    _dataFetchTimer?.cancel();
    _serialPort?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (_serialPort == null) {
      return const Scaffold(
        body: Center(
          child: Text("Device has not been detected at /dev/ttyUSB0.\nReconnect and restart the App"),
        ),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(text: 'O2',),
              Tab(text: 'CO2',),
              Tab(text: 'Flujo (SMF3200)',),
              Tab(text: 'Flujo (SMF3019)',),
              Tab(text: 'PM2.5',)
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
                    _buildChart('O2', 'Tiempo', 'PPM', _oxygenData),
                    _buildChart('CO2', 'Tiempo', 'PPM', _co2Data),
                    _buildChart('Flujo (SMF3200)', 'Tiempo', 'sml', _smf3200Data),
                    _buildChart('Flujo (SMF3019)', 'Tiempo', 'sml', _smf3200Data),
                    _buildChart('PM2.5', 'Tiempo', 'PPM', _pm25Data),
                  ],
                ),
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.only(
            //     left: 8,
            //     right: 8,
            //     bottom: 8
            //   ),
            //   child: Padding(
            //     padding: const EdgeInsets.symmetric(
            //       vertical: 8.0,
            //       horizontal: 16.0
            //     ),
            //     child: Builder(
            //       builder: (context) {
            //         final hasAvailablePorts = SerialPort.availablePorts.isNotEmpty;

            //         return Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //           children: [
            //             Row(
            //               mainAxisAlignment: MainAxisAlignment.start,
            //               children: [
            //                 if (hasAvailablePorts) Padding(
            //                   padding: const EdgeInsets.only(
            //                     right: 8
            //                   ),
            //                   child: Text('Port:',
            //                     style: Theme.of(context).textTheme.bodyText1,
            //                   ),
            //                 ),
            //                 if (hasAvailablePorts) DropdownButton<String>(
            //                   hint: const Text('Select a port'),
            //                   value: _selectedPortName,
            //                   items: _availablePortsMenuItems,
            //                   onChanged: _activePort != null ? null : (value) {
            //                     setState(() {
            //                       _selectedPortName = value;
            //                     });
            //                   },
            //                 ),
            //                 if (!hasAvailablePorts) const Text('No devices dectected... Connect a device and try again')
            //               ],
            //             ),
            //             if (hasAvailablePorts) IconButton(
            //               icon: Icon(_activePort == null ? Icons.play_circle : Icons.stop_circle),
            //               onPressed: _selectedPortName == null ? null : () {
            //                 if (_activePort != null) {
            //                   _stopReadingPort();
            //                 } else {
            //                   _startReadingPort();
            //                 }
            //               },
            //             )
            //           ],
            //         );
            //       }
            //     ),
            //   ),
            // )
          ],
        )
      ),
    );
  }
}
