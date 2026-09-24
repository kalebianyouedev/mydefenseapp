import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/event.dart';
import '../models/ticket.dart';
import '../services/order_service.dart';

const _green = Color(0xFF1E9E6B);
const _red = Color(0xFFD32F2F);

/// Résultat d'un scan, affiché en plein écran : vert = entrée autorisée
/// (le billet vient d'être validé), rouge = refusé (faux QR code, billet
/// d'un autre événement, déjà scanné ou annulé).
class _ScanResult {
  final bool ok;
  final String title;
  final String details;

  const _ScanResult({required this.ok, required this.title, this.details = ''});
}

/// Scan du QR code d'un billet à l'entrée. Un billet valide passe au vert
/// et est marqué "utilisé" : il ne peut plus être validé une seconde fois.
/// Un QR code inconnu (faux billet) ou déjà scanné s'affiche en rouge.
/// Accessible depuis le tableau de bord de l'événement, bouton "Scanner".
class ScanCheckinScreen extends StatefulWidget {
  final Event event;

  const ScanCheckinScreen({super.key, required this.event});

  @override
  State<ScanCheckinScreen> createState() => _ScanCheckinScreenState();
}

class _ScanCheckinScreenState extends State<ScanCheckinScreen> {
  /// Durée d'affichage du résultat avant de pouvoir scanner le suivant.
  static const _resultDuration = Duration(seconds: 3);

  /// Tant que le même QR code reste devant la caméra, on ne le relit pas
  /// (sinon un billet validé en vert repasserait aussitôt en rouge
  /// "déjà scanné").
  static const _sameCodeCooldown = Duration(seconds: 8);

  final _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  bool _busy = false;
  _ScanResult? _result;
  String? _lastCode;
  DateTime? _lastCodeAt;
  int _validated = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String rawCode, {bool manual = false}) async {
    final code = rawCode.trim().toUpperCase();
    if (_busy || code.isEmpty) return;
    final now = DateTime.now();
    if (!manual &&
        code == _lastCode &&
        _lastCodeAt != null &&
        now.difference(_lastCodeAt!) < _sameCodeCooldown) {
      return;
    }
    _lastCode = code;
    _lastCodeAt = now;
    setState(() => _busy = true);

    _ScanResult result;
    try {
      result = await _verify(code);
    } catch (_) {
      result = const _ScanResult(
        ok: false,
        title: 'Vérification impossible',
        details: 'Vérifiez la connexion internet puis réessayez.',
      );
    }
    if (!mounted) return;
    if (result.ok) {
      _validated++;
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _result = result);

    await Future.delayed(_resultDuration);
    if (!mounted) return;
    setState(() {
      _result = null;
      _busy = false;
    });
  }

  Future<_ScanResult> _verify(String code) async {
    final ticket =
        await OrderService.instance.findTicketByCode(widget.event.id, code);
    if (ticket == null) {
      return const _ScanResult(
        ok: false,
        title: 'QR code invalide',
        details: 'Faux billet ou billet d\'un autre événement.',
      );
    }
    final who = '${ticket.buyerName} · ${ticket.ticketTypeName}';
    switch (ticket.status) {
      case TicketStatus.cancelled:
        return _ScanResult(ok: false, title: 'Billet annulé', details: who);
      case TicketStatus.used:
        return _alreadyUsed(ticket);
      case TicketStatus.valid:
        final ok = await OrderService.instance.checkIn(ticket.id);
        if (ok) {
          return _ScanResult(ok: true, title: 'Billet valide', details: who);
        }
        // Validé entre-temps (autre scanner) : on relit pour l'heure.
        final fresh =
            await OrderService.instance.findTicketByCode(widget.event.id, code);
        return _alreadyUsed(fresh ?? ticket);
    }
  }

  _ScanResult _alreadyUsed(Ticket ticket) {
    final at = ticket.checkedInAt;
    return _ScanResult(
      ok: false,
      title: 'Déjà scanné',
      details: [
        '${ticket.buyerName} · ${ticket.ticketTypeName}',
        if (at != null)
          "Validé le ${DateFormat("d MMM 'à' HH'h'mm", 'fr_FR').format(at)}",
      ].join('\n'),
    );
  }

  Future<void> _searchManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Saisir le code du billet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Ex. AB12CD34EF'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Valider')),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.trim().isNotEmpty) {
      await _handleCode(code, manual: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            Text('$_validated entrée${_validated > 1 ? 's' : ''} validée${_validated > 1 ? 's' : ''}',
                style: GoogleFonts.nunito(fontSize: 11.5, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flash_on_outlined)),
          IconButton(
              onPressed: _busy ? null : _searchManually,
              icon: const Icon(Icons.keyboard_outlined)),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              final value = barcodes.isEmpty ? null : barcodes.first.rawValue;
              if (value != null) _handleCode(value);
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (result == null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: Text(
                _busy ? 'Vérification…' : 'Placez le QR code du billet dans le cadre',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 13.5, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          if (result != null)
            Positioned.fill(
              child: Container(
                color: result.ok ? _green : _red,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(result.ok ? Icons.check_circle : Icons.cancel,
                        size: 120, color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      result.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    if (result.ok) ...[
                      const SizedBox(height: 4),
                      Text('Accès autorisé',
                          style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text('Accès refusé',
                          style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                    if (result.details.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        result.details,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            fontSize: 14, color: Colors.white, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
