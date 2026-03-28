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
    if (!categories.contains(selectedCategory)) {
      categories.add(selectedCategory);
    }
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
          backgroundColor: const Color(0xFF8D72C2),
        ),
      );
      return;
    }

    if (precioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El precio es requerido'),
          backgroundColor: const Color(0xFF8D72C2),
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
        );

        if (mounted) {
          Navigator.pop(context, true); // true indica nuevo producto creado
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFF8D72C2)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
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
            backgroundColor: const Color(0xFF8D72C2),
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
