import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuTakipPaneli extends StatefulWidget {
  final Map<String, dynamic> hayvanVerisi;

  const SuTakipPaneli({Key? key, required this.hayvanVerisi}) : super(key: key);

  @override
  State<SuTakipPaneli> createState() => _SuTakipPaneliDurumu();
}

class _SuTakipPaneliDurumu extends State<SuTakipPaneli> {
  final _supabase = Supabase.instance.client;

  final Color koyuMavi = const Color(0xFF0D47A1);
  final Color ortaMavi = const Color(0xFF1E88E5);
  final Color beyazRenk = Colors.white;

  final List<String> _olcuBirimleri = ['Kap (Kase)', 'Mililitre (ml)', 'Litre (L)'];

  List<Map<String, dynamic>> _suGecmisi = [];
  bool _yukleniyor = true;
  String _gecerliKullaniciId = '';

  @override
  void initState() {
    super.initState();
    _gecerliKullaniciId = _supabase.auth.currentUser?.id ?? '';
    _verileriGetir();
  }

  // Supabase'den su geçmişini çeken fonksiyon
  Future<void> _verileriGetir() async {
    try {
      setState(() => _yukleniyor = true);
      final hayvanId = widget.hayvanVerisi['id'];

      final gecmis = await _supabase
          .from('aktivite_gunlugu')
          .select('''
            id,
            miktar_numerik,
            olcu_birimi,
            gerceklesme_zamani,
            kullanicilar (ad_soyad)
          ''')
          .eq('hayvan_id', hayvanId)
          .eq('aktivite_tipi', 'Su')
          .order('gerceklesme_zamani', ascending: false);

      if (mounted) {
        setState(() {
          _suGecmisi = List<Map<String, dynamic>>.from(gecmis);
        });
      }
    } catch (e) {
      debugPrint('Su verileri getirme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıtlar yüklenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // Su ekleme/düzenleme formunu açan fonksiyon
  void _suFormunuAc({Map<String, dynamic>? mevcutKayit}) {
    String seciliBirim = mevcutKayit?['olcu_birimi'] ?? _olcuBirimleri.first;
    final miktarKontrolcusu = TextEditingController(text: mevcutKayit?['miktar_numerik']?.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (BuildContext baglam) {
        return StatefulBuilder(
          builder: (BuildContext formBaglami, StateSetter formSetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(baglam).viewInsets.bottom,
                left: 20, right: 20, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    mevcutKayit == null ? 'Suyu Tazele' : 'Kaydı Düzenle',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: koyuMavi),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: miktarKontrolcusu,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Miktar',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: Icon(Icons.water_drop, color: ortaMavi),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: seciliBirim,
                          decoration: InputDecoration(
                            labelText: 'Birim',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _olcuBirimleri.map((birim) => DropdownMenuItem(value: birim, child: Text(birim))).toList(),
                          onChanged: (y) => formSetState(() => seciliBirim = y!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      if (miktarKontrolcusu.text.trim().isEmpty) return;

                      double miktar = double.tryParse(miktarKontrolcusu.text.trim()) ?? 0;

                      setState(() => _yukleniyor = true);
                      Navigator.pop(context);

                      try {
                        final kayitVerisi = {
                          'aile_id': widget.hayvanVerisi['aile_id'],
                          'hayvan_id': widget.hayvanVerisi['id'],
                          'kullanici_id': _gecerliKullaniciId,
                          'aktivite_tipi': 'Su',
                          'miktar_numerik': miktar,
                          'olcu_birimi': seciliBirim,
                        };

                        if (mevcutKayit == null) {
                          await _supabase.from('aktivite_gunlugu').insert(kayitVerisi);
                        } else {
                          await _supabase.from('aktivite_gunlugu').update(kayitVerisi).eq('id', mevcutKayit['id']);
                        }

                        await _verileriGetir();
                      } catch (e) {
                        debugPrint('Kayıt hatası: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: koyuMavi,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Supabase'den su kaydı silme
  Future<void> _kayitSil(String id) async {
    try {
      setState(() => _yukleniyor = true);
      await _supabase.from('aktivite_gunlugu').delete().eq('id', id);
      await _verileriGetir();
    } catch (e) {
      debugPrint('Silme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayvanAdi = widget.hayvanVerisi['ad'] ?? 'İsimsiz';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('$hayvanAdi - Su Takibi', style: TextStyle(color: beyazRenk, fontWeight: FontWeight.bold)),
        backgroundColor: koyuMavi,
        iconTheme: IconThemeData(color: beyazRenk),
        centerTitle: true,
      ),
      body: _yukleniyor
          ? Center(child: CircularProgressIndicator(color: ortaMavi))
          : _suGecmisi.isEmpty
          ? _bosListeTasarimi()
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _suGecmisi.length,
        itemBuilder: (context, indeks) {
          final kayit = _suGecmisi[indeks];
          final kisi = kayit['kullanicilar']?['ad_soyad'] ?? 'Bir Üye';
          final miktar = kayit['miktar_numerik']?.toString() ?? '';
          final birim = kayit['olcu_birimi'] ?? '';

          DateTime tarih = DateTime.parse(kayit['gerceklesme_zamani']).toLocal();
          String saatMetni = "${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}";

          final bildirimMetni = "$hayvanAdi dostumuza $kisi tarafından $miktar $birim su verildi.";

          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  radius: 25,
                  child: Icon(Icons.water_drop, color: Colors.blue[700], size: 28),
                ),
                title: Text(
                  bildirimMetni,
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800], fontSize: 15, height: 1.3),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(saatMetni, style: TextStyle(color: koyuMavi, fontWeight: FontWeight.bold)),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (deger) {
                    if (deger == 'duzenle') _suFormunuAc(mevcutKayit: kayit);
                    if (deger == 'sil') _kayitSil(kayit['id']);
                  },
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'duzenle', child: Row(children: [Icon(Icons.edit, color: ortaMavi, size: 20), const SizedBox(width: 8), const Text('Düzenle')])),
                    const PopupMenuItem(value: 'sil', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), const SizedBox(width: 8), const Text('Sil')])),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _suFormunuAc(),
        backgroundColor: ortaMavi,
        icon: const Icon(Icons.opacity, color: Colors.white),
        label: const Text('Suyu Tazeledim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _bosListeTasarimi() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.water_drop_outlined, size: 80, color: Colors.blue[200]),
          const SizedBox(height: 16),
          Text('Bugün henüz su tazelenmedi.', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          const Text('Kayıt eklemek için butona dokunun.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}