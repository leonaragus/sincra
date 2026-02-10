// ========================================================================
// SERVICIO DE ALERTAS PROACTIVAS
// Genera alertas automáticas para prevenir errores y mejorar gestión
// ========================================================================

import '../models/empleado_completo.dart';
import '../models/prestamo.dart';
import '../models/ausencia.dart';

class AlertaProactiva {
  final String id;
  final String tipo; // 'critica', 'alta', 'media', 'baja'
  final String categoria; // 'paritarias', 'empleado', 'prestamo', 'ausencia', 'cct'
  final String titulo;
  final String descripcion;
  final String? accionRecomendada;
  final DateTime fechaCreacion;
  final String? entidadId; // CUIL, ID de préstamo, etc.
  final String? entidadNombre;
  
  AlertaProactiva({
    required this.id,
    required this.tipo,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
    this.accionRecomendada,
    required this.fechaCreacion,
    this.entidadId,
    this.entidadNombre,
  });
  
  bool get esCritica => tipo == 'critica';
  bool get esAlta => tipo == 'alta';
  bool get esMedia => tipo == 'media';
  bool get esBaja => tipo == 'baja';
}

class ResumenAlertas {
  final int totalAlertas;
  final int criticas;
  final int altas;
  final int medias;
  final int bajas;
  final List<AlertaProactiva> alertas;
  
  ResumenAlertas({
    required this.totalAlertas,
    required this.criticas,
    required this.altas,
    required this.medias,
    required this.bajas,
    required this.alertas,
  });
}

class AlertasProactivasService {
  /// Genera todas las alertas del sistema
  static Future<ResumenAlertas> generarAlertasCompletas({
    required List<EmpleadoCompleto> empleados,
    List<Prestamo>? prestamos,
    List<Ausencia>? ausencias,
    DateTime? fechaUltimaActualizacionParitarias,
    DateTime? fechaUltimaActualizacionCCT,
  }) async {
    final alertas = <AlertaProactiva>[];
    
    // 1. ALERTAS DE EMPLEADOS
    alertas.addAll(_generarAlertasEmpleados(empleados));
    
    // 2. ALERTAS DE PRÉSTAMOS
    if (prestamos != null) {
      alertas.addAll(_generarAlertasPrestamos(prestamos, empleados));
    }
    
    // 3. ALERTAS DE AUSENCIAS
    if (ausencias != null) {
      alertas.addAll(_generarAlertasAusencias(ausencias, empleados));
    }
    
    // 4. ALERTAS DE PARITARIAS
    if (fechaUltimaActualizacionParitarias != null) {
      alertas.addAll(_generarAlertasParitarias(fechaUltimaActualizacionParitarias));
    }
    
    // 5. ALERTAS DE CCT
    if (fechaUltimaActualizacionCCT != null) {
      alertas.addAll(_generarAlertasCCT(fechaUltimaActualizacionCCT));
    }
    
    // Ordenar por tipo (críticas primero)
    alertas.sort((a, b) {
      const orden = {'critica': 0, 'alta': 1, 'media': 2, 'baja': 3};
      return orden[a.tipo]!.compareTo(orden[b.tipo]!);
    });
    
    final criticas = alertas.where((a) => a.esCritica).length;
    final altas = alertas.where((a) => a.esAlta).length;
    final medias = alertas.where((a) => a.esMedia).length;
    final bajas = alertas.where((a) => a.esBaja).length;
    
    return ResumenAlertas(
      totalAlertas: alertas.length,
      criticas: criticas,
      altas: altas,
      medias: medias,
      bajas: bajas,
      alertas: alertas,
    );
  }
  
  /// Genera alertas relacionadas con empleados
  static List<AlertaProactiva> _generarAlertasEmpleados(List<EmpleadoCompleto> empleados) {
    final alertas = <AlertaProactiva>[];
    final hoy = DateTime.now();
    
    for (final empleado in empleados) {
      // ALERTA 1: Cumpleaños de antigüedad próximo (30 días)
      final antiguedadAnios = hoy.difference(empleado.fechaIngreso).inDays ~/ 365;
      final proximoCumpleAnios = empleado.fechaIngreso.add(Duration(days: (antiguedadAnios + 1) * 365));
      final diasHastaProximoCumple = proximoCumpleAnios.difference(hoy).inDays;
      
      if (diasHastaProximoCumple > 0 && diasHastaProximoCumple <= 30) {
        alertas.add(AlertaProactiva(
          id: 'emp_antig_${empleado.cuil}',
          tipo: 'media',
          categoria: 'empleado',
          titulo: 'Cumpleaños de antigüedad próximo',
          descripcion: '${empleado.nombreCompleto} cumplirá ${antiguedadAnios + 1} años de antigüedad '
              'en $diasHastaProximoCumple días (${proximoCumpleAnios.toString().split(' ')[0]})',
          accionRecomendada: 'Actualizar porcentaje de antigüedad en próxima liquidación',
          fechaCreacion: hoy,
          entidadId: empleado.cuil,
          entidadNombre: empleado.nombreCompleto,
        ));
      }
      
      // ALERTA 2: Empleado sin CBU (alta prioridad si lleva más de 1 mes)
      if (empleado.cbu == null || empleado.cbu!.isEmpty) {
        final diasDesdeIngreso = hoy.difference(empleado.fechaIngreso).inDays;
        if (diasDesdeIngreso > 30) {
          alertas.add(AlertaProactiva(
            id: 'emp_cbu_${empleado.cuil}',
            tipo: 'alta',
            categoria: 'empleado',
            titulo: 'Empleado sin CBU',
            descripcion: '${empleado.nombreCompleto} no tiene CBU configurado. '
                'Lleva ${(diasDesdeIngreso / 30).floor()} meses en la empresa.',
            accionRecomendada: 'Solicitar CBU al empleado para pagos electrónicos',
            fechaCreacion: hoy,
            entidadId: empleado.cuil,
            entidadNombre: empleado.nombreCompleto,
          ));
        }
      }
      
      // ALERTA 3: Empleado sin código RNOS (crítico)
      if (empleado.codigoRnos == null || empleado.codigoRnos!.isEmpty) {
        alertas.add(AlertaProactiva(
          id: 'emp_rnos_${empleado.cuil}',
          tipo: 'critica',
          categoria: 'empleado',
          titulo: 'Empleado sin código RNOS',
          descripcion: '${empleado.nombreCompleto} no tiene obra social configurada. '
              'Esto impedirá la exportación del LSD.',
          accionRecomendada: 'Solicitar código RNOS al empleado y actualizar en sistema',
          fechaCreacion: hoy,
          entidadId: empleado.cuil,
          entidadNombre: empleado.nombreCompleto,
        ));
      }
      
      // ALERTA 4: Empleado sin categoría (crítico)
      if (empleado.categoria.isEmpty) {
        alertas.add(AlertaProactiva(
          id: 'emp_cat_${empleado.cuil}',
          tipo: 'critica',
          categoria: 'empleado',
          titulo: 'Empleado sin categoría',
          descripcion: '${empleado.nombreCompleto} no tiene categoría asignada. '
              'No podrá liquidarse correctamente.',
          accionRecomendada: 'Asignar categoría según convenio colectivo',
          fechaCreacion: hoy,
          entidadId: empleado.cuil,
          entidadNombre: empleado.nombreCompleto,
        ));
      }
      
      // ALERTA 5: Empleado sin email (baja prioridad)
      final email = empleado.email ?? '';
      if (email.isEmpty) {
        alertas.add(AlertaProactiva(
          id: 'emp_email_${empleado.cuil}',
          tipo: 'baja',
          categoria: 'empleado',
          titulo: 'Empleado sin email',
          descripcion: '${empleado.nombreCompleto} no tiene email registrado.',
          accionRecomendada: 'Solicitar email para envío de recibos digitales',
          fechaCreacion: hoy,
          entidadId: empleado.cuil,
          entidadNombre: empleado.nombreCompleto,
        ));
      }
      
      // ALERTA 6: Empleado próximo a jubilarse (65 años)
      if (empleado.fechaNacimiento != null) {
        final edad = hoy.difference(empleado.fechaNacimiento!).inDays ~/ 365;
        if (edad >= 63 && edad < 65) {
          alertas.add(AlertaProactiva(
            id: 'emp_jubilacion_${empleado.cuil}',
            tipo: 'media',
            categoria: 'empleado',
            titulo: 'Empleado próximo a jubilarse',
            descripcion: '${empleado.nombreCompleto} tiene $edad años. '
                'Edad jubilatoria: 65 años.',
            accionRecomendada: 'Consultar con empleado sobre planes de jubilación',
            fechaCreacion: hoy,
            entidadId: empleado.cuil,
            entidadNombre: empleado.nombreCompleto,
          ));
        }
      }
    }
    
    return alertas;
  }
  
  /// Genera alertas relacionadas con préstamos
  static List<AlertaProactiva> _generarAlertasPrestamos(
    List<Prestamo> prestamos,
    List<EmpleadoCompleto> empleados,
  ) {
    final alertas = <AlertaProactiva>[];
    
    for (final prestamo in prestamos) {
      if (prestamo.estado == 'activo') {
        // Encontrar empleado
        final matchingEmpleados = empleados.where((e) => e.cuil == prestamo.empleadoCuil);
        final EmpleadoCompleto? empleado = matchingEmpleados.isNotEmpty ? matchingEmpleados.first : null;
        final nombreEmpleado = empleado?.nombreCompleto ?? 'Empleado ${prestamo.empleadoCuil}';
        
        // ALERTA 1: Préstamo próximo a completarse (quedan 3 cuotas o menos)
        final cuotasRestantes = prestamo.cantidadCuotas - prestamo.cuotasPagadas;
        if (cuotasRestantes <= 3 && cuotasRestantes > 0) {
          alertas.add(AlertaProactiva(
            id: 'prest_final_${prestamo.id}',
            tipo: 'media',
            categoria: 'prestamo',
            titulo: 'Préstamo próximo a finalizar',
            descripcion: '$nombreEmpleado tiene un préstamo que finaliza en $cuotasRestantes cuotas. '
                'Monto restante: \$${(prestamo.montoTotal - prestamo.montoPagado).toStringAsFixed(2)}',
            accionRecomendada: 'Verificar que las cuotas se estén descontando correctamente',
            fechaCreacion: DateTime.now(),
            entidadId: prestamo.id,
            entidadNombre: nombreEmpleado,
          ));
        }
        
        // ALERTA 2: Préstamo con cuota muy alta (>20% del sueldo estimado)
        // Nota: Necesitaríamos el sueldo, pero hacemos una alerta general si la cuota es > $200k
        if (prestamo.valorCuota > 200000) {
          alertas.add(AlertaProactiva(
            id: 'prest_cuota_alta_${prestamo.id}',
            tipo: 'alta',
            categoria: 'prestamo',
            titulo: 'Cuota de préstamo muy alta',
            descripcion: '$nombreEmpleado tiene una cuota mensual de \$${prestamo.valorCuota.toStringAsFixed(2)}. '
                'Verificar que no exceda 20% del salario neto.',
            accionRecomendada: 'Revisar capacidad de pago del empleado',
            fechaCreacion: DateTime.now(),
            entidadId: prestamo.id,
            entidadNombre: nombreEmpleado,
          ));
        }
      }
    }
    
    return alertas;
  }
  
  /// Genera alertas relacionadas con ausencias
  static List<AlertaProactiva> _generarAlertasAusencias(
    List<Ausencia> ausencias,
    List<EmpleadoCompleto> empleados,
  ) {
    final alertas = <AlertaProactiva>[];
    final hoy = DateTime.now();
    
    for (final ausencia in ausencias) {
      // Solo alertas para ausencias pendientes o activas
      if (ausencia.estado == 'pendiente' || ausencia.estado == 'aprobada') {
        final matchingEmpleados = empleados.where((e) => e.cuil == ausencia.empleadoCuil);
        final EmpleadoCompleto? empleado = matchingEmpleados.isNotEmpty ? matchingEmpleados.first : null;
        final nombreEmpleado = empleado?.nombreCompleto ?? 'Empleado ${ausencia.empleadoCuil}';
        
        // ALERTA 1: Ausencia pendiente de aprobación
        if (ausencia.estado == 'pendiente') {
          final diasDesde = hoy.difference(ausencia.fechaDesde).inDays;
          alertas.add(AlertaProactiva(
            id: 'aus_pend_${ausencia.id}',
            tipo: 'alta',
            categoria: 'ausencia',
            titulo: 'Ausencia pendiente de aprobación',
            descripcion: '$nombreEmpleado tiene una ausencia (${ausencia.tipo}) '
                'pendiente desde hace $diasDesde días.',
            accionRecomendada: 'Aprobar o rechazar la solicitud',
            fechaCreacion: hoy,
            entidadId: ausencia.id,
            entidadNombre: nombreEmpleado,
          ));
        }
        
        // ALERTA 2: Ausencia próxima a vencer (quedan 7 días o menos)
        if (ausencia.estado == 'aprobada') {
          final diasHastaFin = ausencia.fechaHasta.difference(hoy).inDays;
          if (diasHastaFin > 0 && diasHastaFin <= 7) {
            alertas.add(AlertaProactiva(
              id: 'aus_venc_${ausencia.id}',
              tipo: 'media',
              categoria: 'ausencia',
              titulo: 'Ausencia próxima a finalizar',
              descripcion: '$nombreEmpleado regresa de ${ausencia.tipo} en $diasHastaFin días '
                  '(${ausencia.fechaHasta.toString().split(' ')[0]}).',
              accionRecomendada: 'Planificar reincorporación del empleado',
              fechaCreacion: hoy,
              entidadId: ausencia.id,
              entidadNombre: nombreEmpleado,
            ));
          }
        }
      }
    }
    
    return alertas;
  }
  
  /// Genera alertas relacionadas con paritarias
  static List<AlertaProactiva> _generarAlertasParitarias(DateTime fechaUltimaActualizacion) {
    final alertas = <AlertaProactiva>[];
    final hoy = DateTime.now();
    final diasDesdeActualizacion = hoy.difference(fechaUltimaActualizacion).inDays;
    
    // ALERTA 1: Paritarias desactualizadas (>60 días)
    if (diasDesdeActualizacion > 60) {
      alertas.add(AlertaProactiva(
        id: 'parit_desact',
        tipo: 'alta',
        categoria: 'paritarias',
        titulo: 'Paritarias desactualizadas',
        descripcion: 'Las paritarias no se actualizan hace $diasDesdeActualizacion días '
            '(última actualización: ${fechaUltimaActualizacion.toString().split(' ')[0]}).',
        accionRecomendada: 'Verificar si hay nuevos acuerdos paritarios y actualizar escalas salariales',
        fechaCreacion: hoy,
      ));
    } else if (diasDesdeActualizacion > 30) {
      // ALERTA 2: Paritarias próximas a desactualizarse (>30 días)
      alertas.add(AlertaProactiva(
        id: 'parit_prox_desact',
        tipo: 'media',
        categoria: 'paritarias',
        titulo: 'Paritarias próximas a desactualizarse',
        descripcion: 'Las paritarias no se actualizan hace $diasDesdeActualizacion días.',
        accionRecomendada: 'Revisar si hay actualizaciones disponibles',
        fechaCreacion: hoy,
      ));
    }
    
    return alertas;
  }
  
  /// Genera alertas relacionadas con CCT
  static List<AlertaProactiva> _generarAlertasCCT(DateTime fechaUltimaActualizacion) {
    final alertas = <AlertaProactiva>[];
    final hoy = DateTime.now();
    final diasDesdeActualizacion = hoy.difference(fechaUltimaActualizacion).inDays;
    
    // ALERTA 1: CCT desactualizados (>90 días)
    if (diasDesdeActualizacion > 90) {
      alertas.add(AlertaProactiva(
        id: 'cct_desact',
        tipo: 'alta',
        categoria: 'cct',
        titulo: 'CCT desactualizados',
        descripcion: 'Los convenios colectivos no se actualizan hace $diasDesdeActualizacion días '
            '(última actualización: ${fechaUltimaActualizacion.toString().split(' ')[0]}).',
        accionRecomendada: 'Ejecutar robot de actualización de CCT (actualizar_cct.bat)',
        fechaCreacion: hoy,
      ));
    } else if (diasDesdeActualizacion > 60) {
      // ALERTA 2: CCT próximos a desactualizarse (>60 días)
      alertas.add(AlertaProactiva(
        id: 'cct_prox_desact',
        tipo: 'media',
        categoria: 'cct',
        titulo: 'CCT próximos a desactualizarse',
        descripcion: 'Los convenios colectivos no se actualizan hace $diasDesdeActualizacion días.',
        accionRecomendada: 'Planificar próxima actualización de CCT',
        fechaCreacion: hoy,
      ));
    }
    
    return alertas;
  }
}
