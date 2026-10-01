import 'package:flutter/material.dart';

class UserBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const UserBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFF3E2723).withValues(alpha: 0.12),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
        (states) => TextStyle(
          fontSize: 10,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: Color(0xFF3E2723)),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.star_border),
          selectedIcon: Icon(Icons.star, color: Color(0xFF3E2723)),
          label: 'Rewards',
        ),
        NavigationDestination(
          icon: Icon(Icons.redeem),
          selectedIcon: Icon(Icons.redeem, color: Color(0xFF3E2723)),
          label: 'Redeem',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_offer_outlined),
          selectedIcon: Icon(Icons.local_offer, color: Color(0xFF3E2723)),
          label: 'Deals',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history, color: Color(0xFF3E2723)),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: Color(0xFF3E2723)),
          label: 'Profile',
        ),
      ],
    );
  }
}
