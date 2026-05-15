import 'package:flutter/material.dart';

void main() => runApp(const KeleganceApp());

// Configuration de l'API (à remplir avec ta clé)
class KeleganceConfig {
  static const String googleMapsApiKey = "AIzaSyCM_g7NBu0L8WZDi8SuJTyt2wiilbCvfmI"; 
}

class KeleganceApp extends StatelessWidget {
  const KeleganceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark, 
        primaryColor: Colors.amber, 
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black)
      ),
      home: const PageSalon(),
    );
  }
}

// ==========================================
// 1. PAGE SALON (ACCÈS GÉNÉRAL)
// ==========================================
class PageSalon extends StatefulWidget {
  const PageSalon({super.key});
  @override
  _PageSalonState createState() => _PageSalonState();
}

class _PageSalonState extends State<PageSalon> {
  bool _rememberMe = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, 
            colors: [Colors.black, Colors.black87]
          )
        ),
        child: Column(children: [
          const SizedBox(height: 90),
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 70),
          const Text("KÉLÉGANCE", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 6, color: Colors.amber)),
          const Text("Nouveau chez Kélégance ?", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(children: [
              _field("Email", Icons.email),
              const SizedBox(height: 15),
              _field("Mot de passe", Icons.lock, obs: true),
              Row(children: [
                Checkbox(value: _rememberMe, activeColor: Colors.amber, onChanged: (v) => setState(() => _rememberMe = v!)),
                const Text("Se souvenir de moi", style: TextStyle(fontSize: 12, color: Colors.white60)),
              ]),
              const SizedBox(height: 20),
              _btn("SE CONNECTER", Colors.amber, Colors.black, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PageClient()))),
              const SizedBox(height: 15),
              _btn("CRÉER UN COMPTE", Colors.transparent, Colors.amber, () {}, border: true),
            ]),
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PageLoginConsole())), 
            child: const Text("ACCÈS CHAUFFEUR PARTENAIRE", style: TextStyle(color: Colors.white10, fontSize: 10))
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
  Widget _field(String h, IconData i, {bool obs = false}) => TextField(obscureText: obs, decoration: InputDecoration(hintText: h, prefixIcon: Icon(i, color: Colors.amber, size: 20), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
  Widget _btn(String t, Color bg, Color tx, VoidCallback f, {bool border = false}) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: bg, minimumSize: const Size(double.infinity, 55), side: border ? const BorderSide(color: Colors.amber) : null, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: f, child: Text(t, style: TextStyle(color: tx, fontWeight: FontWeight.bold)));
}

// ==========================================
// 2. PAGE LOGIN CONDUCTEUR (SÉCURISÉE)
// ==========================================
class PageLoginConsole extends StatefulWidget {
  const PageLoginConsole({super.key});
  @override
  _PageLoginConsoleState createState() => _PageLoginConsoleState();
}

class _PageLoginConsoleState extends State<PageLoginConsole> {
  bool _rememberPro = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.amber), onPressed: () => Navigator.pop(context))),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("ESPACE\nPROFESSIONNEL", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 40),
            _fieldPro("Email ou N° de téléphone", Icons.badge),
            const SizedBox(height: 20),
            _fieldPro("Mot de passe", Icons.lock, obs: true),
            const SizedBox(height: 10),
            Row(children: [
                Checkbox(value: _rememberPro, activeColor: Colors.amber, onChanged: (v) => setState(() => _rememberPro = v!)),
                const Text("Maintenir la session professionnelle", style: TextStyle(fontSize: 12, color: Colors.white60)),
            ]),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const PageConsole())), 
              child: const Text("OUVRIR MA SESSION", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 20),
        ]),
      ),
    );
  }
  Widget _fieldPro(String h, IconData i, {bool obs = false}) => TextField(obscureText: obs, decoration: InputDecoration(hintText: h, prefixIcon: Icon(i, color: Colors.amber), enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber))));
}

// ==========================================
// 3. PAGE CLIENT (L'INTÉGRALE)
// ==========================================
class PageClient extends StatefulWidget {
  const PageClient({super.key});
  @override
  _PageClientState createState() => _PageClientState();
}

class _PageClientState extends State<PageClient> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<DateTime> _dates = [];
  TimeOfDay _time = const TimeOfDay(hour: 08, minute: 00);
  String? _dest; 
  double _price = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showHelpModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("BESOIN D'AIDE ?", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _helpTile(Icons.luggage, "Objet perdu", "Signaler un objet oublié"),
            _helpTile(Icons.gavel, "Litige ou Réclamation", "Problème avec une course"),
            _helpTile(Icons.support_agent, "Support Technique", "Problème avec l'app"),
            _helpTile(Icons.phone_forwarded, "Urgence", "Contacter mon chauffeur"),
          ],
        ),
      ),
    );
  }

  Widget _helpTile(IconData icon, String title, String subtitle) => ListTile(
    leading: Icon(icon, color: Colors.amber),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
    onTap: () => Navigator.pop(context),
  );

  @override
  Widget build(BuildContext context) {
    int totalTrips = _dates.isEmpty ? 1 : _dates.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text("ESPACE CLIENT"),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.help_outline, color: Colors.amber), onPressed: () => _showHelpModal(context))],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.add_location_alt), text: "Réserver"),
            Tab(icon: Icon(Icons.event_note), text: "Agenda"),
            Tab(icon: Icon(Icons.receipt_long), text: "Factures"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _lbl("LIEU DE DÉPART"),
              const TextField(decoration: InputDecoration(hintText: "Adresse de prise en charge", filled: true, fillColor: Colors.white10)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: ActionChip(label: Text("Heure : ${_time.format(context)}"), onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _time); if (t != null) setState(() => _time = t);
                })),
                const SizedBox(width: 10),
                Expanded(child: ActionChip(label: const Text("Ajouter Date"), avatar: const Icon(Icons.calendar_today, size: 14), onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2027));
                  if (d != null) setState(() => _dates.add(d));
                })),
              ]),
              const SizedBox(height: 20),
              _lbl("CHOISIR UN FORFAIT"),
              _buildForfaitsScroll(),
              if (_dest != null) ...[
                const SizedBox(height: 25),
                _recap(_price * totalTrips, totalTrips),
                const SizedBox(height: 15),
                _btn("CONFIRMER LA RÉSERVATION", Colors.green[800]!, Colors.white, () {}),
              ],
              const SizedBox(height: 30),
              _buildServiceIcons(),
            ]),
          ),
          _buildAgendaView(),
          _buildFacturesView(),
        ],
      ),
    );
  }

  Widget _buildAgendaView() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _lbl("MES PROCHAINES COURSES"),
      _appointmentCard("Demain - 14:30", "CDG Terminal 2F", "Confirmé", Colors.green),
      _appointmentCard("22 Mai - 05:00", "Gare de Lyon", "En attente", Colors.amber),
    ],
  );

  Widget _buildFacturesView() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      _lbl("MES DOCUMENTS"),
      _factureTile("Facture #KE-9842", "12 Mai 2026", "65.00€"),
      _factureTile("Facture #KE-9710", "08 Mai 2026", "45.00€"),
    ],
  );

  Widget _appointmentCard(String date, String lieu, String statut, Color color) => Card(
    margin: const EdgeInsets.only(bottom: 15), color: Colors.white10,
    child: ListTile(
      leading: const Icon(Icons.calendar_today, color: Colors.amber),
      title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(lieu),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Text(statut, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
    ),
  );

  Widget _factureTile(String ref, String date, String prix) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent), title: Text(ref), subtitle: Text(date), trailing: Text(prix, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), onTap: () {}),
  );

  Widget _buildForfaitsScroll() => SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
    _forfait("ORLY", 55, ["T1", "T2", "T3", "T4"]),
    _forfait("CDG", 65, ["T1", "T2", "T3", "2A", "2B", "2C", "2D", "2E", "2F", "2G"]),
    _forfait("BEAUVAIS", 120, ["T1", "T2"]),
    _forfait("GARES", 45, ["Lyon", "Nord", "Montparnasse", "Est", "Bercy", "St-Lazare", "Austerlitz"]),
  ]));

  Widget _forfait(String l, double p, List<String> z) => Container(margin: const EdgeInsets.only(right: 8), child: InkWell(
    onTap: () => showModalBottomSheet(context: context, builder: (c) => ListView(children: z.map((s) => ListTile(title: Text(s), onTap: () { setState(() { _dest = "$l ($s)"; _price = p; }); Navigator.pop(c); })).toList())),
    child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), Text("$p€", style: const TextStyle(color: Colors.amber, fontSize: 11))])))));

  Widget _recap(double t, int n) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white10, border: Border.all(color: Colors.amber), borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("$n COURSE(S)", style: const TextStyle(fontSize: 9)), Text(_dest!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
      Text("${t.toStringAsFixed(2)} €", style: const TextStyle(fontSize: 20, color: Colors.amber, fontWeight: FontWeight.bold))
    ]));

  Widget _buildServiceIcons() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _lbl("VOTRE CONFORT À BORD"),
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.spaceAround,
          children: [
            const _Svc(Icons.wifi, "WIFI 5G", isRule: false),
            const _Svc(Icons.local_drink, "EAU FRAÎCHE", isRule: false),
            const _Svc(Icons.smoke_free, "NON FUMEUR", isRule: true),
            const _Svc(Icons.vaping_rooms, "PAS DE VAPOTAGE", isRule: true),
            const _Svc(Icons.no_food, "PAS DE NOURRITURE", isRule: true),
            const _Svc(Icons.pets, "PAS D'ANIMAUX", isRule: true),
          ],
        ),
      ),
    ],
  );

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 10, top: 5), child: Text(t, style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)));
  Widget _btn(String t, Color bg, Color tx, VoidCallback f) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: bg, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: f, child: Text(t, style: TextStyle(color: tx, fontWeight: FontWeight.bold)));
}

// ==========================================
// 4. CONSOLE CONDUCTEUR
// ==========================================
class PageConsole extends StatefulWidget {
  const PageConsole({super.key});
  @override
  _PageConsoleState createState() => _PageConsoleState();
}

class _PageConsoleState extends State<PageConsole> {
  bool _isOnline = false;
  bool _hideRevenue = false;
  String _currentMissionStatus = "PLANIFIÉ"; 

  // Fonction pour afficher le carnet de commandes (Widget bas droite)
  void _showReservationsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("MES RÉSERVATIONS PLANIFIÉES", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(child: ListView(children: [
              _resItem("14:30", "Françoise", "Paris > Guyancourt"),
              _resItem("16:45", "Jean-Pierre", "Orly T4 > Neuilly"),
              _resItem("19:00", "Résa Web", "Gare de l'Est > CDG"),
              _resItem("Demain 05:00", "Françoise", "Guyancourt > Orly"),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _resItem(String h, String n, String t) => ListTile(
    leading: const Icon(Icons.access_time, color: Colors.amber, size: 20),
    title: Text(n, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    subtitle: Text(t, style: const TextStyle(fontSize: 12, color: Colors.white54)),
    trailing: Text(h, style: const TextStyle(color: Colors.amber, fontSize: 12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _drawer(),
      body: Stack(children: [
        Container(color: Colors.black, child: const Center(child: Icon(Icons.satellite_alt, size: 100, color: Colors.white10))),
        Positioned(
          top: 50, left: 15, right: 15,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu, size: 30, color: Colors.white), onPressed: () => Scaffold.of(c).openDrawer())),
            GestureDetector(
              onTap: () => setState(() => _hideRevenue = !_hideRevenue),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), 
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.amber, width: 0.5)),
                child: Column(children: [
                  const Text("JOURNALIER", style: TextStyle(fontSize: 9, color: Colors.white38)),
                  Text(_hideRevenue ? "**** €" : "485.50 €", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
                ])
              ),
            ),
            const Icon(Icons.account_circle, size: 35, color: Colors.white),
          ]),
        ),
        Positioned(
          top: 130, left: 0, right: 0, 
          child: SizedBox(
            height: 110, 
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _missionCard("14:30", "Françoise", "Paris > Guyancourt", isPriority: true),
                _missionCard("16:45", "Jean-Pierre", "Orly T4 > Neuilly"),
                _missionCard("19:00", "Résa Web", "Gare de l'Est > CDG"),
              ],
            ),
          ),
        ),
        Positioned(bottom: 50, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          const CircleAvatar(radius: 25, backgroundColor: Colors.black87, child: Icon(Icons.home, color: Colors.amber)),
          GestureDetector(
            onTap: () => setState(() => _isOnline = !_isOnline),
            child: Container(
              width: 180, height: 65, 
              decoration: BoxDecoration(color: _isOnline ? Colors.green[700] : Colors.red[900], borderRadius: BorderRadius.circular(35), boxShadow: [const BoxShadow(color: Colors.black45, blurRadius: 10)]),
              child: Center(child: Text(_isOnline ? "EN LIGNE" : "HORS LIGNE", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)))
            ),
          ),
          GestureDetector(
            onTap: _showReservationsList,
            child: const CircleAvatar(radius: 25, backgroundColor: Colors.black87, child: Icon(Icons.view_list, color: Colors.amber)),
          ),
        ])),
      ]),
    );
  }

  Widget _missionCard(String heure, String client, String trajet, {bool isPriority = false}) {
    bool onSite = isPriority && _currentMissionStatus == "SUR PLACE";
    return Container(
      width: 280, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15), border: Border.all(color: onSite ? Colors.green : Colors.amber.withOpacity(0.3), width: onSite ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: onSite ? Colors.green : Colors.amber, borderRadius: BorderRadius.circular(5)), child: Text(isPriority ? _currentMissionStatus : "PLANIFIÉ", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))),
              Text(heure, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(client, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(trajet, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _drawer() => Drawer(child: Container(color: Colors.black, child: Column(children: [
    const UserAccountsDrawerHeader(decoration: BoxDecoration(color: Colors.white10), currentAccountPicture: CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.person, color: Colors.black, size: 40)), accountName: Text("NICOLAS"), accountEmail: Text("Chauffeur Kelegance")),
    _tile(Icons.euro, "Revenus Mensuels"),
    _tile(Icons.calendar_view_week, "Revenus Hebdomadaires"),
    _tile(Icons.folder_shared, "Documents Conducteur"),
    _tile(Icons.directions_car, "Documents Véhicule"),
    const Divider(color: Colors.white10),
    _tile(Icons.group, "Mes Bras Droits"),
    _tile(Icons.person_add, "Nouveaux Chauffeurs"),
    ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Déconnexion"), onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const PageSalon()), (route) => false)),
    const Spacer(),
    _tile(Icons.settings, "Paramètres"),
    const SizedBox(height: 20),
  ])));

  Widget _tile(IconData i, String t) => ListTile(leading: Icon(i, color: Colors.amber, size: 22), title: Text(t, style: const TextStyle(fontSize: 13, color: Colors.white)));
}

class _Svc extends StatelessWidget {
  final IconData i; 
  final String t; 
  final bool isRule; 
  const _Svc(this.i, this.t, {required this.isRule});

  @override 
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    child: Column(
      children: [
        Icon(i, color: isRule ? Colors.white30 : Colors.amber, size: 26),
        const SizedBox(height: 5),
        Text(t, 
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 8, 
            fontWeight: FontWeight.bold,
            color: isRule ? Colors.white30 : Colors.white70
          )
        ),
      ],
    ),
  );
}