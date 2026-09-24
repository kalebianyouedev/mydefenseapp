import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/organisation.dart';
import '../services/organisation_service.dart';
import '../widgets/auth_widgets.dart' show authPrimary, authInk, authMuted, authBorder;
import 'create_organisation_screen.dart';
import 'organisation_hub_screen.dart';

const _orgBlue = Color(0xFF1E3A6B);

/// "Vos organisations" : liste des organisations de l'utilisateur, avec
/// création si aucune n'existe encore. [selectMode] fait que taper sur
/// une organisation (ou en créer une) renvoie ("pop") cette organisation
/// à l'écran appelant — utilisé par le raccourci de création rapide
/// (bouton "Posts").
class OrganisationsScreen extends StatelessWidget {
  final bool selectMode;

  const OrganisationsScreen({super.key, this.selectMode = false});

  Future<void> _createNew(BuildContext context) async {
    final created = await Navigator.of(context).push<Organisation>(
      MaterialPageRoute(builder: (_) => const CreateOrganisationScreen()),
    );
    if (created == null || !context.mounted) return;
    if (selectMode) {
      Navigator.of(context).pop(created);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OrganisationHubScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.chevron_left, color: authInk),
                      ),
                      Text(
                        'Organisations',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: authInk,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: IconButton.styleFrom(
                      side: const BorderSide(color: authBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.home_outlined, color: _orgBlue),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vos organisations',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: authInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gérez vos structures, événements, votes et retraits.',
                      style: GoogleFonts.nunito(fontSize: 14, color: authMuted),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _createNew(context),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(
                          'Nouvelle organisation',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: authPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    StreamBuilder<List<Organisation>>(
                      stream: OrganisationService.instance.watchMine(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: authPrimary,
                              ),
                            ),
                          );
                        }
                        final organisations = snapshot.data!;
                        if (organisations.isEmpty) {
                          return _EmptyState(
                            onCreate: () => _createNew(context),
                          );
                        }
                        return Column(
                          children: organisations
                              .map((o) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _OrganisationCard(
                                      organisation: o,
                                      onTap: selectMode
                                          ? () => Navigator.of(context).pop(o)
                                          : null,
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.apartment_outlined,
                  size: 40, color: authMuted),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune organisation',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: authInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez par créer votre première organisation.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orgBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Créer une organisation',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganisationCard extends StatelessWidget {
  final Organisation organisation;
  final VoidCallback? onTap;

  const _OrganisationCard({required this.organisation, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: authBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFF4F4F6),
                backgroundImage: organisation.logoUrl != null
                    ? NetworkImage(organisation.logoUrl!)
                    : null,
                child: organisation.logoUrl == null
                    ? const Icon(Icons.apartment_outlined, color: authMuted)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organisation.name,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: authInk,
                      ),
                    ),
                    if (organisation.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Créée le ${DateFormat.yMMMd('fr_FR').format(organisation.createdAt!)}',
                          style: GoogleFonts.nunito(
                              fontSize: 12, color: authMuted),
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: authMuted),
            ],
          ),
        ),
      ),
    );
  }
}
