import 'package:flutter_test/flutter_test.dart';
import 'package:sawit_detector/utils/forward_chaining.dart';

void main() {
  group('Pengujian Engine Forward Chaining Deteksi Penyakit Sawit', () {
    test('Harus mengembalikan daftar kosong jika tidak ada gejala yang dipilih', () {
      final results = ForwardChainingEngine.diagnose([]);
      expect(results.isEmpty, true);
    });

    test('Harus mendeteksi Ganoderma (P01) dengan kecocokan 100% saat gejala G01, G02, G03, G04 terpenuhi', () {
      final selectedSymptoms = ['G01', 'G02', 'G03', 'G04'];
      final results = ForwardChainingEngine.diagnose(selectedSymptoms);

      expect(results.isNotEmpty, true);
      
      // Ambil hasil teratas (confidence tertinggi)
      final primaryResult = results.first;
      expect(primaryResult.disease.id, 'P01');
      expect(primaryResult.confidence, 100.0);
      expect(primaryResult.matchedSymptoms.length, 4);
      expect(primaryResult.totalSymptoms, 4);
    });

    test('Harus mendeteksi Busuk Pucuk (P02) dengan kecocokan 100% saat gejala G05, G06 terpenuhi', () {
      final selectedSymptoms = ['G05', 'G06'];
      final results = ForwardChainingEngine.diagnose(selectedSymptoms);

      expect(results.isNotEmpty, true);
      final primaryResult = results.first;
      expect(primaryResult.disease.id, 'P02');
      expect(primaryResult.confidence, 100.0);
    });

    test('Harus menghitung kecocokan parsial secara akurat jika hanya sebagian gejala terpenuhi', () {
      // Penyakit Mahkota (P03) butuh G07, G08, G09
      // Kita pilih G07 dan G09 saja (2 dari 3 gejala = 66.67%)
      final selectedSymptoms = ['G07', 'G09'];
      final results = ForwardChainingEngine.diagnose(selectedSymptoms);

      expect(results.isNotEmpty, true);

      // Cari hasil untuk penyakit P03
      final crownDiseaseResult = results.firstWhere((r) => r.disease.id == 'P03');
      expect(crownDiseaseResult.confidence, closeTo(66.67, 0.01));
      expect(crownDiseaseResult.matchedSymptoms.contains('G07'), true);
      expect(crownDiseaseResult.matchedSymptoms.contains('G09'), true);
    });

    test('Harus mengurutkan hasil berdasarkan persentase kecocokan (confidence) tertinggi', () {
      // Kita pilih G01 (bagian dari P01 - 1/4 = 25%) dan G05, G06 (bagian dari P02 - 100%)
      final selectedSymptoms = ['G01', 'G05', 'G06'];
      final results = ForwardChainingEngine.diagnose(selectedSymptoms);

      expect(results.length >= 2, true);
      
      // P02 harus berada di urutan pertama (100% > 25%)
      expect(results[0].disease.id, 'P02');
      expect(results[0].confidence, 100.0);

      // P01 harus berada di urutan setelahnya
      expect(results[1].disease.id, 'P01');
      expect(results[1].confidence, 25.0);
    });
  });
}
