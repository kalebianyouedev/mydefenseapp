import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/organisation.dart';
import '../services/organisation_service.dart';
import '../widgets/auth_widgets.dart'
    show authPrimary, authInk, authMuted, authBorder;
import 'create_organisation_screen.dart';
import 'events_list_screen.dart';
import 'organisations_screen.dart';
import 'placeholder_screen.dart';
import 'votes_screen.dart';
import 'wallet_screen.dart';

/// Petit tableau de bord d'une organisation : logo/nom/description de
/// l'organisation sélectionnée puis un menu rapide vers Événements,
/// Votes, Campagnes, Membres, Portefeuille et la liste des organisations.
/// Accessible depuis "Mon compte" et depuis l'icône à côté des
/// notifications sur l'onglet Événements.
class OrganisationHubScreen extends StatefulWidget {
  const OrganisationHubScreen({super.key});

  @override
  State<OrganisationHubScreen> createState() => _OrganisationHubScreenState();
}

class _OrganisationHubScreenState extends State<OrganisationHubScreen> {
  String? _selectedId;

  void _openPlaceholder(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Organisation organisation,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceholderScreen(
          title: title,
          icon: icon,
          message: 'Bientôt disponible pour ${organisation.name}.',
        ),
      ),
    );
  }

  Future<void> _createNew(BuildContext context) async {
    await Navigator.of(context).push<Organisation>(
      MaterialPageRoute(builder: (_) => const CreateOrganisationScreen()),
    );
  }

  void _openOrganisations(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrganisationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: authInk,
        title: Text(
          'Tableau de bord',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: authInk,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Organisation>>(
          stream: OrganisationService.instance.watchMine(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: authPrimary),
              );
            }
            final organisations = snapshot.data!;
            if (organisations.isEmpty) {
              return _EmptyHub(onCreate: () => _createNew(context));
            }

            final selected = organisations.firstWhere(
              (o) => o.id == _selectedId,
              orElse: () => organisations.first,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (organisations.length > 1) ...[
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: organisations.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final org = organisations[index];
                          final active = org.id == selected.id;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedId = org.id),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: active ? authInk : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: active ? authInk : authBorder,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                org.name,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : authMuted,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _DashboardCard(organisation: selected),
                  const SizedBox(height: 24),
                  Text(
                    'Actions rapides',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: authInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                    children: [
                      _HubTile(
                        icon: Icons.event_outlined,
                        label: 'Événements',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EventsListScreen(organisation: selected),
                          ),
                        ),
                      ),
                      _HubTile(
                        icon: Icons.how_to_vote_outlined,
                        label: 'Votes',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VotesScreen(organisation: selected),
                          ),
                        ),
                      ),
                      _HubTile(
                        icon: Icons.campaign_outlined,
                        label: 'Campagnes',
                        onTap: () => _openPlaceholder(
                          context,
                          title: 'Campagnes',
                          icon: Icons.campaign_outlined,
                          organisation: selected,
                        ),
                      ),
                      _HubTile(
                        icon: Icons.groups_outlined,
                        label: 'Membres',
                        onTap: () => _openPlaceholder(
                          context,
                          title: 'Membres',
                          icon: Icons.groups_outlined,
                          organisation: selected,
                        ),
                      ),
                      _HubTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Portefeuille',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WalletScreen(organisation: selected),
                          ),
                        ),
                      ),
                      _HubTile(
                        icon: Icons.apartment_outlined,
                        label: 'Organisations',
                        onTap: () => _openOrganisations(context),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Organisation organisation;

  const _DashboardCard({required this.organisation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: authBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
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
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: authInk,
                  ),
                ),
                if (organisation.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    organisation.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                        fontSize: 12.5, color: authMuted),
                  ),
                ],
                if (organisation.createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Créée le ${DateFormat.yMMMd('fr_FR').format(organisation.createdAt!)}',
                    style: GoogleFonts.nunito(fontSize: 11.5, color: authMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: authBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: authPrimary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: authPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: authInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHub extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyHub({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.dashboard_customize_outlined,
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
              'Créez votre organisation pour accéder à son tableau de bord (événements, votes, campagnes, membres, portefeuille...).',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 13.5, color: authMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: authPrimary,
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
