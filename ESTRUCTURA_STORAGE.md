# 📁 Estructura de Storage para Festeasy

## ✅ Estructura ESTÁNDAR (Sincronizada Web ↔ Móvil)

### Bucket Principal
- **Nombre:** `festeasy`
- **Tipo:** Público
- **Límite:** 5MB por archivo
- **Tipos permitidos:** JPEG, PNG, GIF, WebP

### Rutas de Almacenamiento

```
Bucket: festeasy
│
├── packages/                              ← Fotos de paquetes/servicios
│   └── {userId}-{timestamp}-{random}.{ext}
│
├── avatars/                               ← Avatares de usuarios
│   └── {userId}-{timestamp}-{random}.{ext}
│
└── comprobantes/                          ← Comprobantes de pago
    └── {orderId}-{timestamp}.{ext}
```

## 🔑 Formato de Nombres de Archivo

### Fotos de Paquetes
```
packages/{userId}-{timestamp}-{random}.{ext}
```

| Componente | Descripción | Ejemplo |
|------------|-------------|---------|
| `packages/` | Carpeta fija | `packages/` |
| `userId` | UUID del proveedor | `a1b2c3d4-e5f6-...` |
| `timestamp` | Milisegundos | `1737849600000` |
| `random` | 7 chars aleatorios (base36) | `x7k2m9p` |
| `ext` | Extensión | `jpg`, `png` |

### Ejemplo de URL Completa
```
https://{supabase-url}/storage/v1/object/public/festeasy/packages/a1b2c3d4-e5f6-7890-abcd-1234567890ab-1737849600000-x7k2m9p.jpg
```

## 📱 Implementación en Móvil (Flutter)

**Archivo:** `lib/services/storage_constants.dart`

```dart
/// Genera la ruta para una foto de paquete
static String getPaqueteFotoPath({
  required String userId,
  required String fileExtension,
}) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomStr = _generateRandomString(); // 7 chars base36
  return 'packages/$userId-$timestamp-$randomStr.$fileExtension';
}

/// Genera string aleatorio de 7 caracteres
static String _generateRandomString() {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
  final random = Random();
  return List.generate(7, (_) => chars[random.nextInt(chars.length)]).join();
}
```

## 🌐 Implementación en Web (TypeScript)

**Archivo:** `paquetes.component.ts` (líneas 385-386)

```typescript
const filePath = `packages/${userId}-${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;
```

## ✅ Checklist de Sincronización

| Componente | Web | Móvil | Estado |
|------------|-----|-------|--------|
| Bucket name | `festeasy` | `festeasy` | ✅ |
| Carpeta fotos | `packages/` | `packages/` | ✅ |
| Formato nombre | `{userId}-{ts}-{rand}.{ext}` | `{userId}-{ts}-{rand}.{ext}` | ✅ |
| Random string | 7 chars (base36) | 7 chars (base36) | ✅ |

## 🔄 Notas sobre Migración

Las imágenes existentes subidas con la estructura anterior (`{userId}/paquete_fotos/{paqueteId}/{fileName}`) seguirán funcionando ya que las URLs completas están guardadas en `detalles_json.fotos`. 

Las nuevas imágenes usarán la estructura `packages/{userId}-{timestamp}-{random}.{ext}`.

---

**Última actualización:** Enero 2026
