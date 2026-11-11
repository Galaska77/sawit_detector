import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/forward_chaining.dart';
import '../utils/palm_image_analyzer.dart';
import 'diagnosis_page.dart';
import 'scan_page.dart';

class ResultPage extends StatelessWidget {
  final List<String> selectedSymptomIds;
  final List<DiagnosisResult> results;
  final String? imagePath;
  final Uint8List? imageBytes;
  final PalmImageAnalysis? visualAnalysis;

  const ResultPage({
    super.key,
    required this.selectedSymptomIds,
    required this.results,
    this.imagePath,
    this.imageBytes,
    this.visualAnalysis,
  });

  bool get _isNotPalmFrond =>
      visualAnalysis != null && !visualAnalysis!.isPalmFrond;

  @override
  Widget build(BuildContext context) {
    final primaryResult = results.isNotEmpty ? results.first : null;
    final otherResults =
        results.length > 1 ? results.sublist(1) : <DiagnosisResult>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0C1910),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1910),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
        title: Text(
          _isNotPalmFrond ? 'Validasi Objek Scan' : 'Hasil Diagnosis',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageBytes != null || imagePath != null) ...[
                  _buildCapturedImagePreview(),
                  const SizedBox(height: 20),
                ],

                if (_isNotPalmFrond) ...[
                  // Kondisi 1: Objek bukan pelepah/daun sawit -> Jangan deteksi penyakit sawit
                  _buildNotPalmFrondCard(context, visualAnalysis!),
                  const SizedBox(height: 20),
                  _buildScanTipsCard(),
                  const SizedBox(height: 24),
                ] else if (primaryResult == null) ...[
                  // Kondisi 2: Pelepah sawit sehat / tidak ada gejala terdeteksi
                  _buildNoDiseaseCard(context),
                  if (visualAnalysis != null) ...[
                    const SizedBox(height: 20),
                    _buildVisualMetricsSection(visualAnalysis!),
                  ],
                  const SizedBox(height: 24),
                ] else ...[
                  // Kondisi 3: Penyakit sawit terdeteksi
                  _buildPrimaryDiagnosisCard(context, primaryResult),
                  const SizedBox(height: 20),

                  if (visualAnalysis != null) ...[
                    _buildVisualMetricsSection(visualAnalysis!),
                    const SizedBox(height: 20),
                  ],

                  _buildMatchedSymptomsSection(primaryResult),
                  const SizedBox(height: 20),

                  _buildSolutionSection(primaryResult),
                  const SizedBox(height: 24),

                  if (otherResults.isNotEmpty) ...[
                    const Text(
                      'Kemungkinan Penyakit Lain',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...otherResults.map(_buildAlternativeDiagnosisItem),
                    const SizedBox(height: 24),
                  ],
                ],

                // Tombol Lengkapi Gejala via Kuisioner (jika datang dari scan kamera sawit)
                if (!_isNotPalmFrond && visualAnalysis != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiagnosisPage(
                            initialSymptomIds: selectedSymptomIds,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assignment_outlined, color: Color(0xFF10B981)),
                    label: const Text(
                      'Lengkapi Gejala Lain (Kuisioner)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Tombol Scan Ulang jika berasal dari halaman scan
                if (visualAnalysis != null || imageBytes != null) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScanPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      _isNotPalmFrond ? 'Scan Ulang Pelepah Sawit' : 'Scan Pelepah Lain',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Tombol Kembali ke Beranda
                ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (visualAnalysis != null || imageBytes != null)
                        ? const Color(0xFF152A1C)
                        : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    side: (visualAnalysis != null || imageBytes != null)
                        ? const BorderSide(color: Color(0xFF223E2A), width: 1.5)
                        : BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Kembali ke Beranda',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapturedImagePreview() {
    Widget imageWidget;
    if (imageBytes != null) {
      imageWidget = Image.memory(imageBytes!, fit: BoxFit.cover);
    } else if (imagePath != null && imagePath!.startsWith('assets/')) {
      imageWidget = Image.asset(imagePath!, fit: BoxFit.cover);
    } else if (imagePath != null && imagePath!.startsWith('http')) {
      imageWidget = Image.network(imagePath!, fit: BoxFit.cover);
    } else {
      imageWidget = const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 48),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 210,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isNotPalmFrond ? Colors.amber : const Color(0xFF223E2A),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: imageWidget,
      ),
    );
  }

  Widget _buildNotPalmFrondCard(BuildContext context, PalmImageAnalysis analysis) {
    final greenPct = (analysis.greenLeafRatio * 100).clamp(0.0, 100.0);
    final nonPlantPct = (analysis.skinOrNonPlantRatio * 100).clamp(0.0, 100.0);
    final brightnessPct = (analysis.meanBrightness * 100).clamp(0.0, 100.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF152A1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber, width: 1),
            ),
            child: const Text(
              'OBJEK BUKAN PELEPAH SAWIT',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 52,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            analysis.statusTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            analysis.statusDetail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF223E2A)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricChip(
                  label: 'Hijau Daun',
                  value: '${greenPct.toStringAsFixed(0)}%',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricChip(
                  label: 'Non-Sawit/Kulit',
                  value: '${nonPlantPct.toStringAsFixed(0)}%',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricChip(
                  label: 'Kecerahan',
                  value: '${brightnessPct.toStringAsFixed(0)}%',
                  color: Colors.lightBlueAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanTipsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF122217),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D3525), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Text(
                'Panduan Pengambilan Gambar Pelepah:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '1. Arahkan kamera langsung ke helai daun atau pelepah kelapa sawit (jarak ±30–60 cm).\n'
            '2. Pastikan pelepah mengisi bagian tengah bingkai kotak hijau.\n'
            '3. Hindari mengarahkan kamera ke wajah, tembok, lantai, atau objek non-tanaman.\n'
            '4. Gunakan pencahayaan alami yang cukup dan tidak terlalu silau.',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualMetricsSection(PalmImageAnalysis analysis) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF122217),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D3525), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.document_scanner_outlined, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'Analisis Visual Citra Pelepah:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            analysis.statusDetail,
            style: TextStyle(color: Colors.grey[350], fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricChip(
                  label: 'Hijau Sehat',
                  value: '${analysis.healthyVegetationPercent.toStringAsFixed(0)}%',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricChip(
                  label: 'Menguning',
                  value: '${analysis.yellowingPercent.toStringAsFixed(0)}%',
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricChip(
                  label: 'Bercak/Busuk',
                  value: '${analysis.lesionPercent.toStringAsFixed(0)}%',
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDiseaseCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF152A1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF223E2A), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 52,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tanaman Sawit Sehat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            visualAnalysis != null
                ? 'Pelepah sawit terdeteksi dalam kondisi dominan hijau segar tanpa indikasi gejala penyakit yang berarti.'
                : 'Berdasarkan gejala-gejala yang Anda masukkan, sistem tidak menemukan indikasi penyakit kelapa sawit yang cocok dengan database kami.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF223E2A)),
          const SizedBox(height: 16),
          const Text(
            'Rekomendasi Pemeliharaan:',
            style: TextStyle(
              color: Color(0xFF10B981),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tetap lakukan pemantauan berkala, pemupukan berimbang NPK sesuai dosis, serta pembersihan gulma di sekitar piringan pohon sawit secara terjadwal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryDiagnosisCard(BuildContext context, DiagnosisResult result) {
    final isHighConfidence = result.confidence >= 75.0;
    final statusColor = isHighConfidence ? const Color(0xFFEF4444) : Colors.orangeAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF152A1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  isHighConfidence ? 'TERDETEKSI KUAT' : 'INDIKASI GEJALA',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${result.confidence.toStringAsFixed(1)}% Cocok',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            result.disease.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kode Penyakit: ${result.disease.id}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Deskripsi Penyakit:',
            style: TextStyle(
              color: Color(0xFF10B981),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.disease.description,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedSymptomsSection(DiagnosisResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF122217),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1D3525), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gejala yang Terpenuhi:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...result.matchedSymptoms.map((sId) {
            final symptom = ForwardChainingEngine.symptoms.firstWhere(
              (s) => s.id == sId,
              orElse: () => Symptom(id: sId, name: sId, question: ''),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_box_outlined,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '[$sId] ${symptom.name}',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSolutionSection(DiagnosisResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF152A1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223E2A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.healing_outlined, color: Colors.orangeAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Saran Penanganan:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.disease.solution,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeDiagnosisItem(DiagnosisResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF152A1C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF223E2A), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.disease.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cocok ${result.matchedSymptoms.length} dari ${result.totalSymptoms} gejala',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${result.confidence.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
