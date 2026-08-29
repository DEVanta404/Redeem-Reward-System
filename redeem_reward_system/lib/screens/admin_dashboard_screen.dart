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
        _promotions = promotions;
        _rewards = rewards;
        widget.state.promotions = promotions.where((p) => p.isActive).toList();
        widget.state.rewards = rewards.where((r) => r.isActive).toList();
        _loading = false;
      });

      widget.onAdminChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load admin data: $error')),
      );
    }
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

  Future<void> _deletePromotion(String id) async {
    await _service.deletePromotion(id);
    await _loadData();
    widget.onAdminChanged?.call();
  }

  Future<void> _deleteReward(String id) async {
    await _service.deleteReward(id);
    await _loadData();
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
                              validUntilController.text =
                                  Promotion.formatDateForDisplay(picked);
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
                        DropdownMenuItem(value: 'today_drink', child: Text('Today\'s Drink')),
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
                                switch (icon.codePoint) {
                                  0xe61d => 'Coffee',
                                  0xe87e => 'Offer',
                                  0xe7f0 => 'Bakery',
                                  0xe3a7 => 'Bar',
                                  0xe838 => 'Stars',
                                  0xe8b5 => 'Redeem',
                                  _ => 'Cafe',
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
                  _SectionHeader(
                    title: 'Promotions',
                    actionLabel: 'Add',
                    onAction: () => _openPromotionEditor(),
                  ),
                  const SizedBox(height: 12),
                  if (_promotions.isEmpty)
                    const _EmptyState(label: 'No promotions yet')
                  else
                    ..._promotions.map(
                      (promotion) => _PromotionTile(
                        promotion: promotion,
                        onToggle: () => _togglePromotion(promotion),
                        onEdit: () => _openPromotionEditor(promotion),
                        onDelete: () => _deletePromotion(promotion.id),
                      ),
                    ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: 'Rewards',
                    actionLabel: 'Add',
                    onAction: () => _openRewardEditor(),
                  ),
                  const SizedBox(height: 12),
                  if (_rewards.isEmpty)
                    const _EmptyState(label: 'No rewards yet')
                  else
                    ..._rewards.map(
                      (reward) => _RewardTile(
                        reward: reward,
                        onToggle: () => _toggleReward(reward),
                        onEdit: () => _openRewardEditor(reward),
                        onDelete: () => _deleteReward(reward.id),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add),
          label: Text(actionLabel),
        ),
      ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: const TextStyle(color: Colors.grey)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: promotion.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(promotion.icon, color: promotion.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${promotion.subtitle} · ${promotion.category}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  promotion.validUntil,
                  style: const TextStyle(color: Color(0xFF3E2723), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(value: promotion.isActive, onChanged: (_) => onToggle()),
              Row(
                children: [
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(reward.icon, color: const Color(0xFF3E2723)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reward.pointsCost} pts · ${reward.stock} left · ${reward.category}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(value: reward.isActive, onChanged: (_) => onToggle()),
              Row(
                children: [
                  IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
