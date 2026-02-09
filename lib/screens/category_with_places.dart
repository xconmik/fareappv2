import 'package:flutter/material.dart';

class CategoryWithPlaces extends StatefulWidget {
  @override
  _CategoryWithPlacesState createState() => _CategoryWithPlacesState();
}

class _CategoryWithPlacesState extends State<CategoryWithPlaces> {
  int activeIndex = 0;

  final List<Map<String, dynamic>> categories = [
    {
      "icon": Icons.fastfood,
      "label": "Food",
      "places": ["Jollibee", "McDonald's", "KFC", "Chowking"]
    },
    {
      "icon": Icons.school,
      "label": "School",
      "places": ["Wesleyan University", "NEUST", "High School A"]
    },
    {
      "icon": Icons.store,
      "label": "Mall",
      "places": ["SM Cabanatuan", "NE Pacific Mall"]
    },
    {
      "icon": Icons.local_cafe,
      "label": "Cafe",
      "places": ["Starbucks", "Bo's Coffee", "Coffee Project"]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            /// CATEGORY SECTION
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final isActive = index == activeIndex;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        activeIndex = index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isActive ? Colors.amber : Colors.grey.shade900,
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.6),
                                  blurRadius: 12,
                                )
                              ]
                            : [],
                      ),
                      child: Icon(
                        categories[index]["icon"],
                        color: isActive ? Colors.black : Colors.white,
                        size: 28,
                      ),
                    ),
                  );
                },
              ),
            ),

            /// PLACES CONTAINER
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  key: ValueKey(activeIndex),
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListView.builder(
                    itemCount:
                        categories[activeIndex]["places"].length,
                    itemBuilder: (context, index) {
                      final place =
                          categories[activeIndex]["places"][index];

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.amber),
                            const SizedBox(width: 12),
                            Text(
                              place,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
