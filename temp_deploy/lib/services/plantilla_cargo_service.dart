// PlantillaCargoService - Persistencia vía HybridStore (local + sync Supabase). Multi-dispositivo.

import '../models/plantilla_cargo_omni.dart';
import 'hybrid_store.dart';

class PlantillaCargoService {
  static Future<PlantillaCargoOmni?> getByPerfilId(String perfilCargoId) async =>
      HybridStore.getPlantillaByPerfilId(perfilCargoId);

  static Future<void> save(PlantillaCargoOmni p) async =>
      HybridStore.savePlantilla(p);
}
