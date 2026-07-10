import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class HayvanEklePaneli extends StatefulWidget {
  const HayvanEklePaneli({super.key});

  @override
  State<HayvanEklePaneli> createState() => _HayvanEklePaneliState();
}

class _HayvanEklePaneliState extends State<HayvanEklePaneli>
    with SingleTickerProviderStateMixin {
  final _formAnahtari = GlobalKey<FormState>();

  final TextEditingController _adKontrolcusu = TextEditingController();
  final TextEditingController _irkKontrolcusu = TextEditingController();
  final TextEditingController _cipNoKontrolcusu = TextEditingController();

  String? _secilenTur;
  String? _secilenCinsiyet;
  DateTime? _secilenDogumTarihi;

  bool _cipliMi = false;
  bool _kronikHastalikVarMi = false;
  bool _kaydediliyor = false;

  
  final Color anaMavi = const Color(0xFF1A237E);
  final Color anaMaviLight = const Color(0xFF283593);
  final Color vurguRengi = const Color(0xFFFFC107);
  final Color vurguRengiLight = const Color(0xFFFFD54F);
  final Color arkaPlan = const Color(0xFFF8F9FA);
  final Color kartBeyazi = Colors.white;
  final Color textGri = const Color(0xFF546E7A);

  late AnimationController _animasyonKontrol;
  late Animation<double> _fadeAnimasyon;
  late Animation<Offset> _kaymaAnimasyon;

  String _yasHesapla() {
    if (_secilenDogumTarihi == null) return "Doğum tarihi seçilmedi";

    final bugun = DateTime.now();
    int yasYil = bugun.year - _secilenDogumTarihi!.year;
    int yasAy = bugun.month - _secilenDogumTarihi!.month;

    if (yasAy < 0) {
      yasYil--;
      yasAy += 12;
    }

    if (yasYil > 0) {
      return "$yasYil Yıl $yasAy Ay";
    } else {
      return "$yasAy Aylık";
    }
  }

  @override
  void initState() {
    super.initState();
    _animasyonKontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimasyon = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animasyonKontrol, curve: Curves.easeOut),
    );
    _kaymaAnimasyon = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animasyonKontrol, curve: Curves.easeOut),
    );
    _animasyonKontrol.forward();
  }

  @override
  void dispose() {
    _animasyonKontrol.dispose();
    _adKontrolcusu.dispose();
    _irkKontrolcusu.dispose();
    _cipNoKontrolcusu.dispose();
    super.dispose();
  }

  Future<void> _tarihSec(BuildContext context) async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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

    if (secilen != null && secilen != _secilenDogumTarihi) {
      setState(() {
        _secilenDogumTarihi = secilen;
      });
    }
  }

  Future<void> _hayvaniKaydet() async {
    if (_formAnahtari.currentState!.validate()) {
      if (_secilenDogumTarihi == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Lütfen doğum tarihi seçin.'),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      setState(() {
        _kaydediliyor = true;
      });

      try {
        final supabase = Supabase.instance.client;
        final mevcutKullaniciId = supabase.auth.currentUser?.id;

        if (mevcutKullaniciId == null) {
          throw Exception('Kullanıcı oturumu bulunamadı.');
        }

        final kullaniciVerisi = await supabase
            .from('kullanicilar')
            .select('aile_id')
            .eq('id', mevcutKullaniciId)
            .maybeSingle();

        if (kullaniciVerisi == null || kullaniciVerisi['aile_id'] == null) {
          throw Exception('Hayvan ekleyebilmek için bir aileye dahil olmalısınız.');
        }

        final String gercekAileId = kullaniciVerisi['aile_id'];

        await supabase.from('evcil_hayvanlar').insert({
          'aile_id': gercekAileId,
          'ad': _adKontrolcusu.text.trim(),
          'tur': _secilenTur,
          'irk': _irkKontrolcusu.text.trim(),
          'cinsiyet': _secilenCinsiyet,
          'dogum_tarihi': _secilenDogumTarihi!.toIso8601String(),
          'mikrocip_no': _cipliMi ? _cipNoKontrolcusu.text.trim() : null,
          'kronik_hastalik_var_mi': _kronikHastalikVarMi,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🎉 Pati başarıyla eklendi!'),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (hata) {
        debugPrint('Kayıt başarısız: $hata');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Hata: $hata'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _kaydediliyor = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimasyon,
      child: Scaffold(
        backgroundColor: arkaPlan,
        appBar: AppBar(
          title: Text(
            '🐾 Yeni Pati',
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
                child: const Icon(Icons.close, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: SlideTransition(
            position: _kaymaAnimasyon,
            child: Form(
              key: _formAnahtari,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('📸 Fotoğraf seçme özelliği yakında eklenecek!'),
                            backgroundColor: anaMavi,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: anaMavi.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.blue.shade50,
                              child: Icon(
                                Icons.pets,
                                size: 55,
                                color: anaMavi.withOpacity(0.6),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [anaMavi, anaMaviLight],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  
                  Text(
                    'Pati Bilgileri',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: anaMavi,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Yeni patini ailemize ekle 🐾',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: textGri,
                    ),
                  ),
                  const SizedBox(height: 20),

                  
                  _modernTextField(
                    controller: _adKontrolcusu,
                    label: 'Pati Adı',
                    hint: 'Örn: Lokum, Pamuk',
                    icon: Icons.badge,
                    validator: (deger) => deger!.isEmpty ? 'İsim zorunludur' : null,
                  ),
                  const SizedBox(height: 16),

                  
                  Row(
                    children: [
                      Expanded(
                        child: _modernDropdown(
                          value: _secilenTur,
                          items: ['Kedi', 'Köpek', 'Kuş', 'Diğer'],
                          label: 'Türü',
                          hint: 'Seçiniz',
                          icon: Icons.category,
                          onChanged: (deger) => setState(() => _secilenTur = deger),
                          validator: (deger) => deger == null ? 'Seçiniz' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _modernDropdown(
                          value: _secilenCinsiyet,
                          items: ['Dişi', 'Erkek'],
                          label: 'Cinsiyet',
                          hint: 'Seçiniz',
                          icon: Icons.transgender,
                          onChanged: (deger) => setState(() => _secilenCinsiyet = deger),
                          validator: (deger) => deger == null ? 'Seçiniz' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  
                  _modernTextField(
                    controller: _irkKontrolcusu,
                    label: 'Irkı',
                    hint: 'Örn: Tekir, Golden, Van',
                    icon: Icons.merge_type,
                  ),
                  const SizedBox(height: 16),

                  
                  InkWell(
                    onTap: () => _tarihSec(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: anaMaviLight, size: 22),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Doğum Tarihi',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: textGri,
                                    ),
                                  ),
                                  Text(
                                    _secilenDogumTarihi == null
                                        ? 'Tarih Seçin'
                                        : '${_secilenDogumTarihi!.day}/${_secilenDogumTarihi!.month}/${_secilenDogumTarihi!.year}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: _secilenDogumTarihi == null
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                      color: _secilenDogumTarihi == null
                                          ? textGri
                                          : anaMavi,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [vurguRengi, vurguRengiLight],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _yasHesapla(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: anaMavi,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
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
                    child: SwitchListTile(
                      title: Row(
                        children: [
                          Icon(Icons.memory, color: _cipliMi ? anaMavi : textGri, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Mikroçipi Var Mı?',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: _cipliMi ? anaMavi : textGri,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Kayıp durumunda bulunmasını kolaylaştırır.',
                        style: GoogleFonts.poppins(fontSize: 12, color: textGri),
                      ),
                      value: _cipliMi,
                      activeColor: anaMavi,
                      activeTrackColor: anaMavi.withOpacity(0.2),
                      onChanged: (deger) {
                        setState(() {
                          _cipliMi = deger;
                        });
                      },
                    ),
                  ),

                  if (_cipliMi) ...[
                    const SizedBox(height: 12),
                    _modernTextField(
                      controller: _cipNoKontrolcusu,
                      label: 'Çip Numarası',
                      hint: '15 haneli numarayı girin',
                      icon: Icons.memory,
                      keyboardType: TextInputType.number,
                      validator: (deger) => deger!.isEmpty ? 'Çip numarası giriniz' : null,
                    ),
                  ],

                  const SizedBox(height: 12),

                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SwitchListTile(
                      title: Row(
                        children: [
                          Icon(
                            Icons.health_and_safety,
                            color: _kronikHastalikVarMi ? Colors.red.shade400 : textGri,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Kronik Hastalığı / Alerjisi Var Mı?',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: _kronikHastalikVarMi ? Colors.red.shade400 : textGri,
                            ),
                          ),
                        ],
                      ),
                      value: _kronikHastalikVarMi,
                      activeColor: Colors.red.shade400,
                      activeTrackColor: Colors.red.shade100,
                      onChanged: (deger) {
                        setState(() {
                          _kronikHastalikVarMi = deger;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _kaydediliyor ? null : _hayvaniKaydet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: anaMavi,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: _kaydediliyor
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            'Patini Kaydet',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
          labelStyle: GoogleFonts.poppins(color: textGri, fontSize: 13),
          prefixIcon: Icon(icon, color: anaMaviLight, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _modernDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required String hint,
    required IconData icon,
    required void Function(String?) onChanged,
    required String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: textGri, fontSize: 13),
          prefixIcon: Icon(icon, color: anaMaviLight, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        hint: Text(
          hint,
          style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        dropdownColor: Colors.white,
        style: GoogleFonts.poppins(fontSize: 14, color: anaMavi),
        icon: Icon(Icons.keyboard_arrow_down, color: anaMaviLight),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}