import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'artham_theme.dart';

/// Material icons available for categories, keyed by the value stored in
/// `categories.icon_key`. The map is const so Flutter's icon tree shaking
/// keeps exactly these glyphs.
const Map<String, IconData> categoryIcons = {
  // Built-in category icons
  'trending_up': Icons.trending_up_rounded,
  'payments': Icons.payments_rounded,
  'person': Icons.person_rounded,
  'work': Icons.work_rounded,
  'sell': Icons.sell_rounded,
  'restaurant': Icons.restaurant_rounded,
  'home': Icons.home_rounded,
  'lightbulb': Icons.lightbulb_rounded,
  'directions_car': Icons.directions_car_rounded,
  'local_grocery_store': Icons.local_grocery_store_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  'flight': Icons.flight_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'health_and_safety': Icons.health_and_safety_rounded,
  'movie': Icons.movie_rounded,
  'wifi': Icons.wifi_rounded,
  'card_giftcard': Icons.card_giftcard_rounded,
  'receipt_long': Icons.receipt_long_rounded,
  'water_drop': Icons.water_drop_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'credit_card': Icons.credit_card_rounded,
  'local_atm': Icons.local_atm_rounded,
  'account_balance': Icons.account_balance_rounded,
  'currency_exchange': Icons.currency_exchange_rounded,
  'sync_alt': Icons.sync_alt_rounded,
  'request_quote': Icons.request_quote_rounded,
  'school': Icons.school_rounded,
  'category': Icons.category_rounded,

  // Extra choices for custom categories
  'local_cafe': Icons.local_cafe_rounded,
  'fastfood': Icons.fastfood_rounded,
  'local_gas_station': Icons.local_gas_station_rounded,
  'two_wheeler': Icons.two_wheeler_rounded,
  'directions_bus': Icons.directions_bus_rounded,
  'train': Icons.train_rounded,
  'local_taxi': Icons.local_taxi_rounded,
  'hotel': Icons.hotel_rounded,
  'medication': Icons.medication_rounded,
  'spa': Icons.spa_rounded,
  'child_care': Icons.child_care_rounded,
  'pets': Icons.pets_rounded,
  'checkroom': Icons.checkroom_rounded,
  'devices': Icons.devices_rounded,
  'phone_android': Icons.phone_android_rounded,
  'tv': Icons.tv_rounded,
  'sports_esports': Icons.sports_esports_rounded,
  'music_note': Icons.music_note_rounded,
  'menu_book': Icons.menu_book_rounded,
  'build': Icons.build_rounded,
  'cleaning_services': Icons.cleaning_services_rounded,
  'local_laundry_service': Icons.local_laundry_service_rounded,
  'chair': Icons.chair_rounded,
  'savings': Icons.savings_rounded,
  'volunteer_activism': Icons.volunteer_activism_rounded,
  'celebration': Icons.celebration_rounded,
  'subscriptions': Icons.subscriptions_rounded,
  'family_restroom': Icons.family_restroom_rounded,
  'park': Icons.park_rounded,
  'temple_hindu': Icons.temple_hindu_rounded,
  'mosque': Icons.mosque_rounded,
  'church': Icons.church_rounded,
  'storefront': Icons.storefront_rounded,
  'attach_money': Icons.attach_money_rounded,
  'currency_rupee': Icons.currency_rupee_rounded,
  'more_horiz': Icons.more_horiz_rounded,
};

const String fallbackCategoryIconKey = 'category';

IconData categoryIconFor(String? iconKey) =>
    categoryIcons[iconKey] ?? Icons.category_rounded;

/// Parses a `#RRGGBB` colour, falling back to lavender.
Color categoryColorFor(String? colorHex) {
  final hex = (colorHex ?? '').replaceFirst('#', '').trim();
  final value = int.tryParse(hex, radix: 16);
  if (hex.length != 6 || value == null) return ArthamColors.lavender;
  return Color(0xFF000000 | value);
}

/// A round tinted badge with a category's icon.
class CategoryIconBadge extends StatelessWidget {
  final String? iconKey;
  final String? colorHex;
  final double size;

  const CategoryIconBadge({
    super.key,
    required this.iconKey,
    required this.colorHex,
    this.size = 36,
  });

  CategoryIconBadge.forCategory(Category category, {Key? key, double size = 36})
    : this(
        key: key,
        iconKey: category.iconKey,
        colorHex: category.colorHex,
        size: size,
      );

  @override
  Widget build(BuildContext context) {
    final color = categoryColorFor(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(categoryIconFor(iconKey), color: color, size: size * 0.52),
    );
  }
}

/// A category shown as icon + name, for dropdown items and lists.
class CategoryLabel extends StatelessWidget {
  final Category category;

  const CategoryLabel({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CategoryIconBadge.forCategory(category, size: 26),
        const SizedBox(width: 10),
        Flexible(child: Text(category.name, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
