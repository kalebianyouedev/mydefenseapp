import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/order.dart';
import '../models/ticket.dart';

const _pdfPrimary = PdfColor.fromInt(0xFFE30B4C);
const _pdfInk = PdfColor.fromInt(0xFF1A1A1E);
const _pdfMuted = PdfColor.fromInt(0xFF6B6B72);
const _pdfBorder = PdfColor.fromInt(0xFFE3E3E8);

/// Génère le PDF des billets d'une commande confirmée (un billet = une
/// page, avec QR code) et propose de le partager / l'enregistrer via la
/// feuille de partage native.
class TicketPdfService {
  TicketPdfService._();
  static final TicketPdfService instance = TicketPdfService._();

  Future<File> buildPdf({required TicketOrder order, required List<Ticket> tickets}) async {
    final doc = pw.Document();
    final dateFormat = DateFormat("EEEE d MMMM y 'à' HH'h'mm", 'fr_FR');

    for (final ticket in tickets) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(28),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'BILLET',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _pdfPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.Text(
                      ticket.status.name == 'valid' ? 'Valide' : 'Utilisé',
                      style: const pw.TextStyle(fontSize: 10, color: _pdfMuted),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  ticket.eventTitle,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfInk,
                  ),
                ),
                if (ticket.seanceName != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(ticket.seanceName!,
                      style: const pw.TextStyle(fontSize: 11, color: _pdfMuted)),
                ],
                pw.SizedBox(height: 16),
                pw.Divider(color: _pdfBorder),
                pw.SizedBox(height: 16),
                if (ticket.seanceStart != null)
                  _infoRow('Date', dateFormat.format(ticket.seanceStart!)),
                if (ticket.venue.isNotEmpty || ticket.city.isNotEmpty)
                  _infoRow('Lieu', [ticket.venue, ticket.city]
                      .where((e) => e.isNotEmpty)
                      .join(', ')),
                _infoRow('Type de billet', ticket.ticketTypeName),
                _infoRow('Titulaire', ticket.buyerName),
                _infoRow('Prix', '${_formatAmount(ticket.price)} XAF'),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: ticket.code,
                        width: 130,
                        height: 130,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        ticket.code,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 3,
                          color: _pdfInk,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Divider(color: _pdfBorder),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Présentez ce QR code à l\'entrée. Commande #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                  style: const pw.TextStyle(fontSize: 9, color: _pdfMuted),
                ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/billets_${order.id}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 10, color: _pdfMuted)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _pdfInk)),
          ),
        ],
      ),
    );
  }

  String _formatAmount(num value) =>
      NumberFormat.decimalPattern('fr_FR').format(value);

  /// Génère le PDF puis ouvre la feuille de partage native (enregistrer,
  /// envoyer par mail/WhatsApp...).
  Future<void> shareTickets({required TicketOrder order, required List<Ticket> tickets}) async {
    final file = await buildPdf(order: order, tickets: tickets);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Billets — ${order.eventTitle}',
    );
  }
}
