
class LSDHeader {
  String tipoRegistro; // 1
  String cuitEmpresa; // 11
  String periodo; // 6
  String fechaPago; // 8
  String razonSocial; // 30
  String domicilio; // 40
  String extra; // 99

  LSDHeader({
    required this.tipoRegistro,
    required this.cuitEmpresa,
    required this.periodo,
    required this.fechaPago,
    required this.razonSocial,
    required this.domicilio,
    required this.extra,
  });

  String toLine() {
    return '$tipoRegistro$cuitEmpresa$periodo$fechaPago$razonSocial$domicilio$extra';
  }
}

class LSDLegajoRef {
  String tipoRegistro; // 2
  String cuil; // 11
  String legajo; // 10
  String cbu; // 22
  String diasBase; // 3
  String extra; // 148

  LSDLegajoRef({
    required this.tipoRegistro,
    required this.cuil,
    required this.legajo,
    required this.cbu,
    required this.diasBase,
    required this.extra,
  });

  String toLine() {
    return '$tipoRegistro$cuil$legajo$cbu$diasBase$extra';
  }
}

class LSDConcepto {
  String tipoRegistro; // 3
  String cuil; // 11
  String codigo; // 10
  String cantidad; // 4
  String tipo; // 1
  String importe; // 15
  String descripcion; // 153

  LSDConcepto({
    required this.tipoRegistro,
    required this.cuil,
    required this.codigo,
    required this.cantidad,
    required this.tipo,
    required this.importe,
    required this.descripcion,
  });

  double get importeAsDouble {
    try {
      return double.parse(importe) / 100;
    } catch (e) {
      return 0.0;
    }
  }

  String toLine() {
    return '$tipoRegistro$cuil$codigo$cantidad$tipo$importe$descripcion';
  }
}

class LSDBases {
  String tipoRegistro; // 4
  String cuil; // 11
  List<String> bases; // 10 bases de 15 chars
  String extra; // 33

  LSDBases({
    required this.tipoRegistro,
    required this.cuil,
    required this.bases,
    required this.extra,
  });

  double getBaseAsDouble(int index) {
    if (index < 0 || index >= bases.length) return 0.0;
    try {
      return double.parse(bases[index]) / 100;
    } catch (e) {
      return 0.0;
    }
  }

  String toLine() {
    return '$tipoRegistro$cuil${bases.join()}$extra';
  }
}

class LSDComplementarios {
  String tipoRegistro; // 5
  String cuil; // 11
  String rnos; // 6
  String cantFamiliares; // 4
  String adherentes; // 1
  String actividad; // 3
  String puesto; // 4
  String condicion; // 2
  String modalidad; // 3
  String siniestrado; // 2
  String zona; // 1
  String extra; // 157

  LSDComplementarios({
    required this.tipoRegistro,
    required this.cuil,
    required this.rnos,
    required this.cantFamiliares,
    required this.adherentes,
    required this.actividad,
    required this.puesto,
    required this.condicion,
    required this.modalidad,
    required this.siniestrado,
    required this.zona,
    required this.extra,
  });

  String toLine() {
    return '$tipoRegistro$cuil$rnos$cantFamiliares$adherentes$actividad$puesto$condicion$modalidad$siniestrado$zona$extra';
  }
}

class LSDParsedFile {
  LSDHeader? header;
  List<LSDLegajoRef> referencias = [];
  List<LSDConcepto> conceptos = [];
  List<LSDBases> bases = [];
  List<LSDComplementarios> complementarios = [];
  List<String> erroresParsing = [];

  bool get isValid => erroresParsing.isEmpty && header != null;
}
