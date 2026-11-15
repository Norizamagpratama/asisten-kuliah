import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const warna = Color(0xFF4F46E5);
const gelap = Color(0xFF1E1B4B);
const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
const bobot = {'A': 4.0, 'B+': 3.5, 'B': 3.0, 'C+': 2.5, 'C': 2.0, 'D': 1.0, 'E': 0.0};
const batasHadir = 75.0; // batas minimal kehadiran (%)

// ================== PENYIMPANAN LOKAL ==================
class Db {
  static final Map<String, List<Map<String, dynamic>>> d = {};
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    for (final k in ['mk', 'tugas', 'jadwal', 'absen', 'prev']) {
      d[k] = (jsonDecode(p.getString(k) ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();
    }
  }

  static Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    for (final e in d.entries) {
      await p.setString(e.key, jsonEncode(e.value));
    }
  }
}

List<Map<String, dynamic>> get mk => Db.d['mk']!;
List<Map<String, dynamic>> get mkAktif => mk.where((m) => (m['status'] ?? 'aktif') == 'aktif').toList();

// IPK dan total SKS semester sebelumnya (diisi manual oleh pengguna)
Map<String, dynamic> get prev {
  final l = Db.d['prev']!;
  if (l.isEmpty) l.add({'ipk': 0.0, 'sks': 0});
  return l.first;
}

// Lulus jika nilai C ke atas (bobot >= 2). Nilai "-", D, dan E dianggap belum lulus.
bool lulus(String n) => (bobot[n] ?? -1) >= 2.0;

int sksTotal() => (prev['sks'] as num).toInt() + sksDinilai(mk);
double ipkTotal() {
  final ps = (prev['sks'] as num).toInt();
  final pi = (prev['ipk'] as num).toDouble();
  final poin = dinilai(mk).fold<double>(0, (a, m) => a + bobot[m['nilai']]! * (m['sks'] as int));
  final tot = ps + sksDinilai(mk);
  return tot == 0 ? 0 : (pi * ps + poin) / tot;
}

// ================== FUNGSI BANTU ==================
String uid() => DateTime.now().microsecondsSinceEpoch.toString();
String tgl(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String namaMk(String id) => mk.where((m) => m['id'] == id).map((m) => m['nama'] as String).firstOrNull ?? '-';

Iterable<Map<String, dynamic>> dinilai(Iterable<Map<String, dynamic>> l) => l.where((m) => bobot.containsKey(m['nilai']));
int sksDinilai(Iterable<Map<String, dynamic>> l) => dinilai(l).fold(0, (a, m) => a + (m['sks'] as int));
double ipk(Iterable<Map<String, dynamic>> l) {
  final s = sksDinilai(l);
  if (s == 0) return 0;
  return dinilai(l).fold<double>(0, (a, m) => a + bobot[m['nilai']]! * (m['sks'] as int)) / s;
}

Map<String, dynamic> absen(String id) {
  final l = Db.d['absen']!;
  return l.firstWhere((x) => x['id'] == id, orElse: () {
    final n = {'id': id, 'h': 0, 'i': 0, 's': 0, 'a': 0};
    l.add(n);
    return n;
  });
}

List<DropdownMenuItem<String>> mkItems([String? termasuk]) => mk
    .where((m) => (m['status'] ?? 'aktif') == 'aktif' || m['id'] == termasuk)
    .map((m) => DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['nama'], overflow: TextOverflow.ellipsis)))
    .toList();

Widget tf(TextEditingController c, String l, {bool num = false, void Function(String)? ch}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        onChanged: ch,
        keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(labelText: l, border: const OutlineInputBorder()),
      ),
    );

Widget dd(String l, String v, List<DropdownMenuItem<String>> items, void Function(String?) f) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: v,
        isExpanded: true,
        decoration: InputDecoration(labelText: l, border: const OutlineInputBorder()),
        items: items,
        onChanged: f,
      ),
    );

Widget kosong(IconData i, String t) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 72, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(t, style: TextStyle(color: Colors.grey.shade600)),
      ]),
    );

Widget hapusBg() => Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );

Widget judulBagian(BuildContext c, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(t, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: warna)),
    );

Future<void> form(BuildContext c, String title, Widget Function(StateSetter) body, bool Function() ok) =>
    showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 14),
              body(set),
              const SizedBox(height: 6),
              FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(14)),
                onPressed: () {
                  if (ok()) Navigator.pop(ctx);
                },
                child: const Text('Simpan'),
              ),
            ]),
          ),
        ),
      ),
    );

// ================== LOGO ==================
class Logo extends StatelessWidget {
  final double size;
  const Logo(this.size, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF818CF8), warna], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(size * .28),
        ),
        child: Icon(Icons.school_rounded, color: Colors.white, size: size * .58),
      );
}

// ================== APP ==================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Db.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Asisten Kuliah',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: warna, useMaterial3: true, scaffoldBackgroundColor: const Color(0xFFF5F5FB)),
        home: const Splash(),
      );
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home()));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: gelap,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Logo(120),
            SizedBox(height: 24),
            Text('Asisten Kuliah', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Tugas • Jadwal • Absensi • IPK', style: TextStyle(color: Colors.white70)),
          ]),
        ),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  final cariC = TextEditingController();
  String filterMk = 'semua'; // semua, lulus, belum, perbaikan
  String statusTab = 'berjalan'; // berjalan atau selesai
  final simSks = TextEditingController(), simIps = TextEditingController();

  void refresh() {
    Db.save();
    setState(() {});
  }

  void snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void hapusMk(Map<String, dynamic> m) {
    mk.remove(m);
    Db.d['tugas']!.removeWhere((e) => e['mk'] == m['id']);
    Db.d['jadwal']!.removeWhere((e) => e['mk'] == m['id']);
    Db.d['absen']!.removeWhere((e) => e['id'] == m['id']);
    refresh();
  }

  bool cocokStatus(String idMk) {
    final m = mk.where((x) => x['id'] == idMk).firstOrNull;
    final berjalan = m == null || (m['status'] ?? 'aktif') == 'aktif';
    return berjalan == (statusTab == 'berjalan');
  }

  Widget statusBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(children: [
          for (final f in [['berjalan', 'Sedang berjalan'], ['selesai', 'Selesai']])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f[1]),
                selected: statusTab == f[0],
                onSelected: (_) => setState(() => statusTab = f[0]),
              ),
            ),
        ]),
      );

  Widget cariBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: TextField(
          controller: cariC,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: ['Cari tugas atau mata kuliah', 'Cari jadwal, dosen, atau ruangan', 'Cari mata kuliah'][tab],
            prefixIcon: const Icon(Icons.search),
            suffixIcon: cariC.text.isEmpty
                ? null
                : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => cariC.clear())),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
          ),
        ),
      );

  Future<bool> konfirmasi(String judul, String isi) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(judul),
          content: Text(isi),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
          ],
        ),
      ) ??
      false;

  Future<void> hapusMkKonfirmasi(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus "${m['nama']}"?'),
        content: const Text('Tugas, jadwal, dan absensi mata kuliah ini ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) hapusMk(m);
  }

  // ---------- TUGAS ----------
  void formTugas([Map<String, dynamic>? t]) async {
    if (t == null && mkAktif.isEmpty) return snack('Belum ada mata kuliah yang sedang berjalan. Tambah di tab IPK.');
    final j = TextEditingController(text: t?['judul'] ?? '');
    String m = t?['mk'] ?? mkAktif.first['id'];
    DateTime d = t != null ? DateTime.parse(t['dl']) : DateTime.now().add(const Duration(days: 1));
    await form(context, t == null ? 'Tambah Tugas' : 'Edit Tugas', (set) => Column(children: [
          tf(j, 'Judul tugas'),
          dd('Mata kuliah', m, mkItems(t?['mk']), (v) => set(() => m = v!)),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text('Deadline: ${tgl(d)}'),
            onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (p != null) set(() => d = p);
            },
          ),
          const SizedBox(height: 10),
        ]), () {
      if (j.text.trim().isEmpty) return false;
      final n = {'id': t?['id'] ?? uid(), 'judul': j.text.trim(), 'mk': m, 'dl': d.toIso8601String(), 'done': t?['done'] ?? false};
      t == null ? Db.d['tugas']!.add(n) : t.addAll(n);
      return true;
    });
    refresh();
  }

  Widget tugasPage() {
    final semua = [...Db.d['tugas']!]..sort((a, b) {
        if (a['done'] != b['done']) return (a['done'] as bool) ? 1 : -1;
        return (a['dl'] as String).compareTo(b['dl']);
      });
    final q = cariC.text.trim().toLowerCase();
    final l = semua.where((t) => cocokStatus(t['mk']) && (q.isEmpty || t['judul'].toLowerCase().contains(q) || namaMk(t['mk']).toLowerCase().contains(q))).toList();
    if (semua.isEmpty) return kosong(Icons.assignment_outlined, 'Belum ada tugas.\nKetuk + untuk menambah.');
    if (l.isEmpty) return kosong(Icons.search_off, 'Tidak ada data yang sesuai');
    final now = DateTime.now(), today = DateTime(now.year, now.month, now.day);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
      itemCount: l.length,
      itemBuilder: (_, i) {
        final t = l[i];
        final d = DateTime.parse(t['dl']);
        final done = t['done'] as bool;
        final sisa = d.difference(today).inDays;
        final telat = !done && sisa < 0, dekat = !done && sisa >= 0 && sisa <= 2;
        final info = telat ? 'Telat ${-sisa} hr' : sisa == 0 ? 'Hari ini' : '$sisa hr lagi';
        return Dismissible(
          key: ValueKey(t['id']),
          direction: DismissDirection.endToStart,
          background: hapusBg(),
          onDismissed: (_) {
            Db.d['tugas']!.remove(t);
            refresh();
          },
          child: Card(
            child: ListTile(
              leading: Checkbox(value: done, onChanged: (v) { t['done'] = v; refresh(); }),
              title: Text(t['judul'], style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
              subtitle: Text(
                '${namaMk(t['mk'])} • ${tgl(d)}${done ? '' : '\n$info'}',
                style: TextStyle(color: telat ? Colors.red : dekat ? Colors.orange.shade800 : null),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Hapus',
                onPressed: () async {
                  if (await konfirmasi('Hapus tugas?', '"${t['judul']}" akan dihapus.')) {
                    Db.d['tugas']!.remove(t);
                    refresh();
                  }
                },
              ),
              onTap: () => formTugas(t),
            ),
          ),
        );
      },
    );
  }

  // ---------- JADWAL ----------
  void formJadwal([Map<String, dynamic>? t]) async {
    if (t == null && mkAktif.isEmpty) return snack('Belum ada mata kuliah yang sedang berjalan. Tambah di tab IPK.');
    String m = t?['mk'] ?? mkAktif.first['id'], h = t?['hari'] ?? hari.first, a = t?['mulai'] ?? '08:00', b = t?['selesai'] ?? '09:40';
    final r = TextEditingController(text: t?['ruang'] ?? ''), ds = TextEditingController(text: t?['dosen'] ?? '');
    Future<String?> jam(String cur) async {
      final p = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(cur.substring(0, 2)), minute: int.parse(cur.substring(3))));
      return p == null ? null : '${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}';
    }

    await form(context, t == null ? 'Tambah Jadwal' : 'Edit Jadwal', (set) => Column(children: [
          dd('Mata kuliah', m, mkItems(t?['mk']), (v) => set(() => m = v!)),
          dd('Hari', h, hari.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), (v) => set(() => h = v!)),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () async { final x = await jam(a); if (x != null) set(() => a = x); }, child: Text('Mulai $a'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () async { final x = await jam(b); if (x != null) set(() => b = x); }, child: Text('Selesai $b'))),
          ]),
          const SizedBox(height: 10),
          tf(r, 'Ruangan'),
          tf(ds, 'Dosen'),
        ]), () {
      final n = {'id': t?['id'] ?? uid(), 'mk': m, 'hari': h, 'mulai': a, 'selesai': b, 'ruang': r.text.trim(), 'dosen': ds.text.trim()};
      t == null ? Db.d['jadwal']!.add(n) : t.addAll(n);
      return true;
    });
    refresh();
  }

  Widget jadwalPage() {
    final semua = Db.d['jadwal']!;
    final q = cariC.text.trim().toLowerCase();
    final l = semua
        .where((e) => cocokStatus(e['mk']) && (q.isEmpty || [namaMk(e['mk']), e['dosen'], e['ruang'], e['hari']].any((x) => x.toString().toLowerCase().contains(q))))
        .toList();
    if (semua.isEmpty) return kosong(Icons.calendar_month_outlined, 'Belum ada jadwal.\nKetuk + untuk menambah.');
    if (l.isEmpty) return kosong(Icons.search_off, 'Tidak ada data yang sesuai');
    return ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
      for (final h in hari)
        ...(() {
          final x = l.where((e) => e['hari'] == h).toList()..sort((a, b) => (a['mulai'] as String).compareTo(b['mulai']));
          if (x.isEmpty) return <Widget>[];
          return <Widget>[
            judulBagian(context, h),
            ...x.map((e) => Dismissible(
                  key: ValueKey(e['id']),
                  direction: DismissDirection.endToStart,
                  background: hapusBg(),
                  onDismissed: (_) { semua.remove(e); refresh(); },
                  child: Card(
                    child: ListTile(
                      leading: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(e['mulai'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(e['selesai'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      title: Text(namaMk(e['mk']), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Ruang ${e['ruang'].isEmpty ? '-' : e['ruang']} • ${e['dosen'].isEmpty ? '-' : e['dosen']}'),
                      onTap: () => formJadwal(e),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Hapus', onPressed: () async {
                        if (await konfirmasi('Hapus jadwal?', '${namaMk(e['mk'])} hari ${e['hari']} akan dihapus.')) {
                          semua.remove(e);
                          refresh();
                        }
                      }),
                    ),
                  ),
                )),
          ];
        })(),
    ]);
  }

  // ---------- ABSENSI ----------
  Widget absenPage() {
    if (mk.isEmpty) return kosong(Icons.fact_check_outlined, 'Tambah mata kuliah dulu di tab IPK');
    final q = cariC.text.trim().toLowerCase();
    final daftar = mk.where((m) => cocokStatus(m['id']) && (q.isEmpty || m['nama'].toLowerCase().contains(q))).toList();
    if (daftar.isEmpty) return kosong(Icons.search_off, 'Tidak ada data yang sesuai');
    const kat = [['h', 'Hadir'], ['i', 'Izin'], ['s', 'Sakit'], ['a', 'Alpa']];
    Color warnaKat(String k) => k == 'h' ? Colors.green : k == 'a' ? Colors.red : Colors.orange;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24), children: [
      const Padding(
        padding: EdgeInsets.all(4),
        child: Text('Salah input? Tekan tombol minus (-) untuk mengurangi.', style: TextStyle(color: Colors.grey)),
      ),
      ...daftar.map((m) {
        final a = absen(m['id']);
        int n(String k) => (a[k] ?? 0) as int;
        final tot = n('h') + n('i') + n('s') + n('a');
        final p = tot == 0 ? 100.0 : n('h') / tot * 100;
        final c = p < batasHadir ? Colors.red : p < 85 ? Colors.orange : Colors.green;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(m['nama'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                Text('${p.toStringAsFixed(0)}%', style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus catatan absensi',
                  onPressed: () async {
                    if (await konfirmasi('Hapus catatan absensi?', 'Semua hitungan absensi ${m['nama']} kembali ke 0.')) {
                      Db.d['absen']!.removeWhere((x) => x['id'] == m['id']);
                      refresh();
                    }
                  },
                ),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: p / 100, color: c, minHeight: 8, borderRadius: BorderRadius.circular(8)),
              const SizedBox(height: 6),
              Text('Total pertemuan tercatat: $tot'),
              if (p < batasHadir) Text('Di bawah batas minimal ${batasHadir.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 6),
              for (final k in kat)
                Row(children: [
                  Icon(Icons.circle, size: 12, color: warnaKat(k[0])),
                  const SizedBox(width: 8),
                  Expanded(child: Text(k[1], style: const TextStyle(fontSize: 15))),
                  IconButton.outlined(
                    tooltip: 'Kurangi ${k[1]}',
                    icon: const Icon(Icons.remove),
                    onPressed: n(k[0]) > 0 ? () { a[k[0]] = n(k[0]) - 1; refresh(); } : null,
                  ),
                  SizedBox(width: 44, child: Text('${n(k[0])}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton.filled(
                    tooltip: 'Tambah ${k[1]}',
                    icon: const Icon(Icons.add),
                    onPressed: () { a[k[0]] = n(k[0]) + 1; refresh(); },
                  ),
                ]),
            ]),
          ),
        );
      }),
    ]);
  }

  // ---------- IPK ----------
  void formMk([Map<String, dynamic>? t]) async {
    final n = TextEditingController(text: t?['nama'] ?? '');
    final s = TextEditingController(text: t?['sks']?.toString() ?? '');
    final sm = TextEditingController(text: t?['sem']?.toString() ?? '');
    String nilai = t?['nilai'] ?? '-';
    String status = t?['status'] ?? 'aktif';
    await form(context, t == null ? 'Tambah Mata Kuliah' : 'Edit Mata Kuliah', (set) => Column(children: [
          tf(n, 'Nama mata kuliah'),
          Row(children: [
            Expanded(child: tf(s, 'SKS', num: true)),
            const SizedBox(width: 8),
            Expanded(child: tf(sm, 'Semester', num: true)),
          ]),
          dd('Nilai (pilih "-" jika belum ada)', nilai, ['-', ...bobot.keys].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), (v) => set(() {
                nilai = v!;
                if (nilai != '-') status = 'selesai';
              })),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mata kuliah sudah selesai'),
            subtitle: const Text('Tugas, jadwal, dan absensinya pindah ke tab Selesai'),
            value: status == 'selesai',
            onChanged: (v) => set(() => status = v ? 'selesai' : 'aktif'),
          ),
        ]), () {
      final sk = int.tryParse(s.text), se = int.tryParse(sm.text);
      if (n.text.trim().isEmpty || sk == null || se == null) return false;
      final x = {'id': t?['id'] ?? uid(), 'nama': n.text.trim(), 'sks': sk, 'sem': se, 'nilai': nilai, 'status': status};
      t == null ? mk.add(x) : t.addAll(x);
      return true;
    });
    refresh();
  }

  void formPrev() async {
    final i = TextEditingController(text: (prev['ipk'] as num) == 0 ? '' : prev['ipk'].toString());
    final s = TextEditingController(text: (prev['sks'] as num) == 0 ? '' : prev['sks'].toString());
    await form(context, 'IPK Semester Lalu', (set) => Column(children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Isi jika IPK kamu mencakup semester yang tidak dicatat di aplikasi ini.', style: TextStyle(color: Colors.grey)),
          ),
          tf(i, 'IPK semester lalu (contoh 3,45)', num: true),
          tf(s, 'Total SKS semester lalu', num: true),
        ]), () {
      final ik = double.tryParse(i.text.replaceAll(',', '.')) ?? 0;
      final sk = int.tryParse(s.text) ?? 0;
      if (ik < 0 || ik > 4 || (ik > 0) != (sk > 0)) {
        snack('IPK harus 0-4, dan SKS wajib diisi bersama IPK');
        return false;
      }
      prev['ipk'] = ik;
      prev['sks'] = sk;
      return true;
    });
    refresh();
  }

  Widget ipkPage() {
    final sks = sksTotal(), total = ipkTotal();
    bool cocok(Map<String, dynamic> m, String f) =>
        f == 'semua' ||
        (f == 'lulus' && lulus(m['nilai'])) ||
        (f == 'belum' && !lulus(m['nilai'])) ||
        (f == 'perbaikan' && m['nilai'] == 'C');
    final tampil = mk.where((m) => cocok(m, filterMk)).toList();
    final sem = mk.map((m) => m['sem'] as int).toSet().toList()..sort();
    final s = int.tryParse(simSks.text), g = double.tryParse(simIps.text.replaceAll(',', '.'));
    final hasil = (s != null && g != null && s > 0) ? (total * sks + g * s) / (sks + s) : null;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
      Card(
        color: warna,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Text('IPK', style: TextStyle(color: Colors.white70, fontSize: 16)),
            Text(total.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold)),
            Text('$sks SKS (termasuk semester lalu)', style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.history_edu),
          title: const Text('IPK semester lalu'),
          subtitle: Text((prev['sks'] as num) == 0
              ? 'Belum diisi. Ketuk untuk mengisi.'
              : 'IPK ${(prev['ipk'] as num).toStringAsFixed(2)} • ${prev['sks']} SKS'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: formPrev,
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Simulasi IPK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('Kalau semester depan dapat IPS tertentu, IPK jadi berapa?', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: tf(simSks, 'SKS semester depan', num: true, ch: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: tf(simIps, 'Target IPS', num: true, ch: (_) => setState(() {}))),
            ]),
            Text(hasil == null ? 'Isi kedua kolom untuk melihat hasil' : 'Perkiraan IPK: ${hasil.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: hasil == null ? Colors.grey : warna, fontSize: 16)),
          ]),
        ),
      ),
      if (sem.isNotEmpty) judulBagian(context, 'IPS per Semester'),
      ...sem.map((x) => Card(
            child: ListTile(
              title: Text('Semester $x'),
              subtitle: Text('${mk.where((m) => m['sem'] == x).length} mata kuliah'),
              trailing: Text('IPS ${ipk(mk.where((m) => m['sem'] == x)).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )),
      judulBagian(context, 'Daftar Mata Kuliah'),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('Standar lulus: nilai C ke atas.', style: TextStyle(color: Colors.grey))),
      if (mk.any((m) => !lulus(m['nilai'])))
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Text('${mk.where((m) => !lulus(m['nilai'])).length} mata kuliah berwarna merah (nilai D, E, atau belum ada).',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
        ),
      if (mk.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in [['semua', 'Semua'], ['lulus', 'Lulus'], ['belum', 'Belum lulus'], ['perbaikan', 'Perbaikan (C)']])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${f[1]} (${mk.where((m) => cocok(m, f[0])).length})'),
                  selected: filterMk == f[0],
                  onSelected: (_) => setState(() => filterMk = f[0]),
                ),
              ),
          ]),
        ),
      if (mk.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Belum ada mata kuliah. Ketuk + untuk menambah.', style: TextStyle(color: Colors.grey)))),
      if (mk.isNotEmpty && tampil.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Tidak ada mata kuliah pada filter ini.', style: TextStyle(color: Colors.grey)))),
      ...tampil.map((m) => Dismissible(
            key: ValueKey(m['id']),
            direction: DismissDirection.endToStart,
            background: hapusBg(),
            confirmDismiss: (_) async =>
                await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus mata kuliah?'),
                    content: const Text('Tugas, jadwal, dan absensi mata kuliah ini ikut terhapus.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                    ],
                  ),
                ) ??
                false,
            onDismissed: (_) => hapusMk(m),
            child: Card(
              child: ListTile(
                tileColor: lulus(m['nilai']) ? null : Colors.red.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(
                  backgroundColor: lulus(m['nilai']) ? null : Colors.red,
                  foregroundColor: lulus(m['nilai']) ? null : Colors.white,
                  child: Text(m['nilai']),
                ),
                title: Text(m['nama'], style: TextStyle(color: lulus(m['nilai']) ? null : Colors.red, fontWeight: lulus(m['nilai']) ? null : FontWeight.bold)),
                subtitle: Text(
                  'Semester ${m['sem']} • ${m['sks']} SKS • ${(m['status'] ?? 'aktif') == 'selesai' ? 'Selesai' : 'Berjalan'}${lulus(m['nilai']) ? '' : (m['nilai'] == '-' ? ' • Belum ada nilai' : ' • Belum lulus')}',
                  style: TextStyle(color: lulus(m['nilai']) ? null : Colors.red),
                ),
                onTap: () => formMk(m),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Hapus', onPressed: () => hapusMkKonfirmasi(m)),
              ),
            ),
          )),
    ]);
  }

  // ---------- TAMPILAN UTAMA ----------
  @override
  Widget build(BuildContext context) {
    const judul = ['Tugas', 'Jadwal Kuliah', 'Absensi', 'IPK & Nilai'];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(children: [const Logo(32), const SizedBox(width: 10), Text(judul[tab], style: const TextStyle(fontWeight: FontWeight.bold))]),
      ),
      body: tab == 3 ? ipkPage() : Column(children: [cariBar(), statusBar(), Expanded(child: [tugasPage, jadwalPage, absenPage][tab]())]),
      floatingActionButton: tab == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => [formTugas, formJadwal, null, formMk][tab]!(),
              icon: const Icon(Icons.add),
              label: Text(['Tugas', 'Jadwal', '', 'Mata Kuliah'][tab]),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() {
          tab = i;
          cariC.clear();
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist_rounded), label: 'Tugas'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Jadwal'),
          NavigationDestination(icon: Icon(Icons.fact_check), label: 'Absensi'),
          NavigationDestination(icon: Icon(Icons.calculate), label: 'IPK'),
        ],
      ),
    );
  }
}
