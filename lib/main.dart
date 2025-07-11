// main.dart (Flutter-приложение с интеграцией TFLite моделей)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:audiofileplayer/audiofileplayer.dart';

void main() {
  runApp(CoughAnalyzerApp());
}

class CoughAnalyzerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cough Analyzer',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String result = "";
  bool loading = false;
  File? audioFile;

  late Interpreter diagnosisModel;
  late Interpreter infectionModel;
  late Interpreter coughTypeModel;

  @override
  void initState() {
    super.initState();
    loadModels();
  }

  Future<void> loadModels() async {
    diagnosisModel = await Interpreter.fromAsset('diagnosis.tflite');
    infectionModel = await Interpreter.fromAsset('infection.tflite');
    coughTypeModel = await Interpreter.fromAsset('cough_type.tflite');
  }

  Future<void> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        audioFile = File(result.files.single.path!);
      });
      Audio.load(audioFile!.path)..play();
    }
  }

  Future<void> analyze() async {
    if (audioFile == null) return;

    setState(() {
      loading = true;
      result = "";
    });

    var inputDiagnosis = List.filled(40 * 128, 0.0).reshape([1, 40, 128, 1]);
    var inputOther = List.filled(40 * 256, 0.0).reshape([1, 40, 256, 1]);

    var outputDiagnosis = List.filled(3, 0.0).reshape([1, 3]);
    var outputInfection = List.filled(2, 0.0).reshape([1, 2]);
    var outputCough = List.filled(2, 0.0).reshape([1, 2]);

    diagnosisModel.run(inputDiagnosis, outputDiagnosis);
    infectionModel.run(inputOther, outputInfection);
    coughTypeModel.run(inputOther, outputCough);

    final labels = ["COVID-19", "healthy", "symptomatic"];
    final diagnosis = labels[outputDiagnosis[0].indexOf(outputDiagnosis[0].reduce((a, b) => a > b ? a : b))];
    final upper = outputInfection[0][0] > 0.5 ? "Да" : "Нет";
    final lower = outputInfection[0][1] > 0.5 ? "Да" : "Нет";
    final dry = outputCough[0][0] > 0.5 ? "Да" : "Нет";
    final wet = outputCough[0][1] > 0.5 ? "Да" : "Нет";

    setState(() {
      result = "🩺 Диагноз: $diagnosis
⬆ Верхняя инфекция: $upper
⬇ Нижняя инфекция: $lower
💨 Сухой: $dry
💧 Влажный: $wet";
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cough Analyzer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: loading ? null : pickAudio,
              child: Text('📙 Загрузить аудио'),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: loading || audioFile == null ? null : analyze,
              child: Text('⚗️ Проанализировать'),
            ),
            SizedBox(height: 24),
            loading
                ? CircularProgressIndicator()
                : Text(result, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

extension on List {
  List<List<List<List<double>>>> reshape(List<int> dims) {
    return [
      List.generate(dims[1], (i) =>
        List.generate(dims[2], (j) =>
          List.generate(dims[3], (k) => 0.0)))
    ];
  }
}
