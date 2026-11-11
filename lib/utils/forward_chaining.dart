class Symptom {
  final String id;
  final String name;
  final String question;

  const Symptom({
    required this.id,
    required this.name,
    required this.question,
  });
}

class Disease {
  final String id;
  final String name;
  final String description;
  final String solution;

  const Disease({
    required this.id,
    required this.name,
    required this.description,
    required this.solution,
  });
}

class Rule {
  final String id;
  final List<String> symptomIds;
  final String diseaseId;

  const Rule({
    required this.id,
    required this.symptomIds,
    required this.diseaseId,
  });
}

class DiagnosisResult {
  final Disease disease;
  final double confidence;
  final List<String> matchedSymptoms;
  final int totalSymptoms;

  DiagnosisResult({
    required this.disease,
    required this.confidence,
    required this.matchedSymptoms,
    required this.totalSymptoms,
  });
}

class ForwardChainingEngine {
  static const List<Symptom> symptoms = [
    Symptom(
      id: 'G01',
      name: 'Pelepah daun tua menguning dan sengkleh (menggantung layu)',
      question: 'Apakah pelepah daun tua kelapa sawit terlihat menguning dan sengkleh (menggantung layu di sekitar batang)?',
    ),
    Symptom(
      id: 'G02',
      name: 'Daun tombak (pucuk muda) tidak membuka lebih dari 2-3 pelepah',
      question: 'Apakah terdapat lebih dari 2-3 daun tombak (pucuk muda) yang tetap tegak dan tidak mau membuka?',
    ),
    Symptom(
      id: 'G03',
      name: 'Terdapat tubuh buah jamur (basidiokarp berbentuk setengah lingkaran) di pangkal batang',
      question: 'Apakah terlihat adanya tubuh buah jamur seperti kuping/setengah lingkaran keras berwarna coklat/putih di pangkal batang?',
    ),
    Symptom(
      id: 'G04',
      name: 'Pangkal batang membusuk, berongga, atau mengeluarkan lendir kecoklatan',
      question: 'Apakah pangkal batang kelapa sawit membusuk, berongga, atau mengeluarkan cairan berlendir coklat saat dibongkar?',
    ),
    Symptom(
      id: 'G05',
      name: 'Daun tombak (pucuk) membusuk, berwarna kecoklatan, dan sangat mudah dicabut',
      question: 'Apakah daun tombak di pucuk membusuk basah, berwarna coklat gelap, dan gampang sekali dicabut?',
    ),
    Symptom(
      id: 'G06',
      name: 'Keluar aroma busuk menyengat dari bagian titik tumbuh (pucuk sawit)',
      question: 'Apakah tercium aroma busuk menyengat (seperti pembusukan basah) dari area titik tumbuh di puncak batang?',
    ),
    Symptom(
      id: 'G07',
      name: 'Pelepah daun muda yang baru tumbuh membengkok, melengkung, atau terpelintir',
      question: 'Apakah pelepah daun muda yang baru keluar terlihat membengkok, melengkung abnormal, atau terpelintir seperti mahkota?',
    ),
    Symptom(
      id: 'G08',
      name: 'Anak daun di bagian tengah pelepah tidak tumbuh/ompong (hanya lidi)',
      question: 'Apakah anak daun di bagian tengah pelepah tidak berkembang atau ompong, menyisakan lidi saja?',
    ),
    Symptom(
      id: 'G09',
      name: 'Serangan terjadi dominan pada tanaman muda umur 1 sampai 3 tahun',
      question: 'Apakah tanaman sawit yang terkena gejala ini tergolong masih muda (berumur sekitar 1-3 tahun)?',
    ),
    Symptom(
      id: 'G10',
      name: 'Pelepah daun di bagian tengah tajuk patah atau mengering terlebih dahulu',
      question: 'Apakah pelepah daun di bagian tengah tajuk/mahkota patah atau mengering duluan sebelum daun bagian bawah?',
    ),
    Symptom(
      id: 'G11',
      name: 'Batang atas membusuk atau patah di ketinggian lebih dari 2 meter dari tanah',
      question: 'Apakah terlihat pembusukan batang atau batang patah di ketinggian lebih dari 2 meter dari permukaan tanah?',
    ),
    Symptom(
      id: 'G12',
      name: 'Terdapat bercak coklat kehitaman dikelilingi warna kuning (halo) pada daun bibit',
      question: 'Apakah terdapat bercak-bercak coklat gelap kehitaman yang memiliki tepian lingkaran kuning terang pada daun bibit?',
    ),
    Symptom(
      id: 'G13',
      name: 'Bercak kecil bulat kuning kecoklatan dengan pusat bercak agak cekung ke dalam',
      question: 'Apakah daun sawit dipenuhi bercak kecil bulat kuning kecoklatan dengan titik tengah yang agak cekung ke dalam?',
    ),
  ];

  static const List<Disease> diseases = [
    Disease(
      id: 'P01',
      name: 'Busuk Pangkal Batang (Ganoderma)',
      description: 'Penyakit kelapa sawit paling mematikan yang disebabkan oleh jamur Ganoderma boninense. Jamur menyerang dari dalam tanah dan membusukkan jaringan batang bagian bawah secara perlahan namun pasti hingga tanaman tumbang.',
      solution: '1. Lakukan pembubunan tanah di sekitar pangkal batang untuk memperkuat berdirinya tanaman.\n2. Aplikasikan fungisida berbahan aktif mikrobia antagonis seperti Trichoderma harzianum ke tanah sekitar pangkal batang.\n3. Jika tanaman sudah rusak parah (>50% pangkal batang busuk), segera bongkar tanaman, buat parit isolasi, dan bakar sisa tunggul agar tidak menular ke tanaman sehat sekitarnya.',
    ),
    Disease(
      id: 'P02',
      name: 'Busuk Pucuk (Bud Rot)',
      description: 'Kerusakan pada bagian pucuk tanaman sawit yang biasanya diawali oleh serangan bakteri Erwinia atau jamur Phytophthora setelah adanya luka fisik atau serangan hama kumbang tanduk. Jika meristem mati, tanaman tidak bisa tumbuh lagi.',
      solution: '1. Potong bagian pucuk yang membusuk sampai batas jaringan pelepah yang sehat.\n2. Semprotkan fungisida kontak dan sistemik dicampur bakterisida secara berkala di pucuk tanaman.\n3. Bersihkan sisa potongan dan taburkan kapur pertanian atau tembaga hidroksida untuk menekan kelembapan meristem.',
    ),
    Disease(
      id: 'P03',
      name: 'Penyakit Mahkota (Crown Disease)',
      description: 'Penyakit bawaan faktor genetik turunan yang biasanya menyerang kelapa sawit muda berumur 1-3 tahun. Ditandai dengan daun tengah bengkok terpelintir dan ompong.',
      solution: '1. Berikan pupuk makro dan mikro yang seimbang, terutama unsur Nitrogen dan Kalium secara teratur untuk mempercepat pemulihan tajuk daun baru.\n2. Lakukan kastrasi (pembuangan bunga/buah prematur) agar nutrisi fokus ke pemulihan vegetatif daun.\n3. Penyakit ini umumnya akan sembuh dengan sendirinya seiring bertambahnya umur tanaman (>3 tahun) apabila sifat bawaan genetiknya tidak terlalu parah.',
    ),
    Disease(
      id: 'P04',
      name: 'Busuk Batang Atas (Upper Stem Rot)',
      description: 'Pembusukan jaringan dalam batang kelapa sawit pada bagian tengah atau atas tajuk tanaman (>2 meter dari tanah). Disebabkan oleh infeksi spora jamur Ganoderma sp. yang menyebar melalui udara (aerogen) dan masuk lewat bekas luka pemanenan pelepah.',
      solution: '1. Bersihkan pelepah yang terinfeksi dan lakukan sanitasi bagian tajuk atas.\n2. Lakukan injeksi batang menggunakan fungisida sistemik berbahan aktif Hexaconazole atau Propioconazole.\n3. Hindari membuat luka mekanis yang berlebihan pada batang bagian atas saat proses pemanenan pelepah.',
    ),
    Disease(
      id: 'P05',
      name: 'Antraknosa (Anthracnose)',
      description: 'Penyakit bercak daun yang sangat merugikan di pembibitan kelapa sawit (nursery). Disebabkan oleh kelompok jamur Melanconium sp., Glomerella cingulata, atau Botryodiplodia sp. Menyebar sangat cepat melalui percikan air siraman.',
      solution: '1. Kurangi frekuensi penyiraman pembibitan di sore hari untuk menghindari daun basah dalam waktu lama di malam hari.\n2. Segera pisahkan (karantina) bibit yang menunjukkan gejala bercak agar tidak menyebar ke bibit sehat.\n3. Semprotkan fungisida protektif berbahan aktif Mancozeb atau Captan dengan dosis anjuran seminggu sekali.',
    ),
    Disease(
      id: 'P06',
      name: 'Bercak Daun Curvularia (Curvularia Leaf Spot)',
      description: 'Penyakit daun yang disebabkan oleh jamur Curvularia maculans. Sangat umum menyerang bibit muda di pre-nursery maupun main-nursery, ditandai bercak bulat kuning-coklat cekung.',
      solution: '1. Atur jarak antar polibag bibit (jangan terlalu rapat) guna memperlancar sirkulasi udara dan mengurangi kelembapan sekitar tajuk.\n2. Aplikasikan fungisida berbahan aktif Tembaga Hidroksida atau Difenokonazol secara berkala sesuai tingkat keparahan gejala.\n3. Berikan pemupukan nitrogen dan mikronutrien yang cukup agar imunitas sel daun bibit meningkat.',
    ),
  ];

  static const List<Rule> rules = [
    Rule(id: 'R1', symptomIds: ['G01', 'G02', 'G03', 'G04'], diseaseId: 'P01'),
    Rule(id: 'R2', symptomIds: ['G05', 'G06'], diseaseId: 'P02'),
    Rule(id: 'R3', symptomIds: ['G07', 'G08', 'G09'], diseaseId: 'P03'),
    Rule(id: 'R4', symptomIds: ['G10', 'G11'], diseaseId: 'P04'),
    Rule(id: 'R5', symptomIds: ['G12', 'G09'], diseaseId: 'P05'),
    Rule(id: 'R6', symptomIds: ['G13', 'G09'], diseaseId: 'P06'),
  ];

  /// Mendiagnosis penyakit kelapa sawit berdasarkan daftar symptomIds yang dipilih user.
  /// Menggunakan metode Forward Chaining.
  /// Mengembalikan list DiagnosisResult yang terurut berdasarkan confidence tertinggi.
  static List<DiagnosisResult> diagnose(List<String> selectedSymptomIds) {
    if (selectedSymptomIds.isEmpty) return [];

    List<DiagnosisResult> results = [];

    // Evaluasi setiap rule (Forward Chaining)
    for (var rule in rules) {
      List<String> matched = [];
      for (var sId in rule.symptomIds) {
        if (selectedSymptomIds.contains(sId)) {
          matched.add(sId);
        }
      }

      if (matched.isNotEmpty) {
        // Hitung persentase kecocokan (confidence)
        // confidence = (jumlah gejala yang cocok / total gejala pada rule) * 100
        double confidence = (matched.length / rule.symptomIds.length) * 100.0;
        
        // Dapatkan data Penyakit
        Disease disease = diseases.firstWhere((d) => d.id == rule.diseaseId);

        results.add(DiagnosisResult(
          disease: disease,
          confidence: confidence,
          matchedSymptoms: matched,
          totalSymptoms: rule.symptomIds.length,
        ));
      }
    }

    // Urutkan berdasarkan persentase kecocokan tertinggi
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    return results;
  }
}
