import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../aile/ekranlar/aile_secim_paneli.dart';
// Eğer bu alt satırda kırmızı hata çıkarsa, sonundaki ismin üzerine tıklayıp Alt + Enter yapabilirsin
import 'package:pati_ailesi/cekirdek/navigasyon/ana_navigasyon_paneli.dart';class KimlikDogrulamaPaneli extends StatefulWidget {
  const KimlikDogrulamaPaneli({super.key});

  @override
  State<KimlikDogrulamaPaneli> createState() => _KimlikDogrulamaPaneliState();
}

class _KimlikDogrulamaPaneliState extends State<KimlikDogrulamaPaneli> {
  final _formAnahtari = GlobalKey<FormState>();

  final TextEditingController _adSoyadKontrolcusu = TextEditingController();
  final TextEditingController _epostaKontrolcusu = TextEditingController();
  final TextEditingController _sifreKontrolcusu = TextEditingController();

  bool _islemYapiliyor = false;
  bool _girisModuMu = true;

  void _formuTemizle() {
    setState(() {
      _adSoyadKontrolcusu.clear();
      _epostaKontrolcusu.clear();
      _sifreKontrolcusu.clear();
    });
  }

  void _dogrulamaMailiGonderildiDiyalogu(String kayitliEposta) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext veriBaglami) {
        return AlertDialog(
          backgroundColor: Colors.blue[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.mark_email_unread, color: Colors.blue[800], size: 28),
              const SizedBox(width: 12),
              Text('Son Bir Adım!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kayıt işlemi başarılı! Lütfen uygulamaya giriş yapabilmek için ',
                style: TextStyle(color: Colors.blue[900], fontSize: 15),
              ),
              Text(
                kayitliEposta,
                style: TextStyle(color: Colors.blue[900], fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                ' adresine gönderdiğimiz doğrulama bağlantısına tıklayın.\n\nDoğrulamayı tamamladıktan sonra şifrenizi girerek giriş yapabilirsiniz.',
                style: TextStyle(color: Colors.blue[900], fontSize: 15),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(veriBaglami).pop();
                setState(() {
                  _girisModuMu = true;
                  _adSoyadKontrolcusu.clear();
                  _sifreKontrolcusu.clear();
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.blue[900]),
              child: const Text('Anladım', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
      ),
    );
  }

  Future<void> _girisYap() async {
    if (_formAnahtari.currentState!.validate()) {
      setState(() => _islemYapiliyor = true);

      try {
        final yanit = await Supabase.instance.client.auth.signInWithPassword(
          email: _epostaKontrolcusu.text.trim(),
          password: _sifreKontrolcusu.text.trim(),
        );

        if (yanit.user != null) {
          final kullaniciVerisi = await Supabase.instance.client
              .from('kullanicilar')
              .select('aile_id')
              .eq('id', yanit.user!.id)
              .maybeSingle();

          if (mounted) {
            if (kullaniciVerisi != null && kullaniciVerisi['aile_id'] != null) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AnaNavigasyonPaneli()));
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AileSecimPaneli()));
            }
          }
        }
      } on AuthException catch (e) {
        if (e.message.contains('Email not confirmed')) {
          _hataGoster('Lütfen önce e-posta adresinize gelen bağlantıdan hesabınızı doğrulayın.');
        } else {
          _hataGoster('Giriş başarısız: E-posta veya şifre hatalı.');
        }
      } catch (hata) {
        _hataGoster('Bağlantı hatası oluştu: $hata');
      } finally {
        if (mounted) setState(() => _islemYapiliyor = false);
      }
    }
  }

  Future<void> _kayitOl() async {
    if (_formAnahtari.currentState!.validate()) {
      setState(() => _islemYapiliyor = true);

      try {
        final response = await Supabase.instance.client.auth.signUp(
          email: _epostaKontrolcusu.text.trim(),
          password: _sifreKontrolcusu.text.trim(),
        );

        if (response.user != null) {
          await Supabase.instance.client.from('kullanicilar').insert({
            'id': response.user!.id,
            'ad_soyad': _adSoyadKontrolcusu.text.trim(),
          });

          if (mounted) {
            _dogrulamaMailiGonderildiDiyalogu(_epostaKontrolcusu.text.trim());
          }
        }
      } on AuthException catch (e) {
        _hataGoster('Hata: ${e.message}');
      } catch (e) {
        _hataGoster('Beklenmedik bir hata oluştu: $e');
      } finally {
        if (mounted) setState(() => _islemYapiliyor = false);
      }
    }
  }

  @override
  void dispose() {
    _adSoyadKontrolcusu.dispose();
    _epostaKontrolcusu.dispose();
    _sifreKontrolcusu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formAnahtari,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.pets, size: 80, color: Colors.blue[800]),
                  const SizedBox(height: 16),
                  Text(
                    'Pati Ailesi',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _girisModuMu = true;
                              _formuTemizle();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _girisModuMu ? Colors.blue[800] : Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                'Giriş Yap',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, color: _girisModuMu ? Colors.white : Colors.blue[900]),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _girisModuMu = false;
                              _formuTemizle();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_girisModuMu ? Colors.blue[800] : Colors.transparent,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                'Kayıt Ol',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, color: !_girisModuMu ? Colors.white : Colors.blue[900]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!_girisModuMu) ...[
                    TextFormField(
                      controller: _adSoyadKontrolcusu,
                      style: TextStyle(color: Colors.blue[900]),
                      decoration: InputDecoration(
                        labelText: 'Adınız Soyadınız',
                        labelStyle: TextStyle(color: Colors.blue[800]),
                        prefixIcon: Icon(Icons.person, color: Colors.blue[800]),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[300]!)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[800]!, width: 2)),
                      ),
                      validator: (deger) => deger!.isEmpty ? 'Ad Soyad zorunludur' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _epostaKontrolcusu,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Colors.blue[900]),
                    decoration: InputDecoration(
                      labelText: 'E-Posta Adresiniz',
                      labelStyle: TextStyle(color: Colors.blue[800]),
                      prefixIcon: Icon(Icons.email, color: Colors.blue[800]),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[300]!)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[800]!, width: 2)),
                    ),
                    validator: (deger) {
                      if (deger == null || deger.isEmpty) return 'E-posta zorunludur';
                      if (!deger.contains('@')) return 'Geçerli bir e-posta giriniz';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _sifreKontrolcusu,
                    obscureText: true,
                    style: TextStyle(color: Colors.blue[900]),
                    decoration: InputDecoration(
                      labelText: 'Şifreniz',
                      labelStyle: TextStyle(color: Colors.blue[800]),
                      prefixIcon: Icon(Icons.lock, color: Colors.blue[800]),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[300]!)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue[800]!, width: 2)),
                    ),
                    validator: (deger) {
                      if (deger == null || deger.isEmpty) return 'Şifre zorunludur';
                      if (!_girisModuMu && deger.length < 6) return 'Şifre en az 6 karakter olmalıdır';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _islemYapiliyor ? null : (_girisModuMu ? _girisYap : _kayitOl),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _islemYapiliyor
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      _girisModuMu ? 'Giriş Yap' : 'Kayıt Ol',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}