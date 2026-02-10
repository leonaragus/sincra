import 'package:flutter/material.dart';

class AppHelp {
  static void showHelpDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con icono
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.help_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Contenido con mejor formato
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Botón de cierre moderno
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        '¡Entendido!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Map<String, String> getHelpContent(String screenName) {
    switch (screenName) {
      case 'EmpresaScreen':
        return {
          'title': 'Gestión de Empresas',
          'content': '''• RAZÓN SOCIAL: Nombre completo de la empresa
• CUIT: Número de CUIT (11 dígitos sin guiones)
• DOMICILIO: Dirección completa (calle/numero/ciudad)
• CONVENIOS: Seleccione los convenios colectivos que aplican
• LOGO Y FIRMA: Agregue imágenes para recibos digitales ARCA 2026

💡 Puede añadir nuevos convenios desde la ventana de Convenios.''',
        };
      
      case 'EmpleadoScreen':
        return {
          'title': 'Gestión de Empleados',
          'content': '''• DATOS PERSONALES: Complete nombre, CUIL, categoría
• CONVENIO: Seleccione convenio colectivo aplicable
• CATEGORÍA: Elija la categoría según convenio
• UBICACIÓN: Datos de domicilio y localidad
• BANCARIOS: CBU y datos bancarios
• OBRA SOCIAL: RNOS y datos de cobertura

💡 Verifique que los datos estén actualizados antes de liquidar.''',
        };
      
      case 'ConveniosScreen':
        return {
          'title': 'Gestión de Convenios',
          'content': '''• BUSCAR: Use el buscador para encontrar convenios
• AÑADIR: Puede crear nuevos convenios personalizados
• ACTUALIZAR: Los convenios se sincronizan automáticamente
• ESCALAS: Contiene categorías y salarios base

💡 Mantenga los convenios actualizados para cálculos precisos.''',
        };
      
      case 'LiquidadorFinalScreen':
        return {
          'title': 'Liquidación de Sueldos',
          'content': '''• SELECCIONE: Empresa y empleado a liquidar
• CONCEPTOS: Agregue conceptos adicionales si es necesario
• FECHAS: Defina período de liquidación
• CÁLCULOS: El sistema calcula automáticamente
• EXPORTAR: Genere PDF del recibo de sueldo

💡 Revise siempre los cálculos antes de confirmar.''',
        };
      
      case 'HomeScreen':
        return {
          'title': 'Panel Principal',
          'content': '''• EMPRESAS: Gestione sus empresas registradas
• EMPLEADOS: Administre el personal
• LIQUIDACIÓN: Acceso rápido a liquidación
• CONVENIOS: Biblioteca de convenios colectivos
• HISTORIAL: Consulta de liquidaciones anteriores

💡 Use el menú lateral para navegar entre secciones.''',
        };
      
      case 'verificador_recibo':
        return {
          'title': 'Verificador de Recibo',
          'content': '''• VERIFICADOR DE RECIBO (OCR): Escanea tu recibo físico usando la cámara. El sistema analizará los conceptos, aportes y el neto para detectar posibles errores.

• ESCANEAR QR: Acceso rápido para recibos con código QR oficial, permitiendo una carga de datos más precisa y rápida.

• PROYECCIONES IPC: Calcula cuánto valdrá tu sueldo en 3 y 6 meses basándose en la inflación proyectada por el INDEC y tus ajustes salariales.

• EPA (ESCUDO DE PODER ADQUISITIVO): Un indicador visual que te dice si estás ganando, manteniendo o perdiendo poder de compra frente a la inflación.

• METAS EN UNIDADES (SMVM): Mide tu sueldo en "Salarios Mínimos, Vitales y Móviles". Es la mejor forma de saber si tu nivel de ingresos progresa en el tiempo.

• ESTIMADOR DE LIQUIDACIÓN: Simula cuánto cobrarías en caso de renuncia o despido. Incluye SAC, vacaciones e indemnizaciones base.

💡 Los datos se actualizan automáticamente desde fuentes oficiales.''',
        };
      
      case 'teacher_interface':
        return {
          'title': 'Panel Docente - Liquidación Federal 2026',
          'content': '''• CREAR INSTITUCIÓN: Agregue nueva institución educativa con datos completos
• INSTITUCIÓN YA CREADA: Acceda a instituciones existentes para gestionar legajos
• OPCIONES DE LIQUIDACIÓN: Configuración avanzada para cálculos docentes
• TUTORIAL: Guía completa del sistema de liquidación docente

📋 CARACTERÍSTICAS:
- Sistema federal con 24 jurisdicciones
- Escalas dinámicas editables
- Exportación ARCA 2026 compatible
- Gestión masiva de legajos
- Cálculos específicos para docentes

💡 Use el menú de opciones para configurar parámetros específicos.''',
        };
      
      case 'sanidad_interface':
        return {
          'title': 'Panel Sanidad - FATSA CCT 122/75 y 108/75',
          'content': '''• GESTIÓN DE INSTITUCIONES: Hospitales y clínicas del sector salud
• LEGAJOS DE EMPLEADOS: Personal de sanidad con categorías específicas
• SIMULADOR NETO: Cálculos precisos de liquidación sanidad
• EXPORTACIÓN LSD: Formatos oficiales para el sector

🏥 CARACTERÍSTICAS:
- Convenios FATSA CCT 122/75 y 108/75
- Sistema Omni con 24 jurisdicciones
- Escalas dinámicas para personal de salud
- Exportación masiva en pack ZIP
- Modos SAC/Vacaciones/Final
- Compatible ARCA 2026

💡 Configure RNOS y categorías específicas para cálculos precisos.''',
        };
      
      default:
        return {
          'title': 'Ayuda',
          'content': 'Información de ayuda no disponible para esta pantalla.',
        };
    }
  }

  static Widget buildHelpButton(BuildContext context, String screenName) {
    return IconButton(
      icon: const Icon(Icons.help_outline, size: 22),
      onPressed: () {
        final helpContent = getHelpContent(screenName);
        showHelpDialog(context, helpContent['title']!, helpContent['content']!);
      },
      tooltip: 'Ayuda',
    );
  }
}