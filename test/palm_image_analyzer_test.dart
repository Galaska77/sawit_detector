import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sawit_detector/utils/palm_image_analyzer.dart';

Uint8List _createRgbaGrid(
  int width,
  int height,
  List<int> Function(int x, int y) pixelBuilder,
) {
  final buffer = Uint8List(width * height * 4);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final rgb = pixelBuilder(x, y);
      final idx = (y * width + x) * 4;
      buffer[idx] = rgb[0];
      buffer[idx + 1] = rgb[1];
      buffer[idx + 2] = rgb[2];
      buffer[idx + 3] = 255;
    }
  }
  return buffer;
}

void main() {
  group('Pengujian PalmImageAnalyzer (Validasi Pelepah Sawit & Deteksi Visual)', () {
    test('Harus menolak gambar wajah / warna kulit sebagai bukan pelepah sawit', () {
      final rgba = _createRgbaGrid(64, 64, (x, y) {
        // Warna kulit manusia dengan sedikit variasi pencahayaan
        final delta = (x % 3) * 4;
        return [210 - delta, 155 - delta, 125 - delta];
      });

      final result = PalmImageAnalyzer.analyzeRgba(rgba, 64, 64);

      expect(result.isPalmFrond, false);
      expect(result.validationError, PalmValidationError.nonPlantSkinOrFace);
      expect(result.detectedSymptomIds, isEmpty);
    });

    test('Harus menolak wajah di tengah bingkai meskipun ada latar hijau di pinggir', () {
      final rgba = _createRgbaGrid(64, 64, (x, y) {
        final inCenter = x >= 14 && x <= 50 && y >= 14 && y <= 50;
        if (inCenter) {
          return [205, 148, 118]; // Wajah di tengah
        }
        return (x + y) % 2 == 0 ? [45, 130, 50] : [60, 150, 65]; // Daun di tepi
      });

      final result = PalmImageAnalyzer.analyzeRgba(rgba, 64, 64);

      expect(result.isPalmFrond, false);
      expect(result.validationError, PalmValidationError.nonPlantSkinOrFace);
      expect(result.detectedSymptomIds, isEmpty);
    });

    test('Harus menolak tembok polos / latar abu-abu netral', () {
      final rgba = _createRgbaGrid(64, 64, (x, y) => [215, 215, 218]);

      final result = PalmImageAnalyzer.analyzeRgba(rgba, 64, 64);

      expect(result.isPalmFrond, false);
      expect(result.validationError, PalmValidationError.neutralBackground);
      expect(result.detectedSymptomIds, isEmpty);
    });

    test('Harus menolak gambar yang terlalu gelap', () {
      final rgba = _createRgbaGrid(64, 64, (x, y) => [10, 12, 10]);

      final result = PalmImageAnalyzer.analyzeRgba(rgba, 64, 64);

      expect(result.isPalmFrond, false);
      expect(result.validationError, PalmValidationError.tooDark);
    });

    test('Harus menolak bidang hijau polos tanpa tekstur helai daun', () {
      final rgba = _createRgbaGrid(64, 64, (x, y) => [40, 150, 45]);

      final result = PalmImageAnalyzer.analyzeRgba(rgba, 64, 64);

      expect(result.isPalmFrond, false);
      expect(result.validationError, PalmValidationError.flatGreenSurface);
    });

    test('Harus mengenali pelepah sawit hijau bertekstur sebagai sehat', () {
      final rgba = _createRgbaGrid(64, 64, (x, y) {
        // Pola garis lidi/helai anak daun hijau sawit
        if (x % 4 == 0) {
          return [30, 95, 35]; // Bayangan celah helai daun
        }
        return [55, 145, 50]; // Hijau daun segar
      });

      final result = PalmImageAnalyzer.analyzeRgba(rgba, 64, 64);

      expect(result.isPalmFrond, true);
      expect(result.detectedSymptomIds, isEmpty);
      expect(result.healthyVegetationPercent, greaterThan(75.0));
    });

    test('Harus mendeteksi gejala menguning luas (G01) pada pelepah sawit', () {
      final rgba = _createRgbaGrid(64, 64, (x, y) {
        if (y < 24) {
          return x % 3 == 0 ? [40, 110, 35] : [60, 145, 55]; // Sebagian hijau
        }
        // Area pelepah menguning klorosis
        return y % 4 == 0 ? [185, 170, 35] : [205, 190, 45];
      });

      final result = PalmImageAnalyzer.analyzeRgba(rgba, 64, 64);

      expect(result.isPalmFrond, true);
      expect(result.detectedSymptomIds.contains('G01'), true);
    });

    test('Harus mendeteksi gejala bercak gelap dengan halo kuning (G12)', () {
      final rgba = _createRgbaGrid(64, 64, (x, y) {
        // Buat 6 bercak coklat gelap dikelilingi lingkaran kuning di atas daun hijau
        for (final cx in [16, 32, 48]) {
          for (final cy in [20, 44]) {
            final dx = (x - cx).abs();
            final dy = (y - cy).abs();
            if (dx <= 1 && dy <= 1) {
              return [65, 42, 22]; // Pusat bercak coklat gelap
            }
            if (dx <= 3 && dy <= 3) {
              return [205, 190, 40]; // Halo kuning
            }
          }
        }
        return x % 5 == 0 ? [38, 105, 38] : [55, 145, 50];
      });

      final result = PalmImageAnalyzer.analyzeRgba(rgba, 64, 64);

      expect(result.isPalmFrond, true);
      expect(result.detectedSymptomIds.contains('G12'), true);
    });
  });
}
