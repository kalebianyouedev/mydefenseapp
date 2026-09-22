import 'dart:io';

import 'package:http/http.dart' as http;
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

    final coverImage = await _fetchImage(order.eventCoverImageUrl);

    for (final ticket in tickets) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Photo de couverture de l'événement (le "flyer"), pour
                // que le billet reste identifiable même partagé seul.
                if (coverImage != null)
                  pw.SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: pw.Image(coverImage, fit: pw.BoxFit.cover),
                  )
                else
                  pw.Container(height: 90, width: double.infinity, color: _pdfInk),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(28, 18, 28, 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                'ÇA BOUGE',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _pdfPrimary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              pw.SizedBox(width: 8),
                              pw.Text(
                                '· BILLET',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _pdfInk,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          pw.Text(
                            ticket.status.name == 'valid' ? 'Valide' : 'Utilisé',
                            style: const pw.TextStyle(fontSize: 10, color: _pdfMuted),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 12),
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
                      pw.SizedBox(height: 16),
                      pw.Center(
                        child: pw.Column(
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: ticket.code,
                              width: 120,
                              height: 120,
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
                      pw.SizedBox(height: 16),
                      pw.Divider(color: _pdfBorder),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Présentez ce QR code à l\'entrée. Commande #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                        style: const pw.TextStyle(fontSize: 9, color: _pdfMuted),
                      ),
                    ],
                  ),
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

  /// Télécharge une image réseau pour l'embarquer dans le PDF. Renvoie
  /// `null` en cas d'échec (réseau, URL absente) plutôt que de faire
  /// échouer toute la génération du billet.
  Future<pw.ImageProvider?> _fetchImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      return pw.MemoryImage(response.bodyBytes);
    } catch (_) {
      return null;
    }
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
