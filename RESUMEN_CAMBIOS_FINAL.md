# 📝 Resumen de Cambios: Upload de Fotos en Paquetes

## ✅ Cambios Realizados

### 1. **politicasRLS.txt** (Líneas 6-47)
Actualizado para usar bucket `festeasy` con validación RLS mejorada:

**ANTES:**
```sql
bucket_id = 'festeasy'
```

**AHORA:**
```sql
-- INSERT: Valida que el usuario suba solo en su carpeta
CREATE POLICY "Usuarios autenticados pueden subir imagenes"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'festeasy' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- UPDATE/DELETE: Solo modifica sus propios archivos
USING (bucket_id = 'festeasy' AND auth.uid()::text = (storage.foldername(name))[1])
```

**Mejora:** Ahora valida que el primer segmento de la ruta sea el `userId` del usuario autenticado.

---

### 2. **provider_paquetes_service.dart** (Línea 350)
Corrección de estructura de ruta para cumplir con RLS:

**ANTES:**
```dart
final filePath = 'paquete_fotos/$proveedorUsuarioId/$paqueteId/$fileName';
```

**AHORA:**
```dart
final filePath = '$proveedorUsuarioId/paquete_fotos/$paqueteId/$fileName';
```

**Razón:** Las políticas RLS validan `auth.uid()::text = (storage.foldername(name))[1]`, que extrae el **primer segmento** de la ruta. Debe ser el `userId`.

---

## 📊 Flujo Completo

### Paso 1: Usuario crea paquete
```
provider_home_page.dart → _showCreatePaqueteDialog()
```
- Llena datos: nombre, descripción, precio, categoría
- Selecciona 1-5 fotos
- Click "Crear"

### Paso 2: Se crea paquete vacío
```dart
final paquete = await ProviderPaquetesService.instance.createPaquete(
  proveedorUsuarioId: user.id,
  categoriaServicioId: selectedCategoryId,
  nombre: nombreController.text,
  descripcion: descripcionController.text,
  precioBase: precioBase,
  tipoCobro: tipoCobro,
  fotos: [], // Fotos vacías por ahora
);
```

### Paso 3: Se suben fotos
```dart
for (final foto in fotosSeleccionadas) {
  final url = await _uploadPhotoToSupabase(
    imageFile: foto,
    paqueteId: paquete.id,
  );
  if (url != null) {
    fotosUrls.add(url);
  }
}
```

### Paso 4: Se actualiza paquete con URLs
```dart
await ProviderPaquetesService.instance.updatePaquete(
  paqueteId: paquete.id,
  detallesJson: {
    'tipoCobro': tipoCobro,
    'fotos': fotosUrls, // URLs públicas
  },
);
```

---

## 🔒 Validación RLS en Supabase

```
Usuario intenta subir a: festeasy/{userId}/paquete_fotos/{paqueteId}/1705.jpg

Supabase valida:
1. ¿bucket_id = 'festeasy'? ✅
2. ¿auth.uid() = (storage.foldername(name))[1]?
   → storage.foldername(name) = ['{userId}', 'paquete_fotos', '{paqueteId}', '1705.jpg']
   → [1] = '{userId}' 
   → auth.uid() = '{userId}' ✅

Resultado: ✅ PERMITIDO
```

---

## 📁 Estructura Final en Storage

```
Bucket: festeasy
│
├── a1b2c3d4-e5f6-7890-abcd-ef1234567890/  ← UUID Proveedor 1
│   ├── paquete_fotos/
│   │   ├── paquete-001/
│   │   │   ├── 1705695600000.jpg
│   │   │   └── 1705695610000.jpg
│   │   └── paquete-002/
│   │       └── 1705695620000.jpg
│
└── b2c3d4e5-f6g7-8901-bcde-f12345678901/  ← UUID Proveedor 2
    └── paquete_fotos/
        └── paquete-003/
            └── 1705695630000.jpg
```

---

## 🔧 Archivos Modificados

| Archivo | Cambio | Líneas |
|---------|--------|------:|
| `politicasRLS.txt` | Mejora RLS con validación de usuario | 6-47 |
| `provider_paquetes_service.dart` | Reordenar ruta para RLS | 350 |

---

## ✨ Variables Clave

| Variable | Valor | Descripción |
|----------|-------|------------|
| `bucket` | `festeasy` | Nombre del bucket en Supabase Storage |
| `proveedorUsuarioId` | UUID | auth.uid() del proveedor |
| `paqueteId` | UUID | ID del paquete creado |
| `fileName` | `timestamp.jpg` | Nombre archivo (timestamp en ms) |
| `filePath` | `{userId}/paquete_fotos/{paqueteId}/{fileName}` | Ruta completa |

---

## 🚀 Pasos para Activar

### 1. Supabase SQL Editor
```sql
-- Copiar TODO de politicasRLS.txt
-- Pegar en SQL Editor
-- Ejecutar
```

### 2. Recompilar App
```bash
flutter clean
flutter pub get
flutter run
```

### 3. Probar
1. Crear paquete nuevo
2. Agregar foto
3. Click Crear
4. ✅ Foto debe guardarse en: `festeasy/{userId}/paquete_fotos/{paqueteId}/{timestamp}.jpg`

---

## 📸 URL Pública Resultante

```
https://[proyecto].supabase.co/storage/v1/object/public/festeasy/
a1b2c3d4-e5f6-7890-abcd-ef1234567890/paquete_fotos/paq-xyz/1705695600000.jpg
```

---

## ⚠️ Notas Importantes

- ✅ **No se modificó**: Lógica de negocio en `createPaquete()`, `updatePaquete()`
- ✅ **No se modificó**: Tabla `paquetes_proveedor` en BD
- ✅ **Solo cambios**: Estructura de rutas y políticas RLS
- ✅ **Bucket**: Sigue siendo `festeasy` como en politicasRLS.txt original
- ✅ **Seguridad**: Ahora cada usuario solo puede subir en su carpeta personal

---

## 🎓 Documentación Relacionada

- `GUIA_UPLOAD_FOTOS_PAQUETES.md` - Guía detallada de upload
- `politicasRLS.txt` - Políticas RLS SQL
- `CORRECCION_RLS_STORAGE.md` - Análisis técnico (puede estar desactualizado)
