import 'package:festeasy/services/provider_inventario_service.dart';
import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderCotizacionPage extends StatefulWidget {
  const ProviderCotizacionPage({
    required this.solicitud,
    required this.itemsOriginales,
    required this.onCotizacionEnviada,
    super.key,
  });

  final ProviderSolicitudData solicitud;
  final List<Map<String, dynamic>> itemsOriginales;
  final VoidCallback onCotizacionEnviada;

  @override
  State<ProviderCotizacionPage> createState() => _ProviderCotizacionPageState();
}

class _ProviderCotizacionPageState extends State<ProviderCotizacionPage> {
  bool _isLoading = false;
  List<ProductoInventarioData> _inventory = [];

  // Cotización state
  late double _basePrice;
  late int _baseQuantity;
  final List<Map<String, dynamic>> _extraItems = [];

  @override
  void initState() {
    super.initState();
    // Iniciar con precio de item original o 0
    if (widget.itemsOriginales.isNotEmpty) {
      _basePrice =
          (widget.itemsOriginales.first['precio_unitario'] as num?)
              ?.toDouble() ??
          0.0;
      _baseQuantity =
          (widget.itemsOriginales.first['cantidad'] as num?)?.toInt() ?? 1;
      
      // Cargar el resto de los items (productos/ítems extra) a la UI  
      if (widget.itemsOriginales.length > 1) {
        for (int i = 1; i < widget.itemsOriginales.length; i++) {
          final extraMap = widget.itemsOriginales[i];
          _extraItems.add({
            // Como estos extraItems de items_solicitud no traen el id de inventario,
            // asignamos su nombre como id temporal y su propio nombre para mostrar en pantalla.
            'id': 'temporal_$i',
            'nombre': extraMap['nombre_paquete_snapshot'] ?? 'Extra $i',
            'precio': (extraMap['precio_unitario'] as num?)?.toDouble() ?? 0.0,
            'cantidad': (extraMap['cantidad'] as num?)?.toInt() ?? 1,
          });
        }
      }
    } else {
      _basePrice = 0.0;
      _baseQuantity = 1;
    }
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) return;
      final items = await ProviderInventarioService.instance.getProductos(myId);
      if (mounted) {
        setState(() {
          _inventory = items;
        });
      }
    } catch (e) {
      debugPrint('Error loading inventory: $e');
    }
  }

  double get _subtotal {
    double total = _basePrice * _baseQuantity;
    for (var item in _extraItems) {
      total += (item['precio'] as double) * (item['cantidad'] as int);
    }
    return total;
  }

  void _addExtraItem(ProductoInventarioData product) {
    setState(() {
      final idx = _extraItems.indexWhere((e) => e['id'] == product.id);
      if (idx >= 0) {
        _extraItems[idx]['cantidad'] =
            (_extraItems[idx]['cantidad'] as int) + 1;
      } else {
        _extraItems.add({
          'id': product.id,
          'nombre': product.nombre,
          'precio': product.precioUnitario,
          'cantidad': 1,
        });
      }
    });
  }

  void _removeExtraItem(int index) {
    setState(() {
      if ((_extraItems[index]['cantidad'] as int) > 1) {
        _extraItems[index]['cantidad'] =
            (_extraItems[index]['cantidad'] as int) - 1;
      } else {
        _extraItems.removeAt(index);
      }
    });
  }

  Future<void> _enviarCotizacion() async {
    setState(() => _isLoading = true);
    try {
      // Calculamos total, 50% anticipo
      final total = _subtotal;
      final anticipo = total * 0.5;
      final liquida = total - anticipo;

      await ProviderSolicitudesService.instance.enviarCotizacion(
        solicitudId: widget.solicitud.id,
        nuevoMontoTotal: total,
        nuevoMontoAnticipo: anticipo,
        nuevoMontoLiquidacion: liquida,
        baseItemId: widget.itemsOriginales.isNotEmpty ? widget.itemsOriginales.first['id'] as String? : null,
        baseItemPrecio: _basePrice,
        baseItemCantidad: _baseQuantity,
        extraItems: _extraItems,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cotización enviada al cliente',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCotizacionEnviada();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFF8D72C2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFFF0E6FF),
                        child: Icon(
                          Icons.architecture,
                          color: Color(0xFF8D72C2),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Constructor de Cotización',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF010302),
                              ),
                            ),
                            Text(
                              'Personaliza y ajusta los detalles de la oferta oficial.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Paquete Base
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2, color: Color(0xFF8D72C2)),
                            SizedBox(width: 8),
                            Text(
                              'Paquete Base',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.itemsOriginales.isNotEmpty
                              ? '${widget.itemsOriginales.first['nombre_paquete_snapshot']}'
                              : 'Ajuste Manual',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PRECIO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          '\$',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: _basePrice
                                                .toStringAsFixed(0),
                                            keyboardType: TextInputType.number,
                                            decoration:
                                                const InputDecoration.collapsed(
                                                  hintText: '0',
                                                ),
                                            onChanged: (val) {
                                              setState(() {
                                                _basePrice =
                                                    double.tryParse(val) ?? 0.0;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CANT.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: TextFormField(
                                      initialValue: _baseQuantity.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration:
                                          const InputDecoration.collapsed(
                                            hintText: '1',
                                          ),
                                      onChanged: (val) {
                                        setState(() {
                                          _baseQuantity =
                                              int.tryParse(val) ?? 1;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Productos Extra
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart,
                                  color: Color(0xFF8D72C2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Productos Extra',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_extraItems.length} ítems',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_extraItems.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.grey[400],
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Aún sin productos extra agregados',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._extraItems.asMap().entries.map(
                            (e) => ListTile(
                              title: Text(e.value['nombre'] as String),
                              subtitle: Text('\$${e.value['precio']} c/u'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: const Color(0xFF8D72C2),
                                    ),
                                    onPressed: () => _removeExtraItem(e.key),
                                  ),
                                  Text(
                                    '${e.value['cantidad']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),


                  // Inventario List To Pick
                  const Text(
                    '  Mi Inventario',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _inventory.isEmpty
                        ? const Center(
                            child: Text(
                              'Sin productos en inventario',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _inventory.length,
                            separatorBuilder: (c, i) =>
                                const Divider(height: 1),
                            itemBuilder: (c, i) {
                              final p = _inventory[i];
                              return ListTile(
                                title: Text(
                                  p.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  '\$${p.precioUnitario.toStringAsFixed(2)} - Stock: ${p.stock}',
                                  style: const TextStyle(
                                    color: Color(0xFF8D72C2),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _addExtraItem(p),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                Text(
                  '\$${_subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL A PAGAR',
                  style: TextStyle(
                    color: Color(0xFF010302),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '\$${_subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF8D72C2),
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _enviarCotizacion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D72C2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Enviar Cotización',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
