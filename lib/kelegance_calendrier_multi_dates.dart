import 'package:flutter/material.dart';

/// Calendrier mensuel avec sélection multiple et surbrillance jaune.
class KeleganceCalendrierMultiDates extends StatefulWidget {
  const KeleganceCalendrierMultiDates({
    super.key,
    required this.selection,
    required this.onToggle,
    required this.firstDate,
    required this.lastDate,
    this.initialMonth,
  });

  final List<DateTime> selection;
  final ValueChanged<DateTime> onToggle;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialMonth;

  @override
  State<KeleganceCalendrierMultiDates> createState() => _KeleganceCalendrierMultiDatesState();
}

class _KeleganceCalendrierMultiDatesState extends State<KeleganceCalendrierMultiDates> {
  late DateTime _moisAffiche;

  @override
  void initState() {
    super.initState();
    _moisAffiche = widget.initialMonth ?? DateTime.now();
    _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month);
  }

  bool _estSelectionnee(DateTime jour) => widget.selection.any(
        (s) => s.year == jour.year && s.month == jour.month && s.day == jour.day,
      );

  bool _estSelectable(DateTime jour) {
    final normalise = DateTime(jour.year, jour.month, jour.day);
    final debut = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final fin = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !normalise.isBefore(debut) && !normalise.isAfter(fin);
  }

  void _moisPrecedent() {
    setState(() => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month - 1));
  }

  void _moisSuivant() {
    setState(() => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month + 1));
  }

  List<DateTime?> _joursGrille() {
    final premier = DateTime(_moisAffiche.year, _moisAffiche.month, 1);
    final joursDansMois = DateTime(_moisAffiche.year, _moisAffiche.month + 1, 0).day;
    final offset = premier.weekday - DateTime.monday;
    final cells = <DateTime?>[];

    for (var i = 0; i < offset; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= joursDansMois; d++) {
      cells.add(DateTime(_moisAffiche.year, _moisAffiche.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  static const _moisNoms = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  Widget build(BuildContext context) {
    final jours = _joursGrille();
    final peutReculer = DateTime(_moisAffiche.year, _moisAffiche.month, 1)
        .isAfter(DateTime(widget.firstDate.year, widget.firstDate.month, 1));
    final peutAvancer = DateTime(_moisAffiche.year, _moisAffiche.month + 1, 0)
        .isBefore(DateTime(widget.lastDate.year, widget.lastDate.month + 1, 0));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: peutReculer ? _moisPrecedent : null,
              icon: const Icon(Icons.chevron_left, color: Colors.amber),
            ),
            Expanded(
              child: Text(
                '${_moisNoms[_moisAffiche.month - 1]} ${_moisAffiche.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            IconButton(
              onPressed: peutAvancer ? _moisSuivant : null,
              icon: const Icon(Icons.chevron_right, color: Colors.amber),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: const [
            _EnteteJour('L'),
            _EnteteJour('M'),
            _EnteteJour('M'),
            _EnteteJour('J'),
            _EnteteJour('V'),
            _EnteteJour('S'),
            _EnteteJour('D'),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.15,
          ),
          itemCount: jours.length,
          itemBuilder: (_, index) {
            final jour = jours[index];
            if (jour == null) return const SizedBox.shrink();

            final selectionnee = _estSelectionnee(jour);
            final selectable = _estSelectable(jour);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: selectable ? () => widget.onToggle(jour) : null,
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectionnee
                        ? Colors.amber
                        : selectable
                            ? Colors.white.withOpacity(0.04)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: selectionnee
                        ? Border.all(color: Colors.amber.shade700, width: 1.2)
                        : Border.all(color: Colors.white12, width: 0.5),
                  ),
                  child: Text(
                    '${jour.day}',
                    style: TextStyle(
                      color: selectionnee
                          ? Colors.black
                          : selectable
                              ? Colors.white
                              : Colors.white24,
                      fontWeight: selectionnee ? FontWeight.bold : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EnteteJour extends StatelessWidget {
  const _EnteteJour(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
