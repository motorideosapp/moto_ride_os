
import 'package:flutter/material.dart';
import 'package:moto_ride_os/models/navigation.dart';

class SearchPanel extends StatefulWidget {
  final TextEditingController searchController;
  final bool isListening;
  final int voiceSearchCountdown;
  final bool hasRoute;
  final List<SearchResultItem> searchResults;
  final List<Map<String, dynamic>> recentRoutes;
  final bool isHomeSet;
  final bool isWorkSet;
  final Function(String) onSearch;
  final VoidCallback onListen;
  final VoidCallback onClearRoute;
  final Function(SearchResultItem) onSelectItem;
  final Function(Map<String, dynamic>) onSelectRecent;
  final Function(String) onFavoriteTap; // 'home' veya 'work'

  const SearchPanel({
    super.key,
    required this.searchController,
    required this.isListening,
    required this.voiceSearchCountdown,
    required this.hasRoute,
    required this.searchResults,
    required this.recentRoutes,
    required this.isHomeSet,
    required this.isWorkSet,
    required this.onSearch,
    required this.onListen,
    required this.onClearRoute,
    required this.onSelectItem,
    required this.onSelectRecent,
    required this.onFavoriteTap,
  });

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  bool _showRecentRoutes = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bool showSearchResults = widget.searchResults.isNotEmpty;
    final bool showResultsContainer = showSearchResults || _showRecentRoutes;

    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Arama çubuğu ve sonuçları (genişleyen kısım)
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widget.searchController,
                            decoration: InputDecoration(
                              hintText: widget.isListening ? 'Dinliyorum...' : 'Adres Ara...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                            ),
                            onChanged: (query) {
                              if (_showRecentRoutes) {
                                setState(() => _showRecentRoutes = false);
                              }
                              widget.onSearch(query);
                            },
                            onTap: () {
                              if (_showRecentRoutes) {
                                setState(() => _showRecentRoutes = false);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(widget.isListening ? Icons.mic_off : Icons.mic),
                          color: widget.isListening ? Colors.red : (isDarkMode ? Colors.white : Colors.black),
                          onPressed: widget.onListen,
                        ),
                        IconButton(
                          icon: const Icon(Icons.history),
                          color: isDarkMode ? Colors.white : Colors.black,
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            setState(() => _showRecentRoutes = !_showRecentRoutes);
                          },
                        ),
                        if (widget.hasRoute)
                          IconButton(icon: const Icon(Icons.close), onPressed: widget.onClearRoute)
                        else
                          IconButton(icon: const Icon(Icons.search), onPressed: () => widget.onSearch(widget.searchController.text)),
                      ],
                    ),
                  ),
                  if (showResultsContainer)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: showSearchResults
                            ? _buildSearchResultsList()
                            : _buildRecentRoutesList(),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Favori Butonları (sağda sabit kısım)
          if (widget.searchResults.isEmpty && !_showRecentRoutes)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                children: [
                  // << YENİ: Butonları arama çubuğunun altına hizalamak için boşluk >>
                  const SizedBox(height: 58.0),
                  if (widget.isHomeSet)
                    _buildFavoriteIcon(context, Icons.home, () => widget.onFavoriteTap('home')),
                  if (widget.isHomeSet && widget.isWorkSet)
                    const SizedBox(height: 8),
                  if (widget.isWorkSet)
                    _buildFavoriteIcon(context, Icons.work, () => widget.onFavoriteTap('work')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoriteIcon(BuildContext context, IconData icon, VoidCallback onPressed) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon),
        color: isDarkMode ? Colors.white : Colors.black,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: widget.searchResults.length,
      itemBuilder: (context, index) {
        final result = widget.searchResults[index];
        final placemark = result.placemark;
        final name = placemark.name ?? '';
        final street = placemark.street ?? '';
        final title = name.isNotEmpty && name != street ? name : street;
        final subtitle = [placemark.subLocality, placemark.locality, placemark.administrativeArea]
            .where((s) => s != null && s.isNotEmpty && s != title)
            .toSet()
            .join(', ');

        return ListTile(
          title: Text(title.isNotEmpty ? title : 'Bilinmeyen Konum'),
          subtitle: Text(subtitle),
          onTap: () {
            if (_showRecentRoutes) setState(() => _showRecentRoutes = false);
            widget.onSelectItem(result);
          },
        );
      },
    );
  }

  Widget _buildRecentRoutesList() {
    if (widget.recentRoutes.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Son gidilen rota bulunmuyor.'),
      ));
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: widget.recentRoutes.length,
      itemBuilder: (context, index) {
        final route = widget.recentRoutes[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(route['name'] ?? 'Bilinmeyen Konum'),
          onTap: () {
            setState(() => _showRecentRoutes = false);
            widget.onSelectRecent(route);
          },
        );
      },
    );
  }
}
