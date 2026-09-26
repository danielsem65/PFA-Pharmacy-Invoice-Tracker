import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design.dart';
import '../../core/format.dart';
import '../../data/excel_service.dart';
import '../../widgets/desktop_form.dart';
import '../../widgets/export_actions.dart';
import '../../widgets/page_header.dart';
import '../../widgets/toast.dart';
import '../invoices/invoices_controller.dart';
import '../suppliers/suppliers_controller.dart';
import 'invoice_importer.dart';

const _invoiceFields = [
  ImportField.supplier,
  ImportField.invoiceNumber,
  ImportField.amount,
  ImportField.invoiceDate,
  ImportField.receivedDate,
  ImportField.dueDate,
  ImportField.paid,
  ImportField.paidDate,
  ImportField.taxPercent,
  ImportField.reference,
  ImportField.paymentMethod,
  ImportField.description,
  ImportField.notes,
];

const _lineItemFields = [
  ImportField.product,
  ImportField.boxes,
  ImportField.piecesPerBox,
  ImportField.pricePerBox,
];

const _previewColumns = 12;
const _previewRows = 14;
const _previewCellWidth = 150.0;
const _previewRowHeight = 32.0;

/// Reads a hand-kept .xlsx invoice sheet into the app.
///
/// The sheet is never trusted: the user picks the sheet and header row, sees a
/// live preview, can correct the automatic column mapping, and only then
/// commits. Nothing is written until Import is pressed.
class ImportExcelScreen extends ConsumerStatefulWidget {
  const ImportExcelScreen({super.key});

  @override
  ConsumerState<ImportExcelScreen> createState() => _ImportExcelScreenState();
}

class _ImportExcelScreenState extends ConsumerState<ImportExcelScreen> {
  String? _fileName;
  XlsxWorkbook? _workbook;
  String? _readError;

  String? _sheetName;
  int _headerRow = 0;
  ImportMapping _mapping = const ImportMapping.empty();
  bool _skipExisting = true;
  bool _showProblems = false;
  bool _importing = false;

  InvoiceImportPlan? _plan;
  String? _planKey;

  @override
  Widget build(BuildContext context) {
    final workbook = _workbook;
    final sheet = workbook == null ? null : _sheetOf(workbook);
    // Resolved once here so the footer and the summary always agree, whatever
    // order the panels happen to build in.
    final plan = sheet == null ? null : _currentPlan(sheet);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context),
          const Divider(height: 1),
          Expanded(
            child: sheet == null
                ? _emptyState(context)
                : _workspace(context, sheet, plan!),
          ),
          _actionsBar(context, plan),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.xxl, 18, Insets.xl, 14),
      child: PageHeader(
        title: 'Import from Excel',
        subtitle: _fileName == null
            ? 'Bring an existing .xlsx invoice sheet into the app'
            : '$_fileName — check the columns, then import',
        icon: Icons.upload_file,
        accentIndex: 3,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: <Widget>[
          OutlinedButton.icon(
            key: const Key('choose-excel-file'),
            onPressed: _importing ? null : _chooseFile,
            icon: const Icon(Icons.folder_open, size: 18),
            label: Text(_fileName == null ? 'Choose .xlsx file' : 'Change file'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file, size: 64, color: scheme.outline),
              const SizedBox(height: 12),
              Text('No file chosen', style: texts.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Pick the .xlsx sheet you keep your supplier invoices in. '
                'Columns are matched by their headings, and you can change '
                'any of them before importing.',
                style: texts.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (_readError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _readError!,
                    style: texts.bodySmall
                        ?.copyWith(color: scheme.onErrorContainer),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _importing ? null : _chooseFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose .xlsx file'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _workspace(
    BuildContext context,
    XlsxSheet sheet,
    InvoiceImportPlan plan,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final preview = _previewPanel(context, sheet);
        final mapping = _mappingPanel(context, sheet, plan);
        if (constraints.maxWidth >= 940) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 11, child: preview),
              const VerticalDivider(width: 1),
              Expanded(flex: 9, child: mapping),
            ],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 430, child: preview),
              const SizedBox(height: 16),
              mapping,
            ],
          ),
        );
      },
    );
  }

  Widget _previewPanel(BuildContext context, XlsxSheet sheet) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormSection(
            title: 'Sheet',
            icon: Icons.grid_on,
            children: [
              FieldRow(
                fields: [
                  (
                    flex: 3,
                    child: _Dropdown<String>(
                      labelText: 'Worksheet',
                      value: _sheetName ?? sheet.name,
                      items: [
                        for (final name in _workbook!.sheetNames)
                          DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: _importing ? null : _selectSheet,
                    ),
                  ),
                  (
                    flex: 3,
                    child: _Dropdown<int>(
                      labelText: 'Headings are on row',
                      value: _headerRow,
                      items: _headerRowChoices(sheet),
                      onChanged: _importing ? null : _selectHeaderRow,
                    ),
                  ),
                ],
              ),
              Text(
                'Anything above the heading row is ignored, so a title or '
                'filter block at the top of the sheet is fine.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _previewGrid(context, sheet)),
        ],
      ),
    );
  }

  Widget _previewGrid(BuildContext context, XlsxSheet sheet) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final columns = sheet.columnCount.clamp(0, _previewColumns);
    final lastRow = (_headerRow + _previewRows).clamp(0, sheet.rowCount);
    final mappedColumns = _mapping.columns.values.toSet();

    final cells = <Widget>[];
    for (var r = _headerRow; r < lastRow; r++) {
      final isHeader = r == _headerRow;
      final row = sheet.rowAt(r);
      cells.add(
        _cell(
          context,
          '${r + 1}',
          background: isHeader
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          style: texts.labelSmall?.copyWith(fontWeight: FontWeight.w800),
          width: 44,
        ),
      );
      for (var c = 0; c < columns; c++) {
        cells.add(
          _cell(
            context,
            displayText(row[c]),
            background: mappedColumns.contains(c)
                ? scheme.tertiaryContainer.withValues(alpha: 0.35)
                : null,
            style: texts.bodySmall?.copyWith(
              fontWeight: isHeader ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Text(
                  'Preview — shaded columns are being used',
                  style: texts.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (var i = 0; i < columns; i++)
                _cell(
                  context,
                  _columnLetter(i),
                  background:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  style: texts.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                  bottomBorder: true,
                ),
              ...cells,
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String value, {
    Color? background,
    TextStyle? style,
    double width = _previewCellWidth,
    bool bottomBorder = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: _previewRowHeight,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          bottom: bottomBorder
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
        ),
      ),
      child: Text(
        value,
        style: style ?? Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _mappingPanel(
    BuildContext context,
    XlsxSheet sheet,
    InvoiceImportPlan plan,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormSection(
            title: 'Invoice columns',
            icon: Icons.receipt_long,
            children: [
              for (final field in _invoiceFields)
                _fieldRow(context, sheet, field),
            ],
          ),
          const SizedBox(height: 14),
          FormSection(
            title: 'Items on each invoice',
            icon: Icons.medication_outlined,
            children: [
              for (final field in _lineItemFields)
                _fieldRow(context, sheet, field),
              const SizedBox(height: 4),
              Text(
                'When a row lists one medicine, rows sharing a supplier and '
                'invoice number are joined into a single invoice with several '
                'items.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _planSection(context, plan),
        ],
      ),
    );
  }

  Widget _fieldRow(BuildContext context, XlsxSheet sheet, ImportField field) {
    final scheme = Theme.of(context).colorScheme;
    final column = _mapping.columnOf(field);
    final missing = field.isRequired && column == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              missing ? '${field.label} *' : field.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: missing ? scheme.error : scheme.onSurface,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Dropdown<int>(
              key: Key('map-${field.name}'),
              value: column ?? -1,
              errorText: missing ? 'needed' : null,
              items: [
                const DropdownMenuItem(
                  value: -1,
                  child: Text('— not mapped —'),
                ),
                for (var c = 0; c < sheet.columnCount; c++)
                  DropdownMenuItem(
                    value: c,
                    child: Text(
                      '${_columnLetter(c)}: ${_headerLabel(sheet, c)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _importing
                  ? null
                  : (value) {
                      setState(() {
                        _mapping = _mapping.withColumn(
                          field,
                          value == -1 ? null : value,
                        );
                        _invalidatePlan();
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _planSection(BuildContext context, InvoiceImportPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final missing = _mapping.missingRequired;

    return FormSection(
      title: 'Ready to import',
      icon: Icons.download_done,
      children: [
        if (missing.isNotEmpty)
          Text(
            'Map ${missing.map((f) => f.label).join(', ')} to continue.',
            style: texts.bodySmall?.copyWith(color: scheme.error),
          )
        else if (plan.isEmpty)
          Text(
            'No invoices found in this sheet. Check the heading row and the '
            'column mapping.',
            style: texts.bodySmall?.copyWith(color: scheme.error),
          )
        else ...[
          Text(
            '${plan.invoices.length} '
            '${plan.invoices.length == 1 ? 'invoice' : 'invoices'}, '
            '${plan.lineCount} ${plan.lineCount == 1 ? 'item' : 'items'}, '
            '${formatPesewas(plan.totalPesewas)} total',
            style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.newSuppliers.length} new '
            '${plan.newSuppliers.length == 1 ? 'supplier' : 'suppliers'} will '
            'be created'
            '${plan.skippedExisting > 0 ? ', ${plan.skippedExisting} already in the app will be skipped' : ''}.',
            style: texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            key: const Key('skip-existing'),
            value: _skipExisting,
            onChanged: _importing
                ? null
                : (value) {
                    setState(() {
                      _skipExisting = value ?? true;
                      _invalidatePlan();
                    });
                  },
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Skip invoices already in the app'),
            subtitle: Text(
              'Matched on supplier and invoice number',
              style:
                  texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (plan.problems.isNotEmpty) ...[
            TextButton.icon(
              onPressed: () => setState(() => _showProblems = !_showProblems),
              icon: Icon(
                _showProblems ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                '${plan.problems.length} '
                '${plan.problems.length == 1 ? 'row' : 'rows'} could not be '
                'imported',
              ),
            ),
            if (_showProblems)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final problem in plan.problems)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          problem.toString(),
                          style: texts.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _actionsBar(BuildContext context, InvoiceImportPlan? plan) {
    final scheme = Theme.of(context).colorScheme;
    final count = plan?.invoices.length ?? 0;
    final canImport =
        _workbook != null && _mapping.isUsable && count > 0 && !_importing;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              if (_importing) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Importing…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _importing ? null : () => context.go('/'),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const Key('run-import'),
                onPressed: canImport ? _commit : null,
                icon: const Icon(Icons.download, size: 18),
                label: Text(count == 0 ? 'Import' : 'Import $count'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> _chooseFile() async {
    final picked = await openFile(acceptedTypeGroups: const [kExcelType]);
    if (picked == null || !mounted) return;
    try {
      final bytes = await picked.readAsBytes();
      final workbook = readXlsx(bytes);
      if (workbook.sheets.isEmpty) {
        setState(() {
          _readError = 'That workbook has no worksheets.';
          _workbook = null;
          _fileName = null;
        });
        return;
      }
      final first = workbook.sheets.first;
      setState(() {
        _readError = null;
        _fileName = picked.name;
        _workbook = workbook;
        _sheetName = first.name;
        _headerRow = _defaultHeaderRow(first);
        _mapping = detectMapping(_headerLabels(first, _headerRow));
        _invalidatePlan();
      });
    } on FormatException catch (e) {
      setState(() {
        _readError = e.message;
        _workbook = null;
        _fileName = null;
      });
    } catch (e) {
      setState(() {
        _readError = 'Could not read that file: $e';
        _workbook = null;
        _fileName = null;
      });
    }
  }

  void _selectSheet(String? name) {
    if (name == null) return;
    final sheet = _workbook!.sheet(name);
    setState(() {
      _sheetName = name;
      _headerRow = _defaultHeaderRow(sheet);
      _mapping = detectMapping(_headerLabels(sheet, _headerRow));
      _invalidatePlan();
    });
  }

  void _selectHeaderRow(int row) {
    final sheet = _sheetOf(_workbook!);
    setState(() {
      _headerRow = row;
      _mapping = detectMapping(_headerLabels(sheet, row));
      _invalidatePlan();
    });
  }

  Future<void> _commit() async {
    final plan = _plan;
    if (plan == null || plan.invoices.isEmpty) return;
    setState(() => _importing = true);
    try {
      if (plan.newSuppliers.isNotEmpty) {
        await ref.read(suppliersProvider.notifier).addMany(plan.newSuppliers);
      }
      await ref.read(invoicesProvider.notifier).addMany(plan.invoices);
      if (!mounted) return;
      final count = plan.invoices.length;
      toast(context, 'Imported $count ${count == 1 ? 'invoice' : 'invoices'}.');
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      toast(context, 'Import failed: $e');
    }
  }

  // ---------------------------------------------------------------- helpers

  XlsxSheet _sheetOf(XlsxWorkbook workbook) =>
      workbook.sheet(_sheetName ?? workbook.sheetNames.first);

  /// Finds the row that looks most like headings. That is usually row 1, but
  /// on a hand-kept sheet it is often lower down.
  int _defaultHeaderRow(XlsxSheet sheet) {
    final limit = sheet.rowCount < 12 ? sheet.rowCount : 12;
    var bestRow = 0;
    var bestScore = 0;
    for (var r = 0; r < limit; r++) {
      final labels = _headerLabels(sheet, r);
      if (labels.every((label) => label.isEmpty)) continue;
      final score = detectMapping(labels).columns.length;
      if (score > bestScore) {
        bestScore = score;
        bestRow = r;
      }
    }
    return bestScore == 0 ? 0 : bestRow;
  }

  List<DropdownMenuItem<int>> _headerRowChoices(XlsxSheet sheet) {
    final limit = sheet.rowCount < 15 ? sheet.rowCount : 15;
    return [
      for (var r = 0; r < limit; r++)
        DropdownMenuItem(value: r, child: Text('Row ${r + 1}')),
    ];
  }

  List<String> _headerLabels(XlsxSheet sheet, int headerRow) {
    final row = sheet.rowAt(headerRow);
    return [for (final cell in row) displayText(cell).trim()];
  }

  String _headerLabel(XlsxSheet sheet, int column) {
    final labels = _headerLabels(sheet, _headerRow);
    if (column >= labels.length) return '';
    final label = labels[column];
    return label.isEmpty ? '(no heading)' : label;
  }

  void _invalidatePlan() {
    _plan = null;
    _planKey = null;
  }

  /// Re-parses the sheet only when the sheet, mapping or options change, so a
  /// large workbook is not re-read on every frame.
  InvoiceImportPlan _currentPlan(XlsxSheet sheet) {
    final key = [
      _sheetName,
      _headerRow,
      _skipExisting,
      _mapping.columns.entries
          .map((entry) => '${entry.key.name}=${entry.value}')
          .join(','),
    ].join('|');
    if (_plan != null && _planKey == key) return _plan!;
    final plan = buildImportPlan(
      sheet: sheet,
      headerRowIndex: _headerRow,
      mapping: _mapping,
      existingSuppliers: ref.read(suppliersProvider),
      existingInvoices: ref.read(invoicesProvider),
      skipExisting: _skipExisting,
    );
    _plan = plan;
    _planKey = key;
    return plan;
  }
}

/// A labelled dropdown that does not depend on the form-field API, so it works
/// the same on every stable Flutter release.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelText,
    this.errorText,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T>? onChanged;
  final String? labelText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelText: labelText,
        errorText: errorText,
        errorStyle: const TextStyle(fontSize: 10, height: 1.1),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: onChanged == null
              ? null
              : (selected) {
                  if (selected is T) onChanged!(selected);
                },
        ),
      ),
    );
  }
}

String _columnLetter(int index) {
  var value = index;
  final buffer = StringBuffer();
  while (value >= 0) {
    buffer.write(String.fromCharCode(65 + value % 26));
    value = value ~/ 26 - 1;
  }
  return buffer.toString().split('').reversed.join();
}
