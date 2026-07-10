import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'aile_paneli.dart';

class AileSecimPaneli extends StatefulWidget {
  const AileSecimPaneli({super.key});

  @override
  State<AileSecimPaneli> createState() => _AileSecimPaneliState();
}

class _AileSecimPaneliState extends State<AileSecimPaneli>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _islemYapiliyor = false;

  final TextEditingController _aileAdiKontrolcusu = TextEditingController();
  final TextEditingController _davetKoduKontrolcusu = TextEditingController();

  
  final Color anaMavi = const Color(0xFF1A237E);
  final Color anaMaviLight = const Color(0xFF283593);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color vurguRengiLight = const Color(0xFFFFD54F);
  final Color arkaPlan = const Color(0xFFF8F9FA);
  final Color kartBeyazi = Colors.white;
  final Color textGri = const Color(0xFF546E7A);

  late AnimationController _animasyonKontrol;
  late Animation<double> _fadeAnimasyon;
  late Animation<Offset> _kaymaAnimasyon1;
  late Animation<Offset> _kaymaAnimasyon2;

  String _davetKoduUret() {
    const harflerVeSayilar = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rastgele = Random();
    return String.fromCharCodes(Iterable.generate(
        6,
            (_) => harflerVeSayilar
            .codeUnitAt(rastgele.nextInt(harflerVeSayilar.length))));
  }

  @override
  void initState() {
    super.initState();
    _animasyonKontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimasyon = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrol, curve: Curves.easeOut),
    );

    _kaymaAnimasyon1 = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animasyonKontrol,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _kaymaAnimasyon2 = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animasyonKontrol,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _animasyonKontrol.forward();
  }

  @override
  void dispose() {
    _animasyonKontrol.dispose();
    _aileAdiKontrolcusu.dispose();
    _davetKoduKontrolcusu.dispose();
    super.dispose();
  }

  Future<void> _yeniAileOlustur(String aileAdi) async {
    if (aileAdi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Lütfen bir aile adı girin.'),
          backgroundColor: Colors.orange.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _islemYapiliyor = true);

    try {
      final mevcutKullaniciId = _supabase.auth.currentUser?.id;

      if (mevcutKullaniciId != null) {
        final uretilenKod = _davetKoduUret();

        final yeniAileVerisi = await _supabase
            .from('aileler')
            .insert({
          'aile_adi': aileAdi,
          'davet_kodu': uretilenKod,
          'kurucu_id': mevcutKullaniciId
        })
            .select()
            .single();

        final String olusanAileId = yeniAileVerisi['id'];

        await _supabase
            .from('kullanicilar')
            .update({'aile_id': olusanAileId})
            .eq('id', mevcutKullaniciId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('🎉 "$aileAdi" ailesi oluşturuldu!'),
                ],
              ),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AilePaneli()),
                (route) => false,
          );
        }
      }
    } catch (hata) {
      debugPrint('Aile oluşturma hatası: $hata');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Aile oluşturulamadı: $hata'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _islemYapiliyor = false);
    }
  }

  Future<void> _aileyeKatil(String girilenDavetKodu) async {
    if (girilenDavetKodu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Lütfen davet kodunu girin.'),
          backgroundColor: Colors.orange.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _islemYapiliyor = true);

    try {
      final mevcutKullaniciId = _supabase.auth.currentUser?.id;

      if (mevcutKullaniciId != null) {
        final aileKontrol = await _supabase
            .from('aileler')
            .select('id, aile_adi')
            .eq('davet_kodu', girilenDavetKodu.toUpperCase())
            .maybeSingle();

        if (aileKontrol == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('❌ Geçersiz Davet Kodu!'),
                backgroundColor: Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          return;
        }

        final String bulunanAileId = aileKontrol['id'];
        final String aileAdi = aileKontrol['aile_adi'] ?? 'Aile';

        await _supabase
            .from('kullanicilar')
            .update({'aile_id': bulunanAileId})
            .eq('id', mevcutKullaniciId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('🎉 "$aileAdi" ailesine katıldın!'),
                ],
              ),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AilePaneli()),
                (route) => false,
          );
        }
      }
    } catch (hata) {
      debugPrint('HATA DETAYI: $hata');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Aileye katılım başarısız: $hata'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _islemYapiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: arkaPlan,
      appBar: AppBar(
        title: Text(
          '🏠 Aile Seçimi',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: anaMavi,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _islemYapiliyor
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
              'İşlemin gerçekleşmesi bekleniyor... 🐾',
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [anaMavi, anaMaviLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: anaMavi.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.house_siding,
                      size: 50,
                      color: vurguRengi,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pati Ailem',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: anaMavi,
                    ),
                  ),
                  Text(
                    'Ailene katıl veya yeni bir tane oluştur 🐾',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: textGri,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              
              SlideTransition(
                position: _kaymaAnimasyon1,
                child: Container(
                  decoration: BoxDecoration(
                    color: kartBeyazi,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [anaMavi, anaMaviLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_home,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Yeni Aile Oluştur',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: anaMavi,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: TextField(
                            controller: _aileAdiKontrolcusu,
                            decoration: InputDecoration(
                              labelText: 'Aile Adı',
                              hintText: 'Örn: Görgün Ailesi',
                              labelStyle:
                              TextStyle(color: textGri, fontSize: 13),
                              prefixIcon: Icon(
                                Icons.group,
                                color: anaMaviLight,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                              const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _yeniAileOlustur(
                                _aileAdiKontrolcusu.text.trim()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: anaMavi,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Aile Oluştur',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              
              SlideTransition(
                position: _kaymaAnimasyon2,
                child: Container(
                  decoration: BoxDecoration(
                    color: kartBeyazi,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    vurguRengi,
                                    vurguRengiLight
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                color: Color(0xFF1A237E),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Aileye Katıl',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: anaMavi,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: TextField(
                            controller: _davetKoduKontrolcusu,
                            decoration: InputDecoration(
                              labelText: 'Davet Kodu',
                              hintText: 'Örn: ABC123',
                              labelStyle:
                              TextStyle(color: textGri, fontSize: 13),
                              prefixIcon: Icon(
                                Icons.vpn_key,
                                color: vurguRengi,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                              const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              counter: const SizedBox.shrink(),
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              letterSpacing: 2,
                            ),
                            onChanged: (value) {
                              if (value.length > 6) {
                                _davetKoduKontrolcusu.text = value.substring(0, 6);
                                _davetKoduKontrolcusu.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _davetKoduKontrolcusu.text.length),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _aileyeKatil(
                                _davetKoduKontrolcusu.text.trim()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: vurguRengi,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Aileye Katıl',
                              style: GoogleFonts.poppins(
                                color: anaMavi,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              
              Center(
                child: Text(
                  '💡 Pati Ailenle birlikte tüm takipleri yapabilirsin',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}