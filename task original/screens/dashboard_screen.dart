import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../widgets/ai_chat_block.dart';
import '../services/llm_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LlmService _llmService = LlmService();
  String _selectedModel = 'qwen';
  bool _isLlmInitialized = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = "Iniciando descarga cerebral...";

  @override
  void initState() {
    super.initState();
    _initializeLlm();
  }

  Future<void> _initializeLlm() async {
    try {
      final Directory? docDir = await getExternalStorageDirectory();
      if (docDir == null) throw Exception("Almacenamiento denegado.");
      
      String modelPath = docDir.path + '/model.task';
      File modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        await _downloadModel(modelPath);
      } else {
        _llmService.setModelType('qwen');
        bool success = await _llmService.initLlm(modelPath);
        setState(() => _isLlmInitialized = success);
        if (!success) _showErrorSnackBar("Qwen", modelPath);
      }
    } catch (e) {
      _showErrorSnackBar("Inicialización Qwen", e.toString());
    }
  }

  Future<void> _downloadModel(String path) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatusText = "Conectando al servidor central...";
    });

    try {
      final dio = Dio();
      const url = 'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct-LiteRT/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.task';
      
      await dio.download(
        url,
        path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
              _downloadStatusText = "Descargando Cerebro... " + (received / 1024 / 1024).toStringAsFixed(1) + " MB / " + (total / 1024 / 1024).toStringAsFixed(1) + " MB";
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
        _downloadStatusText = "¡Descarga completada! Compilando IA...";
      });

      _llmService.setModelType('qwen');
      bool success = await _llmService.initLlm(path);
      setState(() => _isLlmInitialized = success);

      if (!success) {
        _showErrorSnackBar("Qwen", path);
      } else {
        _showDeleteSnackbar("¡Inteligencia Artificial Qwen 2.5 Descargada Exitosamente!");
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      _showErrorSnackBar("Fallo Fatal De Red", e.toString());
    }
  }

  void _showErrorSnackBar(String modelKey, String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar ' + modelKey + '.\\nCópialo en: ' + path),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 8),
        ),
      );
    });
  }

  void _showDeleteSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'CERRAR', textColor: Colors.white, onPressed: () {}),
      ),
    );
  }

  Future<bool> _confirmDeletion(BuildContext context, String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D3E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI Tasks',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _isLlmInitialized ? Colors.green : Colors.red,
                        radius: 8,
                      ),
                    ],
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Consumer<TaskProvider>(
                builder: (context, provider, child) {
                  return SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.categories.length,
                      itemBuilder: (context, index) {
                        final cat = provider.categories[index];
                        final isSelected = cat == provider.selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              cat.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.greenAccent,
                            backgroundColor: const Color(0xFF2A2D3E),
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            side: BorderSide.none,
                            onSelected: (val) {
                              provider.setCategory(cat);
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Consumer<TaskProvider>(
                builder: (context, taskProvider, child) {
                  if (taskProvider.tasks.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay tareas. ¡Háblale a la IA!',
                        style: TextStyle(color: Colors.white54, fontSize: 18),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: taskProvider.tasks.length,
                    itemBuilder: (context, index) {
                      final task = taskProvider.tasks[index];
                      return Dismissible(
                        key: Key(task.id),
                        direction: DismissDirection.horizontal,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            // Swipe hacia la derecha = Modo Edición
                            _editTaskDialog(context, task);
                            return false; // Evita que se borre de la UI
                          }
                          // Swipe hacia la izquierda = Modo Borrado Confirmado
                          return await _confirmDeletion(context, 'Eliminar Tarea Principal', '¿Estás seguro de que deseas eliminar permanentemente: "' + task.title + '" y TODAS sus subactividades?');
                        },
                        onDismissed: (_) {
                          taskProvider.removeTask(task.id);
                          _showDeleteSnackbar('¡Tarea "' + task.title + '" eliminada exitosamente!');
                        },
                        child: _buildTaskCard(task),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isDownloading
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2D3E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_download_outlined, color: Colors.blueAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _downloadStatusText,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                            minHeight: 12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "(" + (_downloadProgress * 100).toStringAsFixed(1) + "%) Este proceso extremadamente pesado (1.6 Gigabytes) ocurre mágicamente SOLO una vez. Mantén la App abierta.",
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : AiChatBlock(llmService: _llmService),
            ),
          ],
        ),
      ),
    );
  }

  void _editTaskDialog(BuildContext context, AppTask task) {
    TextEditingController titleCtrl = TextEditingController(text: task.title);
    TextEditingController detailsCtrl = TextEditingController(text: task.details);
    TextEditingController categoryCtrl = TextEditingController(text: task.category);
    DateTime tempDate = task.dueDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2D3E),
              title: const Text('Editar Tarea Principal', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Título corto', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    TextField(
                      controller: categoryCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Categoría', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    TextField(
                      controller: detailsCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Descripción / Voz original', labelStyle: TextStyle(color: Colors.white54)),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text("Fecha: " + DateFormat('MMM dd, yy, HH:mm').format(tempDate), style: const TextStyle(color: Colors.white70))
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: tempDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2040),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(tempDate),
                              );
                              if (time != null) {
                                setModalState(() {
                                  tempDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                          child: const Text('Cambiar'),
                        )
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent)),
                ),
                TextButton(
                  onPressed: () {
                    task.title = titleCtrl.text;
                    task.details = detailsCtrl.text;
                    task.category = categoryCtrl.text.toLowerCase();
                    task.dueDate = tempDate;
                    Provider.of<TaskProvider>(context, listen: false).updateTask(task);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.greenAccent)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _editSubActivityDialog(BuildContext context, AppTask parentTask, SubActivity subTask) {
    TextEditingController titleCtrl = TextEditingController(text: subTask.title);
    DateTime tempDate = subTask.date;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2D3E),
              title: const Text('Editar Sub-Actividad', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Actividad', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text("Límite: " + DateFormat('MMM dd, yy, HH:mm').format(tempDate), style: const TextStyle(color: Colors.white70))
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: tempDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2040),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(tempDate),
                              );
                              if (time != null) {
                                setModalState(() {
                                  tempDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                          child: const Text('Cambiar'),
                        )
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent)),
                ),
                TextButton(
                  onPressed: () {
                    subTask.title = titleCtrl.text;
                    subTask.date = tempDate;
                    Provider.of<TaskProvider>(context, listen: false).updateTask(parentTask);
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.greenAccent)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  String _getSpanishState(String state) {
    switch (state) {
      case 'pending': return 'PENDIENTE';
      case 'in_progress': return 'EN PROGRESO';
      case 'done': return 'FINALIZADA';
      case 'archived': return 'ARCHIVADA';
      default: return state.toUpperCase();
    }
  }

  Widget _buildTaskCard(AppTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _parseColor(task.color).withOpacity(0.5), width: 2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          title: Text(
            task.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _parseColor(task.color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    task.category,
                    style: TextStyle(color: _parseColor(task.color), fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  initialValue: task.state,
                  color: const Color(0xFF2A2D3E),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_getSpanishState(task.state), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                    ],
                  ),
                  onSelected: (val) {
                    task.state = val;
                    Provider.of<TaskProvider>(context, listen: false).updateTask(task);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Estado actualizado a \${_getSpanishState(val)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        backgroundColor: Colors.blueAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 8),
                        action: SnackBarAction(label: 'CERRAR', textColor: Colors.white, onPressed: () {}),
                      )
                    );
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'pending', child: Text('PENDIENTE', style: TextStyle(color: Colors.orangeAccent))),
                    const PopupMenuItem(value: 'in_progress', child: Text('EN PROGRESO', style: TextStyle(color: Colors.lightBlue))),
                    const PopupMenuItem(value: 'done', child: Text('FINALIZADA', style: TextStyle(color: Colors.greenAccent))),
                    const PopupMenuItem(value: 'archived', child: Text('ARCHIVADA', style: TextStyle(color: Colors.grey))),
                  ],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "Vence: " + DateFormat('MMM dd, HH:mm').format(task.dueDate),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                task.details,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ...task.subActivities.map((subTask) => CheckboxListTile(
                  value: subTask.isCompleted,
                  onChanged: (val) {
                    setState(() {
                      subTask.isCompleted = val ?? false;
                    });
                    Provider.of<TaskProvider>(context, listen: false).updateTask(task);
                  },
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 20),
                        onPressed: () => _editSubActivityDialog(context, task, subTask),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          bool confirm = await _confirmDeletion(context, 'Eliminar Subtarea', '¿Borrar paso: "' + subTask.title + '"?');
                          if (confirm) {
                            task.subActivities.remove(subTask);
                            Provider.of<TaskProvider>(context, listen: false).updateTask(task);
                            _showDeleteSnackbar('Subtarea "' + subTask.title + '" borrada.');
                          }
                        },
                      ),
                    ],
                  ),
                  title: Text(
                    subTask.title,
                    style: TextStyle(
                      color: subTask.isCompleted ? Colors.white38 : Colors.white,
                      decoration: subTask.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(subTask.date),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeColor: _parseColor(task.color),
                  checkColor: Colors.white,
                  controlAffinity: ListTileControlAffinity.leading,
                )),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                  onPressed: () => _editTaskDialog(context, task),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  onPressed: () async {
                    bool confirm = await _confirmDeletion(context, 'Eliminar Tarea Principal', '¿Borrar la tarea completa: "' + task.title + '"?');
                    if (confirm) {
                      Provider.of<TaskProvider>(context, listen: false).removeTask(task.id);
                      _showDeleteSnackbar('¡Tarea principal eliminada!');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
