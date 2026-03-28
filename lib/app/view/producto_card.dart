import 'package:festeasy/services/provider_inventario_service.dart';
import 'package:flutter/material.dart';

class ProductoCard extends StatelessWidget {
  const ProductoCard({
    required this.producto,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleDestacado,
    super.key,
  });

  final ProductoInventarioData producto;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggleDestacado;

  String _getEstadoStockLabel() {
    final estado = producto.getEstadoStock();
    switch (estado) {
      case EstadoStock.sinStock:
        return 'SIN STOCK';
      case EstadoStock.stockBajo:
        return 'STOCK BAJO';
      case EstadoStock.stockAlto:
        return 'STOCK ALTO';
    }
  }

  Color _getEstadoStockColor() {
    final estado = producto.getEstadoStock();
    switch (estado) {
      case EstadoStock.sinStock:
        return const Color(0xFF8D72C2);
      case EstadoStock.stockBajo:
        return Colors.orange;
      case EstadoStock.stockAlto:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contenido
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoría y Badge de Stock
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      producto.categoria.toUpperCase(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getEstadoStockColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getEstadoStockLabel(),
                        style: TextStyle(
                          color: _getEstadoStockColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nombre y Destacado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF010302),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (producto.destacado)
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                // Descripción
                if (producto.descripcion != null &&
                    producto.descripcion!.isNotEmpty)
                  Text(
                    producto.descripcion!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                // Precio y Stock
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRECIO',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${producto.precioUnitario.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF010302),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'STOCK',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          producto.stock.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF00A878),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Botones de acción
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text(
                            'Editar',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: onEdit,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 48,
                        child: OutlinedButton(
                          onPressed: onDelete,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: const Color(0xFF8D72C2),
                            side: const BorderSide(color: const Color(0xFF8D72C2)),
                          ),
                          child: const Icon(Icons.delete, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
