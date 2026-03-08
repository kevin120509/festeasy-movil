import 'dart:io';
import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/provider_inventario_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProductoFormDialog extends StatefulWidget {
  const ProductoFormDialog({super.key, this.producto});

  final ProductoInventarioData? producto;

  @override
  State<ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<ProductoFormDialog> {
  late TextEditingController nombreController;
  late TextEditingController descripcionController;
  late TextEditingController precioController;
  late TextEditingController stockController;

  String selectedCategory = 'General';
  bool isLoading = false;
  XFile? imagenSeleccionada;

  final List<String> categories = [
    'General',
    'Decoración',
    'Catering',
    'Bebidas',
    'Entretenimiento',
    'Sonido',
    'Iluminación',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    nombreController = TextEditingController(
      text: widget.producto?.nombre ?? '',
    );
    descripcionController = TextEditingController(
      text: widget.producto?.descripcion ?? '',
    );
    precioController = TextEditingController(
      text: widget.producto?.precioUnitario.toString() ?? '',
    );
    stockController = TextEditingController(
      text: widget.producto?.stock.toString() ?? '0',
    );
    selectedCategory = widget.producto?.categoria ?? 'General';
  }

  @override
  void dispose() {
    nombreController.dispose();
    descripcionController.dispose();
    precioController.dispose();
    stockController.dispose();
    super.dispose();
  }

  Future<void> _guardarProducto() async {
    if (nombreController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre es requerido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (precioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El precio es requerido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = AuthService.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final precio = double.tryParse(precioController.text) ?? 0;
      final stock = int.tryParse(stockController.text) ?? 0;

      // Subir imagen si existe y es nueva
      String? imagenUrl = widget.producto?.imagenUrl;
      if (imagenSeleccionada != null &&
          !imagenSeleccionada!.path.startsWith('http')) {
        imagenUrl = await ProviderInventarioService.instance.uploadProductImage(
          imageFile: File(imagenSeleccionada!.path),
          proveedorId: user.id,
        );
      }

      if (widget.producto != null) {
        // Actualizar producto existente
        await ProviderInventarioService.instance.updateProducto(
          productoId: widget.producto!.id,
          nombre: nombreController.text,
          descripcion: descripcionController.text.isEmpty
              ? null
              : descripcionController.text,
          categoria: selectedCategory,
          precioUnitario: precio,
          stock: stock,
          imagenUrl: imagenUrl,
        );

        if (mounted) {
          Navigator.pop(context, true); // true indica actualización
        }
      } else {
        // Crear nuevo producto
        await ProviderInventarioService.instance.createProducto(
          proveedorId: user.id,
          nombre: nombreController.text,
          categoria: selectedCategory,
          precioUnitario: precio,
          stock: stock,
          descripcion: descripcionController.text.isEmpty
              ? null
              : descripcionController.text,
          imagenUrl: imagenUrl,
        );

        if (mounted) {
          Navigator.pop(context, true); // true indica nuevo producto creado
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (image != null) {
      setState(() => imagenSeleccionada = image);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.producto != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
      contentPadding: const EdgeInsets.all(24),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Producto',
                hintText: 'Ej: Piñata de Spiderman',
                border: OutlineInputBorder(),
              ),
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: !isLoading
                  ? (value) {
                      if (value != null) {
                        setState(() => selectedCategory = value);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Describe el producto...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: precioController,
              decoration: const InputDecoration(
                labelText: 'Precio Unitario',
                hintText: '0.00',
                prefixText: r'$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(
                labelText: 'Stock Disponible',
                hintText: '0',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: !isLoading,
            ),
            const SizedBox(height: 24),
            // Sección de imagen
            Text(
              'Imagen del Producto',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            // Mostrar imagen seleccionada o actual
            if (imagenSeleccionada != null &&
                !imagenSeleccionada!.path.startsWith('http'))
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(imagenSeleccionada!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => imagenSeleccionada = null),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              )
            else if (widget.producto?.imagenUrl != null)
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.producto!.imagenUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: _seleccionarImagen,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _seleccionarImagen,
                icon: const Icon(Icons.photo_library),
                label: const Text('Seleccionar Imagen'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _guardarProducto,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE01D25),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(isEditing ? 'Actualizar' : 'Crear'),
        ),
      ],
    );
  }
}
