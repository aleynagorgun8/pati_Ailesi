import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // ⭐ BURASI EKLENDİ
import 'package:google_fonts/google_fonts.dart';

class BeslenmeTakipPaneli extends StatefulWidget {
  final Map<String, dynamic> hayvanVerisi;

  const BeslenmeTakipPaneli({Key? key, required this.hayvanVerisi})
      : super(key: key);

  @override
  State<BeslenmeTakipPaneli> createState() => _BeslenmeTakipPaneliDurumu();
}

class _BeslenmeTakipPaneliDurumu extends State<BeslenmeTakipPaneli>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  // Modern renk paleti 💙💛
  final Color anaMavi = const Color(0xFF1A237E);
  final Color anaMaviLight = const Color(0xFF283593);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color vurguRengiLight = const Color(0xFFFFD54F);
  final Color arkaPlan = const Color(0xFFF8F9FA);
  final Color kartBeyazi = Colors.white;
  final Color textGri = const Color(0xFF546E7A);

  // Varsayılan seçeneklerimiz
  final List<String> _varsayilanMamalar = ['Kuru Mama', 'Yaş Mama', 'Ödül Maması'];
  final List<String> _olcuBirimleri = [
    'Gram (gr)',
    'Su Bardağı',
    'Yemek Kaşığı',
    'Adet',
    'Mililitre (ml)'
  ];

  List<Map<String, dynamic>> _veritabanindakiMamalar = [];
  List<Map<String, dynamic>> _beslenmeGecmisi = [];
  bool _yukleniyor = true;
  String _gecerliKullaniciId = '';

  late AnimationController _animasyonKontrol;
  late Animation<double> _fadeAnimasyon;

  @override
  void initState() {
    super.initState();
    _gecerliKullaniciId = _supabase.auth.currentUser?.id ?? '';

    // ⭐ TÜRKÇE LOCALE VERİLERİNİ BAŞLAT
    initializeDateFormatting('tr_TR', null);

    _animasyonKontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimasyon = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrol, curve: Curves.easeOut),
    );

    _verileriGetir();
  }

  @override
  void dispose() {
    _animasyonKontrol.dispose();
    super.dispose();
  }

  Future<void> _verileriGetir() async {
    try {
      setState(() => _yukleniyor = true);
      final hayvanId = widget.hayvanVerisi['id'];

      final besinler = await _supabase
          .from('besin_cesitleri')
          .select()
          .eq('aile_id', widget.hayvanVerisi['aile_id']);

      final gecmis = await _supabase
          .from('aktivite_gunlugu')
          .select('''
            id,
            miktar_numerik,
            olcu_birimi,
            islem_detayi,
            gerceklesme_zamani,
            besin_cesitleri (id, besin_adi),
            kullanicilar (ad_soyad)
          ''')
          .eq('hayvan_id', hayvanId)
          .eq('aktivite_tipi', 'Beslenme')
          .order('gerceklesme_zamani', ascending: false);

      if (mounted) {
        setState(() {
          _veritabanindakiMamalar = List<Map<String, dynamic>>.from(besinler);
          _beslenmeGecmisi = List<Map<String, dynamic>>.from(gecmis);
          _animasyonKontrol.forward(from: 0.0);
        });
      }
    } catch (e) {
      debugPrint('Veri getirme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Kayıtlar yüklenemedi: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  List<String> _gosterilecekMamaListesiniHazirla() {
    List<String> tumMamalar = [..._varsayilanMamalar];
    for (var b in _veritabanindakiMamalar) {
      String besinAdi = b['besin_adi'];
      if (!tumMamalar.contains(besinAdi)) {
        tumMamalar.add(besinAdi);
      }
    }
    tumMamalar.add('Farklı Ekle...');
    return tumMamalar;
  }

  void _mamaFormunuAc({Map<String, dynamic>? mevcutKayit}) {
    List<String> mamaSecenekleri = _gosterilecekMamaListesiniHazirla();

    String seciliBesinAdi = mevcutKayit?['besin_cesitleri']?['besin_adi'] ??
        _varsayilanMamalar.first;
    if (!mamaSecenekleri.contains(seciliBesinAdi)) {
      seciliBesinAdi = 'Farklı Ekle...';
    }

    String seciliBirim = mevcutKayit?['olcu_birimi'] ?? _olcuBirimleri.first;
    bool farkliMamaMi = seciliBesinAdi == 'Farklı Ekle...';

    final miktarKontrolcusu = TextEditingController(
        text: mevcutKayit?['miktar_numerik']?.toString());
    final ozelMamaKontrolcusu = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext baglam) {
        return StatefulBuilder(
          builder: (BuildContext formBaglami, StateSetter formSetState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(baglam).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 12,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Başlık çubuğu
                    Container(
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mevcutKayit == null
                              ? '🍽️ Yeni Besleme'
                              : '✏️ Kaydı Düzenle',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: anaMavi,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade600),
                          onPressed: () => Navigator.pop(baglam),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Mama Seçimi
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: seciliBesinAdi,
                        decoration: InputDecoration(
                          labelText: 'Mama / Yiyecek Tipi',
                          labelStyle: TextStyle(color: textGri),
                          prefixIcon: Icon(Icons.restaurant_menu,
                              color: anaMaviLight),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        items: mamaSecenekleri.map((isim) {
                          return DropdownMenuItem<String>(
                            value: isim,
                            child: Text(
                              isim,
                              style: GoogleFonts.poppins(
                                fontWeight: isim == 'Farklı Ekle...'
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isim == 'Farklı Ekle...'
                                    ? vurguRengi
                                    : textGri,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (yeniDeger) {
                          formSetState(() {
                            seciliBesinAdi = yeniDeger!;
                            farkliMamaMi = yeniDeger == 'Farklı Ekle...';
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Farklı Ekle...
                    if (farkliMamaMi) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: ozelMamaKontrolcusu,
                          decoration: InputDecoration(
                            labelText: 'Yiyeceğin Adını Girin',
                            labelStyle: TextStyle(color: textGri),
                            prefixIcon: Icon(Icons.edit, color: anaMaviLight),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          style: GoogleFonts.poppins(fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Miktar ve Birim
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: TextField(
                              controller: miktarKontrolcusu,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Miktar',
                                labelStyle: TextStyle(color: textGri),
                                prefixIcon:
                                Icon(Icons.scale, color: anaMaviLight),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                              style: GoogleFonts.poppins(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: seciliBirim,
                              decoration: InputDecoration(
                                labelText: 'Birim',
                                labelStyle: TextStyle(color: textGri),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                              items: _olcuBirimleri.map((birim) {
                                return DropdownMenuItem(
                                  value: birim,
                                  child: Text(
                                    birim,
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (y) =>
                                  formSetState(() => seciliBirim = y!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Kaydet Butonu
                    ElevatedButton(
                      onPressed: () async {
                        if (miktarKontrolcusu.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('⚠️ Lütfen miktar girin'),
                              backgroundColor: Colors.orange.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }

                        String islemYapilacakBesinAdi = farkliMamaMi
                            ? ozelMamaKontrolcusu.text.trim()
                            : seciliBesinAdi;
                        if (islemYapilacakBesinAdi.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  '⚠️ Lütfen yiyecek adı girin'),
                              backgroundColor: Colors.orange.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }

                        double miktar = double.tryParse(
                            miktarKontrolcusu.text.trim()) ??
                            0;

                        setState(() => _yukleniyor = true);
                        Navigator.pop(context);

                        try {
                          String gercekBesinId = '';

                          var mevcutDBBesin = _veritabanindakiMamalar
                              .where((b) =>
                          b['besin_adi'] == islemYapilacakBesinAdi)
                              .toList();

                          if (mevcutDBBesin.isNotEmpty) {
                            gercekBesinId = mevcutDBBesin.first['id'];
                          } else {
                            final yeniBesin = await _supabase
                                .from('besin_cesitleri')
                                .insert({
                              'aile_id': widget.hayvanVerisi['aile_id'],
                              'besin_adi': islemYapilacakBesinAdi,
                            }).select().single();

                            gercekBesinId = yeniBesin['id'];
                          }

                          final kayitVerisi = {
                            'aile_id': widget.hayvanVerisi['aile_id'],
                            'hayvan_id': widget.hayvanVerisi['id'],
                            'kullanici_id': _gecerliKullaniciId,
                            'aktivite_tipi': 'Beslenme',
                            'besin_id': gercekBesinId,
                            'miktar_numerik': miktar,
                            'olcu_birimi': seciliBirim,
                          };

                          if (mevcutKayit == null) {
                            await _supabase
                                .from('aktivite_gunlugu')
                                .insert(kayitVerisi);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('✅ Besleme kaydedildi!'),
                                backgroundColor: Colors.green.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          } else {
                            await _supabase
                                .from('aktivite_gunlugu')
                                .update(kayitVerisi)
                                .eq('id', mevcutKayit['id']);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('✅ Kayıt güncellendi!'),
                                backgroundColor: Colors.green.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }

                          await _verileriGetir();
                        } catch (e) {
                          debugPrint('Kayıt hatası: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('⚠️ Kayıt hatası: $e'),
                              backgroundColor: Colors.red.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _yukleniyor = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: anaMavi,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            mevcutKayit == null ? 'Kaydet' : 'Güncelle',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _kayitSil(String id) async {
    try {
      setState(() => _yukleniyor = true);
      await _supabase.from('aktivite_gunlugu').delete().eq('id', id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🗑️ Kayıt silindi'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await _verileriGetir();
    } catch (e) {
      debugPrint('Silme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Silme hatası: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // ⭐ TARİH FORMATLAMA İÇİN YARDIMCI FONKSİYON
  String _tarihFormatla(DateTime tarih) {
    try {
      return DateFormat('d MMM', 'tr_TR').format(tarih);
    } catch (e) {
      // Hata durumunda basit format dene
      return DateFormat('d MMM').format(tarih);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayvanAdi = widget.hayvanVerisi['ad'] ?? 'İsimsiz';

    return Scaffold(
      backgroundColor: arkaPlan,
      appBar: AppBar(
        title: Text(
          '$hayvanAdi · Beslenme',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: anaMavi,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        centerTitle: true,
      ),
      body: _yukleniyor
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF1A237E),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Beslenme kayıtları yükleniyor... 🐾',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : _beslenmeGecmisi.isEmpty
          ? _bosListeTasarimi()
          : FadeTransition(
        opacity: _fadeAnimasyon,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          physics: const BouncingScrollPhysics(),
          itemCount: _beslenmeGecmisi.length,
          itemBuilder: (context, indeks) {
            final kayit = _beslenmeGecmisi[indeks];
            final kisi = kayit['kullanicilar']?['ad_soyad'] ??
                'Bir Üye';
            final besinAdi = kayit['besin_cesitleri']?['besin_adi'] ??
                'Bilinmeyen Mama';
            final miktar = kayit['miktar_numerik']?.toString() ?? '';
            final birim = kayit['olcu_birimi'] ?? '';

            DateTime tarih = DateTime.parse(
                kayit['gerceklesme_zamani']).toLocal();
            String saatMetni =
                "${tarih.hour.toString().padLeft(2, '0')}:${tarih.minute.toString().padLeft(2, '0')}";
            // ⭐ YARDIMCI FONKSİYON KULLANILDI
            String gunMetni = _tarihFormatla(tarih);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: kartBeyazi,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        // İkon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            color: Color(0xFFFF6B35),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // İçerik
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$miktar $birim $besinAdi',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: anaMavi,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 12,
                                    color: textGri,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    kisi,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: textGri,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color:
                                      textGri.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: textGri,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$gunMetni $saatMetni',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: textGri,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Menü Butonu
                        PopupMenuButton<String>(
                          onSelected: (deger) {
                            if (deger == 'duzenle') {
                              _mamaFormunuAc(mevcutKayit: kayit);
                            }
                            if (deger == 'sil') {
                              _kayitSil(kayit['id']);
                            }
                          },
                          icon: Icon(
                            Icons.more_vert,
                            color: Colors.grey.shade400,
                          ),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'duzenle',
                              child: Row(
                                children: [
                                  Icon(Icons.edit,
                                      color: anaMavi, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Düzenle',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'sil',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red.shade400,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sil',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: anaMavi.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _mamaFormunuAc(),
          backgroundColor: anaMavi,
          icon: const Icon(Icons.restaurant, color: Colors.white),
          label: Text(
            'Mama Ver',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bosListeTasarimi() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz besleme yapılmadı 🍽️',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kayıt eklemek için "Mama Ver" butonuna dokun.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}