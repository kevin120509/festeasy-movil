import 'package:flutter/material.dart';
import 'package:festeasy/app/view/providers_map_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async'; // Para TimeoutException

/// Modelo para los datos del requerimiento de servicio.
/// Estos datos se enviarán a la base de datos al buscar proveedores.
class ServiceRequirementData {
  final String categoryId;
  final String categoryName;
  final IconData categoryIcon;
  String description;
  DateTime? date;
  TimeOfDay? time;
  String? address;
  double? latitude;
  double? longitude;

  ServiceRequirementData({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    this.description = '',
    this.date,
    this.time,
    this.address,
    this.latitude,
    this.longitude,
  });
}

class ServiceRequirementPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final IconData categoryIcon;

  const ServiceRequirementPage({
    Key? key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
  }) : super(key: key);

  @override
  State<ServiceRequirementPage> createState() => _ServiceRequirementPageState();
}

class _ServiceRequirementPageState extends State<ServiceRequirementPage> {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  double selectedLatitude = 20.9674; // Mérida, Yucatán por defecto
  double selectedLongitude = -89.6243;
  late final MapController _mapController;
  bool _isMapReady = false;

  bool get isFormValid =>
      addressController.text.isNotEmpty &&
      selectedDate != null &&
      selectedTime != null;

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } on MissingPluginException catch (e) {
      debugPrint('MissingPluginException: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Servicio de ubicación no disponible. Reinicia la app (full restart) y verifica la instalación del plugin.',
            ),
          ),
        );
      }
      return;
    } catch (e) {
      debugPrint('Error comprobando servicio de ubicación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error comprobando servicio de ubicación: $e'),
          ),
        );
      }
      return;
    }
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Los servicios de ubicación están desactivados.'),
          ),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de ubicación denegados.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Los permisos de ubicación están denegados permanentemente.',
            ),
          ),
        );
      }
      return;
    }

    // Feedback inmediato
    debugPrint('Intentando obtener ubicación actual...');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obteniendo ubicación...')),
      );
    }

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: const Color(0xFFE01D25)),
      ),
    );

    try {
      // Usar LocationSettings para mayor precisión y compatibilidad
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );

      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          ).timeout(
            const Duration(seconds: 10),
          ); // Timeout de 10s para evitar hangs

      if (!mounted) {
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        selectedLatitude = position.latitude;
        selectedLongitude = position.longitude;
        // Mostrar coords inmediatamente como feedback
        addressController.text =
            '${selectedLatitude.toStringAsFixed(6)}, ${selectedLongitude.toStringAsFixed(6)}';
      });

      // Intentar mover el mapa tan pronto esté listo (reintentos)
      _moveMapWhenReady(LatLng(selectedLatitude, selectedLongitude));

      // Obtener dirección (Geocoding inverso)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          selectedLatitude,
          selectedLongitude,
        );

        if (!mounted) {
          Navigator.of(context).pop();
          return;
        }

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Construir dirección legible mejorada
          List<String> addressParts = [];
          if (place.street?.isNotEmpty ?? false)
            addressParts.add(place.street!);
          if (place.subLocality?.isNotEmpty ?? false)
            addressParts.add(place.subLocality!);
          if (place.locality?.isNotEmpty ?? false)
            addressParts.add(place.locality!);
          if (place.administrativeArea?.isNotEmpty ?? false)
            addressParts.add(place.administrativeArea!);
          if (place.country?.isNotEmpty ?? false)
            addressParts.add(place.country!);

          String address = addressParts.join(', ');

          setState(() {
            addressController.text = address;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ubicación actual establecida')),
            );
          }
        } else {
          // Si no hay placemarks, usaremos las coordenadas como fallback
          final coords =
              '${selectedLatitude.toStringAsFixed(6)}, ${selectedLongitude.toStringAsFixed(6)}';
          setState(() {
            addressController.text = coords;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ubicación establecida: $coords')),
            );
          }
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
        // Fallback a coordenadas si falla el geocoding
        final coords =
            '${selectedLatitude.toStringAsFixed(6)}, ${selectedLongitude.toStringAsFixed(6)}';
        setState(() {
          addressController.text = coords;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ubicación establecida: $coords')),
          );
        }
      }

      // Si ocurre un error al obtener la ubicación o dirección, mostrar mensaje y cerrar loading
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Cerrar loading si sigue abierto
      }
    } on TimeoutException catch (_) {
      // Timeout específico
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se agotó el tiempo de espera para obtener la ubicación.',
            ),
          ),
        );
      }
      return;
    } catch (e) {
      // Error general
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener la ubicación: $e')),
        );
      }
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    // Solo actualizar coordenadas, no llamar setState para evitar rebuild
    if (hasGesture) {
      selectedLatitude = camera.center.latitude;
      selectedLongitude = camera.center.longitude;
    }
  }

  void _onMapReady() {
    _isMapReady = true;
  }

  void _moveMapWhenReady(LatLng target, {int attempts = 0}) {
    if (_isMapReady) {
      try {
        _mapController.move(target, 16);
      } catch (e) {
        debugPrint('Error moviendo mapa: $e');
      }
      return;
    }
    if (attempts >= 10) {
      debugPrint('No se pudo mover el mapa: no está listo (intentos agotados)');
      return;
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _moveMapWhenReady(target, attempts: attempts + 1);
    });
  }

  @override
  void dispose() {
    descriptionController.dispose();
    addressController.dispose();
    if (_isMapReady) {
      _mapController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF010302)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Detalles del Servicio',
          style: TextStyle(
            color: Color(0xFF010302),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: 0.33,
            backgroundColor: const Color(0xFFF4F7F9),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
            minHeight: 5,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen de Categoría
              _buildCategorySummary(),
              const SizedBox(height: 24),
              // Detalles del Requerimiento
              _buildDescriptionField(),
              const SizedBox(height: 24),
              // Fecha y Hora
              _buildDateTimeRow(),
              const SizedBox(height: 24),
              // Ubicación Exacta
              _buildLocationSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomButton(),
    );
  }

  Widget _buildCategorySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5E7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(widget.categoryIcon, color: const Color(0xFFE01D25), size: 36),
          const SizedBox(width: 14),
          Text(
            widget.categoryName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF010302),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué necesitas exactamente?',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF4F7F9),
            hintText:
                'Ej: Necesito 50 sillas plegables blancas y 5 mesas redondas para 10 personas...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFFE01D25)),
                  const SizedBox(width: 10),
                  Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Fecha',
                    style: TextStyle(
                      color: selectedDate != null ? Colors.black : Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFFE01D25)),
                  const SizedBox(width: 10),
                  Text(
                    selectedTime != null
                        ? selectedTime!.format(context)
                        : 'Hora',
                    style: TextStyle(
                      color: selectedTime != null ? Colors.black : Colors.grey,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ubicación Exacta',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            TextButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.my_location, size: 16),
              label: const Text('Usar mi ubicación actual'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE01D25),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: addressController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF4F7F9),
            hintText: 'Buscar dirección...',
            prefixIcon: const Icon(Icons.location_on, color: Color(0xFFE01D25)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Mapa de OpenStreetMap
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE01D25).withOpacity(0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              RepaintBoundary(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(selectedLatitude, selectedLongitude),
                    initialZoom: 15,
                    onPositionChanged: _onPositionChanged,
                    onMapReady: _onMapReady,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.festeasy.app',
                      maxNativeZoom: 18,
                      tileBuilder: (context, tileWidget, tile) => tileWidget,
                    ),
                  ],
                ),
              ),
              // Pin central fijo
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(
                    Icons.location_pin,
                    color: Color(0xFFE01D25),
                    size: 48,
                  ),
                ),
              ),
              // Botón de ubicación actual
              Positioned(
                right: 10,
                bottom: 10,
                child: FloatingActionButton.small(
                  backgroundColor: Colors.white,
                  heroTag: 'locationBtn',
                  onPressed: () {
                    if (_isMapReady) {
                      _mapController.move(
                        LatLng(selectedLatitude, selectedLongitude),
                        15,
                      );
                    }
                  },
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFFE01D25),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mueve el mapa para marcar el punto exacto de entrega',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE01D25),
            disabledBackgroundColor: const Color(0xFFE01D25).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: isFormValid ? _onSearchProviders : null,
          child: const Text(
            'Buscar Proveedores Disponibles',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE01D25),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE01D25),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void _onSearchProviders() {
    // Construir el objeto de datos para enviar a la base de datos
    // Esto puede incluir insertar en la tabla "carrito" o crear una "solicitud"
    // Ejemplo de datos a enviar:
    // - cliente_usuario_id: ID del usuario logueado
    // - fecha_servicio_deseada: selectedDate
    // - direccion_servicio: addressController.text
    // - latitud_servicio: selectedLatitude
    // - longitud_servicio: selectedLongitude
    // - descripcion: descriptionController.text
    // - categoria_servicio_id: widget.categoryId

    // Aquí iría la lógica para enviar a la base de datos (Supabase, API, etc.)
    // Por ahora, mostramos una animación de "Matching"
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE01D25)),
            ),
            SizedBox(height: 20),
            Text(
              'Buscando proveedores cercanos...',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    // Simular espera y cerrar diálogo
    Future<void>.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Cerrar diálogo
      // Navegar a la pantalla de mapa con proveedores
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ProvidersMapPage(
            categoryName: widget.categoryName,
            categoryId: widget.categoryId,
            serviceAddress: addressController.text,
            serviceDate: selectedDate,
            serviceTime: selectedTime,
          ),
        ),
      );
    });
  }
}
