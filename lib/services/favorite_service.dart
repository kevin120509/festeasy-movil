import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService {
  FavoriteService._();
  static final FavoriteService instance = FavoriteService._();

  static const String _prefsKey = 'favorite_providers';

  /// Obtiene la lista de IDs de proveedores favoritos
  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? [];
  }

  /// Verifica si un proveedor es favorito
  Future<bool> isFavorite(String providerId) async {
    final favorites = await getFavorites();
    return favorites.contains(providerId);
  }

  /// Agrega un proveedor a favoritos
  Future<void> addFavorite(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_prefsKey) ?? [];
    if (!favorites.contains(providerId)) {
      favorites.add(providerId);
      await prefs.setStringList(_prefsKey, favorites);
    }
  }

  /// Elimina un proveedor de favoritos
  Future<void> removeFavorite(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_prefsKey) ?? [];
    if (favorites.contains(providerId)) {
      favorites.remove(providerId);
      await prefs.setStringList(_prefsKey, favorites);
    }
  }

  /// Alterna el estado de favorito
  Future<bool> toggleFavorite(String providerId) async {
    final isFav = await isFavorite(providerId);
    if (isFav) {
      await removeFavorite(providerId);
      return false;
    } else {
      await addFavorite(providerId);
      return true;
    }
  }
}
