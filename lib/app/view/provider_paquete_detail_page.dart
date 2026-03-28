import 'dart:io';

import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/provider_paquetes_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProviderPaqueteDetailPage extends StatefulWidget {
  const ProviderPaqueteDetailPage({
    required this.paquete,
    super.key,
    this.onPaqueteUpdated,
  });
  final PaqueteProveedorData paquete;
  final VoidCallback? onPaqueteUpdated;

  @override
  State<ProviderPaqueteDetailPage> createState() =>
      _ProviderPaqueteDetailPageState();
}

class _ProviderPaqueteDetailPageState extends State<ProviderPaqueteDetailPage> {
  late PaqueteProveedorData _paquete;

  @override
  void initState() {
    super.initState();
    _paquete = widget.paquete;
  }

  Future<void> _toggleEstado() async {
    try {
      PaqueteProveedorData updated;
      if (_paquete.isPublished) {
        // Desactivar -> Archivar
        updated = await ProviderPaquetesService.instance.archivePaquete(_paquete.id);
      } else {
        // Activar -> Publicar
        updated = await ProviderPaquetesService.instance.publishPaquete(_paquete.id);
      }

      if (mounted) {
        setState(() => _paquete = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _paquete.isPublished ? 'Paquete Activado' : 'Paquete Desactivado',
            ),
            backgroundColor: _paquete.isPublished ? Colors.green : Colors.grey[700],
          ),
        );
        widget.onPaqueteUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar estado: $e'), backgroundColor: const Color(0xFF8D72C2)),
        );
      }
    }
  }

  void _editPaquete() {
    final nombreController = TextEditingController(text: _paquete.nombre);
    final descriptionController = TextEditingController(
      text: _paquete.descripcion,
    );
    final priceController = TextEditingController(
      text: _paquete.precioBase.toString(),
    );
    var tipoCobroSelected = _paquete.tipoCobro;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Paquete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Precio Base'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipoCobroSelected,
                items: const [
                  DropdownMenuItem(value: 'fijo', child: Text('Precio Fijo')),
                  DropdownMenuItem(
                    value: 'por_persona',
                    child: Text('Por Persona'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) tipoCobroSelected = value;
                },
                decoration: const InputDecoration(labelText: 'Tipo de Cobro'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final updated = await ProviderPaquetesService.instance
                    .updatePaquete(
                      paqueteId: _paquete.id,
                      nombre: nombreController.text,
                      descripcion: descriptionController.text,
                      precioBase: double.tryParse(priceController.text),
                      detallesJson: {
                        'tipoCobro': tipoCobroSelected,
                        'fotos': _paquete.fotos,
                        ...?_paquete.detallesJson,
                      },
                    );

                if (mounted) {
                  // Cerrar diálogo primero
                  Navigator.pop(context);

                  // Actualizar estado del paquete para que se vea reflejado
                  setState(() => _paquete = updated);

                  // Mostrar mensaje de éxito
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Paquete actualizado'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Llamar callback después de cerrar el diálogo
                  Future.microtask(() => widget.onPaqueteUpdated?.call());
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Selecciona una foto de la galería
  Future<XFile?> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Sube una foto a Supabase y retorna la URL
  Future<String?> _uploadPhotoToSupabase({required XFile imageFile}) async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return null;

      final fileBytes = await imageFile.readAsBytes();
      final photoUrl = await ProviderPaquetesService.instance.uploadFotoPaquete(
        proveedorUsuarioId: user.id,
        fileBytes: fileBytes,
        fileName: imageFile.name,
      );
      return photoUrl;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  void _editFotos() {
    final fotosActuales = List<String>.from(_paquete.fotos);
    final fotosNuevas = <XFile>[];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Fotos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fotosActuales.isNotEmpty)
                  ...fotosActuales.asMap().entries.map((entry) => Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        height: 100,
                        width: double.infinity,
                        child: Image.network(entry.value, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: const Color(0xFF8D72C2)),
                          onPressed: () => setState(() => fotosActuales.removeAt(entry.key)),
                        ),
                      ),
                    ],
                  )),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final img = await _pickImage();
                    if (img != null) setState(() => fotosNuevas.add(img));
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Agregar Foto'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final urlsNuevas = <String>[];
                  for (final f in fotosNuevas) {
                    final url = await _uploadPhotoToSupabase(imageFile: f);
                    if (url != null) urlsNuevas.add(url);
                  }
                  final todas = [...fotosActuales, ...urlsNuevas];
                  final updated = await ProviderPaquetesService.instance.updateFotosPaquete(
                    paqueteId: _paquete.id,
                    fotos: todas,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    this.setState(() => _paquete = updated);
                    widget.onPaqueteUpdated?.call();
                  }
                } catch (e) {
                  debugPrint('Error: $e');
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePaquete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Paquete'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el paquete "${_paquete.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ProviderPaquetesService.instance.deletePaquete(
                  _paquete.id,
                );

                if (mounted) {
                  // Cerrar el diálogo de confirmación
                  Navigator.pop(context);

                  // Mostrar mensaje de éxito
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Paquete eliminado'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Cerrar la página de detalle y regresar a la lista
                  Navigator.pop(context);

                  // Llamar callback después de navegar
                  Future.microtask(() => widget.onPaqueteUpdated?.call());
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D72C2)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF010302),
        title: const Text(
          'Detalles del Paquete',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF010302),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF8D72C2)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_paquete.fotos.isNotEmpty)
              SizedBox(
                height: 250,
                child: PageView.builder(
                  itemCount: _paquete.fotos.length,
                  itemBuilder: (context, index) {
                    return Image.network(_paquete.fotos[index], fit: BoxFit.cover);
                  },
                ),
              )
            else
              Container(
                height: 200,
                color: const Color(0xFFF4F7F9),
                child: const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NOMBRE Y ESTADO
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0E6FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.inventory_2,
                                  color: Color(0xFF8D72C2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _paquete.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF010302),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _paquete.isPublished
                                    ? Colors.green[50]
                                    : _paquete.isDraft
                                    ? Colors.orange[50]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _paquete.estado,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: _paquete.isPublished
                                      ? Colors.green[700]
                                      : _paquete.isDraft
                                      ? Colors.orange[700]
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 32,
                              child: TextButton.icon(
                                onPressed: _toggleEstado,
                                style: TextButton.styleFrom(
                                  backgroundColor: _paquete.isPublished ? const Color(0xFF8D72C2).withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  foregroundColor: _paquete.isPublished ? const Color(0xFF8D72C2) : Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  _paquete.isPublished ? Icons.pause : Icons.play_arrow,
                                  size: 16,
                                ),
                                label: Text(
                                  _paquete.isPublished ? 'Desactivar' : 'Activar',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DESCRIPCIÓN
                  if (_paquete.descripcion != null &&
                      _paquete.descripcion!.isNotEmpty)
                    Container(
                      width: double.infinity,
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
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F7F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.description_outlined,
                                  size: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Descripción',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF010302),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _paquete.descripcion!,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_paquete.descripcion != null &&
                      _paquete.descripcion!.isNotEmpty)
                    const SizedBox(height: 16),

                  // PRECIO
                  Container(
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.attach_money,
                                      size: 18,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Precio Base',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${_paquete.precioBase.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Tipo de Cobro',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _paquete.esCobroFijo
                                      ? 'Precio Fijo'
                                      : 'Por Persona',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ITEMS
                  if (_paquete.items != null && _paquete.items!.isNotEmpty)
                    Container(
                      width: double.infinity,
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
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0E6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.checklist,
                                  size: 18,
                                  color: Color(0xFF8D72C2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Items Incluidos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF010302),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._paquete.items!.map(
                            (item) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F7F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.green[600],
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${item.nombreItem} (${item.cantidad}${item.unidad != null ? ' ${item.unidad}' : ''})',
                                      style: const TextStyle(
                                        color: Color(0xFF010302),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_paquete.items != null && _paquete.items!.isNotEmpty)
                    const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _editPaquete,
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text(
                                  'Editar Datos',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8D72C2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _editFotos,
                                icon: const Icon(Icons.image, size: 18),
                                label: const Text(
                                  'Fotos',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _deletePaquete,
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text(
                              'Eliminar Paquete',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8D72C2),
                              side: const BorderSide(color: const Color(0xFF8D72C2)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
