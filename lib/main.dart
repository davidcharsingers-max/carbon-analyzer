import 'dart:convert';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DieselCarbonAnalyzerApp());
}

class DieselCarbonAnalyzerApp extends StatelessWidget {
  const DieselCarbonAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '디젤 연비·카본 분석',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),
      home: const AnalyzerHomePage(),
    );
  }
}

class AnalyzerHomePage extends StatefulWidget {
  const AnalyzerHomePage({super.key});

  @override
  State<AnalyzerHomePage> createState() => _AnalyzerHomePageState();
}

class _AnalyzerHomePageState extends State<AnalyzerHomePage> {
  AnalysisResult? result;
  String? fileName;
  String? errorMessage;
  bool loading = false;

  Future<void> pickAndAnalyzeCsv() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (picked == null || picked.files.isEmpty) {
        setState(() => loading = false);
        return;
      }

      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('파일을 읽을 수 없습니다.');
      }

      final csvText = utf8.decode(bytes, allowMalformed: true);
      final parsed = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvText);

      final analyzed = ObdCsvAnalyzer().analyze(parsed);
      setState(() {
        result = analyzed;
        fileName = file.name;
        loading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '분석 실패: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('디젤 연비·카본 분석'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OBD CSV 파일을 불러오세요',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Torque, Car Scanner 등에서 저장한 CSV 데이터를 분석합니다.'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: loading ? null : pickAndAnalyzeCsv,
                        icon: const Icon(Icons.upload_file),
                        label: Text(loading ? '분석 중...' : 'CSV 선택 및 분석'),
                      ),
                      if (fileName != null) ...[
                        const SizedBox(height: 8),
                        Text('파일: $fileName'),
                      ],
                    ],
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: result == null
                    ? const Center(
                        child: Text(
                          '분석 결과가 여기에 표시됩니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : AnalysisResultView(result: result!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnalysisResultView extends StatelessWidget {
  final AnalysisResult result;

  const AnalysisResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ScoreCard(title: '종합 엔진 효율 점수', score: result.overallScore, suffix: '점'),
        const SizedBox(height: 12),
        MetricTile(title: '연비 손실 가능성', value: result.fuelLossLevel, detail: result.fuelLossReason),
        MetricTile(title: '카본 누적 의심도', value: result.carbonRiskLevel, detail: result.carbonRiskReason),
        MetricTile(title: '공회전 비율', value: '${result.idleRatio.toStringAsFixed(1)}%', detail: '속도 0km/h, RPM 500 이상 구간 기준'),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('기초 데이터', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DataRowText(label: '샘플 수', value: '${result.sampleCount}개'),
                DataRowText(label: '평균 RPM', value: result.avgRpm.toStringAsFixed(0)),
                DataRowText(label: '평균 속도', value: '${result.avgSpeed.toStringAsFixed(1)} km/h'),
                DataRowText(label: '평균 MAF', value: result.avgMaf == null ? '데이터 없음' : '${result.avgMaf!.toStringAsFixed(2)} g/s'),
                DataRowText(label: '평균 연료소모', value: result.avgFuelRate == null ? '데이터 없음' : '${result.avgFuelRate!.toStringAsFixed(2)} L/h'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('권장 조치', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...result.recommendations.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $r'),
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '주의: 이 결과는 정비 확정 진단이 아니라 OBD 데이터 기반 상태 추정입니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class ScoreCard extends StatelessWidget {
  final String title;
  final double score;
  final String suffix;

  const ScoreCard({super.key, required this.title, required this.score, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('${score.toStringAsFixed(0)}$suffix', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: score.clamp(0, 100) / 100),
          ],
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String detail;

  const MetricTile({super.key, required this.title, required this.value, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(detail),
        trailing: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class DataRowText extends StatelessWidget {
  final String label;
  final String value;

  const DataRowText({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ObdCsvAnalyzer {
  AnalysisResult analyze(List<List<dynamic>> rows) {
    if (rows.length < 2) {
      throw Exception('CSV 데이터가 부족합니다.');
    }

    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final dataRows = rows.skip(1).where((r) => r.any((c) => c.toString().trim().isNotEmpty)).toList();

    final rpmIdx = _findIndex(headers, ['rpm', 'engine rpm']);
    final speedIdx = _findIndex(headers, ['speed', 'vehicle speed', 'km/h']);
    final mafIdx = _findIndex(headers, ['maf', 'mass air flow']);
    final fuelIdx = _findIndex(headers, ['fuel_rate', 'fuel rate', 'fuel consumption', 'fuel']);

    if (rpmIdx == null || speedIdx == null) {
      throw Exception('RPM과 speed 컬럼은 반드시 필요합니다.');
    }

    final rpms = <double>[];
    final speeds = <double>[];
    final mafs = <double>[];
    final fuels = <double>[];

    for (final row in dataRows) {
      final rpm = _readDouble(row, rpmIdx);
      final speed = _readDouble(row, speedIdx);
      if (rpm != null && speed != null) {
        rpms.add(rpm);
        speeds.add(speed);
      }
      if (mafIdx != null) {
        final maf = _readDouble(row, mafIdx);
        if (maf != null) mafs.add(maf);
      }
      if (fuelIdx != null) {
        final fuel = _readDouble(row, fuelIdx);
        if (fuel != null) fuels.add(fuel);
      }
    }

    if (rpms.isEmpty || speeds.isEmpty) {
      throw Exception('유효한 RPM/speed 데이터가 없습니다.');
    }

    final avgRpm = _avg(rpms);
    final avgSpeed = _avg(speeds);
    final avgMaf = mafs.isEmpty ? null : _avg(mafs);
    final avgFuel = fuels.isEmpty ? null : _avg(fuels);

    final idleCount = List.generate(min(rpms.length, speeds.length), (i) => i)
        .where((i) => speeds[i] < 2 && rpms[i] > 500)
        .length;
    final idleRatio = idleCount / rpms.length * 100;

    final rpmStd = _std(rpms);
    double carbonRisk = 0;
    carbonRisk += _scoreAbove(idleRatio, 15, 45, 25);
    carbonRisk += _scoreAbove(rpmStd, 30, 140, 25);
    if (avgMaf != null && avgRpm > 0) {
      final mafPerRpm = avgMaf / avgRpm * 1000;
      carbonRisk += _scoreBelow(mafPerRpm, 8, 4, 30);
    } else {
      carbonRisk += 12;
    }
    if (avgFuel != null && avgSpeed > 5) {
      final fuelPerSpeed = avgFuel / avgSpeed;
      carbonRisk += _scoreAbove(fuelPerSpeed, 0.08, 0.18, 20);
    } else {
      carbonRisk += 8;
    }
    carbonRisk = carbonRisk.clamp(0, 100);

    double fuelLossRisk = 0;
    fuelLossRisk += _scoreAbove(idleRatio, 10, 40, 35);
    if (avgFuel != null && avgSpeed > 5) {
      fuelLossRisk += _scoreAbove(avgFuel / avgSpeed, 0.07, 0.2, 35);
    } else {
      fuelLossRisk += 15;
    }
    fuelLossRisk += _scoreAbove(avgRpm / max(avgSpeed, 1), 45, 90, 20);
    fuelLossRisk += carbonRisk * 0.1;
    fuelLossRisk = fuelLossRisk.clamp(0, 100);

    final overallScore = (100 - (fuelLossRisk * 0.45 + carbonRisk * 0.55)).clamp(0, 100).toDouble();

    final recommendations = <String>[];
    if (carbonRisk >= 60) {
      recommendations.add('흡기·연소계 카본 클리닝 전후 비교 측정을 권장합니다.');
    }
    if (idleRatio >= 25) {
      recommendations.add('공회전 시간이 길어 연비 손실 가능성이 큽니다. 운행 패턴 개선을 권장합니다.');
    }
    if (rpmStd >= 80) {
      recommendations.add('공회전 RPM 변동이 커 인젝터 또는 연소 불균형 점검을 권장합니다.');
    }
    if (recommendations.isEmpty) {
      recommendations.add('현재 데이터상 큰 위험 신호는 낮습니다. 동일 조건에서 주기 측정을 권장합니다.');
    }

    return AnalysisResult(
      sampleCount: rpms.length,
      avgRpm: avgRpm,
      avgSpeed: avgSpeed,
      avgMaf: avgMaf,
      avgFuelRate: avgFuel,
      idleRatio: idleRatio,
      overallScore: overallScore,
      fuelLossLevel: _level(fuelLossRisk),
      carbonRiskLevel: _level(carbonRisk),
      fuelLossReason: _fuelReason(fuelLossRisk, idleRatio, avgFuel, avgSpeed),
      carbonRiskReason: _carbonReason(carbonRisk, avgMaf, rpmStd),
      recommendations: recommendations,
    );
  }

  int? _findIndex(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final exact = headers.indexWhere((h) => h == candidate);
      if (exact >= 0) return exact;
    }
    for (final candidate in candidates) {
      final partial = headers.indexWhere((h) => h.contains(candidate));
      if (partial >= 0) return partial;
    }
    return null;
  }

  double? _readDouble(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return null;
    final cleaned = row[idx].toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  double _avg(List<double> values) => values.reduce((a, b) => a + b) / values.length;

  double _std(List<double> values) {
    final mean = _avg(values);
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  double _scoreAbove(double value, double normal, double bad, double maxScore) {
    if (value <= normal) return 0;
    if (value >= bad) return maxScore;
    return (value - normal) / (bad - normal) * maxScore;
  }

  double _scoreBelow(double value, double normal, double bad, double maxScore) {
    if (value >= normal) return 0;
    if (value <= bad) return maxScore;
    return (normal - value) / (normal - bad) * maxScore;
  }

  String _level(double risk) {
    if (risk < 30) return '낮음';
    if (risk < 60) return '중간';
    if (risk < 80) return '높음';
    return '매우 높음';
  }

  String _fuelReason(double risk, double idleRatio, double? avgFuel, double avgSpeed) {
    if (idleRatio >= 25) return '공회전 비율이 높아 연료 손실 가능성이 큽니다.';
    if (avgFuel != null && avgSpeed > 5 && avgFuel / avgSpeed > 0.12) return '속도 대비 연료소모 패턴이 높게 나타납니다.';
    if (risk >= 60) return '여러 항목에서 연비 손실 패턴이 관찰됩니다.';
    return '현재 데이터상 연비 손실 위험은 제한적입니다.';
  }

  String _carbonReason(double risk, double? avgMaf, double rpmStd) {
    if (rpmStd >= 80) return 'RPM 변동이 커 연소 불균형 또는 카본 누적 가능성이 있습니다.';
    if (avgMaf == null) return 'MAF 데이터가 없어 카본 평가는 제한적입니다.';
    if (risk >= 60) return '흡기량·연료소모·RPM 패턴상 카본 누적 가능성이 있습니다.';
    return '현재 데이터상 카본 누적 의심도는 낮거나 중간 수준입니다.';
  }
}

class AnalysisResult {
  final int sampleCount;
  final double avgRpm;
  final double avgSpeed;
  final double? avgMaf;
  final double? avgFuelRate;
  final double idleRatio;
  final double overallScore;
  final String fuelLossLevel;
  final String carbonRiskLevel;
  final String fuelLossReason;
  final String carbonRiskReason;
  final List<String> recommendations;

  AnalysisResult({
    required this.sampleCount,
    required this.avgRpm,
    required this.avgSpeed,
    required this.avgMaf,
    required this.avgFuelRate,
    required this.idleRatio,
    required this.overallScore,
    required this.fuelLossLevel,
    required this.carbonRiskLevel,
    required this.fuelLossReason,
    required this.carbonRiskReason,
    required this.recommendations,
  });
}
