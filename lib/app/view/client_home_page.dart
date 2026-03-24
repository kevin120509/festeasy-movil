import 'dart:async';

import 'package:festeasy/app/view/cart_list_page.dart';
import 'package:festeasy/app/view/mis_eventos_page.dart';
import 'package:festeasy/app/view/profile_page.dart';
import 'package:festeasy/app/view/chat_list_page.dart';
import 'package:festeasy/app/view/client_notifications_page.dart';
import 'package:festeasy/app/view/provider_detail_page.dart';
import 'package:festeasy/app/view/request_status_page.dart';
import 'package:festeasy/app/view/service_requirement_page.dart';
import 'package:festeasy/services/client_perfil_service.dart';
import 'package:festeasy/services/favorite_service.dart';
import 'package:festeasy/services/provider_database_service.dart';
import 'package:festeasy/services/solicitud_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:festeasy/service_session_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key, this.userName = 'Usuario'});
  final String userName;

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  int _currentIndex = 0;
  final GlobalKey<CartListPageState> _cartKey = GlobalKey<CartListPageState>();
  int cartCount = 0;
  SolicitudData? _activeSolicitud;
  List<SolicitudData> _cancelledSolicitudes = [];
  Timer? _ticker;
  RealtimeChannel? _solicitudesChannel;

  // Ubicación "fake" del usuario (Mérida Centro) para cálculo de distancias
  // En una app real, esto vendría del GPS
  static const LatLng _userLocation = LatLng(20.9674, -89.6243);

  List<ProviderData> _nearbyProviders = [];
  bool _isLoadingProviders = true;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _startTicker();
    _loadActiveSolicitud();
    _loadCancelledSolicitudes();
    _loadNearbyProviders();
    _loadCartCount();
    _subscribeSolicitudesRealtime();
    // Sincronizar carrito local con DB al iniciar
    ServiceSessionData.getInstance().syncWithDatabase().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final perfil = await ClientPerfilService.instance.getPerfil(user.id);
        if (mounted) {
          setState(() {
            _avatarUrl = perfil?.avatarUrl;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCartCount() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      // Obtener carrito activo
      final cartResult = await client
          .from('carrito')
          .select('id')
          .eq('cliente_usuario_id', user.id)
          .eq('estado', 'activo')
          .maybeSingle();

      if (cartResult == null) {
        if (mounted) setState(() => cartCount = 0);
        return;
      }

      // Contar items del carrito
      final itemsResult = await client
          .from('items_carrito')
          .select('cantidad')
          .eq('carrito_id', cartResult['id'] as String);

      var total = 0;
      for (final item in (itemsResult as List)) {
        total += item['cantidad'] as int? ?? 1;
      }

      if (mounted) setState(() => cartCount = total);
    } catch (e) {
      debugPrint('Error cargando cart count: $e');
    }
  }

  void _navigateToMisEventos() {
    setState(() => _currentIndex = 1);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _solicitudesChannel?.unsubscribe();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadActiveSolicitud() async {
    try {
      final solicitud = await SolicitudService.instance
          .getActiveSolicitudForCurrentUser();
      if (!mounted) return;
      setState(() {
        _activeSolicitud = solicitud;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeSolicitud = null;
      });
    }
  }

  Future<void> _loadCancelledSolicitudes() async {
    try {
      final cancelled = await SolicitudService.instance
          .getCancelledSolicitudes();
      if (!mounted) return;
      setState(() {
        _cancelledSolicitudes = cancelled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cancelledSolicitudes = [];
      });
    }
  }

  Future<void> _loadNearbyProviders() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProviders = true;
    });

    try {
      // 1. Obtener lista de favoritos
      final favorites = await FavoriteService.instance.getFavorites();

      if (favorites.isEmpty) {
        if (!mounted) return;
        setState(() {
          _nearbyProviders = [];
          _isLoadingProviders = false;
        });
        return;
      }

      // 2. Cargamos los proveedores favoritos directamente por sus IDs
      // Esto asegura que traigamos todos los favoritos sin importar su categoría
      final providers = await ProviderDatabaseService.instance
          .getProvidersByIds(favorites);

      final validProviders = <ProviderData>[];

      for (final provider in providers) {
        if (provider.latitud != null && provider.longitud != null) {
          final distance = const Distance().as(
            LengthUnit.Kilometer,
            _userLocation,
            LatLng(provider.latitud!, provider.longitud!),
          );

          // Filtramos si está dentro del radio de cobertura
          if (distance <= provider.radioCoberturaKm) {
            validProviders.add(provider);
          }
        } else {
          // Si es favorito pero no tiene ubicación, lo agregamos de todas formas
          // para asegurar que el usuario pueda verlo.
          validProviders.add(provider);
        }
      }

      if (!mounted) return;
      setState(() {
        _nearbyProviders = validProviders;
        _isLoadingProviders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProviders = false;
      });
    }
  }

  void _subscribeSolicitudesRealtime() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    _solicitudesChannel = client
        .channel('solicitudes:cliente:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'solicitudes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'cliente_usuario_id',
            value: user.id,
          ),
          callback: (_) {
            _loadActiveSolicitud();
            _loadCancelledSolicitudes();
          },
        )
        .subscribe();
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar aplicación'),
        content: const Text('¿Estás seguro de que quieres salir de FestEasy?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE01D25),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FFFF),
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeBody(),
              const MisEventosPage(),
              CartListPage(
                key: _cartKey,
                onSolicitudesEnviadas: () {
                  _loadCartCount();
                  _navigateToMisEventos();
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildHomeBody() {
    return RefreshIndicator(
      color: const Color(0xFFE01D25),
      onRefresh: () async {
        _loadActiveSolicitud();
        _loadCancelledSolicitudes();
        _loadNearbyProviders();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 24),
            _buildCategoriesSection(),
            if (_activeSolicitud != null) ...[
              const SizedBox(height: 24),
              _buildActiveRequest(_activeSolicitud!),
            ],
            if (_cancelledSolicitudes.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildCancelledRequestsSection(),
            ],
            const SizedBox(height: 24),
            _buildProvidersSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido, \n ${widget.userName} 👋',
                  style: const TextStyle(
                    color: Color(0xFF010302),
                    fontWeight: FontWeight.w600,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFFE01D25),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChatListPage(isProvider: false),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Color(0xFFE01D25)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ClientNotificationsPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfilePage(),
                    ),
                  )
                  .then((_) {
                    // Refresh active requests logic if needed, but not strictly required
                    if (mounted) {
                      _loadProfile();
                      setState(() {});
                    }
                  });
            },
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFFE5E7),
              backgroundImage: _avatarUrl != null
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: _avatarUrl == null
                  ? const Icon(Icons.person, color: Color(0xFFE01D25), size: 28)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    // Categorías con sus UUIDs de la BD (base.sql)
    // Estos deben coincidir con los IDs en la tabla categorias_servicio
    final categories = [
      {
        'name': 'Música y Sonido',
        'icon': Icons.music_note_outlined,
        'id': null, // Se cargarán dinámicamente
      },
      {'name': 'Decoración', 'icon': Icons.celebration_outlined, 'id': null},
      {'name': 'Catering', 'icon': Icons.restaurant_outlined, 'id': null},
      {
        'name': 'Fotografía y Video',
        'icon': Icons.camera_alt_outlined,
        'id': null,
      },
      {
        'name': 'Alquiler de Mobiliario',
        'icon': Icons.chair_outlined,
        'id': null,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categorías de Servicios',
            style: TextStyle(
              color: Color(0xFF010302),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return GestureDetector(
                onTap: () {
                  // Usar el nombre de la categoría como identificador
                  // En una implementación real, buscarías el UUID en la BD
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => ServiceRequirementPage(
                        categoryId: cat['name']! as String,
                        categoryName: cat['name']! as String,
                        categoryIcon: cat['icon']! as IconData,
                      ),
                    ),
                  ).then((_) {
                    _loadCartCount();
                    if (_currentIndex == 2) {
                      _cartKey.currentState?.loadCart();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cat['icon']! as IconData,
                        color: const Color(0xFFE01D25),
                        size: 32,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat['name']! as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequest(SolicitudData solicitud) {
    final nowUtc = DateTime.now().toUtc();
    var remaining = Duration.zero;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) =>
                  RequestStatusPage(solicitudId: solicitud.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE01D25), Color(0xFFFF5F6D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE01D25).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icono de reloj animado
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Esperando respuesta',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      solicitud.tituloEvento ?? 'Solicitud pendiente',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Contador
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '$hours:$minutes:$seconds',
                      style: const TextStyle(
                        color: Color(0xFFE01D25),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text(
                      'restante',
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelledRequestsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Solicitudes Canceladas',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF010302),
            ),
          ),
          const SizedBox(height: 12),
          ..._cancelledSolicitudes.map(_buildCancelledRequestCard),
        ],
      ),
    );
  }

  Widget _buildCancelledRequestCard(SolicitudData solicitud) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  solicitud.tituloEvento ?? 'Solicitud cancelada',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Cancelada • \$${solicitud.montoTotal.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RequestStatusPage(solicitudId: solicitud.id),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility, color: Colors.grey),
                tooltip: 'Ver detalles',
              ),
              IconButton(
                onPressed: () => _deleteCancelledSolicitud(solicitud.id),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCancelledSolicitud(String solicitudId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar solicitud'),
        content: const Text('¿Eliminar esta solicitud cancelada?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SolicitudService.instance.deleteSolicitud(solicitudId);
      _loadCancelledSolicitudes();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Solicitud eliminada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildProvidersSection() {
    if (_isLoadingProviders) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
          ),
        ),
      );
    }

    if (_nearbyProviders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Tus Favoritos Cerca',
            style: TextStyle(
              color: Color(0xFF010302),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _nearbyProviders.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final provider = _nearbyProviders[index];

              // Cálculo de distancia para mostrar
              var distanceText = 'Desconocida';
              if (provider.latitud != null && provider.longitud != null) {
                final distance = const Distance().as(
                  LengthUnit.Kilometer,
                  _userLocation,
                  LatLng(provider.latitud!, provider.longitud!),
                );
                distanceText = '${distance.toStringAsFixed(1)} km';
              }

              return GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (context) => ProviderDetailPage(
                            providerId: provider.id,
                            perfilId: provider.perfilId,
                            usuarioId: provider.usuarioId,
                            providerName: provider.nombreNegocio,
                            category: provider.categoria,
                            rating: provider.rating ?? 0.0,
                            reviews: provider.reviewCount ?? 0,
                            address: provider.direccion,
                            phone: provider.telefono,
                            thumbnail: provider.avatarUrl,
                            descripcion: provider.descripcion,
                          ),
                        ),
                      ).then((_) {
                        _loadNearbyProviders();
                        _loadCartCount();
                        if (_currentIndex == 2) {
                          _cartKey.currentState?.loadCart();
                        }
                      });
                },
                child: Container(
                  width: 160,
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
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: Container(
                              height: 70,
                              width: double.infinity,
                              color: const Color(0xFFF4F7F9),
                              child: provider.avatarUrl != null
                                  ? Image.network(
                                      provider.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.storefront,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.storefront,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.nombreNegocio,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${provider.rating ?? 0.0}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        distanceText,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFFE01D25),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FFFF),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFFF8FFFF),
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE01D25),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Si cambia a la pestaña de carrito, refrescar datos
          if (index == 2) {
            _cartKey.currentState?.loadCart();
            _loadCartCount();
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Mis eventos',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart),
                if (cartCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE01D25),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Indicador de solicitud pendiente
                if (_activeSolicitud != null)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF8FFFF),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Carrito',
          ),
        ],
      ),
    );
  }
}
