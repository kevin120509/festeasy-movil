import 'dart:convert';
import 'package:festeasy/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GastoData {
  GastoData({
    required this.id,
    required this.proveedorUsuarioId,
    required this.monto,
    required this.fecha,
    required this.categoria,
    required this.concepto,
    required this.creadoEn,
  });

  final String id;
  final String proveedorUsuarioId;
  final double monto;
  final DateTime fecha;
  final String categoria;
  final String concepto;
  final DateTime creadoEn;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'proveedor_usuario_id': proveedorUsuarioId,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'categoria': categoria,
      'concepto': concepto,
      'creado_en': creadoEn.toIso8601String(),
    };
  }

  factory GastoData.fromMap(Map<String, dynamic> map) {
    return GastoData(
      id: map['id'] as String,
      proveedorUsuarioId: map['proveedor_usuario_id'] as String,
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
      categoria: map['categoria'] as String,
      concepto: map['concepto'] as String,
      creadoEn: DateTime.parse(map['creado_en'] as String),
    );
  }
}

class GastosService {
  GastosService._();
  static final GastosService instance = GastosService._();

  static const String _storageKey = 'gastos_proveedor_local';

  Future<List<GastoData>> getGastos() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_storageKey\_${user.id}');
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((m) => GastoData.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<void> saveGasto(GastoData gasto) async {
    final gastos = await getGastos();
    
    // Si ya existe, se actualiza
    final index = gastos.indexWhere((g) => g.id == gasto.id);
    if (index != -1) {
      gastos[index] = gasto;
    } else {
      gastos.add(gasto);
    }
    await _saveAll(gastos);
  }

  Future<void> deleteGasto(String id) async {
    final gastos = await getGastos();
    gastos.removeWhere((g) => g.id == id);
    await _saveAll(gastos);
  }

  Future<void> _saveAll(List<GastoData> gastos) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonList = gastos.map((g) => g.toMap()).toList();
    await prefs.setString('$_storageKey\_${user.id}', jsonEncode(jsonList));
  }
}
