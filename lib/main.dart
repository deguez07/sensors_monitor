import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:intl/intl.dart';
import 'package:sensors_monitor/data_measurement.dart';
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

  /// The port currently selected for reading data
  String? _selectedPort;

  /// Mock timer used for testing purposes
  Timer? _mockTimer;

  List<DataMeasurement> _oxygenData = [];

  List<DataMeasurement> _co2Data = [];

  List<DataMeasurement> _flowData = [];

  List<DataMeasurement> _m25Data = [];

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

  @override
  void initState() {
    _mockTimer = Timer.periodic(const Duration(seconds: 1), (timer) { 
      final mockO2Value = Random().nextDouble() * 100;
      _addDataMeasurements(mockO2Value, mockO2Value, mockO2Value, mockO2Value, DateTime.now()); 
    });
    super.initState();
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
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
                padding: const EdgeInsets.all(8.0),
                child: TabBarView(
                  children: [
                    _buildChart('O2', 'Tiempo', 'PPM', _oxygenData),
                    _buildChart('CO2', 'Tiempo', 'PPM', _co2Data),
                    _buildChart('Flujo', 'Tiempo', 'ml/s', _flowData),
                    _buildChart('M2.5', 'Tiempo', 'Otra Unidad', _m25Data),
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
                              value: _selectedPort,
                              items: _availablePortsMenuItems,
                              onChanged: (value) {
                                setState(() {
                                  _selectedPort = value;
                                });
                              },
                            ),
                            if (!hasAvailablePorts) const Text('No devices dectected... Connect a device and try again')
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.play_circle),
                          onPressed: _selectedPort == null ? null : () {
                            print('Start reading port');
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
