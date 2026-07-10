import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageServisi {
  final _supabase = Supabase.instance.client;

  
  
  Future<File?> fotografSec(ImageSource kaynak) async {
    final picker = ImagePicker();
    final secilenDosya = await picker.pickImage(source: kaynak, imageQuality: 70);

    if (secilenDosya != null) {
      return File(secilenDosya.path);
    }
    return null;
  }

  
  Future<String?> profilFotografiYukle(File resimDosyasi, String benzersizId) async {
    try {
      
      final dosyaUzantisi = resimDosyasi.path.split('.').last;

      
      final dosyaAdi = '${DateTime.now().millisecondsSinceEpoch}_$benzersizId.$dosyaUzantisi';
      final yol = 'kullanicilar/$dosyaAdi';

      
      await _supabase.storage.from('profil_fotograflari').upload(yol, resimDosyasi);

      
      final resimUrl = _supabase.storage.from('profil_fotograflari').getPublicUrl(yol);

      return resimUrl;
    } catch (e) {
      debugPrint('Fotoğraf yükleme hatası: $e');
      return null;
    }
  }
}