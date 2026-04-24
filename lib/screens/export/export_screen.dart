import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/export/excel_export_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

enum _ExportMode { finca, lote }

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isLoading = true;
  bool _isExportingLote = false;
  bool _isExportingCosechas = false;
  bool _isLoadingHistory = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _fincas = const [];
  List<Map<String, dynamic>> _lotes = const [];
  List<ExportFileInfo> _recentFiles = const [];

  _ExportMode _selectedMode = _ExportMode.finca;
  int? _selectedFincaForLotesId;
  int? _selectedLoteId;
  int? _selectedFincaForCosechasId;

  int _actividadesCount = 0;
  int _insumosCount = 0;
  CosechaExportSummary _cosechaSummary = const CosechaExportSummary(
    totalRecords: 0,
    years: [],
  );

  @override
  void initState() {
    super.initState();
    _loadExportData();
  }

  Future<void> _loadExportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fincas = await ExcelExportService.getAvailableFincas();
      final fincaLoteId = _resolveSelectedId(
        items: fincas,
        currentId: _selectedFincaForLotesId,
      );
      final lotes = fincaLoteId == null
          ? <Map<String, dynamic>>[]
          : await ExcelExportService.getAvailableLotesByFinca(fincaLoteId);
      final loteId = _resolveSelectedId(items: lotes, currentId: _selectedLoteId);
      final fincaCosechaId = _resolveSelectedId(
        items: fincas,
        currentId: _selectedFincaForCosechasId ?? fincaLoteId,
      );
      final actividadesCount = loteId == null
          ? 0
          : await ExcelExportService.countActividadesByLote(loteId);
      final insumosCount = loteId == null
          ? 0
          : await ExcelExportService.countInsumosByLote(loteId);
      final cosechaSummary = fincaCosechaId == null
          ? const CosechaExportSummary(totalRecords: 0, years: [])
          : await ExcelExportService.getCosechaSummaryByFinca(fincaCosechaId);
      final history = await ExcelExportService.getExportHistory(limit: 20);

      if (!mounted) {
        return;
      }

      setState(() {
        _fincas = fincas;
        _lotes = lotes;
        _selectedFincaForLotesId = fincaLoteId;
        _selectedLoteId = loteId;
        _selectedFincaForCosechasId = fincaCosechaId;
        _actividadesCount = actividadesCount;
        _insumosCount = insumosCount;
        _cosechaSummary = cosechaSummary;
        _recentFiles = history;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    if (mounted) {
      setState(() => _isLoadingHistory = true);
    }

    try {
      final history = await ExcelExportService.getExportHistory(limit: 20);
      if (!mounted) {
        return;
      }
      setState(() {
        _recentFiles = history;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingHistory = false);
    }
  }

  int? _resolveSelectedId({
    required List<Map<String, dynamic>> items,
    required int? currentId,
  }) {
    if (items.isEmpty) {
      return null;
    }
    if (currentId != null && items.any((item) => _localId(item) == currentId)) {
      return currentId;
    }
    return _localId(items.first);
  }

  int? _localId(Map<String, dynamic> item) {
    final rawId = item['local_id'] ?? item['id'];
    if (rawId is int) {
      return rawId;
    }
    if (rawId is num) {
      return rawId.toInt();
    }
    if (rawId is String) {
      return int.tryParse(rawId);
    }
    return null;
  }

  Future<void> _changeFincaForLotes(int? fincaLocalId) async {
    if (fincaLocalId == null) {
      return;
    }
    setState(() {
      _selectedFincaForLotesId = fincaLocalId;
      _selectedLoteId = null;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lotes = await ExcelExportService.getAvailableLotesByFinca(fincaLocalId);
      final loteId = _resolveSelectedId(items: lotes, currentId: null);
      final actividadesCount = loteId == null
          ? 0
          : await ExcelExportService.countActividadesByLote(loteId);
      final insumosCount = loteId == null
          ? 0
          : await ExcelExportService.countInsumosByLote(loteId);

      if (!mounted) {
        return;
      }
      setState(() {
        _lotes = lotes;
        _selectedLoteId = loteId;
        _actividadesCount = actividadesCount;
        _insumosCount = insumosCount;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _changeLote(int? loteLocalId) async {
    if (loteLocalId == null) {
      return;
    }
    setState(() {
      _selectedLoteId = loteLocalId;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final actividadesCount =
          await ExcelExportService.countActividadesByLote(loteLocalId);
      final insumosCount =
          await ExcelExportService.countInsumosByLote(loteLocalId);

      if (!mounted) {
        return;
      }
      setState(() {
        _actividadesCount = actividadesCount;
        _insumosCount = insumosCount;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _changeFincaForCosechas(int? fincaLocalId) async {
    if (fincaLocalId == null) {
      return;
    }
    setState(() {
      _selectedFincaForCosechasId = fincaLocalId;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary =
          await ExcelExportService.getCosechaSummaryByFinca(fincaLocalId);
      if (!mounted) {
        return;
      }
      setState(() {
        _cosechaSummary = summary;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportLoteBundle() async {
    final loteId = _selectedLoteId;
    if (loteId == null) {
      return;
    }

    setState(() => _isExportingLote = true);

    try {
      final actividades = await ExcelExportService.exportActividades(
        loteLocalId: loteId,
      );
      final insumos = await ExcelExportService.exportInsumos(
        loteLocalId: loteId,
      );
      final generatedFiles = [...actividades.files, ...insumos.files];
      await _refreshHistoryAfterExport();

      if (!mounted) {
        return;
      }

      _showSuccessSnackBar(
        message: 'Reporte generado correctamente',
        fileToOpen: generatedFiles.isEmpty ? null : generatedFiles.first,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _isExportingLote = false);
      }
    }
  }

  Future<void> _exportCosechas() async {
    final fincaId = _selectedFincaForCosechasId;
    if (fincaId == null) {
      return;
    }

    setState(() => _isExportingCosechas = true);

    try {
      final result = await ExcelExportService.exportCosechas(
        fincaLocalId: fincaId,
      );
      await _refreshHistoryAfterExport();

      if (!mounted) {
        return;
      }

      _showSuccessSnackBar(
        message: 'Reporte generado correctamente',
        fileToOpen: result.files.isEmpty ? null : result.files.first,
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _isExportingCosechas = false);
      }
    }
  }

  Future<void> _refreshHistoryAfterExport() async {
    final history = await ExcelExportService.getExportHistory(limit: 20);
    if (!mounted) {
      return;
    }
    setState(() => _recentFiles = history);
  }

  void _showSuccessSnackBar({
    required String message,
    ExportFileInfo? fileToOpen,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        action: fileToOpen == null
            ? null
            : SnackBarAction(
                label: 'Ver',
                textColor: AppColors.surface,
                onPressed: () => _openFile(fileToOpen.filePath),
              ),
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No se pudo generar el Excel: $error'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openFile(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (!mounted) {
      return;
    }

    if (result.type == ResultType.done) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isNotEmpty
              ? result.message
              : 'No se pudo abrir el archivo.',
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareFile(ExportFileInfo file) async {
    await Share.shareXFiles(
      [XFile(file.filePath, name: file.fileName)],
      text: file.fileName,
    );
  }

  Future<void> _deleteFile(ExportFileInfo file) async {
    await ExcelExportService.deleteExportFile(file.filePath);
    await _loadHistory();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archivo eliminado.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showHistorySheet() async {
    await _loadHistory();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> refreshModalHistory() async {
              setModalState(() {});
              await _loadHistory();
              if (mounted) {
                setModalState(() {});
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Historial de exportaciones',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _isLoadingHistory
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.moss,
                            ),
                          )
                        : _recentFiles.isEmpty
                            ? const _EmptyHistoryState()
                            : ListView.separated(
                                itemCount: _recentFiles.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final file = _recentFiles[index];
                                  return _HistoryRow(
                                    file: file,
                                    onOpen: () => _openFile(file.filePath),
                                    onShare: () => _shareFile(file),
                                    onDelete: () async {
                                      await _deleteFile(file);
                                      await refreshModalHistory();
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exportar',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Genera tus reportes Excel desde los datos guardados en tu celular.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _showHistorySheet,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.sand),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppColors.clayStrong,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTab(
              label: 'Finca',
              subtitle: 'Cosechas',
              icon: Icons.agriculture_rounded,
              isSelected: _selectedMode == _ExportMode.finca,
              onTap: () => setState(() => _selectedMode = _ExportMode.finca),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentTab(
              label: 'Lote',
              subtitle: 'Actividades e insumos',
              icon: Icons.grid_view_rounded,
              isSelected: _selectedMode == _ExportMode.lote,
              onTap: () => setState(() => _selectedMode = _ExportMode.lote),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFincaMode() {
    final hasData = _cosechaSummary.totalRecords > 0;
    final yearLabel = _cosechaSummary.years.isEmpty
        ? DateTime.now().year.toString()
        : _cosechaSummary.years.first.toString();

    return _ContentCard(
      eyebrow: 'Modo finca',
      title: 'Exporta el consolidado de cosechas',
      description:
          'Ideal para sacar el reporte anual de una finca sin navegar por más pantallas.',
      child: Column(
        children: [
          _SelectionField(
            label: 'Finca',
            value: _selectedFincaForCosechasId,
            items: _fincas
                .map(
                  (finca) => DropdownMenuItem<int>(
                    value: _localId(finca),
                    child: Text(
                      (finca['nombre'] ?? 'Finca sin nombre').toString(),
                    ),
                  ),
                )
                .toList(),
            onChanged: _changeFincaForCosechas,
          ),
          const SizedBox(height: 16),
          _SingleStatCard(
            icon: Icons.agriculture_rounded,
            label: 'Cosechas registradas',
            value: '${_cosechaSummary.totalRecords}',
            footer: 'Año $yearLabel',
            accent: AppColors.clayStrong,
            isEmpty: !hasData,
            emptyText: 'Sin cosechas registradas este año',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedFincaForCosechasId == null || _isExportingCosechas
                  ? null
                  : _exportCosechas,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.clayStrong,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: _isExportingCosechas
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: Text(
                _isExportingCosechas ? 'Generando...' : 'Exportar cosechas',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoteMode() {
    return _ContentCard(
      eyebrow: 'Modo lote',
      title: 'Exporta el detalle operativo del lote',
      description:
          'Aquí puedes sacar un reporte combinado con actividades e insumos del lugar seleccionado.',
      child: Column(
        children: [
          _SelectionField(
            label: 'Finca',
            value: _selectedFincaForLotesId,
            items: _fincas
                .map(
                  (finca) => DropdownMenuItem<int>(
                    value: _localId(finca),
                    child: Text(
                      (finca['nombre'] ?? 'Finca sin nombre').toString(),
                    ),
                  ),
                )
                .toList(),
            onChanged: _changeFincaForLotes,
          ),
          const SizedBox(height: 14),
          _SelectionField(
            label: 'Lote',
            value: _selectedLoteId,
            items: _lotes
                .map(
                  (lote) => DropdownMenuItem<int>(
                    value: _localId(lote),
                    child: Text(
                      (lote['nombre_lote'] ?? 'Lote sin nombre').toString(),
                    ),
                  ),
                )
                .toList(),
            onChanged: _lotes.isEmpty ? null : _changeLote,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GridStatCard(
                  icon: Icons.grass_rounded,
                  label: 'Actividades',
                  count: _actividadesCount,
                  accent: AppColors.moss,
                  emptyText: 'Sin datos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GridStatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Insumos',
                  count: _insumosCount,
                  accent: AppColors.clayStrong,
                  emptyText: 'Sin datos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedLoteId == null || _isExportingLote
                  ? null
                  : _exportLoteBundle,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.moss,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: _isExportingLote
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: Text(
                _isExportingLote
                    ? 'Generando...'
                    : 'Exportar actividades e insumos',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.background,
            AppColors.backgroundSoft,
            AppColors.surfaceMuted,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadExportData,
          color: AppColors.moss,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 132),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSegmentedControl(),
              const SizedBox(height: 18),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.moss),
                  ),
                )
              else if (_errorMessage != null)
                _MessageCard(
                  icon: Icons.error_outline_rounded,
                  iconColor: AppColors.danger,
                  title: 'No pudimos cargar exportaciones',
                  message: _errorMessage!,
                  actionLabel: 'Reintentar',
                  onAction: _loadExportData,
                )
              else if (_fincas.isEmpty)
                const _MessageCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.clayStrong,
                  title: 'Aún no hay datos para exportar',
                  message:
                      'Primero registra fincas, lotes y actividades para empezar a generar reportes.',
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _selectedMode == _ExportMode.finca
                      ? _buildFincaMode()
                      : _buildLoteMode(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isSelected ? AppColors.soil : AppColors.surfaceMuted;
    final primaryText = isSelected ? AppColors.surface : AppColors.textPrimary;
    final secondaryText =
        isSelected ? AppColors.backgroundSoft : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryText, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(title),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              color: AppColors.clayStrong,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<DropdownMenuItem<int>> items;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$value-${items.length}'),
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.backgroundSoft,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.moss, width: 1.5),
        ),
      ),
      dropdownColor: AppColors.surface,
      iconEnabledColor: AppColors.clayStrong,
      borderRadius: BorderRadius.circular(20),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SingleStatCard extends StatelessWidget {
  const _SingleStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.footer,
    required this.accent,
    required this.isEmpty,
    required this.emptyText,
  });

  final IconData icon;
  final String label;
  final String value;
  final String footer;
  final Color accent;
  final bool isEmpty;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 28),
                const SizedBox(height: 14),
                Text(
                  emptyText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  footer,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        footer,
                        style: const TextStyle(
                          color: AppColors.clayStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _GridStatCard extends StatelessWidget {
  const _GridStatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.emptyText,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final isEmpty = count == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEmpty ? emptyText : '$count',
            style: TextStyle(
              color: isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
              fontSize: isEmpty ? 14 : 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.file,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final ExportFileInfo file;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = file.modifiedAt == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy HH:mm').format(file.modifiedAt!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.fileName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.moss,
                    foregroundColor: AppColors.surface,
                  ),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('Ver'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.clayStrong,
                    side: const BorderSide(color: AppColors.sand),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.inventory_2_outlined,
              size: 44,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 14),
            Text(
              'Aún no has generado ningún reporte',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.moss,
                foregroundColor: AppColors.surface,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
