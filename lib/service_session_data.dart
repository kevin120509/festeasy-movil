import 'package:flutter/material.dart';

/// Representa un item en el carrito local
class CartItemLocal {

  CartItemLocal({
    required this.packageId,
    required this.packageName,
    required this.packagePrice,
    required this.quantity,
    required this.providerUserId,
    required this.providerName,
    required this.providerAvatarUrl,
  });
  final String packageId;
  final String packageName;
  final double packagePrice;
  int quantity;
  final String providerUserId;
  final String providerName;
  final String providerAvatarUrl;

  /// Calcula el subtotal de este item
  double get subtotal => packagePrice * quantity;

  /// Copia con cambios específicos
  CartItemLocal copyWith({
    String? packageId,
    String? packageName,
    double? packagePrice,
    int? quantity,
    String? providerUserId,
    String? providerName,
    String? providerAvatarUrl,
  }) {
    return CartItemLocal(
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      packagePrice: packagePrice ?? this.packagePrice,
      quantity: quantity ?? this.quantity,
      providerUserId: providerUserId ?? this.providerUserId,
      providerName: providerName ?? this.providerName,
      providerAvatarUrl: providerAvatarUrl ?? this.providerAvatarUrl,
    );
  }
}

/// Datos de sesión compartidos durante el flujo de búsqueda y carrito
/// Se usa como singleton para persistir datos entre pantallas
class ServiceSessionData {

  /// Previene instanciación directa
  ServiceSessionData._internal();

  /// Obtiene la instancia singleton
  factory ServiceSessionData.getInstance() {
    return _instance;
  }
  static final ServiceSessionData _instance = ServiceSessionData._internal();

  // Datos iniciales del evento
  DateTime? date;
  TimeOfDay? time;
  String? address;
  double? latitude;
  double? longitude;
  int? numberOfGuests;

  // Datos de categoría
  String? categoryId;
  String? categoryName;

  // Carrito local
  List<CartItemLocal> cartItems = [];

  /// Inicializa los datos de la sesión
  void initialize({
    required DateTime eventDate,
    required TimeOfDay eventTime,
    required String eventAddress,
    required double eventLatitude,
    required double eventLongitude,
    required String category,
    required String categoryName,
    int? eventNumberOfGuests,
  }) {
    date = eventDate;
    time = eventTime;
    address = eventAddress;
    latitude = eventLatitude;
    longitude = eventLongitude;
    categoryId = category;
    this.categoryName = categoryName;
    numberOfGuests = eventNumberOfGuests;
    cartItems = [];
  }

  /// Agrega un item al carrito
  /// Si el item ya existe (mismo paquete del mismo proveedor), incrementa cantidad
  void addCartItem({
    required String packageId,
    required String packageName,
    required double packagePrice,
    required int quantity,
    required String providerUserId,
    required String providerName,
    required String providerAvatarUrl,
  }) {
    // Buscar si ya existe este paquete del mismo proveedor
    final existingIndex = cartItems.indexWhere(
      (item) =>
          item.packageId == packageId && item.providerUserId == providerUserId,
    );

    if (existingIndex != -1) {
      // Incrementar cantidad
      cartItems[existingIndex] = cartItems[existingIndex].copyWith(
        quantity: cartItems[existingIndex].quantity + quantity,
      );
    } else {
      // Nuevo item
      cartItems.add(
        CartItemLocal(
          packageId: packageId,
          packageName: packageName,
          packagePrice: packagePrice,
          quantity: quantity,
          providerUserId: providerUserId,
          providerName: providerName,
          providerAvatarUrl: providerAvatarUrl,
        ),
      );
    }
  }

  /// Actualiza la cantidad de un item
  void updateItemQuantity(
    String packageId,
    String providerUserId,
    int newQuantity,
  ) {
    final index = cartItems.indexWhere(
      (item) =>
          item.packageId == packageId && item.providerUserId == providerUserId,
    );

    if (index != -1) {
      if (newQuantity <= 0) {
        cartItems.removeAt(index);
      } else {
        cartItems[index] = cartItems[index].copyWith(quantity: newQuantity);
      }
    }
  }

  /// Elimina un item del carrito
  void removeCartItem(String packageId, String providerUserId) {
    cartItems.removeWhere(
      (item) =>
          item.packageId == packageId && item.providerUserId == providerUserId,
    );
  }

  /// Obtiene los items agrupados por proveedor
  /// Retorna un Map<providerUserId, List<CartItemLocal>>
  Map<String, List<CartItemLocal>> getCartItemsGroupedByProvider() {
    final grouped = <String, List<CartItemLocal>>{};

    for (final item in cartItems) {
      if (!grouped.containsKey(item.providerUserId)) {
        grouped[item.providerUserId] = [];
      }
      grouped[item.providerUserId]!.add(item);
    }

    return grouped;
  }

  /// Calcula el total del carrito
  double get cartTotal {
    return cartItems.fold(0, (sum, item) => sum + item.subtotal);
  }

  /// Obtiene la cantidad total de items
  int get cartItemCount {
    return cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Limpia el carrito
  void clearCart() {
    cartItems = [];
  }

  /// Limpia toda la sesión
  void clearSession() {
    date = null;
    time = null;
    address = null;
    latitude = null;
    longitude = null;
    categoryId = null;
    categoryName = null;
    cartItems = [];
  }

  /// Retorna true si hay datos iniciales válidos
  bool hasInitialData() {
    return date != null && time != null && address != null;
  }

  /// Retorna true si hay items en el carrito
  bool hasCartItems() {
    return cartItems.isNotEmpty;
  }
}
