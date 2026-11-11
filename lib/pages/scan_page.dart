import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../utils/forward_chaining.dart';
import '../utils/palm_image_analyzer.dart';
import 'result_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Camera variables
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _hasCameraError = false;
  String _cameraErrorMessage = '';
  bool _isFlashOn = false;

  // UI state variables
  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;

  bool _isScanning = false;
  String _scanningStatus = 'Menyiapkan pemindai...';
  double _scanningProgress = 0.0;
  Uint8List? _capturedImageBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();

    // Setup laser scanning animation
    _scannerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _isFlashOn = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _hasCameraError = false;
        _cameraErrorMessage = '';
      });
    }

    try {
      _cameras = await availableCameras();
      if (!mounted) return;

      if (_cameras.isNotEmpty) {
        final backCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first,
        );

        await _cameraController?.dispose();
        final controller = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        _cameraController = controller;

        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }

        setState(() {
          _isCameraInitialized = true;
          _hasCameraError = false;
        });
      } else {
        setState(() {
          _isCameraInitialized = false;
          _hasCameraError = true;
          _cameraErrorMessage = 'Perangkat tidak memiliki modul kamera.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        _hasCameraError = true;
        _cameraErrorMessage =
            'Izin kamera ditolak atau gagal menginisialisasi kamera.';
      });
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final nextFlash = !_isFlashOn;
      await controller.setFlashMode(nextFlash ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() {
          _isFlashOn = nextFlash;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lampu kilat tidak tersedia pada kamera ini.')),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndAnalyze() async {
    if (_isScanning) return;

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kamera belum aktif. Pastikan izin kamera diberikan lalu coba lagi.',
          ),
        ),
      );
      return;
    }

    try {
      setState(() {
        _isScanning = true;
        _scanningStatus = 'Mengambil gambar pelepah...';
        _scanningProgress = 0.1;
      });

      final XFile image = await controller.takePicture();
      final Uint8List bytes = await image.readAsBytes();

      if (_isFlashOn) {
        try {
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {}
      }

      if (!mounted) return;
      await _runVisualAnalysisPipeline(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil gambar: $e')),
      );
    }
  }

  Future<void> _runVisualAnalysisPipeline(Uint8List imageBytes) async {
    setState(() {
      _capturedImageBytes = imageBytes;
      _isFlashOn = false;
      _scanningProgress = 0.2;
      _scanningStatus = 'Memvalidasi objek pelepah sawit...';
    });

    // Jalankan analisis citra nyata secara paralel dengan progres UI singkat
    final analysisFuture = PalmImageAnalyzer.analyzeImageBytes(imageBytes);

    final steps = <(double, String)>[
      (0.4, 'Mengecek spektrum vegetasi & tekstur daun...'),
      (0.65, 'Menganalisis klorosis kuning & bercak daun...'),
      (0.85, 'Mencocokkan gejala visual ke Forward Chaining...'),
    ];

    for (final (progress, status) in steps) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _scanningProgress = progress;
        _scanningStatus = status;
      });
    }

    final PalmImageAnalysis analysis = await analysisFuture;
    if (!mounted) return;

    setState(() {
      _scanningProgress = 1.0;
      _scanningStatus = analysis.isPalmFrond
          ? 'Pelepah sawit terverifikasi. Menyiapkan hasil...'
          : 'Objek bukan pelepah sawit. Menyiapkan laporan...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    // Hanya jalankan Forward Chaining jika gambar benar-benar terdeteksi sebagai pelepah sawit
    final List<String> detectedSymptoms =
        analysis.isPalmFrond ? analysis.detectedSymptomIds : const [];
    final List<DiagnosisResult> diagnosisResults = analysis.isPalmFrond
        ? ForwardChainingEngine.diagnose(detectedSymptoms)
        : const [];

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          selectedSymptomIds: detectedSymptoms,
          results: diagnosisResults,
          imageBytes: imageBytes,
          visualAnalysis: analysis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Scan Pelepah Sawit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isCameraInitialized && !_isScanning)
            IconButton(
              onPressed: _toggleFlash,
              tooltip: _isFlashOn ? 'Matikan Lampu' : 'Nyalakan Lampu',
              icon: Icon(
                _isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: _isFlashOn ? Colors.amber : Colors.white,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isScanning) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Text(
                        'FOKUS: PELEPAH SAWIT',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Arahkan Kamera ke Pelepah Sawit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sistem hanya menganalisis objek pelepah atau helai daun kelapa sawit. Objek selain sawit (wajah, tembok, benda lain) akan otomatis ditolak.',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Viewfinder / Camera Preview
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF102015),
                        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              if (_isCameraInitialized && _cameraController != null)
                                Positioned.fill(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    clipBehavior: Clip.hardEdge,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      child: CameraPreview(_cameraController!),
                                    ),
                                  ),
                                )
                              else
                                Positioned.fill(
                                  child: Container(
                                    color: const Color(0xFF0F2417),
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _hasCameraError
                                              ? Icons.videocam_off_outlined
                                              : Icons.camera_alt_outlined,
                                          color: Colors.grey[400],
                                          size: 52,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _hasCameraError
                                              ? _cameraErrorMessage
                                              : 'Menginisialisasi kamera...',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey[300],
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (_hasCameraError) ...[
                                          const SizedBox(height: 16),
                                          OutlinedButton.icon(
                                            onPressed: _initializeCamera,
                                            icon: const Icon(
                                              Icons.refresh,
                                              size: 18,
                                              color: Color(0xFF10B981),
                                            ),
                                            label: const Text(
                                              'Coba Aktifkan Kamera',
                                              style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Color(0xFF10B981),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

                              // Corner Markers
                              _buildCornerMarkers(),

                              // Label area tengah pemindaian
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: const Text(
                                      'Posisikan pelepah sawit di tengah bingkai',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Responsive scanner laser line
                              AnimatedBuilder(
                                animation: _scannerAnimation,
                                builder: (context, child) {
                                  final maxTop =
                                      (constraints.maxHeight - 4).clamp(0.0, double.infinity);
                                  return Positioned(
                                    top: _scannerAnimation.value * maxTop,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.6),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Panduan singkat akurasi visual
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152A1C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF223E2A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Deteksi warna daun hijau, klorosis kuning, bercak halo, dan nekrosis coklat langsung dari gambar.',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Shutter Button
                ElevatedButton.icon(
                  onPressed: _isCameraInitialized ? _takePictureAndAnalyze : null,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text(
                    'AMBIL FOTO & ANALISIS',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    disabledBackgroundColor: const Color(0xFF1B3524),
                    disabledForegroundColor: Colors.grey[500],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
              ] else ...[
                // SCANNING ACTIVE STATE
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: double.infinity,
                            height: 300,
                            decoration: BoxDecoration(
                              color: const Color(0xFF102015),
                              border: Border.all(
                                color: const Color(0xFF10B981),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: _capturedImageBytes != null
                                          ? Image.memory(
                                              _capturedImageBytes!,
                                              fit: BoxFit.cover,
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                    ),
                                    AnimatedBuilder(
                                      animation: _scannerAnimation,
                                      builder: (context, child) {
                                        final maxTop = (constraints.maxHeight - 4)
                                            .clamp(0.0, double.infinity);
                                        return Positioned(
                                          top: _scannerAnimation.value * maxTop,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF10B981)
                                                      .withValues(alpha: 0.8),
                                                  blurRadius: 10,
                                                  spreadRadius: 3,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        _scanningStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _scanningProgress,
                                backgroundColor: const Color(0xFF1B3524),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF10B981),
                                ),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_scanningProgress * 100).toInt()}% Selesai',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCornerMarkers() {
    const double markerSize = 24.0;
    const double borderThickness = 3.0;
    const Color markerColor = Color(0xFF10B981);

    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: markerSize,
                height: markerSize,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: markerColor, width: borderThickness),
                    left: BorderSide(color: markerColor, width: borderThickness),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: markerSize,
                height: markerSize,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: markerColor, width: borderThickness),
                    right: BorderSide(color: markerColor, width: borderThickness),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: markerSize,
                height: markerSize,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: markerColor, width: borderThickness),
                    left: BorderSide(color: markerColor, width: borderThickness),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: markerSize,
                height: markerSize,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: markerColor, width: borderThickness),
                    right: BorderSide(color: markerColor, width: borderThickness),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
