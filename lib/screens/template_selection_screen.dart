import 'package:flutter/material.dart';
import '../models/work_order_template.dart';
import '../models/work_order.dart';
import '../models/patient.dart';

class TemplateSelectionScreen extends StatefulWidget {
  final Patient patient;
  final Function(WorkOrderTemplate) onTemplateSelected;

  const TemplateSelectionScreen({
    super.key,
    required this.patient,
    required this.onTemplateSelected,
  });

  @override
  State<TemplateSelectionScreen> createState() =>
      _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<WorkOrderTemplate> _defaultTemplates = DefaultTemplates.getAll();
  final List<WorkOrderTemplate> _customTemplates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<WorkOrderTemplate> _filterByType(TemplateType type) {
    return _defaultTemplates
        .where((t) => t.templateType == type)
        .toList();
  }

  Color _typeColor(TemplateType type) {
    switch (type) {
      case TemplateType.rebound:
        return Colors.blue;
      case TemplateType.polyShell:
        return Colors.purple;
      case TemplateType.partialFoot:
        return Colors.orange;
    }
  }

  IconData _typeIcon(TemplateType type) {
    switch (type) {
      case TemplateType.rebound:
        return Icons.layers;
      case TemplateType.polyShell:
        return Icons.view_in_ar;
      case TemplateType.partialFoot:
        return Icons.accessibility_new;
    }
  }

  void _selectTemplate(WorkOrderTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          template.name,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.description,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _detailRow('Base/Shell', template.templateType == TemplateType.polyShell
                ? template.shellThickness
                : template.baseThickness),
            _detailRow('Top Cover', '${template.topCover} ${template.topCoverThickness}'),
            _detailRow('Arch Mod', _archLabel(template.archModification)),
            _detailRow('Heel Cup', template.heelCup),
            if (template.templateType == TemplateType.partialFoot)
              _detailRow('Toe Filler', 'Included'),
            if (template.specialInstructions.isNotEmpty)
              _detailRow('Notes', template.specialInstructions),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onTemplateSelected(template);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3460),
            ),
            child: const Text('Use Template',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _archLabel(int value) {
    if (value == 0) return 'As Cast (0)';
    if (value > 0) return 'Increase Arch (+$value)';
    return 'Decrease Arch ($value)';
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(List<WorkOrderTemplate> templates) {
    if (templates.isEmpty) {
      return const Center(
        child: Text('No templates',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _TemplateCard(
          template: template,
          typeColor: _typeColor(template.templateType),
          typeIcon: _typeIcon(template.templateType),
          onTap: () => _selectTemplate(template),
        );
      },
    );
  }

  Widget _buildCustomTab() {
    if (_customTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bookmark_add_outlined,
                size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No custom templates yet',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Save a work order as a template\nto reuse it here',
              style: TextStyle(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _buildTemplateList(_customTemplates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Select Template',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4FC3F7),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Rebound'),
            Tab(text: 'Poly Shell'),
            Tab(text: 'Partial Foot'),
            Tab(text: 'My Templates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplateList(_filterByType(TemplateType.rebound)),
          _buildTemplateList(_filterByType(TemplateType.polyShell)),
          _buildTemplateList(_filterByType(TemplateType.partialFoot)),
          _buildCustomTab(),
        ],
      ),
    );
  }
}

// ─── Template Card ────────────────────────────────────────────────────────────
class _TemplateCard extends StatelessWidget {
  final WorkOrderTemplate template;
  final Color typeColor;
  final IconData typeIcon;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.typeColor,
    required this.typeIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: typeColor.withOpacity(0.4),
                    ),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.description,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (template.templateType == TemplateType.partialFoot)
                            _chip('Toe Filler', Colors.orange),
                          if (template.specialInstructions
                              .contains('Diabetic'))
                            _chip('Diabetic', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }
}