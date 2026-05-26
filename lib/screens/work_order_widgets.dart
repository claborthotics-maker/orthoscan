import 'package:flutter/material.dart';

// ─── Option Row ───────────────────────────────────────────────────────────────
class OptionRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final Function(String) onChanged;
  final bool wrap;
  final String? subtitle;

  const OptionRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.wrap = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13)),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle!,
                style: const TextStyle(
                    color: Color(0xFF4FC3F7), fontSize: 11)),
          ],
        ]),
        const SizedBox(height: 6),
        wrap
            ? Wrap(
                spacing: 6,
                runSpacing: 6,
                children: options
                    .map((o) => _chip(o, selected == o, onChanged))
                    .toList(),
              )
            : Row(
                children: options
                    .map((o) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3),
                            child: _chip(o, selected == o, onChanged),
                          ),
                        ))
                    .toList(),
              ),
      ],
    );
  }

  Widget _chip(String label, bool isSelected, Function(String) onTap) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F3460)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF4FC3F7)
                  : Colors.white24),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal)),
      ),
    );
  }
}

// ─── Foot Accommodation Row ───────────────────────────────────────────────────
class FootAccommodationRow extends StatelessWidget {
  final String label;
  final String footValue;
  final String sizeValue;
  final Function(String) onFootChanged;
  final Function(String) onSizeChanged;

  const FootAccommodationRow({
    super.key,
    required this.label,
    required this.footValue,
    required this.sizeValue,
    required this.onFootChanged,
    required this.onSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: ['None', 'Left', 'Right', 'Both']
              .map((o) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2),
                      child: GestureDetector(
                        onTap: () => onFootChanged(o),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8),
                          decoration: BoxDecoration(
                            color: footValue == o
                                ? const Color(0xFF0F3460)
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(6),
                            border: Border.all(
                                color: footValue == o
                                    ? const Color(0xFF4FC3F7)
                                    : Colors.white24),
                          ),
                          child: Text(o,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: footValue == o
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 11)),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        if (footValue != 'None') ...[
          const SizedBox(height: 6),
          Row(
            children: ['S', 'M', 'L', 'XL']
                .map((o) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2),
                        child: GestureDetector(
                          onTap: () => onSizeChanged(o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8),
                            decoration: BoxDecoration(
                              color: sizeValue == o
                                  ? Colors.purple.withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(6),
                              border: Border.all(
                                  color: sizeValue == o
                                      ? Colors.purple
                                      : Colors.white24),
                            ),
                            child: Text(o,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: sizeValue == o
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: sizeValue == o
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ─── Heel Lift Row ────────────────────────────────────────────────────────────
class HeelLiftRow extends StatelessWidget {
  final String footValue;
  final TextEditingController heightController;
  final Function(String) onFootChanged;

  const HeelLiftRow({
    super.key,
    required this.footValue,
    required this.heightController,
    required this.onFootChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Heel Lift',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: ['None', 'Left', 'Right', 'Both']
              .map((o) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2),
                      child: GestureDetector(
                        onTap: () => onFootChanged(o),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8),
                          decoration: BoxDecoration(
                            color: footValue == o
                                ? const Color(0xFF0F3460)
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(6),
                            border: Border.all(
                                color: footValue == o
                                    ? const Color(0xFF4FC3F7)
                                    : Colors.white24),
                          ),
                          child: Text(o,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: footValue == o
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 11)),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        if (footValue != 'None') ...[
          const SizedBox(height: 8),
          TextField(
            controller: heightController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Height (e.g. 1/4" or 6mm)',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Color(0xFF4FC3F7))),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Partial Foot Row ─────────────────────────────────────────────────────────
class PartialFootRow extends StatelessWidget {
  final String label;
  final bool isChecked;
  final int toeCount;
  final Function(bool) onChanged;
  final Function(int) onToeCountChanged;

  const PartialFootRow({
    super.key,
    required this.label,
    required this.isChecked,
    required this.toeCount,
    required this.onChanged,
    required this.onToeCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onChanged(!isChecked),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isChecked
                    ? const Color(0xFF4FC3F7).withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: isChecked
                        ? const Color(0xFF4FC3F7)
                        : Colors.white24,
                    width: 2),
              ),
              child: isChecked
                  ? const Icon(Icons.check,
                      color: Color(0xFF4FC3F7), size: 16)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color:
                        isChecked ? Colors.white : Colors.white54,
                    fontSize: 15)),
          ]),
        ),
        if (isChecked) ...[
          const SizedBox(height: 10),
          Row(children: [
            const SizedBox(width: 36),
            const Text('Number of toe fillers:',
                style: TextStyle(
                    color: Colors.white54, fontSize: 13)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.4)),
              ),
              child: DropdownButton<int>(
                value: toeCount,
                dropdownColor: const Color(0xFF16213E),
                underline: const SizedBox(),
                style: const TextStyle(
                    color: Colors.orange, fontSize: 15),
                items: List.generate(5, (i) => i + 1)
                    .map((n) => DropdownMenuItem(
                        value: n,
                        child: Text('$n toe${n > 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: Colors.white))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onToeCountChanged(v);
                },
              ),
            ),
          ]),
        ],
      ],
    );
  }
}

// ─── Quantity Selector ────────────────────────────────────────────────────────
class QuantitySelector extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Function(int) onChanged;

  const QuantitySelector({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (value > 0) onChanged(value - 1);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.remove, color: color, size: 18),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$value',
                  style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ),
            GestureDetector(
              onTap: () {
                if (value < 9) onChanged(value + 1);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.add, color: color, size: 18),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

// ─── Date Row ─────────────────────────────────────────────────────────────────
class WorkOrderDateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color color;

  const WorkOrderDateRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.edit,
              color: Colors.white24, size: 16),
        ]),
      ),
    );
  }
}