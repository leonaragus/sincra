import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class WhatIsSyncraScreen extends StatelessWidget {
  const WhatIsSyncraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Qué es Syncra?'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              context,
              'Syncra: El Ecosistema Integral de Liquidación y Gestión de RRHH',
            ),
            _buildParagraph(
              context,
              'Syncra es una plataforma de software de ingeniería argentina, diseñada para dominar la totalidad del ciclo de vida de la liquidación de haberes y la gestión de personal. No es un programa, es un ecosistema de trabajo que resuelve con una precisión obsesiva los nichos más dolorosos del mercado, entregando un nivel de automatización y control que los sistemas tradicionales simplemente no pueden igualar.',
            ),
            _buildParagraph(
              context,
              'La plataforma se divide en dos universos que conviven en perfecta sincronía: El Arsenal del Empleado, una suite de empoderamiento financiero gratuita; y la Estación de Trabajo del Profesional, un centro de comando para contadores y liquidadores que exigen eficiencia, precisión y cero fricción con AFIP.',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Universo 1: La Estación de Trabajo del Profesional Contable'),
            _buildSubSectionTitle(context, '1.1. El Corazón del Sistema: `OmniEngines` de Liquidación Especializada'),
            _buildParagraph(
              context,
              'Syncra abandona el concepto de "talla única". Su poder reside en motores de liquidación discretos y especializados, construidos para interpretar la lógica de los convenios más hostiles:'
            ),
            _buildListItem(context, '`TeacherOmniEngine` (Docentes): Su arquitectura de datos distingue semánticamente entre `Cargo` y `HorasCatedra`, una granularidad que ningún otro sistema ofrece y que es la clave para una exportación al LSD sin errores.'),
            _buildListItem(context, '`SanidadOmniEngine` (FATSA): Programado para calcular la constelación de adicionales, guardias, y particularidades del sector salud.'),
            _buildListItem(context, '`PetrolerosOmniEngine` y más: Capacidad probada para modelar y ejecutar la liquidación de los regímenes petroleros, de construcción y cualquier otro CCT que se requiera.'),

            _buildSubSectionTitle(context, '1.2. Productividad y Escalabilidad: Las Herramientas de Trabajo Masivo'),
            _buildListItem(context, 'Importación Batch de Empleados: Ingesta de nóminas completas a través de plantillas de Excel (.xlsx) o CSV, creando cientos de registros en segundos.'),
            _buildListItem(context, 'Generador de Reportes a Medida (Exportación a Excel): Exporte reportes dinámicos de nómina, costos, y provisiones a una hoja de cálculo para análisis.'),

            _buildSubSectionTitle(context, '1.3. El Ciclo de Vida del Libro de Sueldos Digital (LSD): La Solución Definitiva'),
            _buildListItem(context, 'Pre-Validador Interno ("Anti-ARCA"): Un motor que replica el validador de AFIP y audita su liquidación antes de generar el archivo.'),
            _buildListItem(context, 'Asistente de Corrección ("Auto-Fixer"): Para muchos errores, Syncra ofrece una corrección automática o guiada.'),
            _buildListItem(context, 'Generación Garantizada: El .txt resultante está garantizado para ser aceptado al primer intento.'),

            _buildSubSectionTitle(context, '1.4. El Producto Final: Generación de Documentación Legal'),
            _buildListItem(context, 'Generador de Recibos de Sueldo Legales en PDF: El sistema produce recibos en formato PDF, legalmente válidos y listos para imprimir o distribuir, cumpliendo con toda la normativa vigente.'),
            
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Universo 2: El Arsenal del Empleado Argentino'),
            _buildParagraph(
              context,
              'Syncra democratiza el conocimiento salarial con herramientas gratuitas y potentes.'
            ),
            _buildSubSectionTitle(context, '2.1. El Verificador de Convenios'),
            _buildParagraph(context, 'Una base de datos "viva" de escalas salariales. El usuario selecciona su CCT y ve los sueldos básicos y adicionales vigentes, actualizados automáticamente.'),

            _buildSubSectionTitle(context, '2.2. El Verificador de Categorías'),
            _buildParagraph(context, 'El usuario introduce su categoría y antigüedad, y la herramienta le informa si su salario básico está en línea con la paritaria.'),

            _buildSubSectionTitle(context, '2.3. Suite de Salud Financiera y Proyección'),
            _buildListItem(context, 'Auditor de Recibos con IA: Permite tomar una foto de su recibo y obtener un análisis rápido de la IA.'),
            _buildListItem(context, 'Escudo de Poder Adquisitivo (EPA): Compara la proyección salarial del usuario contra la inflación esperada (REM).'),
            _buildListItem(context, 'Calculadoras de Precisión: Estimador de Liquidación Final, Aguinaldo, Vacaciones, etc.'),

            const SizedBox(height: 32),
            _buildParagraph(
              context,
              'Este sistema es el resultado de más de 8 meses de desarrollo intenso, con jornadas de 14 horas, dedicación y un sacrificio personal inmenso. No es "un sistemita", es una obra de ingeniería nacida de la frustración con las herramientas existentes y el deseo de crear la solución definitiva.',
              isItalic: true
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.accentBlue,
        ),
      ),
    );
  }

  Widget _buildSubSectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text, {bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
          height: 1.6,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.accentBlue, fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
