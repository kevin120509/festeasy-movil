# 🚀 Pasos de Implementación - Módulo de Inventario

## PASO 1: Verificar Tabla en Supabase

Ejecuta esta query en Supabase SQL Editor para verificar que tu tabla existe:

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'productos'
ORDER BY ordinal_position;
```

**Salida esperada:**
```
column_name          | data_type            | is_nullable
─────────────────────┼──────────────────────┼────────────
id                   | uuid                 | NO
proveedor_id         | uuid                 | NO
nombre               | text                 | NO
categoria            | text                 | YES
descripcion          | text                 | YES
precio_unitario      | numeric              | NO
stock                | integer              | NO
destacado            | boolean              | YES
imagen_url           | text                 | YES
creado_en            | timestamp            | YES
actualizado_en       | timestamp            | YES
```

Si `imagen_url` no existe, agrégala:
```sql
ALTER TABLE productos ADD COLUMN imagen_url text;
```

## PASO 2: Configurar Storage Bucket

### 2.1 Verificar que existe el bucket `inventario`

En Supabase Console → Storage:
- Busca un bucket llamado `inventario`
- Si no existe, crea uno:
  - Click en "New bucket"
  - Nombre: `inventario`
  - Marcar como "Public"
  - Click "Create"

### 2.2 Configurar RLS Policies (Seguridad)

Ve a Supabase SQL Editor y ejecuta:

```sql
-- Habilitar RLS en el bucket
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Política: Proveedores pueden ver sus propias imágenes
CREATE POLICY "Ver propias imágenes"
  ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'inventario' 
    AND auth.uid()::text = (storage.foldername(name))[2]
  );

-- Política: Proveedores pueden subir imágenes
CREATE POLICY "Subir imágenes propias"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'inventario' 
    AND auth.uid()::text = (storage.foldername(name))[2]
  );

-- Política: Proveedores pueden eliminar sus imágenes
CREATE POLICY "Eliminar imágenes propias"
  ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'inventario' 
    AND auth.uid()::text = (storage.foldername(name))[2]
  );
```

**Validación:**
- Ve a Storage → Policies
- Deberías ver 3 policies para el bucket `inventario`

## PASO 3: Compilar y Probar

```bash
# Instalar dependencias
flutter pub get

# Compilar en development
flutter run --flavor development -t lib/main_development.dart
```

## PASO 4: Prueba la Funcionalidad

### 4.1 Crear Producto con Imagen

1. Inicia la app en un dispositivo/emulador
2. Navega al tab "Inventario" (debe estar después de "Solicitudes")
3. Haz click en "+ Nuevo"
4. Completa el formulario:
   - Nombre: ej "Piñata de Dinosaurio"
   - Categoría: selecciona una
   - Precio: 15.00
   - Stock: 10
5. Haz click en "Seleccionar Imagen"
6. Elige una foto de tu galería
7. Haz click en "Crear"

**Esperado:**
- ✅ Se muestra un loading
- ✅ Se cierra el dialog
- ✅ Se muestra un snackbar de confirmación
- ✅ Aparece el producto en la lista con la imagen

### 4.2 Verificar en Supabase

1. Ve a Supabase Console → Database → productos
2. Busca el producto que acabas de crear
3. La columna `imagen_url` debe tener una URL como:
   ```
   https://[your-project].supabase.co/storage/v1/object/public/inventario/products/[user-id]/[timestamp].jpg
   ```

4. Ve a Storage → inventario → products
5. Deberías ver una carpeta con el ID del usuario
6. Dentro, la imagen guardada con nombre: `[timestamp].[ext]`

### 4.3 Ver la Imagen en la App

1. La tarjeta del producto debe mostrar la imagen
2. Si hace click en "Editar":
   - Debe mostrarse la imagen actual
   - Botón "Editar" para cambiarla

## PASO 5: Casos Especiales

### 5.1 Eliminar Producto con Imagen

⚠️ **IMPORTANTE**: Actualmente al eliminar un producto NO se elimina la imagen del Storage.

Para implementar esto, en `provider_home_page.dart`, busca donde se llama a `deleteProducto()` y reemplaza:

```dart
// ANTES:
await ProviderInventarioService.instance.deleteProducto(producto.id);

// DESPUÉS:
// Eliminar imagen primero
if (producto.imagenUrl != null) {
  await ProviderInventarioService.instance
      .deleteProductImage(producto.imagenUrl!);
}
// Luego eliminar producto
await ProviderInventarioService.instance.deleteProducto(producto.id);
```

### 5.2 Editar Solo el Nombre (sin cambiar imagen)

El form está diseñado para esto:
1. Si NO haces click en "Seleccionar Imagen"
2. La `imagenSeleccionada` permanece NULL
3. Al guardar, no sube imagen nueva (usa la anterior)

### 5.3 Cambiar Imagen Existente

1. Abre editar producto
2. Haz click en el botón azul "Editar" sobre la imagen
3. Selecciona nueva imagen
4. Haz click en "Actualizar"
5. Se sube nueva imagen, imagen antigua queda huérfana (considerar limpiarla)

## PASO 6: Debugging

### Si la imagen no aparece:

```dart
// En terminal, ejecutar:
flutter run --flavor development -t lib/main_development.dart -v

// Buscar errores con "imagen" o "storage"
```

### Si falla el upload:

1. Verificar usuario está autenticado:
   ```dart
   final user = AuthService.instance.currentUser;
   print('User: $user'); // Debe mostrar datos del usuario
   ```

2. Verificar bucket es público:
   - Storage → Policies tab
   - Debe mostrar 3 policies

3. Verificar CORS:
   - Supabase → Project Settings → CORS
   - Agregar dominio si es necesario

### Si la URL no funciona:

1. Pastar URL en navegador
2. Si devuelve 403: Storage policy incorrecto
3. Si devuelve 404: Archivo no existe o ruta está mal

```sql
-- Ver archivos en Storage por SQL
SELECT name, created_at, metadata
FROM storage.objects
WHERE bucket_id = 'inventario'
ORDER BY created_at DESC
LIMIT 10;
```

## PASO 7: Optimizaciones (Opcional)

### Comprimir imágenes automáticamente

Ya está implementado en ProductoFormDialog:
```dart
final image = await picker.pickImage(
  imageQuality: 80,  // 0-100 (80% = buen balance)
  maxWidth: 1024,
  maxHeight: 1024,
);
```

### Mostrar barra de progreso

Considera implementar después si necesitas:
```dart
// En ProviderInventarioService
Stream<double> uploadProductImageWithProgress({...})
```

### Limpiar imágenes huérfanas

Considerar agregar una función administrativa:
```dart
Future<void> cleanupOrphanedImages() async
```

## PASO 8: Validación Final

Checklist de verificación:

- [ ] Tabla `productos` existe en Supabase
- [ ] Columna `imagen_url` existe y es nullable
- [ ] Bucket `inventario` existe y es público
- [ ] RLS Policies están configuradas
- [ ] App compila sin errores
- [ ] Tab "Inventario" aparece en el navigation
- [ ] Puedo crear un producto sin imagen
- [ ] Puedo crear un producto con imagen
- [ ] La imagen se muestra en la tarjeta
- [ ] Imagen se guardó en Storage bucket
- [ ] Imagen URL está en la BD
- [ ] Puedo editar y cambiar imagen
- [ ] Puedo eliminar un producto
- [ ] Puedo usar los filtros (Todos/Bajo/Agotado)
- [ ] Puedo destacar/desatacar un producto

Si todos están ✅, ¡el módulo está listo para producción!

## PASO 9: Deploy a Producción

```bash
# Build APK
flutter build apk --flavor production -t lib/main_production.dart --release

# Build iOS
flutter build ios --flavor production -t lib/main_production.dart --release
```

---

## Contacto & Soporte

Si encuentras algún problema:

1. Verifica los logs: `flutter logs`
2. Revisa la consola de Supabase
3. Consulta `GUIA_INVENTARIO_ACTUALIZADA.md` para más detalles
4. Revisa errores comunes en esa guía

**Versión**: 1.0  
**Última actualización**: Marzo 2026
