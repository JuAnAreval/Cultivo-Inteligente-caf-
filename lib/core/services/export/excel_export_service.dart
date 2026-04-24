import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:app_flutter_ai/core/services/auth/session_service.dart';
import 'package:app_flutter_ai/core/services/shared/database_helper.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

class ExportFileInfo {
  const ExportFileInfo({
    required this.fileName,
    required this.filePath,
    required this.itemCount,
    this.modifiedAt,
  });

  final String fileName;
  final String filePath;
  final int itemCount;
  final DateTime? modifiedAt;
}

class ExportBatchResult {
  const ExportBatchResult({
    required this.title,
    required this.files,
  });

  final String title;
  final List<ExportFileInfo> files;

  int get totalFiles => files.length;

  int get totalItems => files.fold(0, (total, file) => total + file.itemCount);
}

class CosechaExportSummary {
  const CosechaExportSummary({
    required this.totalRecords,
    required this.years,
  });

  final int totalRecords;
  final List<int> years;
}

class ExcelExportService {
  static const String _actividadesTemplateAsset =
      'forms/Control de actividades en campo.xlsx';
  static const String _insumosTemplateAsset =
      'forms/Seguimiento y control de insumos.xlsx';
  static const String _cosechasTemplateAsset =
      'forms/Registro de cosecha.xlsx';

  static const String _actividadesSheetPath = 'xl/worksheets/sheet3.xml';
  static const String _insumosSheetPath = 'xl/worksheets/sheet1.xml';
  static const String _cosechasSheetPath = 'xl/worksheets/sheet1.xml';

  static const int _actividadesRowsPerFile = 8;
  static const int _insumosRowsPerFile = 9;
  static const int _cosechasRowsPerFile = 11;

  static Future<List<Map<String, dynamic>>> getAvailableFincas() async {
    return DatabaseHelper().getVisibleFincas(createdBy: SessionService.userId);
  }

  static Future<List<Map<String, dynamic>>> getAvailableLotesByFinca(
    int fincaLocalId,
  ) async {
    return DatabaseHelper().getVisibleLotesByFinca(fincaLocalId);
  }

  static Future<int> countActividadesByLote(int loteLocalId) async {
    final rows = await DatabaseHelper().getVisibleActividadesByLote(loteLocalId);
    return rows.length;
  }

  static Future<int> countInsumosByLote(int loteLocalId) async {
    final rows = await DatabaseHelper().getVisibleInsumosByLote(loteLocalId);
    return rows.length;
  }

  static Future<CosechaExportSummary> getCosechaSummaryByFinca(
    int fincaLocalId,
  ) async {
    final currentYear = DateTime.now().year;
    final rows = await DatabaseHelper().getVisibleCosechasByFinca(fincaLocalId);
    final currentYearRows = rows
        .where((row) => (_extractYear(row) ?? currentYear) == currentYear)
        .toList();

    return CosechaExportSummary(
      totalRecords: currentYearRows.length,
      years: currentYearRows.isEmpty ? const [] : [currentYear],
    );
  }

  static Future<List<ExportFileInfo>> getExportHistory({
    int limit = 20,
  }) async {
    final directory = await _resolveExportDirectory();
    if (!await directory.exists()) {
      return const [];
    }

    final files = <ExportFileInfo>[];
    await for (final entity in directory.list()) {
      if (entity is! File || path.extension(entity.path).toLowerCase() != '.xlsx') {
        continue;
      }

      final stat = await entity.stat();
      files.add(
        ExportFileInfo(
          fileName: path.basename(entity.path),
          filePath: entity.path,
          itemCount: 0,
          modifiedAt: stat.modified,
        ),
      );
    }

    files.sort((left, right) {
      final rightDate = right.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final leftDate = left.modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });

    return files.take(limit).toList();
  }

  static Future<void> deleteExportFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<ExportBatchResult> exportActividades({
    required int loteLocalId,
  }) async {
    final database = DatabaseHelper();
    final lote = await database.getLoteByLocalId(loteLocalId);
    if (lote == null) {
      throw Exception('No se encontró el lote seleccionado.');
    }

    final fincaLocalId = DatabaseHelper.toInt(lote['finca_local_id']);
    final finca = fincaLocalId == null
        ? null
        : await database.getFincaByLocalId(fincaLocalId);

    final actividades = await database.getVisibleActividadesByLote(loteLocalId);
    if (actividades.isEmpty) {
      throw Exception('Este lote aún no tiene actividades para exportar.');
    }

    final files = <ExportFileInfo>[];
    final chunks = _chunkRows(actividades, _actividadesRowsPerFile);
    final fincaName = (finca?['nombre'] ?? 'finca').toString();
    final loteName = (lote['nombre_lote'] ?? 'lote').toString();

    for (var index = 0; index < chunks.length; index++) {
      final archive = await _loadArchiveFromAsset(_actividadesTemplateAsset);
      final sheet = _loadXmlFile(archive, _actividadesSheetPath);

      for (var rowIndex = 0; rowIndex < chunks[index].length; rowIndex++) {
        final rowNumber = 10 + rowIndex;
        final actividad = chunks[index][rowIndex];
        _setCellString(sheet, 'A$rowNumber', (actividad['actividad'] ?? '').toString());
        _setCellString(sheet, 'C$rowNumber', _formatDate(actividad['fecha']));
        _setCellString(
          sheet,
          'D$rowNumber',
          (actividad['aplicaciones'] ?? '').toString(),
        );
        _setCellString(sheet, 'E$rowNumber', (actividad['dosis'] ?? '').toString());
        _setCellString(
          sheet,
          'F$rowNumber',
          (actividad['observaciones_responsable'] ?? '').toString(),
        );
      }

      _replaceXmlFile(archive, _actividadesSheetPath, sheet);

      final partSuffix = chunks.length > 1 ? '_parte_${index + 1}' : '';
      final fileName =
          'actividades_${_slug(fincaName)}_${_slug(loteName)}$partSuffix.xlsx';
      final outputFile = await _writeArchiveToFile(archive, fileName);
      files.add(
        ExportFileInfo(
          fileName: fileName,
          filePath: outputFile.path,
          itemCount: chunks[index].length,
          modifiedAt: DateTime.now(),
        ),
      );
    }

    return ExportBatchResult(
      title: 'Actividades de $loteName',
      files: files,
    );
  }

  static Future<ExportBatchResult> exportInsumos({
    required int loteLocalId,
  }) async {
    final database = DatabaseHelper();
    final lote = await database.getLoteByLocalId(loteLocalId);
    if (lote == null) {
      throw Exception('No se encontró el lote seleccionado.');
    }

    final fincaLocalId = DatabaseHelper.toInt(lote['finca_local_id']);
    final finca = fincaLocalId == null
        ? null
        : await database.getFincaByLocalId(fincaLocalId);

    final insumos = await database.getVisibleInsumosByLote(loteLocalId);
    if (insumos.isEmpty) {
      throw Exception('Este lote aún no tiene insumos para exportar.');
    }

    final files = <ExportFileInfo>[];
    final chunks = _chunkRows(insumos, _insumosRowsPerFile);
    final fincaName = (finca?['nombre'] ?? 'finca').toString();
    final loteName = (lote['nombre_lote'] ?? 'lote').toString();

    for (var index = 0; index < chunks.length; index++) {
      final archive = await _loadArchiveFromAsset(_insumosTemplateAsset);
      final sheet = _loadXmlFile(archive, _insumosSheetPath);

      _setCellString(sheet, 'B8', _producerName);
      _setCellString(sheet, 'E8', (finca?['ubicacion_texto'] ?? '').toString());
      _setCellString(sheet, 'B10', (lote['tipo_cafe'] ?? '').toString());
      _setCellString(sheet, 'D10', _formatNumber(lote['hectareas_lote']));
      _setCellString(sheet, 'F10', loteName);

      for (var rowIndex = 0; rowIndex < chunks[index].length; rowIndex++) {
        final rowNumber = 13 + rowIndex;
        final insumo = chunks[index][rowIndex];
        _setCellString(sheet, 'A$rowNumber', (insumo['insumo'] ?? '').toString());
        _setCellString(
          sheet,
          'B$rowNumber',
          (insumo['ingredientes_activos'] ?? '').toString(),
        );
        _setCellString(sheet, 'C$rowNumber', _formatDate(insumo['fecha']));
        _setCellString(sheet, 'D$rowNumber', (insumo['tipo'] ?? '').toString());
        _setCellString(sheet, 'E$rowNumber', (insumo['origen'] ?? '').toString());
        _setCellString(sheet, 'F$rowNumber', (insumo['factura'] ?? '').toString());
      }

      _replaceXmlFile(archive, _insumosSheetPath, sheet);

      final partSuffix = chunks.length > 1 ? '_parte_${index + 1}' : '';
      final fileName =
          'insumos_${_slug(fincaName)}_${_slug(loteName)}$partSuffix.xlsx';
      final outputFile = await _writeArchiveToFile(archive, fileName);
      files.add(
        ExportFileInfo(
          fileName: fileName,
          filePath: outputFile.path,
          itemCount: chunks[index].length,
          modifiedAt: DateTime.now(),
        ),
      );
    }

    return ExportBatchResult(
      title: 'Insumos de $loteName',
      files: files,
    );
  }

  static Future<ExportBatchResult> exportCosechas({
    required int fincaLocalId,
  }) async {
    final database = DatabaseHelper();
    final finca = await database.getFincaByLocalId(fincaLocalId);
    if (finca == null) {
      throw Exception('No se encontró la finca seleccionada.');
    }

    final currentYear = DateTime.now().year;
    final cosechas = await database.getVisibleCosechasByFinca(fincaLocalId);
    final currentYearRows = cosechas
        .where((row) => (_extractYear(row) ?? currentYear) == currentYear)
        .toList();
    if (currentYearRows.isEmpty) {
      throw Exception('Esta finca aún no tiene cosechas del año actual para exportar.');
    }

    final files = <ExportFileInfo>[];
    final fincaName = (finca['nombre'] ?? 'finca').toString();
    final chunks = _chunkRows(currentYearRows, _cosechasRowsPerFile);

    for (var index = 0; index < chunks.length; index++) {
      final archive = await _loadArchiveFromAsset(_cosechasTemplateAsset);
      final sheet = _loadXmlFile(archive, _cosechasSheetPath);
      final chunk = chunks[index];

      _setCellString(sheet, 'B5', _producerName);
      _setCellString(sheet, 'E5', currentYear.toString());

      double totalCereza = 0;
      double totalPergamino = 0;

      for (var rowIndex = 0; rowIndex < chunk.length; rowIndex++) {
        final rowNumber = 7 + rowIndex;
        final cosecha = chunk[rowIndex];
        final kilosCereza = DatabaseHelper.toDouble(cosecha['kilos_cereza']) ?? 0;
        final kilosPergamino =
            DatabaseHelper.toDouble(cosecha['kilos_pergamino']) ?? 0;

        totalCereza += kilosCereza;
        totalPergamino += kilosPergamino;

        _setCellString(sheet, 'A$rowNumber', _formatDate(cosecha['fecha']));
        _setCellNumber(sheet, 'B$rowNumber', kilosCereza);
        _setCellNumber(sheet, 'C$rowNumber', kilosPergamino);
        _setCellString(sheet, 'D$rowNumber', (cosecha['proceso'] ?? '').toString());
        _setCellString(
          sheet,
          'E$rowNumber',
          (finca['ubicacion_texto'] ?? '').toString(),
        );
        _setCellString(sheet, 'F$rowNumber', fincaName);
      }

      _setCellNumber(sheet, 'B18', totalCereza);
      _setCellNumber(sheet, 'C18', totalPergamino);
      _replaceXmlFile(archive, _cosechasSheetPath, sheet);

      final partSuffix = chunks.length > 1 ? '_parte_${index + 1}' : '';
      final fileName =
          'cosechas_${_slug(fincaName)}_$currentYear$partSuffix.xlsx';
      final outputFile = await _writeArchiveToFile(archive, fileName);
      files.add(
        ExportFileInfo(
          fileName: fileName,
          filePath: outputFile.path,
          itemCount: chunk.length,
          modifiedAt: DateTime.now(),
        ),
      );
    }

    return ExportBatchResult(
      title: 'Cosechas de $fincaName',
      files: files,
    );
  }

  static Future<Archive> _loadArchiveFromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return ZipDecoder().decodeBytes(bytes);
  }

  static XmlDocument _loadXmlFile(Archive archive, String filePath) {
    final file = archive.findFile(filePath);
    if (file == null) {
      throw Exception('No se encontró el archivo $filePath dentro de la plantilla.');
    }

    final content = file.content;
    if (content is! List<int>) {
      throw Exception('La plantilla $filePath no se pudo leer correctamente.');
    }

    return XmlDocument.parse(utf8.decode(content));
  }

  static void _replaceXmlFile(
    Archive archive,
    String filePath,
    XmlDocument document,
  ) {
    final bytes = utf8.encode(document.toXmlString(pretty: false));
    final replacement = ArchiveFile(filePath, bytes.length, bytes);
    archive.addFile(replacement);
  }

  static Future<File> _writeArchiveToFile(
    Archive archive,
    String fileName,
  ) async {
    final directory = await _resolveExportDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeName = path.setExtension(
      '${path.basenameWithoutExtension(fileName)}_$timestamp',
      '.xlsx',
    );
    final outputFile = File(path.join(directory.path, safeName));
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw Exception('No fue posible generar el archivo Excel.');
    }

    await outputFile.writeAsBytes(bytes, flush: true);
    return outputFile;
  }

  static Future<Directory> _resolveExportDirectory() async {
    Directory? baseDirectory = await getExternalStorageDirectory();
    baseDirectory ??= await getApplicationDocumentsDirectory();

    final exportDirectory = Directory(path.join(baseDirectory.path, 'exports'));
    await exportDirectory.create(recursive: true);
    return exportDirectory;
  }

  static List<List<Map<String, dynamic>>> _chunkRows(
    List<Map<String, dynamic>> rows,
    int chunkSize,
  ) {
    final chunks = <List<Map<String, dynamic>>>[];
    for (var index = 0; index < rows.length; index += chunkSize) {
      final end =
          index + chunkSize > rows.length ? rows.length : index + chunkSize;
      chunks.add(rows.sublist(index, end));
    }
    return chunks;
  }

  static void _setCellString(
    XmlDocument document,
    String cellReference,
    String value,
  ) {
    final cell = _ensureCell(document, cellReference);
    _removeValueChildren(cell);
    _removeAttribute(cell, 't');

    if (value.trim().isEmpty) {
      return;
    }

    _setAttribute(cell, 't', 'inlineStr');
    final textAttributes = <XmlAttribute>[];
    if (value.startsWith(' ') || value.endsWith(' ')) {
      textAttributes.add(XmlAttribute(XmlName('space', 'xml'), 'preserve'));
    }

    cell.children.add(
      XmlElement(
        XmlName('is'),
        const [],
        [
          XmlElement(
            XmlName('t'),
            textAttributes,
            [XmlText(value)],
          ),
        ],
      ),
    );
  }

  static void _setCellNumber(
    XmlDocument document,
    String cellReference,
    double value,
  ) {
    final cell = _ensureCell(document, cellReference);
    _removeValueChildren(cell);
    _removeAttribute(cell, 't');
    cell.children.add(
      XmlElement(
        XmlName('v'),
        const [],
        [XmlText(_numericCellValue(value))],
      ),
    );
  }

  static XmlElement _ensureCell(XmlDocument document, String cellReference) {
    final rowNumber = int.tryParse(
      RegExp(r'\d+').firstMatch(cellReference)?.group(0) ?? '',
    );
    if (rowNumber == null) {
      throw Exception('Referencia de celda inválida: $cellReference');
    }

    final sheetData = document.descendants
        .whereType<XmlElement>()
        .firstWhere((element) => element.name.local == 'sheetData');

    XmlElement? row;
    for (final element in sheetData.children.whereType<XmlElement>()) {
      if (element.name.local == 'row' &&
          element.getAttribute('r') == '$rowNumber') {
        row = element;
        break;
      }
    }

    row ??= XmlElement(
      XmlName('row'),
      [XmlAttribute(XmlName('r'), '$rowNumber')],
      const [],
    );

    if (!sheetData.children.contains(row)) {
      sheetData.children.add(row);
    }

    for (final element in row.children.whereType<XmlElement>()) {
      if (element.name.local == 'c' &&
          element.getAttribute('r') == cellReference) {
        return element;
      }
    }

    final cell = XmlElement(
      XmlName('c'),
      [XmlAttribute(XmlName('r'), cellReference)],
      const [],
    );
    row.children.add(cell);
    return cell;
  }

  static void _removeValueChildren(XmlElement cell) {
    cell.children.removeWhere((node) {
      return node is XmlElement &&
          (node.name.local == 'v' ||
              node.name.local == 'is' ||
              node.name.local == 'f');
    });
  }

  static void _setAttribute(XmlElement element, String name, String value) {
    final index =
        element.attributes.indexWhere((attribute) => attribute.name.local == name);
    if (index >= 0) {
      element.attributes[index] = XmlAttribute(XmlName(name), value);
      return;
    }

    element.attributes.add(XmlAttribute(XmlName(name), value));
  }

  static void _removeAttribute(XmlElement element, String name) {
    element.attributes.removeWhere((attribute) => attribute.name.local == name);
  }

  static int? _extractYear(Map<String, dynamic> row) {
    final explicitYear = DatabaseHelper.toInt(row['anio'] ?? row['año']);
    if (explicitYear != null) {
      return explicitYear;
    }

    final rawDate = row['fecha']?.toString();
    if (rawDate == null || rawDate.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawDate)?.year;
  }

  static String _formatDate(dynamic rawValue) {
    final value = rawValue?.toString().trim();
    if (value == null || value.isEmpty) {
      return '';
    }

    final parsedDate = DateTime.tryParse(value);
    if (parsedDate == null) {
      final match = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(value);
      if (match != null) {
        final normalized = DateTime.tryParse(match.group(0)!);
        if (normalized != null) {
          return DateFormat('dd/MM/yyyy').format(normalized);
        }
      }
      return value;
    }

    return DateFormat('dd/MM/yyyy').format(parsedDate);
  }

  static String _formatNumber(dynamic rawValue) {
    final value = DatabaseHelper.toDouble(rawValue);
    if (value == null) {
      return '';
    }

    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  static String _numericCellValue(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  static String get _producerName {
    final userName = SessionService.userName?.trim();
    if (userName != null && userName.isNotEmpty) {
      return userName;
    }

    final email = SessionService.userEmail?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Productor';
  }

  static String _slug(String value) {
    final replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ñ': 'n',
    };

    var normalized = value.toLowerCase();
    replacements.forEach((key, replacement) {
      normalized = normalized.replaceAll(key, replacement);
    });

    final cleaned = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return cleaned.isEmpty ? 'archivo' : cleaned;
  }
}
