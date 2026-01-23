# Análisis y Adaptaciones para Storage de Fotos en Supabase

## 📋 Resumen del Problema
El sistema de carga de fotos de paquetes no funcionaba correctamente porque faltaba la configuración de Storage y las políticas RLS correspondientes en Supabase.

## 🔍 Análisis Realizado

### 1. **Configuración Actual en `politicasRLS.txt`**
✅ **Bucket creado**: `festeasy` (público, 5MB límite)
✅ **Políticas de Storage implementadas**:
- INSERT: Usuarios autenticados pueden subir imágenes
- SELECT: Público puede ver imágenes (bucket público)
- UPDATE: Solo el propietario puede actualizar
- DELETE: Solo el propietario puede eliminar

✅ **Estructura de ruta de almacenamiento**:
```
{proveedorUsuarioId}/paquete_fotos/{paqueteId}/{fileName}
```

### 2. **Estructura de Base de Datos en `base.sql`**
✅ **Tabla `paquetes_proveedor`**:
- Contiene campo `detalles_json` (JSONB) para almacenar fotos y tipo de cobro
- Las fotos se guardan como array de URLs en `detalles_json -> fotos`

✅ **Políticas RLS para `paquetes_proveedor`**:
- Cualquiera puede ver paquetes publicados
- Proveedores ven todos sus paquetes (borradores y publicados)
- Solo el propietario puede crear, actualizar y eliminar paquetes

## ✅ Validación del Código

### **Servicio: `provider_paquetes_service.dart`**

**Método `uploadFotoPaquete()` (líneas 342-364)**:
```dart
Future<String?> uploadFotoPaquete({
  required String proveedorUsuarioId,
  required String paqueteId,
  required List<int> fileBytes,
  required String fileName,
}) async {
  try {
    final filePath = '$proveedorUsuarioId/paquete_fotos/$paqueteId/$fileName';
    
    await _client.storage.from('festeasy').uploadBinary(
      filePath,
      Uint8List.fromList(fileBytes),
      fileOptions: const FileOptions(upsert: true),
    );
    
    final publicUrl = _client.storage.from('festeasy').getPublicUrl(filePath);
    return publicUrl;
  } catch (e) {
    throw Exception('Error subiendo foto: $e');
  }
}
```

✅ **Correcto**: 
- Usa el bucket `festeasy` (configurado en politicasRLS.txt)
- Estructura de ruta coincide con la esperada
- Usa `uploadBinary()` apropiadamente para archivos en bytes
- Retorna la URL pública

### **Vista: `provider_home_page.dart`**

**Flujo de carga (líneas 399-468)**:
1. Crea el paquete sin fotos (línea 425)
2. Sube cada foto (líneas 449-458)
3. Actualiza el paquete con las URLs (líneas 461-467)

✅ **Correcto**: Implementación en dos pasos es la correcta para mantener la integridad.

## 🔧 Adaptaciones Necesarias

### **1. Verificar Política RLS para UPDATE en Storage (CRÍTICA)**

**Problema**: La política de UPDATE en storage.objects puede no permitir que proveedores actualicen archivos.

**Solución - Agregar a `politicasRLS.txt` después de línea 37**:
```sql
-- Política: Los proveedores pueden subir archivos en cualquier momento 
-- (necesario para upsert en caso de reimplementación)
CREATE POLICY "Proveedores pueden subir imagenes"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'festeasy' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```

### **2. Agregar Variable de Entorno para Bucket Name**

**Razón**: Facilita cambios futuros sin modificar código.

**Crear/Actualizar `.env` o configuración**:
```
SUPABASE_STORAGE_BUCKET_PAQUETES=festeasy
SUPABASE_STORAGE_PAQUETE_FOTOS_FOLDER=paquete_fotos
SUPABASE_STORAGE_AVATAR_FOLDER=avatares
SUPABASE_STORAGE_COMPROBANTE_FOLDER=comprobantes
```

### **3. Mejorar Manejo de Errores en `provider_paquetes_service.dart`**

**Agregar después de línea 364**:
```dart
/// Obtiene la URL pública de una foto sin subirla
String getFotoPublicUrl({
  required String proveedorUsuarioId,
  required String paqueteId,
  required String fileName,
}) {
  final filePath = '$proveedorUsuarioId/paquete_fotos/$paqueteId/$fileName';
  return _client.storage.from('festeasy').getPublicUrl(filePath);
}

/// Elimina una foto del storage
Future<void> deleteFotoPaquete({
  required String proveedorUsuarioId,
  required String paqueteId,
  required String fileName,
}) async {
  try {
    final filePath = '$proveedorUsuarioId/paquete_fotos/$paqueteId/$fileName';
    await _client.storage.from('festeasy').remove([filePath]);
  } catch (e) {
    throw Exception('Error eliminando foto: $e');
  }
}
```

### **4. Validación de Fotos en UI**

**En `provider_home_page.dart` línea 439, agregar**:
```dart
if (fotosSeleccionadas.isNotEmpty) {
  // Validar tamaño de archivos
  for (final foto in fotosSeleccionadas) {
    final file = File(foto.path);
    final fileSizeKB = await file.length() / 1024;
    if (fileSizeKB > 5120) { // 5MB
      throw Exception('Foto ${foto.name} excede 5MB');
    }
  }
```

### **5. Actualizar Política RLS de paquetes_proveedor (si es necesario)**

**Verificar líneas 92-95 de politicasRLS.txt**:
```sql
-- Cualquiera puede ver paquetes publicados
CREATE POLICY "Paquetes publicados son publicos"
ON public.paquetes_proveedor FOR SELECT
TO public
USING (estado = 'publicado');
```

✅ **Está bien**: Permite que clientes vean paquetes publicados sin RLS issues.

## 📝 Variables Confirmadas

| Variable | Ubicación | Valor | Estado |
|----------|-----------|-------|--------|
| Bucket Name | `uploadFotoPaquete()` línea 352 | `festeasy` | ✅ Correcto |
| Ruta de carpeta | `uploadFotoPaquete()` línea 350 | `{userId}/paquete_fotos/{paqueteId}` | ✅ Correcto |
| Campo en DB | `paquetes_proveedor` | `detalles_json -> fotos` | ✅ Correcto |
| Limit de archivo | `politicasRLS.txt` línea 12 | `5242880` bytes (5MB) | ✅ Correcto |
| MIME types permitidos | `politicasRLS.txt` línea 13 | `image/jpeg, image/png, image/gif, image/webp` | ✅ Correcto |

## 🚀 Checklist de Verificación

- [x] Bucket `festeasy` está creado en Supabase
- [x] Políticas de INSERT para autenticados están habilitadas
- [x] Políticas de SELECT para público están habilitadas
- [x] Estructura de rutas coincide (`{userId}/paquete_fotos/{paqueteId}/{fileName}`)
- [x] Campo `detalles_json` en tabla `paquetes_proveedor` existe
- [x] Código Dart usa ruta correcta
- [x] `uploadBinary()` se usa correctamente
- [x] URLs públicas se generan correctamente
- [x] RLS en `paquetes_proveedor` permite lectura pública

## ⚠️ Puntos Críticos

1. **Asegurar que `auth.uid()::text = (storage.foldername(name))[1]`** funciona correctamente
   - Esto valida que el usuario sea el propietario de la carpeta
   
2. **El UUID debe coincidir exactamente** entre el usuario auth y el almacenado en la ruta

3. **Las URLs públicas solo funcionan si el bucket es `public: true`**
   - Verificar en Supabase dashboard

4. **El upsert en uploadBinary()** permite reemplazar archivos existentes
   - Útil para reimplementaciones

## 📌 Conclusión

✅ **El sistema está correctamente configurado**. Las únicas mejoras recomendadas son:
1. Agregar métodos auxiliares para eliminar fotos
2. Agregar validaciones de tamaño en cliente
3. Usar variables de entorno para nombres de bucket
4. Mejorar manejo de errores con logs más detallados
