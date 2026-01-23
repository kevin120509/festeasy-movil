# 📸 Guía: Subir Fotos al Crear Paquetes

## 🎯 Configuración Actual

### Bucket Storage
- **Nombre**: `festeasy`
- **Tipo**: Público
- **Límite**: 5MB por imagen
- **Tipos permitidos**: JPEG, PNG, GIF, WebP

### Estructura de Rutas
```
Bucket: festeasy
│
├── {userId}/                        ← PRIMER SEGMENTO (auth.uid())
│   ├── paquete_fotos/              ← Descriptor
│   │   ├── {paqueteId}/
│   │   │   ├── timestamp.jpg
│   │   │   └── timestamp.jpg
```

**Ejemplo Real:**
```
festeasy/
  a1b2c3d4-e5f6-7890-abcd-ef1234567890/
    paquete_fotos/
      paquete-xyz123/
        1705695600000.jpg
        1705695610000.jpg
```

## 🔒 Políticas RLS Configuradas

### 1. **INSERT** - Subir imágenes
```sql
CREATE POLICY "Usuarios autenticados pueden subir imagenes"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'festeasy' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);
```
**Validación**: El usuario puede subir solo en su carpeta personal

### 2. **SELECT** - Ver imágenes
```sql
CREATE POLICY "Las imagenes son publicas"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'festeasy');
```
**Validación**: Cualquiera puede ver las imágenes públicamente

### 3. **UPDATE** - Actualizar imágenes
```sql
CREATE POLICY "Usuarios pueden actualizar sus archivos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'festeasy' AND auth.uid()::text = (storage.foldername(name))[1])
WITH CHECK (bucket_id = 'festeasy' AND auth.uid()::text = (storage.foldername(name))[1]);
```
**Validación**: El usuario solo puede actualizar sus propios archivos

### 4. **DELETE** - Eliminar imágenes
```sql
CREATE POLICY "Usuarios pueden eliminar sus archivos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'festeasy' AND auth.uid()::text = (storage.foldername(name))[1]);
```
**Validación**: El usuario solo puede eliminar sus propios archivos

## 🛠️ Código: `uploadFotoPaquete()`

**Ubicación**: `lib/services/provider_paquetes_service.dart` (línea 341-364)

```dart
/// Sube una foto para un paquete
Future<String?> uploadFotoPaquete({
  required String proveedorUsuarioId,      // auth.uid() del proveedor
  required String paqueteId,               // ID del paquete
  required List<int> fileBytes,            // Bytes de la imagen
  required String fileName,                // Nombre del archivo
}) async {
  try {
    // Construir ruta: {userId}/paquete_fotos/{paqueteId}/{fileName}
    final filePath =
        '$proveedorUsuarioId/paquete_fotos/$paqueteId/$fileName';

    // Subir a bucket 'festeasy'
    await _client.storage.from('festeasy').uploadBinary(
      filePath,
      Uint8List.fromList(fileBytes),
      fileOptions: const FileOptions(upsert: true),  // Reemplaza si existe
    );

    // Obtener URL pública
    final publicUrl =
        _client.storage.from('festeasy').getPublicUrl(filePath);
    return publicUrl;
  } catch (e) {
    throw Exception('Error subiendo foto: $e');
  }
}
```

## 🔄 Flujo de Creación de Paquete con Fotos

### En `provider_home_page.dart` (línea 399-468)

```
1. Usuario hace clic en "Crear Paquete"
   ↓
2. Se abre diálogo con formulario + opción de agregar fotos
   ↓
3. Usuario selecciona fotos (máximo 5)
   ↓
4. Usuario hace clic en "Crear"
   ↓
5. Se crea paquete en BD: createPaquete() con fotos vacías
   ↓
6. Para cada foto seleccionada:
   a. Lee bytes de la imagen
   b. Llama uploadFotoPaquete(userId, paqueteId, fileBytes, timestamp.jpg)
   c. Recibe URL pública
   d. Agrega URL a lista fotosUrls
   ↓
7. Actualiza paquete: updatePaquete() con URLs de fotos
   ↓
8. ✅ Paquete creado con fotos
```

## 📍 Punto Crítico: Validación RLS

### ¿Por qué la ruta debe comenzar con el userId?

La política RLS usa `storage.foldername(name)` que extrae segmentos de la ruta:

```sql
-- Si la ruta es: 'a1b2c3d4-e5f6-7890/paquete_fotos/paq-123/1705.jpg'
SELECT storage.foldername('a1b2c3d4-e5f6-7890/paquete_fotos/paq-123/1705.jpg');
-- Resultado: ['a1b2c3d4-e5f6-7890', 'paquete_fotos', 'paq-123', '1705.jpg']
--            [1] = 'a1b2c3d4-e5f6-7890' ← PRIMER SEGMENTO

-- La política valida:
AND auth.uid()::text = (storage.foldername(name))[1]
-- auth.uid() = 'a1b2c3d4-e5f6-7890' ✅ COINCIDE
```

## ✅ Checklist de Implementación

- [x] Bucket `festeasy` creado
- [x] 4 políticas RLS configuradas
- [x] Método `uploadFotoPaquete()` implementado
- [x] Flujo en `_showCreatePaqueteDialog()` correcto
- [x] Ruta estructura: `{userId}/paquete_fotos/{paqueteId}/{fileName}`
- [x] Validación RLS: primer segmento = userId

## 🚀 Pasos para Activar

### 1. Ejecutar SQL en Supabase
```sql
-- Copiar TODO el contenido de: politicasRLS.txt
-- Pegar en SQL Editor de Supabase
-- Ejecutar
```

### 2. Verificar en Supabase Console
- Storage → festeasy → Políticas
- Confirmar 4 políticas presentes

### 3. Probar en App
1. Ir a: Mis Paquetes → Nuevo
2. Llenar datos del paquete
3. Agregar foto
4. Click "Crear"
5. ✅ Foto debe guardarse

## 📊 Ejemplo de URL Pública Generada

```
https://[proyecto].supabase.co/storage/v1/object/public/festeasy/
a1b2c3d4-e5f6-7890-abcd-ef1234567890/paquete_fotos/paq-123/1705695600000.jpg
                    ↑ userId del proveedor
                                          ↑ ID del paquete
```

## ⚠️ Solución de Problemas

| Error | Causa | Solución |
|-------|-------|----------|
| 403 Unauthorized | RLS deniegaAcceso | Verificar que la ruta comience con userId |
| "Bucket not found" | Bucket no existe | Ejecutar politicasRLS.txt en Supabase |
| Foto no se carga | Política no aplicada | Recargar Supabase, limpiar caché app |
| "Invalid file type" | MIME no permitido | Usar JPEG, PNG, GIF o WebP |
| "File too large" | >5MB | Comprimir imagen (app lo hace automático) |

## 🎓 Referencias

- Bucket: `festeasy`
- Ruta: `{userId}/paquete_fotos/{paqueteId}/{fileName}`
- Políticas: 4 reglas RLS en politicasRLS.txt (líneas 22-47)
- Código upload: `lib/services/provider_paquetes_service.dart:341-364`
- Código UI: `lib/app/view/provider_home_page.dart:399-468`
