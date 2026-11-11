import 'package:flutter/material.dart';
import '../utils/forward_chaining.dart';
import 'result_page.dart';

class DiagnosisPage extends StatefulWidget {
  final List<String>? initialSymptomIds;

  const DiagnosisPage({super.key, this.initialSymptomIds});

  @override
  State<DiagnosisPage> createState() => _DiagnosisPageState();
}

class _DiagnosisPageState extends State<DiagnosisPage> {
  // Map untuk menyimpan jawaban gejala (key: symptomId, value: isSelected)
  final Map<String, bool> _answers = {};
  final Set<String> _answeredIds = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final initialSet = widget.initialSymptomIds?.toSet() ?? const <String>{};
    // Inisialisasi jawaban gejala (pre-fill jika berasal dari hasil scan kamera)
    for (var symptom in ForwardChainingEngine.symptoms) {
      final hasInitial = initialSet.contains(symptom.id);
      _answers[symptom.id] = hasInitial;
      if (hasInitial) {
        _answeredIds.add(symptom.id);
      }
    }
  }

  void _nextQuestion() {
    if (_currentIndex < ForwardChainingEngine.symptoms.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishDiagnosis();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _finishDiagnosis() {
    // Kumpulkan ID gejala yang dijawab 'Ya' (true)
    List<String> selectedSymptomIds = [];
    _answers.forEach((id, val) {
      if (val == true) {
        selectedSymptomIds.add(id);
      }
    });

    // Jalankan Forward Chaining Engine
    List<DiagnosisResult> diagnosisResults = ForwardChainingEngine.diagnose(selectedSymptomIds);

    // Pindah ke Halaman Hasil
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          selectedSymptomIds: selectedSymptomIds,
          results: diagnosisResults,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symptoms = ForwardChainingEngine.symptoms;
    final currentSymptom = symptoms[_currentIndex];
    final progress = (_currentIndex + 1) / symptoms.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0C1910),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1910),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Konsultasi Gejala',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pertanyaan ${_currentIndex + 1} dari ${symptoms.length}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${((_currentIndex + 1) / symptoms.length * 100).toInt()}%',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF1B3524),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 40),

              // Question Card
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152A1C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF223E2A), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon/Badge Gejala
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.help_outline,
                          color: Color(0xFF10B981),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        currentSymptom.id,
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentSymptom.question,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      if (_answeredIds.contains(currentSymptom.id)) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (_answers[currentSymptom.id] == true
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _answers[currentSymptom.id] == true
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                          child: Text(
                            _answers[currentSymptom.id] == true
                                ? 'Jawaban saat ini: YA'
                                : 'Jawaban saat ini: TIDAK',
                            style: TextStyle(
                              color: _answers[currentSymptom.id] == true
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Action Buttons
              Row(
                children: [
                  // Button TIDAK
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _answers[currentSymptom.id] = false;
                          _answeredIds.add(currentSymptom.id);
                        });
                        _nextQuestion();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'TIDAK',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Button YA
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _answers[currentSymptom.id] = true;
                          _answeredIds.add(currentSymptom.id);
                        });
                        _nextQuestion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        shadowColor: const Color(0xFF10B981).withOpacity(0.3),
                      ),
                      child: const Text(
                        'YA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Navigation Bottom Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (only shown if not on the first question)
                  _currentIndex > 0
                      ? TextButton.icon(
                          onPressed: _previousQuestion,
                          icon: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
                          label: const Text(
                            'Kembali',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        )
                      : const SizedBox.shrink(),
                  
                  // Skip / Finish early button
                  TextButton.icon(
                    onPressed: _finishDiagnosis,
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                    label: const Text(
                      'Selesai Lebih Cepat',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
