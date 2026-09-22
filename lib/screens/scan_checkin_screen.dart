import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/event.dart';
import '../models/ticket.dart';
import '../services/order_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary;

/// Scan du QR code d'un billet à l'entrée : recherche le billet par son
/// code puis le marque "utilisé". Accessible depuis le tableau de bord
/// de l'événement, bouton "Scanner".
class ScanCheckinScreen extends StatefulWidget {
  final Event event;

  const ScanCheckinScreen({super.key, required this.event});

  @override
  State<ScanCheckinScreen> createState() => _ScanCheckinScreenState();
}

class _ScanCheckinScreenState extends State<ScanCheckinScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  bool _busy = false;
  String? _lastResultMessage;
  bool? _lastResultOk;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ticket = await OrderService.instance.findTicketByCode(widget.event.id, code);
      if (ticket == null) {
        setState(() {
          _lastResultOk = false;
          _lastResultMessage = 'Billet introuvable pour cet événement.';
        });
        return;
      }
      if (ticket.status != TicketStatus.valid) {
        setState(() {
          _lastResultOk = false;
          _lastResultMessage = '${ticket.buyerName} — billet déjà ${ticket.status == TicketStatus.used ? 'scanné' : 'annulé'}.';
        });
        return;
      }
      final ok = await OrderService.instance.checkIn(ticket.id);
      setState(() {
        _lastResultOk = ok;
        _lastResultMessage = ok
            ? '${ticket.buyerName} — ${ticket.ticketTypeName} — accès autorisé.'
            : 'Échec de la validation du billet.';
      });
    } catch (_) {
      setState(() {
        _lastResultOk = false;
        _lastResultMessage = 'Erreur pendant la vérification.';
      });
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Saisir le code du billet'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Ex. AB12CD34EF'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Valider')),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) {
      await _handleCode(code.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Scanner — ${widget.event.title}', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flash_on_outlined)),
          IconButton(onPressed: _searchManually, icon: const Icon(Icons.keyboard_outlined)),
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
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_lastResultMessage != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_lastResultOk == true ? const Color(0xFF1E9E6B) : authPrimary),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(_lastResultOk == true ? Icons.check_circle_outline : Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lastResultMessage!,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
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
