import 'package:festeasy/services/auth_service.dart';
import 'package:festeasy/services/gastos_service.dart';
import 'package:festeasy/services/provider_solicitudes_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MisFinanzasPage extends StatefulWidget {
  const MisFinanzasPage({super.key});

  @override
  State<MisFinanzasPage> createState() => _MisFinanzasPageState();
}

class _MisFinanzasPageState extends State<MisFinanzasPage> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  bool _isLoading = true;
  List<ProviderSolicitudData> _solicitudes = [];
  List<GastoData> _gastos = [];

  // Paginación tabla gastos
  int _currentPage = 0;
  final int _rowsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final allSolicitudes = await ProviderSolicitudesService.instance
          .getAllSolicitudes(user.id);
      final allGastos = await GastosService.instance.getGastos();

      if (mounted) {
        setState(() {
          // Filtrar ambos por la fecha seleccionada
          _solicitudes = _filterSolicitudesByDate(allSolicitudes, _dateRange);
          _gastos = _filterGastosByDate(allGastos, _dateRange);
          _currentPage = 0; // reset
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading finanzas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ProviderSolicitudData> _filterSolicitudesByDate(
    List<ProviderSolicitudData> data,
    DateTimeRange range,
  ) {
    return data.where((s) {
      if (s.estado == 'rechazada' || s.estado == 'cancelada') return false;
      // Usar fecha del servicio
      final date = s.fechaServicio.toLocal();
      return _isSameDayOrBetween(date, range.start, range.end);
    }).toList();
  }

  List<GastoData> _filterGastosByDate(
    List<GastoData> data,
    DateTimeRange range,
  ) {
    return data.where((g) {
      final date = g.fecha.toLocal();
      return _isSameDayOrBetween(date, range.start, range.end);
    }).toList();
  }

  bool _isSameDayOrBetween(DateTime date, DateTime start, DateTime end) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return d.isAtSameMomentAs(s) ||
        d.isAtSameMomentAs(e) ||
        (d.isAfter(s) && d.isBefore(e));
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF8D72C2)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      _loadData();
    }
  }

  void _showGastoDialog([GastoData? gastoExistente]) {
    final formKey = GlobalKey<FormState>();
    final isEditing = gastoExistente != null;
    final montoController = TextEditingController(
      text: isEditing ? gastoExistente.monto.toString() : '',
    );
    final conceptoController = TextEditingController(
      text: isEditing ? gastoExistente.concepto : '',
    );
    var fechaSeleccionada = isEditing ? gastoExistente.fecha : DateTime.now();
    var categoriaSeleccionada = isEditing
        ? gastoExistente.categoria
        : 'Transporte';

    final categorias = ['Transporte', 'Personal', 'Material', 'Renta', 'Otros'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Editar Gasto' : 'Nuevo Gasto'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: montoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monto del Gasto',
                        prefixText: r'$ ',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Requerido';
                        if (double.tryParse(val) == null) return 'Inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => fechaSeleccionada = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha'),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(fechaSeleccionada),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: categoriaSeleccionada,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: categorias
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => categoriaSeleccionada = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: conceptoController,
                      decoration: const InputDecoration(
                        labelText: 'Nota / Observaciones',
                        hintText: 'Ej. Gasolina evento Carlos',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D72C2),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final user = AuthService.instance.currentUser;
                    if (user == null) return;

                    final gasto = GastoData(
                      id: isEditing
                          ? gastoExistente.id
                          : DateTime.now().millisecondsSinceEpoch.toString(),
                      proveedorUsuarioId: user.id,
                      monto: double.parse(montoController.text),
                      fecha: fechaSeleccionada,
                      categoria: categoriaSeleccionada,
                      concepto: conceptoController.text,
                      creadoEn: isEditing
                          ? gastoExistente.creadoEn
                          : DateTime.now(),
                    );

                    await GastosService.instance.saveGasto(gasto);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData(); // Recargar todo
                    }
                  }
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _eliminarGasto(GastoData gasto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Gasto'),
        content: const Text('¿Estás seguro de que deseas eliminar este gasto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D72C2)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar ?? false) {
      await GastosService.instance.deleteGasto(gasto.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D72C2)),
          ),
        ),
      );
    }

    // Cálculos
    final totalIngresos = _solicitudes.fold<double>(
      0,
      (prev, element) => prev + element.montoTotal,
    );
    final totalGastos = _gastos.fold<double>(
      0,
      (prev, element) => prev + element.monto,
    );
    final gananciaNeta = totalIngresos - totalGastos;
    final ticketPromedio = _solicitudes.isEmpty
        ? 0.0
        : totalIngresos / _solicitudes.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Mis Finanzas',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF8D72C2),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado
                    const Text(
                      'Gestión integral de ingresos y gastos operativos.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Fila de Rango de Fechas y Botón Registrar
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDateRange,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${DateFormat('dd/MM/yy').format(_dateRange.start)} - ${DateFormat('dd/MM/yy').format(_dateRange.end)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _showGastoDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Registrar Gasto',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Grid de KPIs
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 32) / 2;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildKpiCard(
                              'Ingresos',
                              'TOTAL COBRADO',
                              totalIngresos,
                              Icons.account_balance_wallet_outlined,
                              Colors.blue,
                              width,
                            ),
                            _buildKpiCard(
                              'Gastos',
                              'TOTAL EGRESOS',
                              totalGastos,
                              Icons.arrow_downward_outlined,
                              const Color(0xFF8D72C2),
                              width,
                            ),
                            _buildKpiCard(
                              'Neto',
                              'GANANCIA NETA',
                              gananciaNeta,
                              Icons.insights,
                              const Color(0xFF10B981),
                              width,
                              isFeatured: true,
                            ),
                            _buildKpiCard(
                              'Tickets',
                              'TICKET PROMEDIO',
                              ticketPromedio,
                              Icons.confirmation_number_outlined,
                              Colors.orange,
                              width,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Grafica y Tabla
                    _buildCategoriasChart(),
                    const SizedBox(height: 24),
                    _buildGastosTable(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    String badgeText,
    String title,
    double amount,
    IconData icon,
    Color color,
    double width, {
    bool isFeatured = false,
  }) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    );

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFeatured ? color : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isFeatured
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isFeatured ? Colors.white : color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFeatured
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isFeatured ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isFeatured ? Colors.white70 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currencyFormat.format(amount),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isFeatured ? Colors.white : const Color(0xFF010302),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriasChart() {
    if (_gastos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Gastos por Categoría',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.topLeft,
              child: Text(
                'Distribución porcentual de tus egresos operativos.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No hay datos para graficar en esta fecha',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Agrupar por categoría
    final map = <String, double>{};
    for (final g in _gastos) {
      map[g.categoria] = (map[g.categoria] ?? 0) + g.monto;
    }

    final colores = {
      'Transporte': Colors.blue,
      'Personal': Colors.purple,
      'Material': Colors.orange,
      'Renta': Colors.teal,
      'Otros': Colors.grey,
    };

    final chartSections = <PieChartSectionData>[];
    map.forEach((cat, monto) {
      chartSections.add(
        PieChartSectionData(
          value: monto,
          color: colores[cat] ?? const Color(0xFF8D72C2),
          title:
              '$cat\n${((monto / _gastos.fold(0.0, (p, e) => p + e.monto)) * 100).toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gastos por Categoría',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Distribución porcentual de tus egresos operativos.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: chartSections,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGastosTable() {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 2,
    );

    // Sort gastos by date descending
    final sortedGastos = List<GastoData>.from(_gastos)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final totalPages = (sortedGastos.length / _rowsPerPage).ceil();
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage > sortedGastos.length)
        ? sortedGastos.length
        : startIndex + _rowsPerPage;
    final paginatedGastos = sortedGastos.sublist(
      startIndex,
      endIndex < startIndex ? startIndex : endIndex,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listado de Gastos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Control detallado de tus compras y servicios.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (sortedGastos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No hay registros en este periodo',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginatedGastos.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final g = paginatedGastos[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  g.categoria,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(g.monto),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF8D72C2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    g.concepto.isEmpty
                                        ? 'Sin detallar'
                                        : g.concepto,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                    'es',
                                  ).format(g.fecha),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Botones de acción explícitos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showGastoDialog(g),
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  label: const Text(
                                    'Editar',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                TextButton.icon(
                                  onPressed: () => _eliminarGasto(g),
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: const Color(0xFF8D72C2),
                                  ),
                                  label: const Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      color: const Color(0xFF8D72C2),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Paginacion
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage = 0)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_left),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text('Página ${_currentPage + 1} de $totalPages'),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_right),
                      onPressed: _currentPage < totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      onPressed: _currentPage < totalPages - 1
                          ? () => setState(() => _currentPage = totalPages - 1)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
