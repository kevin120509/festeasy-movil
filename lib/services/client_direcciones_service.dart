import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientDireccionesService {
  ClientDireccionesService._();
  static final ClientDireccionesService instance = ClientDireccionesService._();

  String get _prefsKey {
    final user = Supabase.instance.client.auth.currentUser;
    return 'direcciones_guardadas_${user?.id ?? 'guest'}';
  }

  Future<List<Map<String, String>>> loadDirecciones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_prefsKey);
      if (data == null) return [];

      final List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, String>.from(e)).toList();
    } catch (e) {
      debugPrint('Error loading direcciones: $e');
      return [];
    }
  }

  Future<void> saveDirecciones(List<Map<String, String>> direcciones) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(direcciones);
      await prefs.setString(_prefsKey, encoded);
    } catch (e) {
      debugPrint('Error saving direcciones: $e');
    }
  }
}
