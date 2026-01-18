import 'package:flutter/material.dart';
import 'package:festeasy/app/view/provider_detail_page.dart';
import 'package:festeasy/services/provider_database_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ProvidersMapPage extends StatefulWidget {
  final String categoryName;
  final String categoryId;
  final String? serviceAddress;
  final DateTime? serviceDate;
  final TimeOfDay? serviceTime;

  const ProvidersMapPage({
    Key? key,
    required this.categoryName,
    required this.categoryId,
    this.serviceAddress,
    this.serviceDate,
    this.serviceTime,
  }) : super(key: key);

  @override
  State<ProvidersMapPage> createState() => _ProvidersMapPageState();
}

class _ProvidersMapPageState extends State<ProvidersMapPage> {
  int? selectedProviderIndex;
  List<ProviderData> providers = [];
  bool isLoading = true;
  String? errorMessage;
  final MapController _mapController = MapController();
  List<Marker> _markers = [];

  // Posición inicial: Mérida, Yucatán
  static const LatLng _initialPosition = LatLng(20.9674, -89.6243);

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _updateMarkers() {
    final markers = <Marker>[];
    for (int i = 0; i < providers.length; i++) {
      final provider = providers[i];
      if (provider.latitud != null && provider.longitud != null) {
        final isSelected = selectedProviderIndex == i;
        markers.add(
          Marker(
            point: LatLng(provider.latitud!, provider.longitud!),
            width: 120,
            height: 60,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedProviderIndex = i;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE01D25)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      provider.nombreNegocio,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.location_pin,
                    color: isSelected
                        ? const Color(0xFFE01D25)
                        : (provider.isPlus ? Colors.orange : Colors.blue),
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    setState(() {
      _markers = markers;
    });
  }

  Future<void> _loadProviders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Buscar proveedores de la base de datos por nombre de categoría
      final results = await ProviderDatabaseService.instance
          .getProvidersByCategoryName(
            widget.categoryName,
          );

      // NO cargar ratings individualmente - muy lento
      // Los ratings se pueden cargar lazy cuando el usuario ve el detalle

      if (mounted) {
        setState(() {
          providers = results;
          isLoading = false;
        });
        _updateMarkers();

        // Centrar el mapa en el primer proveedor con coordenadas
        if (results.isNotEmpty) {
          final firstWithCoords = results.firstWhere(
            (p) => p.latitud != null && p.longitud != null,
            orElse: () => results.first,
          );
          if (firstWithCoords.latitud != null &&
              firstWithCoords.longitud != null) {
            _mapController.move(
              LatLng(firstWithCoords.latitud!, firstWithCoords.longitud!),
              13,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error al buscar proveedores: $e';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      body: Stack(
        children: [
          // Mapa (placeholder)
          _buildMap(),
          // Header
          _buildHeader(),
          // Lista de proveedores (bottom sheet)
          _buildProvidersBottomSheet(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Botón atrás
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 20,
                  color: Color(0xFF010302),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Título - con ancho limitado para evitar overflow
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFE01D25),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF010302),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Filtros
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.tune, size: 20, color: Color(0xFF010302)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (isLoading) {
      return Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.55,
        color: const Color(0xFFF4F7F9),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
              ),
              SizedBox(height: 16),
              Text(
                'Buscando proveedores...',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.55,
      child: RepaintBoundary(
        child: FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _initialPosition,
            initialZoom: 13,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.festeasy.app',
              maxNativeZoom: 18,
            ),
            MarkerLayer(markers: _markers),
          ],
        ),
      ),
    );
  }

  Widget _buildProvidersBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.40,
      minChildSize: 0.20,
      maxChildSize: 0.80,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Título con categoría filtrada
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isLoading
                                ? 'Buscando...'
                                : errorMessage != null
                                ? 'Error'
                                : '${providers.length} Proveedores',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF010302),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loadProviders,
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFFE01D25),
                            size: 16,
                          ),
                          label: const Text(
                            'Actualizar',
                            style: TextStyle(
                              color: Color(0xFFE01D25),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Mostrar categoría filtrada
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5E7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.filter_alt,
                            size: 14,
                            color: Color(0xFFE01D25),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Categoría: ${widget.categoryName}',
                              style: const TextStyle(
                                color: Color(0xFFE01D25),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Lista de proveedores o mensaje de error
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFE01D25),
                          ),
                        ),
                      )
                    : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProviders,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE01D25),
                              ),
                              child: const Text(
                                'Reintentar',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                    : providers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE5E7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 48,
                                  color: Color(0xFFE01D25),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No hay proveedores de ${widget.categoryName}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF010302),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Aún no tenemos proveedores registrados en esta categoría de servicio.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Elegir otra categoría'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFE01D25),
                                  side: const BorderSide(
                                    color: Color(0xFFE01D25),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: providers.length,
                        cacheExtent: 500,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (context, index) {
                          final provider = providers[index];
                          final isSelected = selectedProviderIndex == index;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: RepaintBoundary(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  // Cerrar el teclado si está abierto
                                  FocusScope.of(context).unfocus();
                                  setState(() {
                                    selectedProviderIndex = index;
                                  });
                                  // Navegar a detalle del proveedor
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (context) => ProviderDetailPage(
                                        providerId: provider.id,
                                        perfilId: provider.perfilId,
                                        usuarioId: provider.usuarioId,
                                        providerName: provider.nombreNegocio,
                                        category: provider.categoria.isNotEmpty
                                            ? provider.categoria
                                            : widget.categoryName,
                                        rating: provider.rating ?? 0.0,
                                        reviews: provider.reviewCount ?? 0,
                                        address: provider.direccion,
                                        phone: provider.telefono,
                                        thumbnail: provider.avatarUrl,
                                        descripcion: provider.descripcion,
                                        serviceAddress: widget.serviceAddress,
                                        serviceDate: widget.serviceDate,
                                        serviceTime: widget.serviceTime,
                                      ),
                                    ),
                                  );
                                },
                                child: _buildProviderCard(provider, isSelected),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderCard(ProviderData provider, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFE5E7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFFE01D25) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Imagen
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 70,
              height: 70,
              color: const Color(0xFFF4F7F9),
              child:
                  provider.avatarUrl != null && provider.avatarUrl!.isNotEmpty
                  ? Image.network(
                      provider.avatarUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: 140,
                      cacheHeight: 140,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: Icon(
                            Icons.storefront,
                            size: 32,
                            color: Colors.grey,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront,
                        size: 32,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(Icons.storefront, size: 32, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.nombreNegocio,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF010302),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.isPlus)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE01D25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Plus',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  provider.direccion ?? provider.categoria,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      provider.rating != null
                          ? provider.rating!.toStringAsFixed(1)
                          : '0.0',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      ' (${provider.reviewCount ?? 0})',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    if (provider.paquetes.isNotEmpty) ...[
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.paquetes.length} paquetes',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}
