import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageServisi {
  final _supabase = Supabase.instance.client;

  /// Galeriden fotoğraf seçer ve File nesnesi olarak döndürür
  // Artık sadece galeri değil, parametreye göre kamera da açabilecek
  Future<File?> fotografSec(ImageSource kaynak) async {
    final picker = ImagePicker();
    final secilenDosya = await picker.pickImage(source: kaynak, imageQuality: 70);

    if (secilenDosya != null) {
      return File(secilenDosya.path);
    }
    return null;
  }

  /// Seçilen dosyayı Supabase Storage'a yükler ve public URL'ini döndürür
  Future<String?> profilFotografiYukle(File resimDosyasi, String benzersizId) async {
    try {
      // Dosya uzantısını alıyoruz (.jpg, .png vs)
      final dosyaUzantisi = resimDosyasi.path.split('.').last;

      // Benzersiz bir dosya adı oluşturuyoruz
      final dosyaAdi = '${DateTime.now().millisecondsSinceEpoch}_$benzersizId.$dosyaUzantisi';
      final yol = 'kullanicilar/$dosyaAdi';

      // Supabase'e yükleme işlemi
      await _supabase.storage.from('profil_fotograflari').upload(yol, resimDosyasi);

      // Yüklenen resmin herkese açık (public) linkini alıyoruz
      final resimUrl = _supabase.storage.from('profil_fotograflari').getPublicUrl(yol);

      return resimUrl;
    } catch (e) {
      debugPrint('Fotoğraf yükleme hatası: $e');
      return null;
    }
  }
}