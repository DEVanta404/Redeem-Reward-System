import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/currency_formatter.dart';
import '../services/order_history_service.dart';
import '../services/sales_service.dart';
import '../services/supabase_profiles.dart';
import 'admin_orders_section.dart';
import 'admin_sales_section.dart';
import 'notifications_screen.dart';
import '../services/notifications_service.dart';
import '../widgets/notification_bell.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback? onAdminChanged;
  final Future<void> Function() onLoggedOut;
  final VoidCallback onUnauthorized;
  final Future<SalesReport> Function(SalesPeriod period)? loadSalesReport;
  final Future<List<OrderHistoryEntry>> Function({
    required String status,
    required int offset,
    String search,
    int limit,
  })?
  loadAdminOrders;
  final Future<Map<String, dynamic>> Function({
    required String orderId,
    required String newStatus,
  })?
  updateAdminOrderStatus;
  final Future<OrderPointsRate> Function()? loadOrderPointsRate;

  const AdminDashboardScreen({
    super.key,
    required this.state,
    required this.onLoggedOut,
    required this.onUnauthorized,
    this.onAdminChanged,
    this.loadSalesReport,
    this.loadAdminOrders,
    this.updateAdminOrderStatus,
    this.loadOrderPointsRate,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with WidgetsBindingObserver {
  final SupabaseProfilesService _service = SupabaseProfilesService();
  bool _loading = true;
  List<Promotion> _promotions = [];
  List<RewardItem> _rewards = [];
  List<DealItem> _deals = [];
  String _dealSearch = '';
  String _dealCategoryFilter = 'All';
  String _selectedSection = 'All';
  bool _redirecting = false;
  int _unreadNotificationCount = 0;
  int _pendingOrderCount = 0;
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _ordersChannel;
  Timer? _liveCountRefreshTimer;
  late final NotificationsService _notificationsService;
  final GlobalKey<AdminSalesSectionState> _salesSectionKey =
      GlobalKey<AdminSalesSectionState>();
  final GlobalKey<AdminOrdersSectionState> _ordersSectionKey =
      GlobalKey<AdminOrdersSectionState>();

  static const _sections = [
    'All',
    'Promotions',
    'Rewards',
    'Deals',
    'Orders',
    'Sales',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationsService = NotificationsService();
    if (widget.state.user.isAdmin) {
      _loadData();
      _refreshLiveCounts();
      _subscribeToLiveEvents();
    } else {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onUnauthorized();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveCountRefreshTimer?.cancel();
    final client = Supabase.instance.client;
    final notificationChannel = _notificationChannel;
    final ordersChannel = _ordersChannel;
    if (notificationChannel != null) client.removeChannel(notificationChannel);
    if (ordersChannel != null) client.removeChannel(ordersChannel);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLiveCounts();
      if (_selectedSection == 'Orders') {
        _ordersSectionKey.currentState?.refresh();
      }
    }
  }

  void _subscribeToLiveEvents() {
    final userId = widget.state.user.id;
    final client = Supabase.instance.client;
    _notificationChannel = client
        .channel('admin-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            if (Supabase.instance.client.auth.currentUser?.id == userId) {
              _scheduleLiveCountRefresh();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) {
            if (Supabase.instance.client.auth.currentUser?.id == userId) {
              _scheduleLiveCountRefresh();
            }
          },
        )
        .subscribe();
    _ordersChannel = client
        .channel('admin-orders-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            if (Supabase.instance.client.auth.currentUser?.id != userId) return;
            _scheduleLiveCountRefresh();
            if (!mounted) return;
            final row = payload.newRecord;
            final code = row['order_code']?.toString() ?? 'new order';
            final orderId = row['id']?.toString() ?? '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('New order $code'),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () => _openOrderFromRealtime(orderId),
                ),
              ),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (_) => _scheduleLiveCountRefresh(),
        )
        .subscribe();
  }

  void _scheduleLiveCountRefresh() {
    _liveCountRefreshTimer?.cancel();
    _liveCountRefreshTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_refreshLiveCounts()),
    );
  }

  Future<void> _refreshLiveCounts() async {
    try {
      final results = await Future.wait([
        _notificationsService.unreadCount(),
        OrderHistoryService().getPendingOrderCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = results[0];
        _pendingOrderCount = results[1];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live dashboard counts are unavailable.')),
      );
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          isAdmin: true,
          onNotificationSelected: (notification) async {
            if (notification.type != 'new_order_admin') return;
            final orderId = notification.data['order_id']?.toString() ?? '';
            if (orderId.isEmpty) return;
            setState(() => _selectedSection = 'Orders');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_openOrderById(orderId));
            });
          },
        ),
      ),
    );
    if (mounted) await _refreshLiveCounts();
  }

  void _openOrderFromRealtime(String orderId) {
    if (orderId.isEmpty) return;
    setState(() => _selectedSection = 'Orders');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openOrderById(orderId));
    });
  }

  Future<void> _openOrderById(String orderId) async {
    try {
      final opened = await _ordersSectionKey.currentState?.openOrderById(
        orderId,
      );
      if (opened == true || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order is no longer available.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open this order. Please refresh and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    try {
      final promotions = await _service.getPromotions();
      final rewards = await _service.getRewards();
      final deals = await _service.getDeals();
      if (!mounted) return;

      setState(() {
        _promotions = promotions.isNotEmpty
            ? promotions
            : List<Promotion>.from(widget.state.promotions);
        _rewards = rewards.isNotEmpty
            ? rewards
            : List<RewardItem>.from(widget.state.rewards);
        _deals = deals;
        widget.state.deals = List<DealItem>.from(_deals);
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

  Future<void> _refreshDashboard() async {
    await _loadData();
    await _ordersSectionKey.currentState?.refresh();
    await _salesSectionKey.currentState?.refresh();
  }

  int get _activePromotionsCount => _promotions.where((p) => p.isActive).length;
  int get _activeDealsCount => _deals.where((d) => d.isActive).length;

  List<DealItem> get _filteredDeals {
    final query = _dealSearch.trim().toLowerCase();
    final deals = _deals.where((deal) {
      final matchesQuery =
          query.isEmpty ||
          deal.name.toLowerCase().contains(query) ||
          deal.description.toLowerCase().contains(query) ||
          deal.category.toLowerCase().contains(query);
      final matchesCategory =
          _dealCategoryFilter == 'All' || deal.category == _dealCategoryFilter;
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

  Future<void> _toggleDeal(DealItem deal) async {
    try {
      await _service.upsertDeal(deal.copyWith(isActive: !deal.isActive));
      await _loadData();
      widget.onAdminChanged?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update deal: $error')));
    }
  }

  Future<void> _deletePromotion(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete promotion?'),
        content: const Text(
          'This action cannot be undone. Do you really want to delete this promotion?',
        ),
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
        content: const Text(
          'This action cannot be undone. Do you really want to delete this reward?',
        ),
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
        content: const Text(
          'This action cannot be undone. Do you really want to remove this deal?',
        ),
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

    try {
      await _service.deleteDeal(deal.id);
      if (!mounted) return;
      setState(() {
        _deals.removeWhere((item) => item.id == deal.id);
        widget.state.deals = List<DealItem>.from(_deals);
      });
      widget.onAdminChanged?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete deal: $error')));
    }
  }

  Future<void> _openPromotionEditor([Promotion? existing]) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final subtitleController = TextEditingController(
      text: existing?.subtitle ?? '',
    );
    final validUntilController = TextEditingController(
      text: existing?.validUntil ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final categoryController = TextEditingController(
      text: existing?.category ?? 'general',
    );
    String categoryValue = existing?.category ?? 'general';
    bool isActive = existing?.isActive ?? true;
    IconData selectedIcon = existing?.icon ?? Promotion.adminIconOptions.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add promotion' : 'Edit promotion',
              ),
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
                        DropdownMenuItem(
                          value: 'today_drink',
                          child: Text("Today's Drink"),
                        ),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                        DropdownMenuItem(
                          value: 'special_offer',
                          child: Text('Special Offer'),
                        ),
                        DropdownMenuItem(
                          value: 'announcement',
                          child: Text('Announcement'),
                        ),
                        DropdownMenuItem(
                          value: 'general',
                          child: Text('General'),
                        ),
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
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      title: const Text('Active'),
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
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

    final parsedDate = Promotion.parseDateInput(
      validUntilController.text.trim(),
    );
    final promotion = Promotion(
      id: existing?.id ?? '',
      title: titleController.text.trim(),
      subtitle: subtitleController.text.trim(),
      validUntil: parsedDate == null
          ? (validUntilController.text.trim().isEmpty
                ? 'Ongoing'
                : validUntilController.text.trim())
          : Promotion.formatDateForDisplay(parsedDate),
      color: existing?.color ?? const Color(0xFF2E7D32),
      icon: selectedIcon,
      description: descriptionController.text.trim(),
      imageUrl: '',
      category: categoryController.text.trim().isEmpty
          ? 'general'
          : categoryController.text.trim(),
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
          content: Text(
            existing == null ? 'Promotion added!' : 'Promotion updated!',
          ),
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
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final pointsController = TextEditingController(
      text: existing?.pointsCost.toString() ?? '100',
    );
    final stockController = TextEditingController(
      text: existing?.stock.toString() ?? '0',
    );
    final categoryController = TextEditingController(
      text: existing?.category ?? 'general',
    );
    String categoryValue = existing?.category ?? 'general';
    bool isActive = existing?.isActive ?? true;
    IconData selectedIcon =
        existing?.icon ?? RewardItem(name: 'Reward', pointsCost: 100).icon;

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
                      decoration: const InputDecoration(
                        labelText: 'Reward name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Points cost',
                      ),
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
                      items:
                          [
                                Icons.local_cafe,
                                Icons.coffee,
                                Icons.local_offer,
                                Icons.bakery_dining,
                                Icons.local_bar,
                                Icons.stars,
                                Icons.redeem,
                              ]
                              .map(
                                (icon) => DropdownMenuItem<IconData>(
                                  value: icon,
                                  child: Row(
                                    children: [
                                      Icon(icon),
                                      const SizedBox(width: 8),
                                      Text(switch (icon) {
                                        Icons.local_cafe => 'Coffee',
                                        Icons.coffee => 'Espresso',
                                        Icons.local_offer => 'Gift',
                                        Icons.bakery_dining => 'Pastry',
                                        Icons.local_bar => 'Drink',
                                        Icons.stars => 'Premium',
                                        Icons.redeem => 'Voucher',
                                        _ => 'Special',
                                      }),
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
                        DropdownMenuItem(
                          value: 'coffee',
                          child: Text('Coffee'),
                        ),
                        DropdownMenuItem(
                          value: 'merchandise',
                          child: Text('Merchandise'),
                        ),
                        DropdownMenuItem(value: 'food', child: Text('Food')),
                        DropdownMenuItem(
                          value: 'discount',
                          child: Text('Discount'),
                        ),
                        DropdownMenuItem(
                          value: 'general',
                          child: Text('General'),
                        ),
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
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
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
      category: categoryController.text.trim().isEmpty
          ? 'general'
          : categoryController.text.trim(),
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
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final categoryController = TextEditingController(
      text: existing?.category ?? 'Seasonal',
    );
    final priceController = TextEditingController(
      text: (existing?.price ?? 0).toStringAsFixed(2),
    );
    final badgeController = TextEditingController(
      text: existing?.badge ?? 'NEW',
    );
    String? priceError;
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
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Price',
                        prefixText: '$pesoSymbol ',
                        errorText: priceError,
                      ),
                      onChanged: (_) {
                        if (priceError != null) {
                          setDialogState(() => priceError = null);
                        }
                      },
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
                        DropdownMenuItem(
                          value: Icons.local_cafe,
                          child: Text('Coffee'),
                        ),
                        DropdownMenuItem(
                          value: Icons.local_bar,
                          child: Text('Cold Brew'),
                        ),
                        DropdownMenuItem(
                          value: Icons.bakery_dining,
                          child: Text('Bakery'),
                        ),
                        DropdownMenuItem(
                          value: Icons.cake,
                          child: Text('Dessert'),
                        ),
                        DropdownMenuItem(
                          value: Icons.free_breakfast,
                          child: Text('Breakfast'),
                        ),
                        DropdownMenuItem(
                          value: Icons.auto_awesome,
                          child: Text('Featured'),
                        ),
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
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
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
                  onPressed: () {
                    final rawPrice = priceController.text.trim();
                    final price = double.tryParse(rawPrice);
                    final valid =
                        RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(rawPrice) &&
                        price != null &&
                        price <= 1000000;
                    if (!valid) {
                      setDialogState(
                        () => priceError =
                            'Enter a price from 0 to 1,000,000 with up to 2 decimals.',
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
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
      category: categoryController.text.trim().isEmpty
          ? 'General'
          : categoryController.text.trim(),
      badge: badgeController.text.trim().isEmpty
          ? 'NEW'
          : badgeController.text.trim(),
      icon: selectedIcon,
      isActive: isActive,
      price: double.parse(priceController.text.trim()),
    );

    try {
      await _service.upsertDeal(deal);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save deal: $error')));
      return;
    }

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
      if (!_redirecting) {
        _redirecting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onUnauthorized();
        });
      }
      return const Scaffold(
        backgroundColor: Color(0xFFF5F0E8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3E2723)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        actions: [
          NotificationBell(
            unreadCount: _unreadNotificationCount,
            onPressed: _openNotifications,
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout, color: Color(0xFF3E2723)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                        final cardHeight = (cardWidth * 0.72).clamp(
                          128.0,
                          150.0,
                        );
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
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _sections.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final section = _sections[index];
                          final selected = section == _selectedSection;
                          return ChoiceChip(
                            label: section == 'Orders' && _pendingOrderCount > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Orders'),
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFC62828),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          _pendingOrderCount > 99
                                              ? '99+'
                                              : '$_pendingOrderCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(section),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedSection = section),
                            selectedColor: const Color(0xFF3E2723),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFF3E2723)
                                  : const Color(0xFFE2D8CC),
                            ),
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF5D4037),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedSection == 'All' ||
                        _selectedSection == 'Promotions')
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
                                        onToggle: () =>
                                            _togglePromotion(promotion),
                                        onEdit: () =>
                                            _openPromotionEditor(promotion),
                                        onDelete: () =>
                                            _deletePromotion(promotion.id),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    if (_selectedSection == 'All') const SizedBox(height: 20),
                    if (_selectedSection == 'All' ||
                        _selectedSection == 'Rewards')
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
                                        onDelete: () =>
                                            _deleteReward(reward.id),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    if (_selectedSection == 'All') const SizedBox(height: 20),
                    if (_selectedSection == 'All' ||
                        _selectedSection == 'Deals')
                      _ManagementSection(
                        title: 'Deals',
                        onAdd: () => _openDealEditor(),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F1E6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search,
                                    size: 18,
                                    color: Color(0xFF7B4B3A),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(
                                        hintText: 'Search deals',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) =>
                                          setState(() => _dealSearch = value),
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
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final category = _dealCategories[index];
                                  final selected =
                                      category == _dealCategoryFilter;
                                  return ChoiceChip(
                                    label: Text(category),
                                    selected: selected,
                                    onSelected: (_) => setState(
                                      () => _dealCategoryFilter = category,
                                    ),
                                    selectedColor: const Color(0xFF3E2723),
                                    backgroundColor: Colors.white,
                                    showCheckmark: false,
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF5D4037),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_filteredDeals.isEmpty)
                              const _EmptyState(
                                label: 'No deals match this filter',
                              )
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
                    if (_selectedSection == 'All') const SizedBox(height: 20),
                    if (_selectedSection == 'All' ||
                        _selectedSection == 'Orders')
                      AdminOrdersSection(
                        key: _ordersSectionKey,
                        loadOrders: widget.loadAdminOrders,
                        updateStatus: widget.updateAdminOrderStatus,
                        loadPointsRate: widget.loadOrderPointsRate,
                        onOrderUpdated: widget.onAdminChanged == null
                            ? null
                            : () async => widget.onAdminChanged?.call(),
                      ),
                    if (_selectedSection == 'All') ...[
                      const SizedBox(height: 20),
                      AdminSalesSection(
                        key: _salesSectionKey,
                        compact: true,
                        loadReport: widget.loadSalesReport,
                      ),
                    ],
                    if (_selectedSection == 'Sales')
                      AdminSalesSection(
                        key: _salesSectionKey,
                        loadReport: widget.loadSalesReport,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3E2723),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.onLoggedOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to log out: $error')));
    }
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
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
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
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
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
                  formatPeso(deal.price),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3E2723),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deal.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
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
