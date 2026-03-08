# 📦 Guía de Configuración - Módulo de Inventario

## Descripción General
Se ha creado un nuevo módulo de **Inventario** para que los proveedores puedan gestionar sus productos de forma completa y eficiente. Este módulo incluye funcionalidades para crear, editar, eliminar y destacar productos, además de un sistema de filtrado inteligente por estado de stock.

## Características Principales

### 1. **Gestión Completa de Productos (CRUD)**
- **Crear**: Los proveedores pueden agregar nuevos productos con nombre, categoría, descripción, precio y stock
- **Leer**: Visualizar todos los productos en un formato de grid/tarjetas
- **Actualizar**: Editar la información de productos existentes
- **Eliminar**: Remover productos del inventario con confirmación

### 2. **Sistema de Filtros de Stock**
El inventario cuenta con 3 filtros de stock accesibles como botones en la parte superior:
- **Todos**: Muestra la lista completa de productos sin filtrar
- **Stock Bajo**: Solo muestra productos con entre 1-4 unidades disponibles
- **Sin Stock**: Muestra exclusivamente productos con 0 unidades

### 3. **Badges de Estado de Stock**
Cada tarjeta de producto muestra un badge visual en la esquina superior izquierda:
- 🔴 **SIN STOCK** (Rojo): Cuando hay 0 unidades
- 🟠 **STOCK BAJO** (Naranja): Cuando hay menos de 5 unidades
- 🟢 **STOCK ALTO** (Verde): Cuando hay 5 o más unidades

### 4. **Funcionalidad de Destaque (VIP)**
- Los proveedores pueden marcar productos como destacados mediante un botón de estrella
- Los productos destacados muestran una insignia dorada/amarilla con una estrella
- El estado se actualiza instantáneamente sin recargar la página
- Útil para promocionar productos populares

### 5. **Tarjetas de Producto (Componentes)**
Cada tarjeta muestra:
- Imagen del producto (o icono por defecto)
- Badges de stock y destacado
- Categoría (texto pequeño superior)
- Nombre del producto
- Descripción (si existe)
- Precio unitario (formateado en $)
- Stock disponible
- 3 botones de acción:
  - **Editar**: Abre un modal para actualizar el producto
  - **Eliminar**: Borra el producto tras confirmación
  - **Destacar**: Alterna el estado VIP del producto

### 6. **Formulario de Crear/Editar**
Modal intuitivo con campos para:
- Nombre del producto (requerido)
- Categoría (dropdown con opciones predefinidas)
- Descripción (opcional, multilinea)
- Precio unitario (requerido, formato decimal)
- Stock disponible (número entero)

### 7. **Categorías Predefinidas**
- General
- Decoración
- Catering
- Bebidas
- Entretenimiento
- Sonido
- Iluminación
- Otros

## Requisitos Previos

### 1. **Configurar la Tabla en Supabase**
Debes ejecutar el script SQL que se encuenta en el archivo `SETUP_INVENTARIO_TABLA.sql`:

1. Ir a [Supabase Console](https://app.supabase.com)
2. Seleccionar tu proyecto
3. Ir a **SQL Editor**
4. Crear una nueva query
5. Copiar el contenido completo del archivo `SETUP_INVENTARIO_TABLA.sql`
6. Ejecutar la query

Esto creará:
- Tabla `inventario_productos`
- Índices para optimizar consultas
- Políticas de Row Level Security (RLS)
- Trigger automático para actualizar `actualizado_en`

### 2. **Archivos Creados**

#### Servicios
- **`lib/services/provider_inventario_service.dart`**
  - Singleton service para gestionar productos
  - Métodos: getProductos(), createProducto(), updateProducto(), deleteProducto(), toggleDestacado()
  - Modelos: `ProductoInventarioData`, `EstadoStock`, `FiltroInventario`

#### Componentes UI
- **`lib/app/view/producto_card.dart`**
  - Widget que renderiza la tarjeta de cada producto
  - Muestra imagen, badges, información y botones de acción

- **`lib/app/view/producto_form_dialog.dart`**
  - Widget de formulario modal para crear/editar productos
  - Validaciones de campos obligatorios
  - Indica si estás creando o editando

#### Página Principal
- **`lib/app/view/provider_home_page.dart`** (ACTUALIZADO)
  - Nuevo tab de Inventario en el BottomNavigationBar
  - Método `_buildInventarioTab()` con toda la lógica
  - Métodos de carga: `_loadProductos()`
  - Método de filtrado: `_buildFiltroButton()`

## Flujo de Uso

### Para Crear un Producto
1. Ir al tab "Inventario"
2. Hacer clic en el botón **"+ Nuevo"** o **"Crear Producto"**
3. Completar el formulario
4. Hacer clic en **"Crear"**
5. El producto aparecerá en la lista

### Para Editar un Producto
1. Encontrar el producto en la lista
2. Hacer clic en el botón **"Editar"**
3. Modificar los datos en el formulario
4. Hacer clic en **"Actualizar"**
5. La tarjeta se actualizará automáticamente

### Para Eliminar un Producto
1. Encontrar el producto en la lista
2. Hacer clic en el botón **"🗑️"** (delete)
3. Confirmar la eliminación
4. El producto se removará de la lista

### Para Destacar un Producto
1. Encontrar el producto en la lista
2. Hacer clic en la estrella en la esquina inferior derecha de la imagen
3. La estrella se llenará/vaciará automáticamente
4. El badge dorado aparecerá/desaparecerá en la esquina superior derecha

### Para Filtrar Productos
1. En la parte superior del tab, verás 3 botones tipo "chip":
   - **"Todos"**: Muestra todos los productos
   - **"Stock bajo"**: Muestra solo los que tienen 1-4 unidades
   - **"Sin stock"**: Muestra solo los que tienen 0 unidades
2. Hacer clic en uno de los botones
3. La lista se filtrará automáticamente

## Estructura de Datos (Base de Datos)

### Tabla: `inventario_productos`
```
├── id (UUID, Primary Key)
├── proveedor_usuario_id (UUID, Foreign Key → auth.users)
├── nombre (VARCHAR 255, Required)
├── descripcion (TEXT, Optional)
├── precio_unitario (DECIMAL 10,2, Default: 0)
├── stock (INTEGER, Default: 0)
├── categoria (VARCHAR 100, Default: 'General')
├── url_foto (TEXT, Optional)
├── destacado (BOOLEAN, Default: FALSE)
├── creado_en (TIMESTAMP, Auto-generated)
└── actualizado_en (TIMESTAMP, Auto-updated)
```

### Seguridad (RLS Policies)
- Solo el proveedor propietario puede ver sus productos
- Solo el proveedor propietario puede crear/editar/eliminar sus productos
- Cumple con regulaciones de privacidad de datos

## Integración en el Menú

El nuevo tab **"Inventario"** aparece en el `BottomNavigationBar` con:
- **Icono**: `Icons.inventory_2`
- **Posición**: Tercer item (entre Solicitudes y Paquetes)
- **Label**: "Inventario"

## Performance y Optimización

### Índices Creados
- `proveedor_usuario_id`: Búsquedas rápidas por proveedor
- `actualizado_en DESC`: Ordenamiento eficiente
- `stock`: Filtrado rápido por estado
- `destacado`: Queries de productos destacados

### Caché y Refresh
- Los productos se cargan al iniciar el app
- Widget RefreshIndicator permite pull-to-refresh
- Cualquier acción (crear/editar/eliminar) recarga la lista automáticamente

### Lazy Loading (Futuro)
Consideración para versiones futuras:
- Implementar pagination si la lista crece mucho
- Agregar búsqueda de productos
- Cache local con Hive o similar

## Errores Comunes y Soluciones

### Error: "Tabla inventario_productos no existe"
**Solución**: Ejecuta el script SQL en `SETUP_INVENTARIO_TABLA.sql` en Supabase

### Error: "Permission denied on inventario_productos"
**Solución**: Verifica que las RLS policies estén configuradas correctamente

### Error: "Producto no se actualiza en tiempo real"
**Solución**: El app requiere hacer refresh (pull-down) o volver a abrir el tab

### Campos vacíos en el formulario
**Solución**: Algunos campos como "descripción" y "foto" son opcionales. Si ves errores, revisa la consola de Flutter

## Próximas Mejoras Sugeridas

1. **Carga de Fotos**
   - Integrar `image_picker` para cargar fotos del dispositivo
   - Subir a Supabase Storage
   - Mostrar preview antes de guardar

2. **Búsqueda y Filtros Avanzados**
   - Search bar para buscar por nombre
   - Filtro por categoría
   - Ordenamiento (precio, stock, fecha)

3. **Importación/Exportación**
   - Importar productos desde CSV
   - Exportar inventario como PDF o Excel

4. **Notificaciones**
   - Alertas cuando el stock es bajo
   - Recordatorios para reabastecer

5. **Historial y Analytics**
   - Seguimiento de cambios de stock
   - Gráficos de productos más vendidos
   - Reportes de inventario

## Soporte y Documentación

Para más información sobre las arquitecturas:
- **Angular (referencia)**: Ver descripción original en la documentación del componente
- **Flutter (esta implementación)**: Revisar los comentarios en el código
- **Supabase**: https://supabase.com/docs

---

**Versión**: 1.0  
**Fecha de Creación**: Marzo 2026  
**Estado**: ✅ Completo y funcional
