import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';

class SaglikTakipPaneli extends StatefulWidget {
  final Map<String, dynamic> hayvanVerisi;

  const SaglikTakipPaneli({Key? key, required this.hayvanVerisi})
      : super(key: key);

  @override
  State<SaglikTakipPaneli> createState() => _SaglikTakipPaneliDurumu();
}

class _SaglikTakipPaneliDurumu extends State<SaglikTakipPaneli>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  
  final Color anaMavi = const Color(0xFF1A237E);
  final Color anaMaviLight = const Color(0xFF283593);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color vurguRengiLight = const Color(0xFFFFD54F);
  final Color arkaPlan = const Color(0xFFF8F9FA);
  final Color kartBeyazi = Colors.white;
  final Color textGri = const Color(0xFF546E7A);

  List<Map<String, dynamic>> _aktifIlaclar = [];
  List<Map<String, dynamic>> _gecmisKayitlar = [];
  List<Map<String, dynamic>> _tumKayitlar = [];

  Map<String, int> _bugunVerilenDozlar = {};

  DateTime _seciliTakvimTarihi = DateTime.now();

  bool _yukleniyor = true;
  String _gecerliKullaniciId = '';

  late AnimationController _animasyonKontrol;
  late Animation<double> _fadeAnimasyon;

  @override
  void initState() {
    super.initState();
    _gecerliKullaniciId = _supabase.auth.currentUser?.id ?? '';
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

      final bugun = DateTime.now();
      final bugunBaslangic =
      DateTime(bugun.year, bugun.month, bugun.day).toUtc().toIso8601String();
      final bugunBitis = DateTime(bugun.year, bugun.month, bugun.day, 23, 59, 59)
          .toUtc()
          .toIso8601String();
      final bugunSifirlanmis = DateTime(bugun.year, bugun.month, bugun.day);

      
      final saglikVerileri = await _supabase
          .from('saglik_kayitlari')
          .select()
          .eq('hayvan_id', hayvanId)
          .order('kayit_tarihi', ascending: true);

      final bugunkuDozAktiviteleri = await _supabase
          .from('aktivite_gunlugu')
          .select('islem_detayi')
          .eq('hayvan_id', hayvanId)
          .eq('aktivite_tipi', 'İlaç Kullanımı')
          .gte('gerceklesme_zamani', bugunBaslangic)
          .lte('gerceklesme_zamani', bugunBitis);

      Map<String, int> dozSayaci = {};
      for (var aktivite in bugunkuDozAktiviteleri) {
        String ilacAdi = aktivite['islem_detayi'];
        dozSayaci[ilacAdi] = (dozSayaci[ilacAdi] ?? 0) + 1;
      }

      List<Map<String, dynamic>> aktifler = [];
      List<Map<String, dynamic>> gecmisler = [];

      for (var kayit in saglikVerileri) {
        DateTime kayitTarihi = DateTime.parse(kayit['kayit_tarihi']).toLocal();
        DateTime kayitTarihiSifirlanmis =
        DateTime(kayitTarihi.year, kayitTarihi.month, kayitTarihi.day);

        if (kayit['kayit_tipi'] == 'İlaç/Tedavi') {
          DateTime bitisTarihi = DateTime.parse(kayit['bitis_tarihi']).toLocal();
          if (bitisTarihi.isAfter(bugun.subtract(const Duration(days: 1)))) {
            aktifler.add(kayit);
          } else {
            gecmisler.add(kayit);
          }
        } else {
          if (!kayitTarihiSifirlanmis.isAfter(bugunSifirlanmis)) {
            gecmisler.add(kayit);
          }
        }
      }

      gecmisler.sort((a, b) => DateTime.parse(b['kayit_tarihi'])
          .compareTo(DateTime.parse(a['kayit_tarihi'])));

      if (mounted) {
        setState(() {
          _aktifIlaclar = aktifler;
          _gecmisKayitlar = gecmisler;
          _tumKayitlar = saglikVerileri;
          _bugunVerilenDozlar = dozSayaci;
          _animasyonKontrol.forward(from: 0.0);
        });
      }
    } catch (e) {
      debugPrint('Sağlık verileri getirme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Veriler yüklenemedi: $e'),
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

  Future<void> _ilacDozuVer(String ilacAdi, int mevcutDozSayisi, int gunlukFrekans) async {
    if (mevcutDozSayisi >= gunlukFrekans) return;

    setState(() => _yukleniyor = true);
    try {
      await _supabase.from('aktivite_gunlugu').insert({
        'aile_id': widget.hayvanVerisi['aile_id'],
        'hayvan_id': widget.hayvanVerisi['id'],
        'kullanici_id': _gecerliKullaniciId,
        'aktivite_tipi': 'İlaç Kullanımı',
        'islem_detayi': ilacAdi,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💊 $ilacAdi dozu verildi!'),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      await _verileriGetir();
    } catch (e) {
      debugPrint('İlaç dozu ekleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Doz eklenemedi: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _kayitSil(Map<String, dynamic> kayit) async {
    try {
      setState(() => _yukleniyor = true);

      String id = kayit['id'];
      String baslik = kayit['baslik'];

      await _supabase
          .from('aktivite_gunlugu')
          .delete()
          .eq('islem_detayi', baslik)
          .eq('aktivite_tipi', 'İlaç Kullanımı')
          .eq('hayvan_id', widget.hayvanVerisi['id']);
      await _supabase.from('saglik_kayitlari').delete().eq('id', id);

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Silme başarısız: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        setState(() => _yukleniyor = false);
      }
    }
  }

  List<Map<String, dynamic>> _gununOlaylari(DateTime gun) {
    DateTime gunSifirlanmis = DateTime(gun.year, gun.month, gun.day);
    List<Map<String, dynamic>> olaylar = [];

    for (var kayit in _tumKayitlar) {
      DateTime baslangic = DateTime.parse(kayit['kayit_tarihi']).toLocal();
      DateTime baslangicSifirlanmis =
      DateTime(baslangic.year, baslangic.month, baslangic.day);

      if (kayit['kayit_tipi'] == 'Aşı/Muayene') {
        if (baslangicSifirlanmis.isAtSameMomentAs(gunSifirlanmis)) {
          olaylar.add(kayit);
        }
      } else if (kayit['kayit_tipi'] == 'İlaç/Tedavi') {
        DateTime bitis = DateTime.parse(kayit['bitis_tarihi']).toLocal();
        DateTime bitisSifirlanmis =
        DateTime(bitis.year, bitis.month, bitis.day);
        int aralik = kayit['tekrar_araligi_gun'] ?? 1;

        if (!gunSifirlanmis.isBefore(baslangicSifirlanmis) &&
            !gunSifirlanmis.isAfter(bitisSifirlanmis)) {
          int gunFarki =
              gunSifirlanmis.difference(baslangicSifirlanmis).inDays;
          if (gunFarki % aralik == 0) {
            olaylar.add(kayit);
          }
        }
      }
    }
    return olaylar;
  }

  void _kayitFormunuAc({Map<String, dynamic>? mevcutKayit}) {
    String seciliTip = mevcutKayit?['kayit_tipi'] ?? 'İlaç/Tedavi';

    final baslikKontrolcusu = TextEditingController(text: mevcutKayit?['baslik']);

    String varsayilanAciklamaDoz = '';
    if (mevcutKayit != null) {
      varsayilanAciklamaDoz = (seciliTip == 'İlaç/Tedavi')
          ? (mevcutKayit['doz_miktari'] ?? '')
          : (mevcutKayit['detay_aciklamasi'] ?? '');
    }
    final aciklamaDozKontrolcusu =
    TextEditingController(text: varsayilanAciklamaDoz);

    int seciliFrekans = mevcutKayit?['gunluk_frekans'] ?? 1;
    int seciliAralik = mevcutKayit?['tekrar_araligi_gun'] ?? 1;

    DateTime baslangicTarihi = mevcutKayit != null
        ? DateTime.parse(mevcutKayit['kayit_tarihi']).toLocal()
        : (_seciliTakvimTarihi.isAfter(DateTime.now())
        ? _seciliTakvimTarihi
        : DateTime.now());

    DateTime bitisTarihi = (mevcutKayit != null && mevcutKayit['bitis_tarihi'] !=
        null)
        ? DateTime.parse(mevcutKayit['bitis_tarihi']).toLocal()
        : baslangicTarihi.add(const Duration(days: 7));

    final aralikSecenekleri = [
      {'deger': 1, 'metin': 'Her Gün'},
      {'deger': 2, 'metin': '2 Günde Bir'},
      {'deger': 3, 'metin': '3 Günde Bir'},
      {'deger': 7, 'metin': 'Haftada Bir'},
      {'deger': 14, 'metin': '15 Günde Bir'},
      {'deger': 30, 'metin': 'Ayda Bir'},
    ];

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
            bool ilacMi = seciliTip == 'İlaç/Tedavi';

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
                              ? '🏥 Yeni Sağlık Kaydı'
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

                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'İlaç/Tedavi',
                            label: Text('💊 İlaç/Tedavi'),
                            icon: Icon(Icons.medication),
                          ),
                          ButtonSegment(
                            value: 'Aşı/Muayene',
                            label: Text('💉 Aşı/Muayene'),
                            icon: Icon(Icons.vaccines),
                          ),
                        ],
                        selected: {seciliTip},
                        onSelectionChanged: (Set<String> yeniSecim) {
                          formSetState(() => seciliTip = yeniSecim.first);
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                                (states) {
                              if (states.contains(WidgetState.selected)) {
                                return anaMavi;
                              }
                              return Colors.transparent;
                            },
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                                (states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return anaMavi;
                            },
                          ),
                          side: WidgetStateProperty.resolveWith(
                                (states) {
                              if (states.contains(WidgetState.selected)) {
                                return BorderSide.none;
                              }
                              return BorderSide(color: anaMavi.withOpacity(0.3));
                            },
                          ),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: baslikKontrolcusu,
                        decoration: InputDecoration(
                          labelText: ilacMi ? '💊 İlacın Adı' : '📋 İşlem Başlığı',
                          hintText: ilacMi ? 'Örn: Antibiyotik' : 'Örn: Karma Aşı',
                          labelStyle: TextStyle(color: textGri),
                          prefixIcon: Icon(
                            ilacMi ? Icons.medication : Icons.vaccines,
                            color: anaMaviLight,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: GoogleFonts.poppins(fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: aciklamaDozKontrolcusu,
                        decoration: InputDecoration(
                          labelText: ilacMi
                              ? '📏 Doz Miktarı'
                              : '📝 Açıklama / Notlar',
                          hintText: ilacMi
                              ? 'Örn: Yarım tablet, 2 Damla'
                              : 'Örn: Veteriner kontrolü yapıldı',
                          labelStyle: TextStyle(color: textGri),
                          prefixIcon: Icon(
                            ilacMi ? Icons.scale : Icons.note,
                            color: anaMaviLight,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: GoogleFonts.poppins(fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (ilacMi) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: DropdownButtonFormField<int>(
                                value: seciliAralik,
                                decoration: InputDecoration(
                                  labelText: '📅 Kullanım Aralığı',
                                  labelStyle: TextStyle(color: textGri),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                items: aralikSecenekleri.map((secenek) {
                                  return DropdownMenuItem<int>(
                                    value: secenek['deger'] as int,
                                    child: Text(
                                      secenek['metin'] as String,
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (yeni) =>
                                    formSetState(() => seciliAralik = yeni!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: anaMavi,
                                ),
                                icon: Icon(Icons.keyboard_arrow_down,
                                    color: anaMaviLight),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: DropdownButtonFormField<int>(
                                value: seciliFrekans,
                                decoration: InputDecoration(
                                  labelText: '⏰ Günde Kaç Kez',
                                  labelStyle: TextStyle(color: textGri),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                items: [1, 2, 3, 4].map((f) {
                                  return DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                      '$f Kez',
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (yeni) =>
                                    formSetState(() => seciliFrekans = yeni!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: anaMavi,
                                ),
                                icon: Icon(Icons.keyboard_arrow_down,
                                    color: anaMaviLight),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Icon(Icons.calendar_month,
                                  color: anaMaviLight),
                              title: Text(
                                'Başlangıç Tarihi',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: textGri,
                                ),
                              ),
                              subtitle: Text(
                                "${baslangicTarihi.day}.${baslangicTarihi.month}.${baslangicTarihi.year}",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: anaMavi,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: anaMavi.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.edit_calendar,
                                    color: anaMavi, size: 18),
                              ),
                              onTap: () async {
                                DateTime? secilen = await showDatePicker(
                                  context: context,
                                  initialDate: baslangicTarihi,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: anaMavi,
                                          onPrimary: Colors.white,
                                          onSurface: anaMavi,
                                        ),
                                        textTheme: GoogleFonts.poppinsTextTheme(),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (secilen != null) {
                                  formSetState(() => baslangicTarihi = secilen);
                                }
                              },
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading:
                              Icon(Icons.event_busy, color: anaMaviLight),
                              title: Text(
                                'Bitiş Tarihi',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: textGri,
                                ),
                              ),
                              subtitle: Text(
                                "${bitisTarihi.day}.${bitisTarihi.month}.${bitisTarihi.year}",
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: anaMavi,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: anaMavi.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.edit_calendar,
                                    color: anaMavi, size: 18),
                              ),
                              onTap: () async {
                                DateTime? secilen = await showDatePicker(
                                  context: context,
                                  initialDate: bitisTarihi,
                                  firstDate: baslangicTarihi,
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: anaMavi,
                                          onPrimary: Colors.white,
                                          onSurface: anaMavi,
                                        ),
                                        textTheme: GoogleFonts.poppinsTextTheme(),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (secilen != null) {
                                  formSetState(() => bitisTarihi = secilen);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading:
                          Icon(Icons.calendar_month, color: anaMaviLight),
                          title: Text(
                            'İşlem Tarihi',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: textGri,
                            ),
                          ),
                          subtitle: Text(
                            "${baslangicTarihi.day}.${baslangicTarihi.month}.${baslangicTarihi.year}",
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: anaMavi,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: anaMavi.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.edit_calendar,
                                color: anaMavi, size: 18),
                          ),
                          onTap: () async {
                            DateTime? secilen = await showDatePicker(
                              context: context,
                              initialDate: baslangicTarihi,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: anaMavi,
                                      onPrimary: Colors.white,
                                      onSurface: anaMavi,
                                    ),
                                    textTheme: GoogleFonts.poppinsTextTheme(),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (secilen != null) {
                              formSetState(() => baslangicTarihi = secilen);
                            }
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () async {
                        if (baslikKontrolcusu.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('⚠️ Başlık giriniz.'),
                              backgroundColor: Colors.orange.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() => _yukleniyor = true);
                        Navigator.pop(context);

                        try {
                          
                          final veri = {
                            'hayvan_id': widget.hayvanVerisi['id'],
                            'kayit_tipi': seciliTip,
                            'baslik': baslikKontrolcusu.text.trim(),
                            'kayit_tarihi':
                            baslangicTarihi.toUtc().toIso8601String(),
                          };

                          if (ilacMi) {
                            veri['detay_aciklamasi'] = 'İlaç Tedavisi';
                            veri['doz_miktari'] = aciklamaDozKontrolcusu.text
                                .trim();
                            veri['gunluk_frekans'] = seciliFrekans;
                            veri['tekrar_araligi_gun'] = seciliAralik;
                            veri['bitis_tarihi'] =
                                bitisTarihi.toUtc().toIso8601String();
                          } else {
                            veri['detay_aciklamasi'] = aciklamaDozKontrolcusu
                                .text
                                .trim();
                            veri['bitis_tarihi'] = null;
                            veri['doz_miktari'] = null;
                            veri['gunluk_frekans'] = null;
                            veri['tekrar_araligi_gun'] = null;
                          }

                          if (mevcutKayit == null) {
                            await _supabase
                                .from('saglik_kayitlari')
                                .insert(veri);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('✅ Sağlık kaydı eklendi!'),
                                backgroundColor: Colors.green.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          } else {
                            await _supabase
                                .from('saglik_kayitlari')
                                .update(veri)
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
                          debugPrint('Kayıt işlemi hatası: $e');
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

  Widget _seceneklerMenusuOlustur(Map<String, dynamic> kayit) {
    return PopupMenuButton<String>(
      onSelected: (deger) {
        if (deger == 'duzenle') {
          _kayitFormunuAc(mevcutKayit: kayit);
        } else if (deger == 'sil') {
          _kayitSil(kayit);
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
              Icon(Icons.edit, color: anaMavi, size: 20),
              const SizedBox(width: 8),
              Text(
                'Düzenle',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'sil',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red.shade400, size: 20),
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
    );
  }

  Widget _takvimModulu() {
    final seciliKayitlar = _gununOlaylari(_seciliTakvimTarihi);

    return Container(
      decoration: BoxDecoration(
        color: kartBeyazi,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: _seciliTakvimTarihi,
            selectedDayPredicate: (day) => isSameDay(_seciliTakvimTarihi, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _seciliTakvimTarihi = selectedDay;
              });
            },
            eventLoader: _gununOlaylari,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: anaMavi,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: anaMavi.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              defaultTextStyle: GoogleFonts.poppins(fontSize: 14),
              weekendTextStyle: GoogleFonts.poppins(fontSize: 14),
              selectedTextStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
              ),
              todayTextStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: anaMavi,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: anaMavi,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: anaMavi),
              rightChevronIcon: Icon(Icons.chevron_right, color: anaMavi),
            ),
          ),
          const Divider(height: 1),

          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: anaMavi.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note, color: anaMavi, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "${_seciliTakvimTarihi.day}.${_seciliTakvimTarihi.month}.${_seciliTakvimTarihi.year} Kayıtları",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: anaMavi,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (seciliKayitlar.isEmpty)
                  Text(
                    "📭 Bu tarihe planlanmış bir sağlık işlemi bulunmuyor.",
                    style: GoogleFonts.poppins(
                      color: textGri,
                      fontSize: 13,
                    ),
                  )
                else
                  ...seciliKayitlar.map((kayit) {
                    bool asiMi = kayit['kayit_tipi'] == 'Aşı/Muayene';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: asiMi
                                  ? Colors.blue.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              asiMi ? Icons.vaccines : Icons.medication,
                              size: 18,
                              color: asiMi ? Colors.blue.shade800 : Colors
                                  .green.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "${kayit['baslik']} ${asiMi ? '' : '(Tedavi Günü)'}",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          _seceneklerMenusuOlustur(kayit),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.hayvanVerisi['ad'] ?? 'İsimsiz';
    final bugunSifirlanmis = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Scaffold(
      backgroundColor: arkaPlan,
      appBar: AppBar(
        title: Text(
          '$ad · Sağlık',
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
              'Sağlık kayıtları yükleniyor... 🐾',
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimasyon,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          physics: const BouncingScrollPhysics(),
          children: [
            
            _takvimModulu(),

            
            if (_aktifIlaclar.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.healing,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Aktif İlaçlar ve Tedaviler',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: anaMavi,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._aktifIlaclar.map((ilac) {
                int frekans = ilac['gunluk_frekans'] ?? 1;
                int aralik = ilac['tekrar_araligi_gun'] ?? 1;

                int bugunIcilmeSayisi =
                    _bugunVerilenDozlar[ilac['baslik']] ?? 0;
                bool bugunTamamlandi = bugunIcilmeSayisi >= frekans;

                DateTime bitis = DateTime.parse(ilac['bitis_tarihi'])
                    .toLocal();
                DateTime baslangic =
                DateTime.parse(ilac['kayit_tarihi']).toLocal();
                DateTime baslangicSifirlanmis = DateTime(
                    baslangic.year, baslangic.month, baslangic.day);

                int gunFarki =
                    bugunSifirlanmis.difference(baslangicSifirlanmis)
                        .inDays;
                bool bugunIlacGunuMu =
                    gunFarki >= 0 && (gunFarki % aralik == 0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: kartBeyazi,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: bugunIlacGunuMu
                          ? (bugunTamamlandi
                          ? Colors.green.shade300
                          : anaMavi)
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ilac['baslik'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: anaMavi,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_busy,
                                        size: 12,
                                        color: Colors.red.shade400,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Bitiş: ${bitis.day}.${bitis.month}.${bitis.year}",
                                        style: GoogleFonts.poppins(
                                          color: Colors.red.shade400,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _seceneklerMenusuOlustur(ilac),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.medical_information,
                                size: 14, color: textGri),
                            const SizedBox(width: 4),
                            Text(
                              "Doz: ${ilac['doz_miktari'] ?? 'Belirtilmedi'}",
                              style: GoogleFonts.poppins(
                                color: textGri,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: textGri.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              aralik == 1
                                  ? 'Her gün'
                                  : '$aralik günde bir',
                              style: GoogleFonts.poppins(
                                color: textGri,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (bugunIlacGunuMu)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bugunTamamlandi
                                  ? Colors.green.shade50
                                  : anaMavi.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  bugunTamamlandi
                                      ? "✅ Bugün Tamamlandı"
                                      : "⏰ Bugünkü Dozlar:",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: bugunTamamlandi
                                        ? Colors.green.shade700
                                        : anaMavi,
                                    fontSize: 13,
                                  ),
                                ),
                                Row(
                                  children: List.generate(frekans,
                                          (indeks) {
                                        bool icildi =
                                            indeks < bugunIcilmeSayisi;
                                        return GestureDetector(
                                          onTap: () => _ilacDozuVer(
                                              ilac['baslik'],
                                              bugunIcilmeSayisi,
                                              frekans),
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                left: 8),
                                            padding:
                                            const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: icildi
                                                  ? Colors.green
                                                  : Colors.grey.shade200,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              icildi
                                                  ? Icons.check
                                                  : Icons.medical_services,
                                              size: 18,
                                              color: icildi
                                                  ? Colors.white
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                        );
                                      }),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: textGri),
                                const SizedBox(width: 8),
                                Text(
                                  "Bugün kullanım günü değil.",
                                  style: GoogleFonts.poppins(
                                    color: textGri,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
            ],

            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Geçmiş Kayıtlar',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: anaMavi,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_gecmisKayitlar.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: Text(
                  '📭 Geçmiş kayıt bulunamadı.',
                  style: GoogleFonts.poppins(
                    color: textGri,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ..._gecmisKayitlar.map((kayit) {
                DateTime tarih =
                DateTime.parse(kayit['kayit_tarihi']).toLocal();
                bool asiMi = kayit['kayit_tipi'] == 'Aşı/Muayene';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: kartBeyazi,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: asiMi
                            ? Colors.blue.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        asiMi
                            ? Icons.vaccines
                            : Icons.medication_liquid,
                        color: asiMi
                            ? Colors.blue.shade800
                            : Colors.orange.shade800,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      kayit['baslik'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "${kayit['detay_aciklamasi'] ?? ''}\n${tarih.day}.${tarih.month}.${tarih.year}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: textGri,
                      ),
                    ),
                    trailing: _seceneklerMenusuOlustur(kayit),
                  ),
                );
              }).toList(),
            const SizedBox(height: 16),
          ],
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
          onPressed: () => _kayitFormunuAc(),
          backgroundColor: anaMavi,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'Kayıt Ekle',
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
}