import 'package:appmobiletestis/model/chart_data.dart';
import 'package:appmobiletestis/model/expense.dart';
import 'package:appmobiletestis/widgets/line_chart.dart';
import 'package:flutter/material.dart';
import 'package:appmobiletestis/service/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TablaView extends StatefulWidget {
  @override
  _TablaViewState createState() => _TablaViewState();
}

class _TablaViewState extends State<TablaView> {
  List<Expense> _expenses = []; // Cambiar a List<Expense>
  bool _showStatistics = false;
  double _prediccion = 0.0;
  double _ultimoGasto = 0.0;
  bool _isLoadingPrediction = false;

  @override
  void initState() {
    super.initState();
    _fetchUserAndExpenses();

    if (!_showStatistics) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no existen pronósticos'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }
  }

  Future<String?> _getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> _fetchUserAndExpenses() async {
  final userId = await _getUserId();
  if (userId != null) {

    
    try {
      final ApiService apiService = ApiService();
      final List<Expense> response = await apiService.getLimitExpensesByUser(userId);
      setState(() {
        _expenses = response; // Cambia a tipo List<Expense>
      });

      // Obtener el último gasto
        final lastExpenseResponse = await apiService.getLastExpensesByUser(userId);
        if (lastExpenseResponse.isNotEmpty) {
          setState(() {
            _ultimoGasto = lastExpenseResponse[0]['expense_value']?.toDouble() ?? 0.0; // Guardar el último gasto
          });
        }
      } catch (e) {
        print('Error fetching expenses: $e');
      }
    } else {
      print('No user is signed in');
    }
  }

  List<PricePoint> _calculatePricePoints(List<Expense> expenses) {
  return expenses.asMap().entries.map((entry) {
    int index = entry.key; // Obtener el índice del gasto
    Expense expense = entry.value; // Obtener el objeto Expense
    return PricePoint(
      x: (expenses.length - index - 1).toDouble(), // Invertir el índice para el eje X
      y: expense.expenseValue, // Usar el valor del gasto como valor de Y
      date: expense.expenseDate,
    );
  }).toList();
}

   void _updatePrediction() async {
    final userId = await _getUserId();
    if (userId != null) {
      final data = {
        'user_id': userId,
      };
      setState(() {
        _isLoadingPrediction = true;
      });

      try {
        final ApiService apiService = ApiService();
        await apiService.createPronostication(data);


        final pronosticationResponse = await apiService.getPronosticationByUser(userId);
        setState(() {
          _prediccion = (pronosticationResponse.isNotEmpty && pronosticationResponse[0]['pronostication_value'] != null)
              ? pronosticationResponse[0]['pronostication_value'] : 0.0;
          _showStatistics = true;
        });
      } catch (e) {
        print('Error al crear el pronóstico: $e');
      }
      finally {
        setState(() {
          _isLoadingPrediction = false;
        });
      }
    } else {
      print('No user is signed in');
    }
  }

  @override
Widget build(BuildContext context) {
  final List<PricePoint> pricePoints = _calculatePricePoints(_expenses);
  final double totalGastos = _expenses.fold(0.0, (sum, item) => sum + item.expenseValue); // Sumar todos los gastos

  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Últimos Gastos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
          const SizedBox(height: 10),
          LineChartWidget(points: pricePoints),
          const SizedBox(height: 20),
          _buildPredictionButton(),
          if (_isLoadingPrediction) // Mostrar mensaje de carga
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "El pronóstico se está realizando correctamente. Por favor espere",
                    style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              ),
          const SizedBox(height: 20),
          _buildStatisticsCard(totalGastos), // Pasar el total de gastos aquí
        ],
      ),
    ),
  );
}

  Widget _buildPredictionButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            if (_expenses.length < 5) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No hay suficientes registros para pronosticar'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          
          _updatePrediction();
        },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Predecir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
        const SizedBox(width: 20),
        Visibility(
          visible: _showStatistics,
          child: Text(
            'S/${_prediccion.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCard(double totalGastos) {
    return Visibility(
      visible: _showStatistics,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blueAccent, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Análisis',
                style: TextStyle(fontWeight: FontWeight.w400, fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildInvoice('Entretenimiento', _prediccion, _ultimoGasto, Colors.black), // Usar el último gasto aquí
            ],
          ),
        ),
      ),
    );
  }

     Widget _buildInvoice(String categoria, double prediccion, double ultimoGasto, Color ahorroColor) {


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildInvoiceRow('Categoría', categoria),
        _buildInvoiceRow('Último Gasto', 'S/${ultimoGasto.toStringAsFixed(2)}'), // Mostrar solo dos decimales
        _buildInvoiceRow('Predicción', 'S/${prediccion.toStringAsFixed(2)}'),
        const Divider(height: 20),
        _buildInvoiceRow('Ahorro', '${((prediccion - ultimoGasto) / prediccion * 100).toStringAsFixed(1)}%', textColor: ahorroColor),
      ],
    );
  }

  Widget _buildInvoiceRow(String title, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 18, color: textColor ?? Colors.black)),
        ],
      ),
    );
  }
}


