import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/event.dart';
import '../models/event_category.dart';
import '../models/organisation.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../services/notification_service.dart';
import '../services/organisation_service.dart';
import '../services/profile_service.dart';
import '../welcome_screen.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/event_actions.dart';
import '../widgets/event_cover.dart';
import 'ai_assistant_screen.dart';
import 'event_detail_screen.dart';
import 'my_follows_screen.dart';
import 'notifications_screen.dart';
import 'organisation_hub_screen.dart';

TextStyle _t(double size, {FontWeight weight = FontWeight.w500, Color color = authInk}) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color);

final _money = NumberFormat.decimalPattern('fr_FR');

/// Accueil façon Ça Bouge Où ? : en-tête (logo, avatar, notifications,
/// menu), recherche, filtres par catégorie et cartes des événements.
/// Les votes restent dans leur onglet de la barre du bas.
class HomeFeed extends StatefulWidget {
  final VoidCallback onOpenAccount;

  const HomeFeed({super.key, required this.onOpenAccount});

  @override
  State<HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<HomeFeed> {
  EventCategory? _category;
  String _query = '';

  bool _matches(String text) => text.toLowerCase().contains(_query.trim().toLowerCase());

  List<Event> _filterEvents(List<Event> events) {
    final q = _query.trim();
    final filtered = events.where((e) {
      if (_category != null && e.category != _category) return false;
      if (q.isEmpty) return true;
      return _matches(e.title) ||
          _matches(e.venue) ||
          _matches(e.city) ||
          _matches(e.organisationName) ||
          _matches(e.category.label);
    }).toList();
    // Les événements boostés remontent en tête (le plus boosté d'abord) ;
    // les autres gardent l'ordre chronologique.
    final order = {for (var i = 0; i < filtered.length; i++) filtered[i].id: i};
    filtered.sort((a, b) {
      final byBoost = b.boostAmount.compareTo(a.boostAmount);
      return byBoost != 0 ? byBoost : order[a.id]!.compareTo(order[b.id]!);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Event>>(
      stream: EventService.instance.watchPublished(),
      builder: (context, snap) {
        final events = _filterEvents(snap.data ?? const []);
        final count = events.length;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onOpenAccount: widget.onOpenAccount),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    child: _SearchField(onChanged: (v) => setState(() => _query = v)),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: authBorder),
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.only(top: 14, bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoryChips(selected: _category, onSelected: (c) => setState(() => _category = c)),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$count ',
                                  style: _t(15, weight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: count > 1 ? 'événements trouvés' : 'événement trouvé',
                                  style: _t(15, color: authMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!snap.hasData)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: Color(0xFFF8FAFC),
                  child: Center(child: CircularProgressIndicator(color: authPrimary)),
                ),
              )
            else if (count == 0)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ColoredBox(
                  color: const Color(0xFFF8FAFC),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_category?.icon ?? Icons.event_busy_outlined, size: 40, color: authMuted),
                          const SizedBox(height: 10),
                          Text(
                            _category == null
                                ? 'Aucun événement pour le moment'
                                : 'Aucun événement « ${_category!.label} » pour le moment',
                            textAlign: TextAlign.center,
                            style: _t(15, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                  child: Column(
                    children: [
                      for (final e in events)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: EventCard(event: e),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// En-tête
// ---------------------------------------------------------------------

class _Header extends StatelessWidget {
  final VoidCallback onOpenAccount;

  const _Header({required this.onOpenAccount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 46,
            errorBuilder: (_, _, _) => Text(
              'Ça Bouge Où ?',
              style: _t(18, weight: FontWeight.w800, color: authPrimary),
            ),
          ),
          const Spacer(),
          _AvatarButton(onTap: onOpenAccount),
          const SizedBox(width: 12),
          const _RoundNotificationButton(),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: const Icon(Icons.menu_rounded, size: 28, color: authInk),
          ),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AvatarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return StreamBuilder<UserProfile?>(
      stream: user == null ? Stream.value(null) : ProfileService.instance.watchProfile(user.uid),
      builder: (context, snap) {
        final name = snap.data?.fullName ?? '';
        final source = name.isNotEmpty ? name : (user?.displayName ?? user?.email ?? '?');
        final photo = imageProviderFromPath(snap.data?.photoUrl);
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: authPrimary,
              image: photo != null ? DecorationImage(image: photo, fit: BoxFit.cover) : null,
              boxShadow: [
                BoxShadow(color: authPrimary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            alignment: Alignment.center,
            child: photo == null
                ? Text(
                    source.substring(0, 1).toUpperCase(),
                    style: _t(17, weight: FontWeight.w700, color: Colors.white),
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Bouton rond façon capture (à la place du thème sombre) : ouvre les
/// notifications, avec la pastille des non lues.
class _RoundNotificationButton extends StatelessWidget {
  const _RoundNotificationButton();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService.instance.watchMine(),
      builder: (context, snap) {
        final unread = (snap.data ?? const <AppNotification>[]).where((n) => !n.read).length;
        return InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: authBorder),
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 22, color: authInk),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: authAccent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: _t(10, weight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: _t(15),
      decoration: InputDecoration(
        hintText: 'Rechercher un événement…',
        hintStyle: _t(15, weight: FontWeight.w400, color: authMuted),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 12, right: 4),
          child: Icon(Icons.search_rounded, size: 22, color: authMuted),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: authBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: authBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: authPrimary, width: 1.4),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final EventCategory? selected;
  final ValueChanged<EventCategory?> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  Widget _chip(EventCategory? value, String label) {
    final active = value == selected;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSelected(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? authPrimary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? authPrimary : authBorder),
          ),
          child: Text(
            label,
            style: _t(14.5, weight: FontWeight.w500, color: active ? Colors.white : authInk),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: [_chip(null, 'Tous'), for (final c in EventCategory.values) _chip(c, c.label)],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Cartes
// ---------------------------------------------------------------------

/// Badge « Certifié » bleu clair.
class CertifiedBadge extends StatelessWidget {
  const CertifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: authPrimarySoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_outlined, size: 15, color: authPrimary),
          const SizedBox(width: 3),
          Text(
            'Certifié',
            style: _t(13, weight: FontWeight.w600, color: authPrimary),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoLine(this.icon, this.iconColor, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(13.5, weight: FontWeight.w400, color: authMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReserveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ReserveButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: authAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: _t(14.5, weight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }
}

/// Carte d'un événement sur l'accueil : grande affiche entière en haut
/// (catégorie, j'aime, partage, boost), puis titre, date, lieu, vues,
/// prix, organisateur et bouton rouge « Voir et réserver ».
class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  /// Prix minimum déjà chargés, pour ne pas relire les billets à chaque
  /// reconstruction de la liste.
  static final Map<String, Future<num?>> _minPrices = {};

  void _open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));

  String? _dateLabel() {
    final now = DateTime.now();
    final upcoming = event.seances.where((s) => s.end.isAfter(now)).toList();
    if (upcoming.length > 1) return 'Plusieurs dates';
    final seance = event.primarySeance;
    if (seance == null) return null;
    final label = DateFormat("EEE d MMM y 'à' HH'h'mm", 'fr_FR').format(seance.start);
    return label[0].toUpperCase() + label.substring(1);
  }

  void _share() {
    final date = _dateLabel();
    final place = [event.venue, event.city].where((e) => e.isNotEmpty).join(', ');
    Share.share(
      [
        event.title,
        if (date != null) '📅 $date',
        if (place.isNotEmpty) '📍 $place',
        'Réserve ta place sur Ça Bouge Où ? 🎉',
      ].join('\n'),
      subject: event.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _dateLabel();
    final place = [event.venue, event.city].where((e) => e.isNotEmpty).join(', ');
    final minPrice = event.isFree
        ? Future<num?>.value(0)
        : _minPrices.putIfAbsent(event.id, () => EventService.instance.fetchMinPrice(event.id));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: authBorder),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Affiche entière sur fond flou, comme avant.
              SizedBox(
                height: 230,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventCover(imageUrl: event.coverImageUrl),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(event.category.icon, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              event.category.label,
                              style: _t(12, weight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Row(
                        children: [
                          _LikeIcon(event: event),
                          _OverlayIcon(icon: Icons.share_outlined, onTap: _share),
                          const SizedBox(width: 4),
                          _BoostPill(event: event),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _t(17, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    if (date != null) _InfoLine(Icons.calendar_month_outlined, authPrimary, date),
                    if (place.isNotEmpty) _InfoLine(Icons.place_outlined, authAccent, place),
                    _InfoLine(
                      Icons.visibility_outlined,
                      authPrimary,
                      '${_money.format(event.views)} vue${event.views > 1 ? 's' : ''}',
                    ),
                    FutureBuilder<num?>(
                      future: minPrice,
                      builder: (context, snap) {
                        final price = snap.data;
                        if (!event.isFree && price == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            event.isFree || price == 0 ? 'Gratuit' : 'À partir de ${_money.format(price)} XAF',
                            style: _t(14.5, weight: FontWeight.w700, color: authSuccess),
                          ),
                        );
                      },
                    ),
                    if (event.organisationName.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: authPrimarySoft,
                            backgroundImage: event.organisationLogoUrl != null
                                ? NetworkImage(event.organisationLogoUrl!)
                                : null,
                            child: event.organisationLogoUrl == null
                                ? Text(
                                    event.organisationName.substring(0, 1).toUpperCase(),
                                    style: _t(14, weight: FontWeight.w800, color: authPrimary),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'par ',
                                        style: _t(13.5, weight: FontWeight.w400, color: authMuted),
                                      ),
                                      TextSpan(
                                        text: event.organisationName,
                                        style: _t(13.5, weight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                if (event.organisationCertified) const CertifiedBadge(),
                              ],
                            ),
                          ),
                          FollowOrganisationButton(
                            organisationId: event.organisationId,
                            organisationName: event.organisationName,
                            organisationLogoUrl: event.organisationLogoUrl,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ReserveButton(
                      label: event.isFree ? 'Réserver ma place' : 'Voir et réserver',
                      onPressed: () => _open(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _OverlayIcon({required this.icon, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(
          icon,
          size: 23,
          color: color,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
    );
  }
}

class _LikeIcon extends StatelessWidget {
  final Event event;

  const _LikeIcon({required this.event});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: EventService.instance.watchLiked(event.id),
      builder: (context, snap) {
        final liked = snap.data ?? false;
        return _OverlayIcon(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? const Color(0xFFFF4D6D) : Colors.white,
          onTap: () async {
            try {
              await EventService.instance.toggleLike(event);
            } catch (_) {
              if (context.mounted) showAuthSnack(context, "Impossible d'enregistrer le j'aime.");
            }
          },
        );
      },
    );
  }
}

/// Pastille ambre « ⚡ 25 » : nombre de boosts, ouvre le paiement du boost.
class _BoostPill extends StatelessWidget {
  final Event event;

  const _BoostPill({required this.event});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: authBoost,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showBoostSheet(context, event),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 18, color: authInk),
              if (event.boosts > 0) ...[
                const SizedBox(width: 2),
                Text('${event.boosts}', style: _t(13.5, weight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Menu (tiroir de droite)
// ---------------------------------------------------------------------

class HomeDrawer extends StatelessWidget {
  final ValueChanged<int> onSelectTab;

  const HomeDrawer({super.key, required this.onSelectTab});

  Widget _item(BuildContext context, IconData icon, String label, VoidCallback onTap, {Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: authPrimary),
      title: Text(label, style: _t(15, weight: FontWeight.w600)),
      trailing: trailing,
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Image.asset('assets/images/logo.png', height: 44, errorBuilder: (_, _, _) => const SizedBox()),
            ),
            if (user?.email != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(user!.email!, style: _t(13, color: authMuted)),
              ),
            const Divider(color: authBorder),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(context, Icons.home_outlined, 'Accueil', () => onSelectTab(0)),
                  _item(context, Icons.confirmation_number_outlined, 'Mes billets', () => onSelectTab(3)),
                  _item(
                    context,
                    Icons.favorite_border_rounded,
                    'Mes favoris',
                    () => _push(context, const MyFavoritesScreen()),
                  ),
                  _item(
                    context,
                    Icons.notifications_active_outlined,
                    'Mes abonnements',
                    () => _push(context, const MyFollowsScreen()),
                  ),
                  _item(
                    context,
                    Icons.notifications_none_rounded,
                    'Notifications',
                    () => _push(context, const NotificationsScreen()),
                  ),
                  _item(
                    context,
                    Icons.auto_awesome_outlined,
                    'Assistant IA',
                    () => _push(context, const AiAssistantScreen()),
                  ),
                  StreamBuilder<List<Organisation>>(
                    stream: OrganisationService.instance.watchMine(),
                    builder: (context, snap) => (snap.data ?? const []).isEmpty
                        ? const SizedBox.shrink()
                        : _item(
                            context,
                            Icons.dashboard_customize_outlined,
                            'Tableau de bord organisateur',
                            () => _push(context, const OrganisationHubScreen()),
                          ),
                  ),
                  _item(context, Icons.person_outline_rounded, 'Mon compte', () => onSelectTab(4)),
                ],
              ),
            ),
            const Divider(color: authBorder),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: authAccent),
              title: Text(
                'Se déconnecter',
                style: _t(15, weight: FontWeight.w600, color: authAccent),
              ),
              onTap: () async {
                await AuthService.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
