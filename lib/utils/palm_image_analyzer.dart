import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Alasan mengapa gambar ditolak sebagai bukan pelepah/daun sawit.
enum PalmValidationError {
  invalidImage,
  tooDark,
  tooBright,
  nonPlantSkinOrFace,
  nonPlantColor,
  neutralBackground,
  noPalmFoliage,
  flatGreenSurface,
}

/// Hasil analisis citra pelepah kelapa sawit berbasis karakteristik visual.
class PalmImageAnalysis {
  final bool isPalmFrond;
  final PalmValidationError? validationError;
  final String statusTitle;
  final String statusDetail;
  final List<String> detectedSymptomIds;

  // Metrik proporsi visual (0.0 - 1.0)
  final double greenLeafRatio;
  final double yellowChlorosisRatio;
  final double brownDryRatio;
  final double darkRotRatio;
  final double skinOrNonPlantRatio;
  final double meanBrightness;
  final double edgeDensity;

  const PalmImageAnalysis({
    required this.isPalmFrond,
    this.validationError,
    required this.statusTitle,
    required this.statusDetail,
    required this.detectedSymptomIds,
    required this.greenLeafRatio,
    required this.yellowChlorosisRatio,
    required this.brownDryRatio,
    required this.darkRotRatio,
    required this.skinOrNonPlantRatio,
    required this.meanBrightness,
    required this.edgeDensity,
  });

  /// Mengembalikan persentase kesehatan daun relatif terhadap area vegetasi.
  double get healthyVegetationPercent {
    final total = greenLeafRatio + yellowChlorosisRatio + brownDryRatio + darkRotRatio;
    if (total <= 0) return 0.0;
    return (greenLeafRatio / total) * 100.0;
  }

  /// Mengembalikan persentase area menguning relatif terhadap area vegetasi.
  double get yellowingPercent {
    final total = greenLeafRatio + yellowChlorosisRatio + brownDryRatio + darkRotRatio;
    if (total <= 0) return 0.0;
    return (yellowChlorosisRatio / total) * 100.0;
  }

  /// Mengembalikan persentase bercak/busuk relatif terhadap area vegetasi.
  double get lesionPercent {
    final total = greenLeafRatio + yellowChlorosisRatio + brownDryRatio + darkRotRatio;
    if (total <= 0) return 0.0;
    return ((brownDryRatio + darkRotRatio) / total) * 100.0;
  }
}

enum _PixelClass {
  greenLeaf,
  yellowLeaf,
  dryBrown,
  darkRot,
  skinTone,
  nonPlantColor,
  neutral,
}

/// Penganalisis citra digital untuk memvalidasi apakah gambar merupakan pelepah/daun sawit
/// serta mengekstrak gejala visual penyakit secara langsung dari piksel gambar.
class PalmImageAnalyzer {
  static const int _targetGridSize = 96;

  /// Mendekode byte gambar terkompresi (JPEG/PNG) menggunakan `dart:ui` lalu menganalisisnya.
  static Future<PalmImageAnalysis> analyzeImageBytes(Uint8List encodedBytes) async {
    if (encodedBytes.isEmpty) {
      return _rejected(
        error: PalmValidationError.invalidImage,
        title: 'Gambar Tidak Valid',
        detail: 'Data gambar kosong atau tidak dapat dibaca.',
      );
    }

    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      // Decode pada resolusi yang efisien agar cepat dan hemat memori
      codec = await ui.instantiateImageCodec(
        encodedBytes,
        targetWidth: 256,
      );
      frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        return _rejected(
          error: PalmValidationError.invalidImage,
          title: 'Gagal Membaca Piksel',
          detail: 'Format piksel gambar tidak didukung.',
        );
      }

      return analyzeRgba(
        byteData.buffer.asUint8List(),
        frame.image.width,
        frame.image.height,
      );
    } catch (e) {
      return _rejected(
        error: PalmValidationError.invalidImage,
        title: 'Gagal Memproses Gambar',
        detail: 'Terjadi kesalahan saat membaca gambar: $e',
      );
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
  }

  /// Menganalisis buffer piksel RGBA mentah untuk memvalidasi pelepah sawit dan gejala visual.
  static PalmImageAnalysis analyzeRgba(Uint8List rgbaBytes, int width, int height) {
    if (width <= 0 || height <= 0 || rgbaBytes.length < width * height * 4) {
      return _rejected(
        error: PalmValidationError.invalidImage,
        title: 'Dimensi Gambar Tidak Valid',
        detail: 'Ukuran atau buffer gambar tidak sesuai.',
      );
    }

    final int gridW = math.min(width, _targetGridSize);
    final int gridH = math.min(height, _targetGridSize);
    final int totalSamples = gridW * gridH;

    final classes = List<_PixelClass>.filled(totalSamples, _PixelClass.neutral);
    final lums = Float64List(totalSamples);
    final exGs = Float64List(totalSamples);

    int greenCount = 0;
    int yellowCount = 0;
    int dryBrownCount = 0;
    int darkRotCount = 0;
    int skinCount = 0;
    int nonPlantColorCount = 0;
    int neutralCount = 0;
    int overexposedCount = 0;

    // Area tengah (ROI 60% x 60%) tempat bingkai kamera diarahkan
    int centerSamples = 0;
    int centerGreenCount = 0;
    int centerYellowCount = 0;
    int centerSkinCount = 0;
    int centerNonPlantCount = 0;

    double sumBrightness = 0.0;
    double sumExGOnGreen = 0.0;
    double sumExG2OnGreen = 0.0;

    for (int gy = 0; gy < gridH; gy++) {
      final int srcY = ((gy + 0.5) * height / gridH).floor().clamp(0, height - 1);
      final bool inCenterY = gy >= (gridH * 0.2) && gy <= (gridH * 0.8);

      for (int gx = 0; gx < gridW; gx++) {
        final int srcX = ((gx + 0.5) * width / gridW).floor().clamp(0, width - 1);
        final bool inCenter = inCenterY && gx >= (gridW * 0.2) && gx <= (gridW * 0.8);

        final int byteIdx = (srcY * width + srcX) * 4;
        final int r = rgbaBytes[byteIdx];
        final int g = rgbaBytes[byteIdx + 1];
        final int b = rgbaBytes[byteIdx + 2];

        final double rn = r / 255.0;
        final double gn = g / 255.0;
        final double bn = b / 255.0;

        final double maxC = math.max(rn, math.max(gn, bn));
        final double minC = math.min(rn, math.min(gn, bn));
        final double delta = maxC - minC;
        final double v = maxC;
        final double s = maxC == 0.0 ? 0.0 : delta / maxC;

        double h = 0.0;
        if (delta > 0.0) {
          if (maxC == rn) {
            h = 60.0 * (((gn - bn) / delta) % 6.0);
          } else if (maxC == gn) {
            h = 60.0 * (((bn - rn) / delta) + 2.0);
          } else {
            h = 60.0 * (((rn - gn) / delta) + 4.0);
          }
          if (h < 0.0) h += 360.0;
        }

        final double lum = 0.299 * rn + 0.587 * gn + 0.114 * bn;
        final double exG = 2.0 * gn - rn - bn;
        final int gIdx = gy * gridW + gx;
        lums[gIdx] = lum;
        exGs[gIdx] = exG;
        sumBrightness += v;

        if (v > 0.96 && s < 0.12) {
          overexposedCount++;
        }

        final _PixelClass pClass = _classifyPixel(r, g, b, rn, gn, bn, h, s, v, exG);
        classes[gIdx] = pClass;

        switch (pClass) {
          case _PixelClass.greenLeaf:
            greenCount++;
            sumExGOnGreen += exG;
            sumExG2OnGreen += exG * exG;
            if (inCenter) centerGreenCount++;
          case _PixelClass.yellowLeaf:
            yellowCount++;
            if (inCenter) centerYellowCount++;
          case _PixelClass.dryBrown:
            dryBrownCount++;
          case _PixelClass.darkRot:
            darkRotCount++;
          case _PixelClass.skinTone:
            skinCount++;
            if (inCenter) centerSkinCount++;
          case _PixelClass.nonPlantColor:
            nonPlantColorCount++;
            if (inCenter) centerNonPlantCount++;
          case _PixelClass.neutral:
            neutralCount++;
        }

        if (inCenter) centerSamples++;
      }
    }

    final double meanBrightness = sumBrightness / totalSamples;
    final double greenRatio = greenCount / totalSamples;
    final double yellowRatio = yellowCount / totalSamples;
    final double dryBrownRatio = dryBrownCount / totalSamples;
    final double darkRotRatio = darkRotCount / totalSamples;
    final double skinRatio = skinCount / totalSamples;
    final double nonPlantColorRatio = nonPlantColorCount / totalSamples;
    final double neutralRatio = neutralCount / totalSamples;
    final double overexposedRatio = overexposedCount / totalSamples;

    final double centerGreenRatio = centerSamples > 0 ? centerGreenCount / centerSamples : 0.0;
    final double centerYellowRatio = centerSamples > 0 ? centerYellowCount / centerSamples : 0.0;
    final double centerSkinRatio = centerSamples > 0 ? centerSkinCount / centerSamples : 0.0;
    final double centerNonPlantRatio = centerSamples > 0 ? centerNonPlantCount / centerSamples : 0.0;

    // Hitung kepadatan tepi / tekstur (untuk membedakan helai daun vs bidang polos)
    int edgePairs = 0;
    int totalPairs = 0;
    for (int gy = 0; gy < gridH - 1; gy++) {
      for (int gx = 0; gx < gridW - 1; gx++) {
        final int idx = gy * gridW + gx;
        final int rightIdx = idx + 1;
        final int downIdx = idx + gridW;

        totalPairs += 2;
        if ((lums[idx] - lums[rightIdx]).abs() > 0.06 ||
            (exGs[idx] - exGs[rightIdx]).abs() > 0.07) {
          edgePairs++;
        }
        if ((lums[idx] - lums[downIdx]).abs() > 0.06 ||
            (exGs[idx] - exGs[downIdx]).abs() > 0.07) {
          edgePairs++;
        }
      }
    }
    final double edgeDensity = totalPairs > 0 ? edgePairs / totalPairs : 0.0;

    double greenExGStdDev = 0.0;
    if (greenCount > 1) {
      final double meanExG = sumExGOnGreen / greenCount;
      final double variance = math.max(0.0, (sumExG2OnGreen / greenCount) - (meanExG * meanExG));
      greenExGStdDev = math.sqrt(variance);
    }

    final double combinedNonPlant = math.min(1.0, skinRatio + nonPlantColorRatio);

    // --- TAHAP 1: VALIDASI APAKAH OBJEK BENAR-BENAR PELEPAH / DAUN SAWIT ---
    if (meanBrightness < 0.13) {
      return PalmImageAnalysis(
        isPalmFrond: false,
        validationError: PalmValidationError.tooDark,
        statusTitle: 'Pencahayaan Terlalu Gelap',
        statusDetail:
            'Gambar terlalu gelap untuk dianalisis. Pastikan pencahayaan cukup dan arahkan kamera langsung ke pelepah sawit.',
        detectedSymptomIds: const [],
        greenLeafRatio: greenRatio,
        yellowChlorosisRatio: yellowRatio,
        brownDryRatio: dryBrownRatio,
        darkRotRatio: darkRotRatio,
        skinOrNonPlantRatio: combinedNonPlant,
        meanBrightness: meanBrightness,
        edgeDensity: edgeDensity,
      );
    }

    if (overexposedRatio > 0.72) {
      return PalmImageAnalysis(
        isPalmFrond: false,
        validationError: PalmValidationError.tooBright,
        statusTitle: 'Gambar Terlalu Silau',
        statusDetail:
            'Cahaya terlalu terang sehingga warna dan tekstur daun sawit tidak dapat dikenali.',
        detectedSymptomIds: const [],
        greenLeafRatio: greenRatio,
        yellowChlorosisRatio: yellowRatio,
        brownDryRatio: dryBrownRatio,
        darkRotRatio: darkRotRatio,
        skinOrNonPlantRatio: combinedNonPlant,
        meanBrightness: meanBrightness,
        edgeDensity: edgeDensity,
      );
    }

    // Tolak wajah / kulit manusia (terutama jika berada di tengah frame kamera)
    if ((centerSkinRatio >= 0.18 && centerGreenRatio < 0.15) ||
        ((centerSkinRatio >= 0.18 || skinRatio >= 0.25) && greenRatio < 0.18)) {
      return PalmImageAnalysis(
        isPalmFrond: false,
        validationError: PalmValidationError.nonPlantSkinOrFace,
        statusTitle: 'Bukan Pelepah Sawit',
        statusDetail:
            'Terdeteksi objek non-tanaman (seperti wajah/kulit atau objek berwarna krem/oranye). Fokuskan kamera hanya pada pelepah atau helai daun kelapa sawit.',
        detectedSymptomIds: const [],
        greenLeafRatio: greenRatio,
        yellowChlorosisRatio: yellowRatio,
        brownDryRatio: dryBrownRatio,
        darkRotRatio: darkRotRatio,
        skinOrNonPlantRatio: combinedNonPlant,
        meanBrightness: meanBrightness,
        edgeDensity: edgeDensity,
      );
    }

    // Tolak warna non-vegetasi dominan (langit biru, baju merah/ungu, dll.)
    if ((nonPlantColorRatio >= 0.35 || centerNonPlantRatio >= 0.35) && greenRatio < 0.20) {
      return PalmImageAnalysis(
        isPalmFrond: false,
        validationError: PalmValidationError.nonPlantColor,
        statusTitle: 'Bukan Pelepah Sawit',
        statusDetail:
            'Warna dominan pada foto tidak sesuai dengan karakteristik vegetasi pelepah atau daun kelapa sawit.',
        detectedSymptomIds: const [],
        greenLeafRatio: greenRatio,
        yellowChlorosisRatio: yellowRatio,
        brownDryRatio: dryBrownRatio,
        darkRotRatio: darkRotRatio,
        skinOrNonPlantRatio: combinedNonPlant,
        meanBrightness: meanBrightness,
        edgeDensity: edgeDensity,
      );
    }

    // Tolak bidang netral/polos (tembok, meja abu-abu/putih, latar belakang ruangan)
    if (neutralRatio >= 0.72 && greenRatio < 0.12) {
      return PalmImageAnalysis(
        isPalmFrond: false,
        validationError: PalmValidationError.neutralBackground,
        statusTitle: 'Bukan Pelepah Sawit',
        statusDetail:
            'Gambar didominasi bidang netral atau polos (tembok, lantai, atau ruangan). Arahkan kamera lebih dekat ke pelepah sawit.',
        detectedSymptomIds: const [],
        greenLeafRatio: greenRatio,
        yellowChlorosisRatio: yellowRatio,
        brownDryRatio: dryBrownRatio,
        darkRotRatio: darkRotRatio,
        skinOrNonPlantRatio: combinedNonPlant,
        meanBrightness: meanBrightness,
        edgeDensity: edgeDensity,
      );
    }

    // Wajib memiliki komponen vegetasi hijau/daun sawit yang memadai di keseluruhan dan tengah frame
    final double totalFoliage = greenRatio + yellowRatio;
    final double centerFoliage = centerGreenRatio + centerYellowRatio;
    final bool hasEnoughPalmFoliage =
        (greenRatio >= 0.10 || (totalFoliage >= 0.28 && greenRatio >= 0.05 && skinRatio < 0.15)) &&
            centerFoliage >= 0.10;

    if (!hasEnoughPalmFoliage) {
      return PalmImageAnalysis(
        isPalmFrond: false,
        validationError: PalmValidationError.noPalmFoliage,
        statusTitle: 'Pelepah Sawit Tidak Terdeteksi',
        statusDetail:
            'Objek di dalam area fokus tidak menunjukkan karakteristik daun/pelepah kelapa sawit. Pastikan pelepah berada di tengah bingkai kamera.',
        detectedSymptomIds: const [],
        greenLeafRatio: greenRatio,
        yellowChlorosisRatio: yellowRatio,
        brownDryRatio: dryBrownRatio,
        darkRotRatio: darkRotRatio,
        skinOrNonPlantRatio: combinedNonPlant,
        meanBrightness: meanBrightness,
        edgeDensity: edgeDensity,
      );
    }

    // Tolak bidang hijau polos seragam tanpa tekstur daun/lidi (misal tembok cat hijau/layar hijau)
    if (edgeDensity < 0.015 &&
        greenExGStdDev < 0.035 &&
        yellowRatio < 0.02 &&
        darkRotRatio < 0.01) {
      return PalmImageAnalysis(
        isPalmFrond: false,
        validationError: PalmValidationError.flatGreenSurface,
        statusTitle: 'Bukan Pelepah Sawit',
        statusDetail:
            'Permukaan hijau terlihat polos dan seragam tanpa tekstur helai daun atau lidi pelepah sawit.',
        detectedSymptomIds: const [],
        greenLeafRatio: greenRatio,
        yellowChlorosisRatio: yellowRatio,
        brownDryRatio: dryBrownRatio,
        darkRotRatio: darkRotRatio,
        skinOrNonPlantRatio: combinedNonPlant,
        meanBrightness: meanBrightness,
        edgeDensity: edgeDensity,
      );
    }

    // --- TAHAP 2: EKSTRAKSI GEJALA PENYAKIT DARI CITRA PELEPAH SAWIT ---
    final int plantPixels = greenCount + yellowCount + dryBrownCount + darkRotCount;
    final double relGreen = plantPixels > 0 ? greenCount / plantPixels : 0.0;
    final double relYellow = plantPixels > 0 ? yellowCount / plantPixels : 0.0;
    final double relDryBrown = plantPixels > 0 ? dryBrownCount / plantPixels : 0.0;
    final double relDarkRot = plantPixels > 0 ? darkRotCount / plantPixels : 0.0;

    // Deteksi pola spasial: bercak gelap dengan halo kuning (Antraknosa) & bintik tersebar (Curvularia)
    int haloSpotPixels = 0;
    int scatteredSpotPixels = 0;
    for (int gy = 2; gy < gridH - 2; gy++) {
      for (int gx = 2; gx < gridW - 2; gx++) {
        final int idx = gy * gridW + gx;
        final _PixelClass c = classes[idx];

        if (c == _PixelClass.darkRot) {
          bool nearYellow = false;
          bool nearGreen = false;
          for (int dy = -4; dy <= 4; dy++) {
            final int ny = gy + dy;
            if (ny < 0 || ny >= gridH) continue;
            for (int dx = -4; dx <= 4; dx++) {
              final int nx = gx + dx;
              if (nx < 0 || nx >= gridW) continue;
              final _PixelClass nb = classes[ny * gridW + nx];
              if (nb == _PixelClass.yellowLeaf && dx.abs() <= 2 && dy.abs() <= 2) {
                nearYellow = true;
              }
              if (nb == _PixelClass.greenLeaf) {
                nearGreen = true;
              }
            }
          }
          if (nearYellow && nearGreen) {
            haloSpotPixels++;
          }
        }

        if (c == _PixelClass.yellowLeaf || c == _PixelClass.dryBrown) {
          int greenNeighbors = 0;
          for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
              if (dx == 0 && dy == 0) continue;
              if (classes[(gy + dy) * gridW + (gx + dx)] == _PixelClass.greenLeaf) {
                greenNeighbors++;
              }
            }
          }
          // Titik kecil yang dikelilingi dominan hijau menandakan bercak bintik terpisah
          if (greenNeighbors >= 14) {
            scatteredSpotPixels++;
          }
        }
      }
    }

    final double haloSpotRatio = plantPixels > 0 ? haloSpotPixels / plantPixels : 0.0;
    final double scatteredSpotRatio = plantPixels > 0 ? scatteredSpotPixels / plantPixels : 0.0;

    final List<String> detectedSymptoms = [];

    final bool isClearlyHealthy = relGreen >= 0.78 &&
        relYellow < 0.15 &&
        relDryBrown < 0.08 &&
        relDarkRot < 0.05 &&
        haloSpotRatio < 0.010 &&
        scatteredSpotRatio < 0.03;

    if (!isClearlyHealthy) {
      // G12: Bercak coklat kehitaman dikelilingi warna kuning (halo) -> Antraknosa (P05)
      if (haloSpotRatio >= 0.010 && relGreen >= 0.25) {
        detectedSymptoms.add('G12');
      }

      // G13: Bercak kecil bulat kuning kecoklatan tersebar -> Curvularia (P06)
      if (scatteredSpotRatio >= 0.03 && !detectedSymptoms.contains('G12')) {
        detectedSymptoms.add('G13');
      }

      // G05: Pembusukan basah berwarna coklat gelap -> Busuk Pucuk (P02)
      if (relDarkRot >= 0.16) {
        detectedSymptoms.add('G05');
      }

      // G01: Pelepah daun menguning luas (klorosis berat) -> indikasi visual Ganoderma (P01)
      if (relYellow >= 0.22) {
        detectedSymptoms.add('G01');
      }

      // G10: Pelepah mengering/coklat jerami luas -> indikasi Busuk Batang Atas (P04)
      if (relDryBrown >= 0.20) {
        detectedSymptoms.add('G10');
      }

      // Jika ada gangguan visual kombinasi ringan-sedang yang belum melewati threshold tunggal
      if (detectedSymptoms.isEmpty) {
        if (relDarkRot >= 0.08) {
          detectedSymptoms.add('G05');
        } else if (relYellow >= relDryBrown && relYellow >= 0.12) {
          detectedSymptoms.add('G01');
        } else if (relDryBrown >= 0.10) {
          detectedSymptoms.add('G10');
        } else if (scatteredSpotRatio >= 0.015) {
          detectedSymptoms.add('G13');
        }
      }
    }

    final String title = detectedSymptoms.isEmpty
        ? 'Pelepah Sawit Terdeteksi (Sehat)'
        : 'Pelepah Sawit Terdeteksi (Ada Gejala Visual)';

    final String detail = detectedSymptoms.isEmpty
        ? 'Daun dan pelepah didominasi warna hijau sehat tanpa indikasi klorosis, bercak halo, maupun pembusukan berarti.'
        : 'Analisis visual mendeteksi indikasi gejala pada pelepah (${detectedSymptoms.join(', ')}). Anda dapat melengkapi gejala lapangan lain melalui kuisioner.';

    return PalmImageAnalysis(
      isPalmFrond: true,
      validationError: null,
      statusTitle: title,
      statusDetail: detail,
      detectedSymptomIds: detectedSymptoms,
      greenLeafRatio: greenRatio,
      yellowChlorosisRatio: yellowRatio,
      brownDryRatio: dryBrownRatio,
      darkRotRatio: darkRotRatio,
      skinOrNonPlantRatio: combinedNonPlant,
      meanBrightness: meanBrightness,
      edgeDensity: edgeDensity,
    );
  }

  static _PixelClass _classifyPixel(
    int r,
    int g,
    int b,
    double rn,
    double gn,
    double bn,
    double h,
    double s,
    double v,
    double exG,
  ) {
    if (s < 0.15) {
      return _PixelClass.neutral;
    }

    // Kulit manusia / wajah: merah dominan, tanpa excess green, saturasi sedang
    final int maxRgb = math.max(r, math.max(g, b));
    final int minRgb = math.min(r, math.min(g, b));
    final bool isSkinRgb = r > 85 &&
        g > 35 &&
        b > 15 &&
        (maxRgb - minRgb) > 15 &&
        (r - g).abs() > 12 &&
        r > g &&
        r > b;
    final bool isSkinHsv = ((h >= 0.0 && h <= 42.0) || h >= 335.0) &&
        s >= 0.12 &&
        s <= 0.72 &&
        v >= 0.20 &&
        v <= 0.96;
    if (isSkinRgb && isSkinHsv && exG < 0.0) {
      return _PixelClass.skinTone;
    }

    // Daun hijau sawit (spektrum hijau dengan excess green positif)
    if (h >= 62.0 && h <= 165.0 && s >= 0.16 && v >= 0.12 && v <= 0.95 && exG > 0.03) {
      return _PixelClass.greenLeaf;
    }

    // Daun menguning / klorosis
    if (h >= 40.0 && h < 62.0 && s >= 0.22 && v >= 0.22 && gn >= rn * 0.72 && gn > bn * 1.25) {
      return _PixelClass.yellowLeaf;
    }

    // Pembusukan / bercak coklat gelap kehitaman
    if (h >= 8.0 && h < 45.0 && s >= 0.18 && v >= 0.08 && v < 0.34 && r > b) {
      return _PixelClass.darkRot;
    }

    // Daun mengering / nekrosis coklat jerami
    if (h >= 18.0 && h < 45.0 && s >= 0.15 && s <= 0.75 && v >= 0.34 && v <= 0.85) {
      return _PixelClass.dryBrown;
    }

    // Warna non-vegetasi (biru, ungu, magenta, merah pekat)
    if (s >= 0.18 && ((h > 170.0 && h < 335.0) || (h < 18.0 && s > 0.38))) {
      return _PixelClass.nonPlantColor;
    }

    return _PixelClass.neutral;
  }

  static PalmImageAnalysis _rejected({
    required PalmValidationError error,
    required String title,
    required String detail,
  }) {
    return PalmImageAnalysis(
      isPalmFrond: false,
      validationError: error,
      statusTitle: title,
      statusDetail: detail,
      detectedSymptomIds: const [],
      greenLeafRatio: 0.0,
      yellowChlorosisRatio: 0.0,
      brownDryRatio: 0.0,
      darkRotRatio: 0.0,
      skinOrNonPlantRatio: 0.0,
      meanBrightness: 0.0,
      edgeDensity: 0.0,
    );
  }
}
