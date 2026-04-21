import 'package:app_flutter_ai/core/config/app_colors.dart';
import 'package:app_flutter_ai/core/services/export/excel_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final files = [...actividades.files, ...insumos.files];
      _rememberFiles(files);

      if (!mounted) {
        return;
      }
      final totalItems = actividades.totalItems + insumos.totalItems;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se generaron ${files.length} archivo(s) con $totalItems registro(s) del lote.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
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
      _rememberFiles(result.files);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se generaron ${result.totalFiles} archivo(s) con ${result.totalItems} cosecha(s).',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _isExportingCosechas = false);
      }
    }
  }

  void _rememberFiles(List<ExportFileInfo> files) {
    if (files.isEmpty || !mounted) {
      return;
    }
    final combined = [...files, ..._recentFiles];
    final deduped = <String, ExportFileInfo>{};
    for (final file in combined) {
      deduped[file.filePath] = file;
    }
    setState(() {
      _recentFiles = deduped.values.take(6).toList();
    });
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

  Future<void> _copyPath(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ruta copiada al portapapeles.'),
        backgroundColor: AppColors.success,
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

  Widget _buildFincaView() {
    return _SectionCard(
      title: 'Vista de finca',
      subtitle:
          'Este modo se centra unicamente en la exportacion de cosechas.',
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
          const SizedBox(height: 14),
          _MetricCard(
            label: 'Cosechas',
            value: '${_cosechaSummary.totalRecords}',
            helper: _cosechaSummary.years.isEmpty
                ? 'Sin registros aun'
                : 'Anios: ${_cosechaSummary.years.join(', ')}',
            icon: Icons.agriculture_rounded,
            accent: AppColors.clayStrong,
            tint: const Color(0xFFF3E3CC),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedFincaForCosechasId == null ||
                      _isExportingCosechas
                  ? null
                  : _exportCosechas,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.clayStrong,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
              label: const Text('Exportar cosechas'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoteView() {
    return _SectionCard(
      title: 'Vista de lote',
      subtitle:
          'Selecciona una finca y un lote para exportar actividades e insumos de ese lugar.',
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Actividades',
                  value: '$_actividadesCount',
                  helper: 'Formato de campo',
                  icon: Icons.grass_rounded,
                  accent: AppColors.moss,
                  tint: const Color(0xFFE6F0DC),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Insumos',
                  value: '$_insumosCount',
                  helper: 'Formato de control',
                  icon: Icons.inventory_2_outlined,
                  accent: AppColors.clayStrong,
                  tint: const Color(0xFFF3E3CC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedLoteId == null || _isExportingLote
                  ? null
                  : _exportLoteBundle,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.moss,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
              label: const Text('Exportar actividades e insumos'),
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
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
            children: [
              const _ExportHeroCard(),
              const SizedBox(height: 16),
              _ModeSwitch(
                selectedMode: _selectedMode,
                onChanged: (mode) => setState(() => _selectedMode = mode),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.moss),
                  ),
                )
              else if (_errorMessage != null)
                _MessageCard(
                  icon: Icons.error_outline_rounded,
                  iconColor: AppColors.danger,
                  title: 'No pudimos cargar exportacion',
                  message: _errorMessage!,
                  actionLabel: 'Reintentar',
                  onAction: _loadExportData,
                )
              else if (_fincas.isEmpty)
                const _MessageCard(
                  icon: Icons.file_copy_outlined,
                  iconColor: AppColors.moss,
                  title: 'Aun no hay fincas para exportar',
                  message:
                      'Primero crea una finca y sus lotes. Despues podras llenar los formatos oficiales con tus registros locales.',
                )
              else ...[
                _selectedMode == _ExportMode.finca
                    ? _buildFincaView()
                    : _buildLoteView(),
                if (_recentFiles.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _RecentFilesCard(
                    files: _recentFiles,
                    onCopyPath: _copyPath,
                    onOpenFile: _openFile,
                    onShareFile: _shareFile,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportHeroCard extends StatelessWidget {
  const _ExportHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.sand),
      ),
      child: const Row(
        children: [
          _HeroIcon(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exportar formatos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Genera los Excel oficiales desde la base local del celular.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
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

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.file_download_outlined,
        color: AppColors.clayStrong,
        size: 28,
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.selectedMode,
    required this.onChanged,
  });

  final _ExportMode selectedMode;
  final ValueChanged<_ExportMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              title: 'Finca',
              subtitle: 'Solo cosechas',
              icon: Icons.agriculture_rounded,
              selected: selectedMode == _ExportMode.finca,
              onTap: () => onChanged(_ExportMode.finca),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              title: 'Lote',
              subtitle: 'Actividades e insumos',
              icon: Icons.grid_view_rounded,
              selected: selectedMode == _ExportMode.lote,
              onTap: () => onChanged(_ExportMode.lote),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.backgroundSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.moss : AppColors.surfaceMuted,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.moss.withValues(alpha: 0.14)
                    : AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.moss : AppColors.clayStrong,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.sand),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.moss, width: 1.6),
        ),
      ),
      dropdownColor: AppColors.surface,
      iconEnabledColor: AppColors.clayStrong,
      borderRadius: BorderRadius.circular(18),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accent,
    required this.tint,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color accent;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentFilesCard extends StatelessWidget {
  const _RecentFilesCard({
    required this.files,
    required this.onCopyPath,
    required this.onOpenFile,
    required this.onShareFile,
  });

  final List<ExportFileInfo> files;
  final ValueChanged<String> onCopyPath;
  final ValueChanged<String> onOpenFile;
  final ValueChanged<ExportFileInfo> onShareFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ultimos archivos generados',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...files.map(
            (file) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                borderRadius: BorderRadius.circular(18),
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
                    '${file.itemCount} registro(s)',
                    style: const TextStyle(
                      color: AppColors.moss,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    file.filePath,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => onOpenFile(file.filePath),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.moss,
                            foregroundColor: AppColors.surface,
                          ),
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          label: const Text('Abrir'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onShareFile(file),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.clayStrong,
                            side: const BorderSide(color: AppColors.sand),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Compartir'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => onCopyPath(file.filePath),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.clayStrong,
                          side: const BorderSide(color: AppColors.sand),
                        ),
                        child: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
