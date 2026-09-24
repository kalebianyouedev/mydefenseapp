import 'package:flutter/material.dart';

/// Catégorie d'un événement, choisie par l'organisateur à la création.
/// Affichée sur la fiche et utilisée comme filtre sur la page d'accueil.
/// Stockée dans Firestore sous forme de [id] (champ `category`).
enum EventCategory {
  concert('concert', 'Concert', Icons.music_note_outlined),
  festival('festival', 'Festival', Icons.celebration_outlined),
  foire('foire', 'Foire', Icons.storefront_outlined),
  culture('culture', 'Culture', Icons.palette_outlined),
  formation('formation', 'Formation', Icons.school_outlined),
  conference('conference', 'Conférence', Icons.co_present_outlined),
  business('business', 'Business', Icons.business_center_outlined),
  sport('sport', 'Sport', Icons.sports_soccer_outlined),
  piscine('piscine', 'Piscine', Icons.pool_outlined),
  tourisme('tourisme', 'Tourisme', Icons.luggage_outlined),
  gastronomie('gastronomie', 'Gastronomie', Icons.restaurant_outlined),
  religieux('religieux', 'Religieux', Icons.volunteer_activism_outlined),
  autres('autres', 'Autres', Icons.more_horiz);

  final String id;
  final String label;
  final IconData icon;

  const EventCategory(this.id, this.label, this.icon);

  /// Les anciens événements (sans catégorie) tombent dans "Autres".
  static EventCategory fromId(String? id) {
    for (final category in values) {
      if (category.id == id) return category;
    }
    return EventCategory.autres;
  }
}
