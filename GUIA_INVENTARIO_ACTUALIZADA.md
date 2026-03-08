# 📦 Configuración del Módulo de Inventario con Soporte de Imágenes

## Descripción General

Se ha adaptado completamente el módulo de **Inventario** para funcionar con tu estructura de base de datos actual en Supabase, incluyendo:

- ✅ Tabla principal: `productos` (en lugar de `inventario_productos`)
- ✅ Columna: `proveedor_id` (en lugar de `proveedor_usuario_id`)
- ✅ Columna: `imagen_url` (en lugar de `url_foto`)
- ✅ Almacenamiento de imágenes en Supabase Storage bucket: `inventario`
- ✅ URLs públicas de imágenes almacenadas en la BD
- ✅ Funcionalidad completa de carga y prévisualización de imágenes

## Estructura de la Base de Datos

### Tabla: `productos`

```sql
Columnas existentes:
├── id (UUID, Primary Key)
├── proveedor_id (UUID, Foreign Key → auth.users)
├── nombre (Text)
├── categoria (Text, opcional)
├── descripcion (Text, opcional)
├── precio_unitario (Numeric)
├── stock (Integer)
├── destacado (Boolean)
├── imagen_url (Text, opcional) ← URL pública almacenada aquí
├── creado_en (Timestamp)
└── actualizado_en (Timestamp)
```

### Storage: `inventario` Bucket

```
Estructura de archivos:
products/
├── {proveedor_id}/
│   ├── 1709768400000.jpg
│   ├── 1709768450000.png
│   └── 1709768500000.webp
└── ...
```

**Patrón de ruta:** `products/{proveedor_id}/{timestamp}.{extension}`
**URL Pública generada:** `https://[supabase-url]/storage/v1/object/public/inventario/products/{proveedor_id}/{timestamp}.{extension}`

## Cambios Implementados

### 1. Servicio de Inventario (`provider_inventario_service.dart`)

#### Clase: `ProductoInventarioData`
- ✅ Renombrados: `proveedorUsuarioId` → `proveedorId`
- ✅ Renombrados: `urlFoto` → `imagenUrl`
- ✅ Mapeo correcto de campos de la BD

#### Métodos de Almacenamiento de Imágenes

**`uploadProductImage()`**
```dart
Future<String> uploadProductImage({
  required File imageFile,
  required String proveedorId,
}) async
```
- Sube la imagen a Supabase Storage
- Genera nombre automático: `products/{proveedorId}/{timestamp}.{extension}`
- Retorna la URL pública para almacenar en la BD
- Optimiza la imagen a 1024x1024 máximo

**`deleteProductImage()`**
```dart
Future<void> deleteProductImage(String imagenUrl) async
```
- Elimina la imagen del Storage cuando se borra un producto
- Extrae la ruta del archivo de la URL pública

#### Métodos CRUD actualizados
- `getProductos(proveedorId)` - Obtiene productos del proveedor
- `createProducto()` - Con parámetro `imagenUrl`
- `updateProducto()` - Puede actualizar la imagen
- `deleteProducto()` - (considerar eliminar también la imagen)

### 2. Formulario de Producto (`producto_form_dialog.dart`)

#### Nuevas Funcionalidades
- ✅ Selector de imágenes con `ImagePicker`
- ✅ Previsualización de imagen seleccionada
- ✅ Muestra imagen actual al editar
- ✅ Permite cambiar imagen existente
- ✅ Carga automática de imagen antes de guardar

#### Interfaz de Usuario
```
Antes: Solo campos de texto
Después: Campos de texto + Sección de Imagen
  ├── Si hay imagen nueva: Mostrar preview + botón eliminar
  ├── Si hay imagen anterior: Mostrar preview + botón editar
  └── Si sin imagen: Botón "Seleccionar Imagen"
```

#### Flujo de Guardado
1. Usuario selecciona imagen (opcional)
2. Usuario completa datos del producto
3. Al hacer click en "Crear/Actualizar":
   - Si hay imagen nueva → Sube a Storage
   - Obtiene URL pública
   - Guarda producto con `imagen_url`
   - Muestra confirmación

### 3. Tarjeta de Producto (`producto_card.dart`)

- ✅ Cambio: `producto.urlFoto` → `producto.imagenUrl`
- ✅ Carga la imagen desde URL pública
- ✅ Muestra icono si no hay imagen

## Flujo de Trabajo Completo

### Crear Producto con Imagen

```
1. Usuario abre el tab "Inventario"
2. Hace click en "+ Nuevo"
3. Se abre ProductoFormDialog
4. Usuario completa formulario y hace click en "Seleccionar Imagen"
5. Se abre gallery, selecciona imagen
6. Se muestra preview de la imagen
7. Usuario hace click en "Crear"
8. ProductoFormDialog:
   a) Valida campos
   b) Sube imagen a Storage → obtiene URL pública
   c) Crea producto con imagen_url
   d) Cierra el dialog
9. ProviderInventarioPage recarga la lista
10. Tarjeta muestra imagen desde URL
```

### Editar Producto con Imagen

```
1. Usuario hace click en "Editar" en la tarjeta
2. Se abre ProductoFormDialog con datos actuales
3. Muestra imagen anterior con botón "Editar"
4. Usuario (opcional) hace click en "Editar" para cambiar imagen
5. Usuario actualiza otros campos
6. Hace click en "Actualizar"
7. Si hay imagen nueva → sube a Storage
8. Actualiza producto con nueva imagen_url
9. Tarjeta se refresca con nueva imagen
```

### Eliminar Producto

```
⚠️ IMPORTANTE: Cuando se elimina un producto, considerar:
- ¿Eliminar también la imagen del Storage?
- ¿O dejar la imagen huérfana?

Recomendación: Agregar método antes de deleteProducto():
  if (producto.imagenUrl != null) {
    await ProviderInventarioService.instance
        .deleteProductImage(producto.imagenUrl!);
  }
```

## Configuración de Supabase

### 1. Storage Bucket (ya existe)

```sql
-- Verificar que existe el bucket
SELECT * FROM storage.buckets WHERE name = 'inventario';

-- Si no existe, crear:
INSERT INTO storage.buckets (id, name, public)
VALUES ('inventario', 'inventario', true);
```

### 2. Políticas de Storage (RLS)

```sql
-- Permitir proveedores ver sus propias Imágenes
CREATE POLICY "Proveedores ven sus fotos"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'inventario' 
    AND auth.uid()::text = (storage.foldername(name))[2]);

-- Permitir subir imágenes
CREATE POLICY "Proveedores suben sus fotos"
  ON storage.objects
  FOR INSERT
  WITH CHECK (bucket_id = 'inventario' 
    AND auth.uid()::text = (storage.foldername(name))[2]);

-- Permitir eliminar propias imágenes
CREATE POLICY "Proveedores eliminan sus fotos"
  ON storage.objects
  FOR DELETE
  USING (bucket_id = 'inventario' 
    AND auth.uid()::text = (storage.foldername(name))[2]);
```

### 3. Validación de Tabla

Verifica que tu tabla `productos` exista con los campos correctos:

```sql
-- Ver estructura
\d productos

-- O por query:
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'productos';
```

## Llamadas de API

### Crear Producto con Imagen

```dart
final user = AuthService.instance.currentUser;
final file = File(imagePath);

// 1. Subir imagen
final imagenUrl = await ProviderInventarioService.instance
    .uploadProductImage(
      imageFile: file,
      proveedorId: user.id,
    );

// 2. Crear producto
final producto = await ProviderInventarioService.instance
    .createProducto(
      proveedorId: user.id,
      nombre: 'Mi Producto',
      categoria: 'Decoración',
      precioUnitario: 10.0,
      stock: 5,
      imagenUrl: imagenUrl, // ← URL pública
    );
```

### Actualizar Imagen

```dart
// La actualización maneja automáticamente:
await ProviderInventarioService.instance.updateProducto(
  productoId: productoId,
  imagenUrl: nuevaImagenUrl, // ← Si hay foto nueva
);
```

### Eliminar Imagen

```dart
// Antes de eliminar el producto:
if (producto.imagenUrl != null) {
  await ProviderInventarioService.instance
      .deleteProductImage(producto.imagenUrl!);
}

// Luego eliminar el producto:
await ProviderInventarioService.instance.deleteProducto(productoId);
```

## Optimizaciones de Imagen

### Cliente (Flutter)
```dart
final image = await picker.pickImage(
  source: ImageSource.gallery,
  imageQuality: 80,        // Comprime a 80%
  maxWidth: 1024,          // Máximo ancho
  maxHeight: 1024,         // Máximo alto
);
```

### Servidor (Supabase Storage)
- **Peso típico:** 150-300 KB por imagen
- **Formato:** JPG, PNG, WebP soportados
- **Límite por archivo:** Depende de tu plan Supabase

## Errores Comunes y Soluciones

### Error: "Storage bucket 'inventario' no existe"
```
Solución:
1. Ir a Supabase Console → Storage
2. Crear nuevo bucket llamado 'inventario'
3. Marcar como "Público" (para acceso a URLs)
```

### Error: "Permission denied" al subir imagen
```
Solución:
1. Verificar RLS policies en Storage
2. Verificar que el usuario está autenticado
3. Revisar token JWT válido
```

### Error: "imagen_url es NULL en la BD"
```
Solución:
1. Si no hay imagen → Dejar NULL (es optional)
2. Solo guardar URL si uploadProductImage retorna valor
3. Validar que Storage.getPublicUrl() genera URL correcta
```

### Imagen no carga en la tarjeta
```
Solución:
1. Revisar URL en la BD: ¿Comienza con https://?
2. Verificar que Storage bucket es "público"
3. Probar URL en navegador manualmente
4. Revisar CORS settings en Supabase
```

## Testing

### Verificar Connection

```dart
// Test en consola
final url = Supabase.instance.client.storage
    .from('inventario')
    .getPublicUrl('products/test-id/12345.jpg');
print(url); // Debe generar URL válida
```

### Verificar Permisos

```dart
// Test upload
try {
  final url = await ProviderInventarioService.instance
      .uploadProductImage(
        imageFile: testFile,
        proveedorId: userId,
      );
  print('✓ Upload exitoso: $url');
} catch (e) {
  print('✗ Error: $e');
}
```

## Próximas Mejoras

1. **Comprimir imágenes del lado del servidor**
   - Usar funciones Edge de Supabase
   - Generar thumbnails automáticos

2. **Crop de imágenes**
   - Permitir al usuario recortar/rotar antes de subir
   - Usar paquete `image_cropper`

3. **Múltiples imágenes**
   - Galería de 3-5 fotos por producto
   - Imagen "destacada" y secundarias

4. **Carga progresiva**
   - Mostrar progreso de subida
   - Barra de progreso en el modal

5. **Eliminación de huérfanos**
   - Limpiar imágenes sin producto asociado
   - Scheduled task semanal

## Notas Importantes

⚠️ **Backup de imágenes**: Supabase Storage hace backup automático
⚠️ **Límite de almacenamiento**: Depende del plan (Free: 1GB)
⚠️ **Acceso a URLs**: Solo funcionan si bucket es público
⚠️ **CDN**: Las URLs se cachean automáticamente

---

**Versión**: 2.0 (Actualizado)  
**Fecha**: Marzo 2026  
**Estado**: ✅ Adaptado a estructura actual de BD  
**Próximas versiones**: Soporte para múltiples imágenes
