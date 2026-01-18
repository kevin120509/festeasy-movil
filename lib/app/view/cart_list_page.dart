import 'package:festeasy/app/view/request_status_page.dart';
import 'package:festeasy/services/cart_service.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:flutter/material.dart';

class CartListPage extends StatefulWidget {
  const CartListPage({super.key});

  @override
  State<CartListPage> createState() => _CartListPageState();
}

class _CartListPageState extends State<CartListPage> {
  List<CartData> _carts = [];
  SolicitudData? _activeSolicitud;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final activeSolicitud = await SolicitudService.instance
          .getActiveSolicitudForCurrentUser();
      final carts = await CartService.instance.getActiveCarts();
      if (mounted) {
        setState(() {
          _activeSolicitud = activeSolicitud;
          _carts = carts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        title: Text(
          _activeSolicitud != null ? 'Solicitud en espera' : 'Mis Carritos',
          style: const TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
              ),
            )
          : _activeSolicitud != null
          ? _buildActiveSolicitudView()
          : _carts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.remove_shopping_cart,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No tienes carritos pendientes',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _carts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cart = _carts[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFE5E7),
                      child: Icon(
                        Icons.shopping_cart,
                        color: Color(0xFFE01D25),
                      ),
                    ),
                    title: Text(
                      cart.direccionServicio ?? 'Carrito sin dirección',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Actualizado: ${cart.actualizadoEn.toLocal().toString().split('.')[0]}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // TODO: Navegar al detalle del carrito
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Detalle de carrito próximamente'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildActiveSolicitudView() {
    final solicitud = _activeSolicitud!;
    final nowUtc = DateTime.now().toUtc();
    Duration remaining = Duration.zero;

    if (solicitud.estado == 'pendiente_aprobacion') {
      final deadline = solicitud.creadoEn.add(const Duration(hours: 24));
      remaining = deadline.difference(nowUtc);
    } else if (solicitud.estado == 'esperando_anticipo' &&
        solicitud.expiracionAnticipo != null) {
      remaining = solicitud.expiracionAnticipo!.difference(nowUtc);
    }

    final safe = remaining.isNegative ? Duration.zero : remaining;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE01D25).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: Color(0xFFE01D25),
                size: 50,
              ),
            ),
            const SizedBox(height: 30),
            // Contador grande
            Text(
              '$hours:$minutes:$seconds',
              style: const TextStyle(
                color: Color(0xFFE01D25),
                fontWeight: FontWeight.w900,
                fontSize: 56,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tiempo restante',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 30),
            const Text(
              'Esperando respuesta del proveedor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF010302),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              solicitud.tituloEvento ?? 'Tu solicitud',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Botón ver detalles
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE01D25),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RequestStatusPage(
                        solicitudId: solicitud.id,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Ver detalles',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
