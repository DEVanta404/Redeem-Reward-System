import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/supabase_profiles.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback? onAdminChanged;

  const AdminDashboardScreen({
    super.key,
    required this.state,
    this.onAdminChanged,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseProfilesService _service = SupabaseProfilesService();
  bool _loading = true;
  List<Promotion> _promotions = [];
  List<RewardItem> _rewards = [];
  List<DealItem> _deals = [];
  String _dealSearch = '';
  String _dealCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final promotions = await _service.getPromotions();
      final rewards = await _service.getRewards();
      if (!mounted) return;

      setState(() {
        _promotions = promotions.isNotEmpty ? promotions : List<Promotion>.from(widget.state.promotions);
        _rewards = rewards.isNotEmpty ? rewards : List<RewardItem>.from(widget.state.rewards);
        _deals = List<DealItem>.from(widget.state.deals);
        widget.state.promotions = _promotions.where((p) => p.isActive).toList();
        widget.state.rewards = _rewards.where((r) => r.isActive).toList();
        _loading = false;
      });

      widget.onAdminChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _promotions = List<Promotion>.from(widget.state.promotions);
        _rewards = List<RewardItem>.from(widget.state.rewards);
        _deals = List<DealItem>.from(widget.state.deals);
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load admin data: $error')),
      );
    }
  }

  int get _activePromotionsCount => _promotions.where((p) => p.isActive).length;
  int get _activeDealsCount => _deals.where((d) => d.isActive).length;

  List<DealItem> get _filteredDeals {
    final query = _dealSearch.trim().toLowerCase();
    final deals = _deals.where((deal) {
      final matchesQuery = query.isEmpty ||
          deal.name.toLowerCase().contains(query) ||
          deal.description.toLowerCase().contains(query) ||
          deal.category.toLowerCase().contains(query);
      final matchesCategory = _dealCategoryFilter == 'All' ||
          deal.category == _dealCategoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();

    return deals;
  }

  List<String> get _dealCategories {
    final categories = _deals.map((deal) => deal.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  Future<void> _togglePromotion(Promotion promotion) async {
    final updated = Promotion(
      id: promotion.id,
      title: promotion.title,
      subtitle: promotion.subtitle,
      validUntil: promotion.validUntil,
      color: promotion.color,
      icon: promotion.icon,
      description: promotion.description,
      imageUrl: promotion.imageUrl,
      category: promotion.category,
      isActive: !promotion.isActive,
      startDate: promotion.startDate,
      endDate: promotion.endDate,
    );

    await _service.upsertPromotion(updated);
    await _loadData();
    widget.onAdminChanged?.call();
  }

  Future<void> _toggleReward(RewardItem reward) async {
    final updated = RewardItem(
      id: reward.id,
      name: reward.name,
      pointsCost: reward.pointsCost,
      icon: reward.icon,
      description: reward.description,
      imageUrl: reward.imageUrl,
      category: reward.category,
      isActive: !reward.isActive,
      stock: reward.stock,
    );

    await _service.upsertReward(updated);
    await _loadData();
    widget.onAdminChanged?.call();
  }

  void _toggleDeal(DealItem deal) {
    setState(() {
      final index = _deals.indexWhere((item) => item.id == deal.id);
      if (index >= 0) {
        _deals[index] = _deals[index].copyWith(isActive: !_deals[index].isActive);
      }
      widget.state.deals = List<DealItem>.from(_deals);
    });
    widget.onAdminChanged?.call();
  }

  Future<void> _deletePromotion(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete promotion?'),
        content: const Text('This action cannot be undone. Do you really want to delete this promotion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _service.deletePromotion(id);
    await _loadData();
    widget.onAdminChanged?.call();
  }

  Future<void> _deleteReward(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reward?'),
        content: const Text('This action cannot be undone. Do you really want to delete this reward?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _service.deleteReward(id);
    await _loadData();
    widget.onAdminChanged?.call();
  }

  Future<void> _deleteDeal(DealItem deal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete deal?'),
        content: const Text('This action cannot be undone. Do you really want to remove this deal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deals.removeWhere((item) => item.id == deal.id);
      widget.state.deals = List<DealItem>.from(_deals);
    });
    widget.onAdminChanged?.call();
  }

  Future<void> _openPromotionEditor([Promotion? existing]) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final subtitleController = TextEditingController(text: existing?.subtitle ?? '');
    final validUntilController = TextEditingController(text: existing?.validUntil ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final categoryController = TextEditingController(text: existing?.category ?? 'general');
    String categoryValue = existing?.category ?? 'general';
    bool isActive = existing?.isActive ?? true;
    IconData selectedIcon = existing?.icon ?? Promotion.adminIconOptions.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add promotion' : 'Edit promotion'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subtitleController,
                      decoration: const InputDecoration(labelText: 'Subtitle'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: validUntilController,
                      keyboardType: TextInputType.datetime,
                      decoration: InputDecoration(
                        labelText: 'Valid until',
                        hintText: 'MM/DD/YY',
                        suffixIcon: IconButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              validUntilController.text = Promotion.formatDateForDisplay(picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<IconData>(
                      initialValue: selectedIcon,
                      decoration: const InputDecoration(labelText: 'Icon'),
                      items: Promotion.adminIconOptions
                          .map(
                            (icon) => DropdownMenuItem<IconData>(
                              value: icon,
                              child: Row(
                                children: [
                                  Icon(icon),
                                  const SizedBox(width: 8),
                                  Text(Promotion.iconLabel(icon)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedIcon = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categoryValue,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'today_drink', child: Text("Today's Drink")),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                        DropdownMenuItem(value: 'special_offer', child: Text('Special Offer')),
                        DropdownMenuItem(value: 'announcement', child: Text('Announcement')),
                        DropdownMenuItem(value: 'general', child: Text('General')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          categoryController.text = value;
                          setDialogState(() => categoryValue = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      title: const Text('Active'),
                      onChanged: (value) => setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final parsedDate = Promotion.parseDateInput(validUntilController.text.trim());
    final promotion = Promotion(
      id: existing?.id ?? '',
      title: titleController.text.trim(),
      subtitle: subtitleController.text.trim(),
      validUntil: parsedDate == null
          ? (validUntilController.text.trim().isEmpty ? 'Ongoing' : validUntilController.text.trim())
          : Promotion.formatDateForDisplay(parsedDate),
      color: existing?.color ?? const Color(0xFF2E7D32),
      icon: selectedIcon,
      description: descriptionController.text.trim(),
      imageUrl: '',
      category: categoryController.text.trim().isEmpty ? 'general' : categoryController.text.trim(),
      isActive: isActive,
      startDate: existing?.startDate,
      endDate: existing?.endDate,
    );

    try {
      await _service.upsertPromotion(promotion);
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Promotion added!' : 'Promotion updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving promotion: $error'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Promotion save error: $error');
    }
  }

  Future<void> _openRewardEditor([RewardItem? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final pointsController = TextEditingController(text: existing?.pointsCost.toString() ?? '100');
    final stockController = TextEditingController(text: existing?.stock.toString() ?? '0');
    final categoryController = TextEditingController(text: existing?.category ?? 'general');
    String categoryValue = existing?.category ?? 'general';
    bool isActive = existing?.isActive ?? true;
    IconData selectedIcon = existing?.icon ?? RewardItem(name: 'Reward', pointsCost: 100).icon;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add reward' : 'Edit reward'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Reward name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Points cost'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<IconData>(
                      initialValue: selectedIcon,
                      decoration: const InputDecoration(labelText: 'Icon'),
                      items: [
                        Icons.local_cafe,
                        Icons.coffee,
                        Icons.local_offer,
                        Icons.bakery_dining,
                        Icons.local_bar,
                        Icons.stars,
                        Icons.redeem,
                      ].map(
                        (icon) => DropdownMenuItem<IconData>(
                          value: icon,
                          child: Row(
                            children: [
                              Icon(icon),
                              const SizedBox(width: 8),
                              Text(
                                switch (icon) {
                                  Icons.local_cafe => 'Coffee',
                                  Icons.coffee => 'Espresso',
                                  Icons.local_offer => 'Gift',
                                  Icons.bakery_dining => 'Pastry',
                                  Icons.local_bar => 'Drink',
                                  Icons.stars => 'Premium',
                                  Icons.redeem => 'Voucher',
                                  _ => 'Special',
                                },
                              ),
                            ],
                          ),
                        ),
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedIcon = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: categoryValue,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'coffee', child: Text('Coffee')),
                        DropdownMenuItem(value: 'merchandise', child: Text('Merchandise')),
                        DropdownMenuItem(value: 'food', child: Text('Food')),
                        DropdownMenuItem(value: 'discount', child: Text('Discount')),
                        DropdownMenuItem(value: 'general', child: Text('General')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          categoryController.text = value;
                          setDialogState(() => categoryValue = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      title: const Text('Available'),
                      onChanged: (value) => setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final reward = RewardItem(
      id: existing?.id ?? '',
      name: nameController.text.trim(),
      description: descriptionController.text.trim(),
      pointsCost: int.tryParse(pointsController.text.trim()) ?? 100,
      imageUrl: '',
      category: categoryController.text.trim().isEmpty ? 'general' : categoryController.text.trim(),
      isActive: isActive,
      stock: int.tryParse(stockController.text.trim()) ?? 0,
      icon: selectedIcon,
    );

    try {
      await _service.upsertReward(reward);
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Reward added!' : 'Reward updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving reward: $error'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('Reward save error: $error');
    }
  }

  Future<void> _openDealEditor([DealItem? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final categoryController = TextEditingController(text: existing?.category ?? 'Seasonal');
    final badgeController = TextEditingController(text: existing?.badge ?? 'NEW');
    bool isActive = existing?.isActive ?? true;
    IconData selectedIcon = existing?.icon ?? Icons.local_cafe;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add deal' : 'Edit deal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Deal name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: badgeController,
                      decoration: const InputDecoration(labelText: 'Badge'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<IconData>(
                      initialValue: selectedIcon,
                      decoration: const InputDecoration(labelText: 'Icon'),
                      items: const [
                        DropdownMenuItem(value: Icons.local_cafe, child: Text('Coffee')),
                        DropdownMenuItem(value: Icons.local_bar, child: Text('Cold Brew')),
                        DropdownMenuItem(value: Icons.bakery_dining, child: Text('Bakery')),
                        DropdownMenuItem(value: Icons.cake, child: Text('Dessert')),
                        DropdownMenuItem(value: Icons.free_breakfast, child: Text('Breakfast')),
                        DropdownMenuItem(value: Icons.auto_awesome, child: Text('Featured')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedIcon = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      title: const Text('Active'),
                      onChanged: (value) => setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result != true) return;

    final deal = DealItem(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      description: descriptionController.text.trim(),
      category: categoryController.text.trim().isEmpty ? 'General' : categoryController.text.trim(),
      badge: badgeController.text.trim().isEmpty ? 'NEW' : badgeController.text.trim(),
      icon: selectedIcon,
      isActive: isActive,
    );

    setState(() {
      final index = _deals.indexWhere((item) => item.id == existing?.id);
      if (index >= 0) {
        _deals[index] = deal;
      } else {
        _deals.insert(0, deal);
      }
      widget.state.deals = List<DealItem>.from(_deals);
    });

    widget.onAdminChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null ? 'Deal added!' : 'Deal updated!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.state.user.isAdmin) {
      return const Scaffold(body: Center(child: Text('Access denied')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 12) / 2;
                      final cardHeight = (cardWidth * 0.72).clamp(128.0, 150.0);
                      return GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisExtent: cardHeight,
                        children: [
                      _OverviewCard(
                        label: 'Total Promotions',
                        value: _promotions.length.toString(),
                        color: const Color(0xFF7B4B3A),
                        icon: Icons.local_offer_outlined,
                      ),
                      _OverviewCard(
                        label: 'Active Promotions',
                        value: _activePromotionsCount.toString(),
                        color: const Color(0xFF2E7D32),
                        icon: Icons.check_circle_outline,
                      ),
                      _OverviewCard(
                        label: 'Total Rewards',
                        value: _rewards.length.toString(),
                        color: const Color(0xFF9A6B32),
                        icon: Icons.redeem_outlined,
                      ),
                      _OverviewCard(
                        label: 'Active Deals',
                        value: _activeDealsCount.toString(),
                        color: const Color(0xFF5D4037),
                        icon: Icons.sell_outlined,
                      ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _ManagementSection(
                    title: 'Promotions',
                    onAdd: () => _openPromotionEditor(),
                    child: _promotions.isEmpty
                        ? const _EmptyState(label: 'No promotions yet')
                        : Column(
                            children: _promotions
                                .map(
                                  (promotion) => _PromotionTile(
                                    promotion: promotion,
                                    onToggle: () => _togglePromotion(promotion),
                                    onEdit: () => _openPromotionEditor(promotion),
                                    onDelete: () => _deletePromotion(promotion.id),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                  _ManagementSection(
                    title: 'Rewards',
                    onAdd: () => _openRewardEditor(),
                    child: _rewards.isEmpty
                        ? const _EmptyState(label: 'No rewards yet')
                        : Column(
                            children: _rewards
                                .map(
                                  (reward) => _RewardTile(
                                    reward: reward,
                                    onToggle: () => _toggleReward(reward),
                                    onEdit: () => _openRewardEditor(reward),
                                    onDelete: () => _deleteReward(reward.id),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                  _ManagementSection(
                    title: 'Deals',
                    onAdd: () => _openDealEditor(),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F1E6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search, size: 18, color: Color(0xFF7B4B3A)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Search deals',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (value) => setState(() => _dealSearch = value),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _dealCategories.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final category = _dealCategories[index];
                              final selected = category == _dealCategoryFilter;
                              return ChoiceChip(
                                label: Text(category),
                                selected: selected,
                                onSelected: (_) => setState(() => _dealCategoryFilter = category),
                                selectedColor: const Color(0xFF3E2723),
                                backgroundColor: Colors.white,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: selected ? Colors.white : const Color(0xFF5D4037),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_filteredDeals.isEmpty)
                          const _EmptyState(label: 'No deals match this filter')
                        else
                          Column(
                            children: _filteredDeals
                                .map(
                                  (deal) => _DealTile(
                                    deal: deal,
                                    onToggle: () => _toggleDeal(deal),
                                    onEdit: () => _openDealEditor(deal),
                                    onDelete: () => _deleteDeal(deal),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E2723).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3E2723),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6D5B53),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementSection extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  final Widget child;

  const _ManagementSection({
    required this.title,
    required this.onAdd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9DED0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3E2723),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3E2723),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PromotionTile extends StatelessWidget {
  final Promotion promotion;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PromotionTile({
    required this.promotion,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: promotion.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(promotion.icon, color: promotion.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${promotion.subtitle} · ${promotion.category}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  promotion.validUntil,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7B4B3A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: promotion.isActive,
                activeThumbColor: const Color(0xFF2E7D32),
                onChanged: (_) => onToggle(),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  final RewardItem reward;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RewardTile({
    required this.reward,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(reward.icon, color: const Color(0xFF3E2723), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reward.pointsCost} pts • ${reward.stock} left • ${reward.category}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: reward.isActive,
                activeThumbColor: const Color(0xFF2E7D32),
                onChanged: (_) => onToggle(),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DealTile extends StatelessWidget {
  final DealItem deal;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DealTile({
    required this.deal,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF7B4B3A).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(deal.icon, color: const Color(0xFF7B4B3A), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        deal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF3E2723),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1E4D5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        deal.badge,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                          color: Color(0xFF7B4B3A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  deal.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9A6B32),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deal.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: deal.isActive,
                activeThumbColor: const Color(0xFF2E7D32),
                onChanged: (_) => onToggle(),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18)),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 18)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;

  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF8D6E63)),
      ),
    );
  }
}
