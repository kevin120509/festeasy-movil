import 'package:festeasy/app/view/package_detail_page_client.dart';
import 'package:festeasy/services/provider_paquetes_service.dart';
import 'package:festeasy/services/provider_search_service.dart';
import 'package:flutter/material.dart';

class ProviderDetailPageClient extends StatefulWidget {

  const ProviderDetailPageClient({
    required this.provider, super.key,
  });
  final ProviderSearchResult provider;

  @override
  State<ProviderDetailPageClient> createState() =>
      _ProviderDetailPageClientState();
}

class _ProviderDetailPageClientState extends State<ProviderDetailPageClient> {
  late Future<List<PaqueteProveedorData>> _paquetesFuture;

  @override
  void initState() {
    super.initState();
    _loadPaquetes();
  }

  void _loadPaquetes() {
    _paquetesFuture =
        ProviderPaquetesService.instance.getPaquetesByProveedor(
      widget.provider.usuarioId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Proveedor', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE01D25),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con info del proveedor
            _buildProviderHeader(),
            const SizedBox(height: 16),
            // Paquetes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Paquetes Disponibles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            _buildPaquetesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderHeader() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar y nombre
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar grande
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[300],
                ),
                child: widget.provider.avatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.provider.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.store, size: 48),
                            );
                          },
                        ),
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.store, size: 48),
                      ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.provider.nombreNegocio,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Rating
                    if (widget.provider.calificacionPromedio != null)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.provider.calificacionPromedio!.toStringAsFixed(1)} (${widget.provider.totalResenas} reseñas)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    // Distancia
                    if (widget.provider.distanciaKm != null)
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Color(0xFFE01D25)),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.provider.distanciaKm!.toStringAsFixed(1)} km de distancia',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFE01D25)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Descripción
          if (widget.provider.descripcion != null) ...[
            Text(
              'Descripción',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              widget.provider.descripcion!,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
          ],
          // Ubicación
          if (widget.provider.direccionFormato != null) ...[
            Text(
              'Ubicación',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Color(0xFFE01D25)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.provider.direccionFormato!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaquetesList() {
    return FutureBuilder<List<PaqueteProveedorData>>(
      future: _paquetesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final paquetes = snapshot.data ?? [];

        if (paquetes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.shopping_bag, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No hay paquetes disponibles',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: paquetes.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final paquete = paquetes[index];
            return _buildPaqueteCard(context, paquete);
          },
        );
      },
    );
  }

  Widget _buildPaqueteCard(BuildContext context, PaqueteProveedorData paquete) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _navigateToPackageDetail(paquete),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del paquete
            if (paquete.fotos.isNotEmpty)
              Container(
                width: double.infinity,
                height: 160,
                color: Colors.grey[300],
                child: Image.network(
                  paquete.fotos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.shopping_bag, size: 48),
                    );
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 160,
                color: Colors.grey[300],
                child: const Icon(Icons.shopping_bag, size: 48),
              ),
            // Contenido
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre
                  Text(
                    paquete.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Descripción
                  if (paquete.descripcion != null)
                    Text(
                      paquete.descripcion!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  // Precio y botón
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${paquete.precioBase.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE01D25),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToPackageDetail(paquete),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('Ver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE01D25),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPackageDetail(PaqueteProveedorData paquete) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PackageDetailPageClient(
          paquete: paquete,
          provider: widget.provider,
        ),
      ),
    );
  }
}
