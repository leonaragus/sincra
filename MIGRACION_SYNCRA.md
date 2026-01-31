# Migración Syncra Arg — Resumen y pruebas

## 1. Rebranding

- **Proyecto:** `name: syncra_arg` en `pubspec.yaml`
- **Android:** `android:label="Syncra Arg"` en `AndroidManifest.xml`
- **iOS:** `CFBundleDisplayName` y `CFBundleName` = "Syncra Arg" en `Info.plist`
- **Web:** título "Syncra Arg - Gestión Contable" en `web/index.html` y `web/manifest.json`
- **UI:** Home y ayuda muestran "Syncra Arg" y el eslogan
- **Splash:** `flutter_native_splash` con color `#0D1B2A`. Para logo y texto: agregar `image: "assets/images/splash_logo.png"` en `pubspec.yaml` y ejecutar `dart run flutter_native_splash:create`

## 2. Supabase y capa híbrida

- **Dependencias:** `supabase_flutter`, `connectivity_plus`. Isar opcional (ver `pubspec.yaml`).
- **Config:** `lib/config/supabase_config.dart` (URL y anon key). Si la anon key es JWT (`eyJ...`), reemplazarla.
- **Tabla:** Ejecutar el SQL de `docs/SUPABASE_SETUP.md` en el SQL Editor de Supabase.
- **HybridStore:** Lectura desde local (SharedPreferences; o Isar si se habilita). Escritura en local y sincronización en background a Supabase cuando hay conexión.
- **Servicios migrados:** `InstitucionesService`, `PlantillaCargoService`, empresas (Home, Empresa, Liquidador) y legajos usan HybridStore.

## 3. Web

- **Plataforma:** `flutter create --platforms web .` (ya ejecutado).
- **Auth Web:** `WebLoginScreen` con Email/Contraseña y opción "Vincular con código" (placeholder). `WebAuthGate` en `main.dart` cuando `kIsWeb`.
- **Responsividad:** `ListaLegajosDocenteScreen` usa `LayoutBuilder`: en pantallas ≥700px muestra `DataTable`; en móvil, `ListView`. Mismo criterio aplicable a otras tablas/grillas.

## 4. Verificación

```bash
flutter pub get
flutter analyze
flutter run -d chrome        # Web
flutter run -d windows       # PC
flutter run                  # Móvil
```

### Flujo de prueba

1. **Móvil:** Escanear recibo (Docente/Sanidad) → guardar en HybridStore → sync a Supabase si hay red.
2. **Web:** Login (Email/Password si Auth está configurado en Supabase) → ver legajos e instituciones sincronizados.
3. **PC/Web:** Generar LSD en liquidador → descargar PDF.

Si Supabase no está configurado o falla la anon key, la app sigue funcionando 100% offline con datos locales.

## 5. Isar (opcional)

Para usar Isar en móvil/desktop:

1. Descomentar `isar` e `isar_generator` + `build_runner` en `pubspec.yaml`.
2. Crear `lib/db/syncra_entity.dart` con la colección y `part 'syncra_entity.g.dart'`.
3. Ejecutar `dart run build_runner build --delete-conflicting-outputs`.
4. En `lib/services/hybrid_store.dart`, cambiar el import a `import 'hybrid_isar_stub.dart' if (dart.library.io) 'hybrid_isar_io.dart' as _local;` y recrear `hybrid_isar_io.dart` + `syncra_entity.g.dart`.

## 6. Motor Omni y LSD

El Motor Omni y la lógica SAC/LSD (`lsd_engine`, `teacher_omni_engine`, `sanidad_omni_engine`) siguen ejecutándose en local; leen y escriben a través de los servicios que ya usan HybridStore (instituciones, legajos, plantillas, etc.).
