// import 'dart:convert';
// import 'dart:js_interop';
// import 'package:flutter/material.dart';
// import 'package:get_api_toflutter/models/product/Product_response.dart';
// import 'package:get_api_toflutter/models/product/Products.dart';
// import 'package:http/http.dart' as httpClient;
// class ProductScreen extends StatefulWidget {
//   const ProductScreen({super.key});
//
//
//   @override
//   State<ProductScreen> createState() => _ProductScreenState();
// }
//
// class _ProductScreenState extends State<ProductScreen>{
//   List<Products> productList = [];
//   bool isLoading = false;
//
//   @override
//   void initState(){
//     _getAllProduct();
//     super.initState();
//   }
//
//   _getAllProduct()async{
//     setState(() {
//       isLoading=true;
//     });
//     var uri = Uri.parse("https://dummyjson.com/products");
//     var response = await httpClient.get(uri);
//     var mapResponse = jsonDecode(response.body);
//     var productResponse = ProductResponse.fromJson(mapResponse);
//     if(productResponse.products!.isNotEmpty){
//       setState(() {
//         productList =[];
//         productList.addAll(productResponse.products!);
//       });
//     }
//     setState(() {
//       isLoading = false;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context){
//     return Scaffold(
//         backgroundColor: Colors.white,
//         appBar: AppBar(
//           backgroundColor: Colors.cyan,
//           title: Text(
//             "Products",
//             style: TextStyle(color: Colors.white),
//           ),
//         ),
//         body: Container(
//           padding: EdgeInsets.only(left: 16, right: 16, top: 30),
//           child: isLoading
//               ?Center(child: CircularProgressIndicator(color: Colors.cyan,))
//               : RefreshIndicator(
//             color: Colors.white,
//             backgroundColor: Colors.cyan,
//             onRefresh: () async {
//               _getAllProduct();
//             },
//             child:  ListView.builder(
//                 itemCount: productList.length,
//                 itemBuilder: (context, index){
//                   var product = productList[index];
//                   return Container(
//                     margin: EdgeInsets.only(top: 10),
//                     decoration: BoxDecoration(
//                         color: Colors.black12,
//                         borderRadius: BorderRadius.all(Radius.circular(20))
//                     ),
//                     width: double.infinity,
//                     child: Column(
//                       children: [
//                         SizedBox(
//                           width: double.infinity,
//                           child: Image.network(
//                               "${product.thumbnail}"
//                           ),
//                         ),
//                         Container(
//                           padding: EdgeInsets.all(10),
//                           width: double.infinity,
//                           child: Text(
//                             "${product.title}",
//                             style: TextStyle(fontSize: 18),
//                           ),
//                         ),
//                         Container(
//                           padding: EdgeInsets.all(10),
//                           width: double.infinity,
//                           child: Text(
//                             "Price : \$${product.price!.toStringAsFixed(2)}",
//                             style: TextStyle(fontSize: 14),
//                           ),
//                         ),
//                         Container(
//                           padding: EdgeInsets.all(10),
//                           width: double.infinity,
//                           child: Text(
//                             "Discount : ${product.discountPercentage}%",
//                             style: TextStyle(fontSize: 14),
//                           ),
//                         ),
//                         Container(
//                           padding: EdgeInsets.all(10),
//                           width: double.infinity,
//                           child: Text(
//                             "${product.description}",
//                             style: TextStyle(fontSize: 12),
//                           ),
//                         )
//                       ],
//                     ),
//                   );
//                 }),
//           ),
//         )
//     );
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_api_toflutter/models/product/Product_response.dart';
import 'package:get_api_toflutter/models/product/Products.dart';
import 'package:get_api_toflutter/screens/product/product_detail.dart';
import 'package:http/http.dart' as httpClient;

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<Products> _allProducts = []; // all loaded products (grows page by page)
  List<Products> _filtered = []; // result after applying search filter

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int _pageSize = 15;
  int _currentSkip = 0; // how many items already fetched from API
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // ── State flags ───────────────────────────────────────────────────────────
  bool _isInitialLoading = false;

  // ── Search ────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Scroll ────────────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchProducts(reset: true);

    // Load next page when user scrolls near the bottom
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchProducts();
      }
    });

    // Re-filter whenever search text changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Networking ────────────────────────────────────────────────────────────

  Future<void> _fetchProducts({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMore && !reset)) return;

    if (reset) {
      setState(() {
        _isInitialLoading = true;
        _currentSkip = 0;
        _hasMore = true;
        _allProducts = [];
        _filtered = [];
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final uri = Uri.parse(
        'https://dummyjson.com/products?limit=$_pageSize&skip=$_currentSkip',
      );
      final response = await httpClient.get(uri);
      final mapResponse = jsonDecode(response.body) as Map<String, dynamic>;

      // DummyJSON returns { products: [...], total: N, skip: N, limit: N }
      final productResponse = ProductResponse.fromJson(mapResponse);
      final newItems = productResponse.products ?? [];
      final total = (mapResponse['total'] as num?)?.toInt() ?? 0;

      setState(() {
        _allProducts.addAll(newItems);
        _currentSkip += newItems.length;
        _hasMore = _currentSkip < total;
        _applyFilter();
      });
    } catch (e) {
      // Silently ignore; user can pull-to-refresh
      debugPrint('Error fetching products: $e');
    } finally {
      setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // ── Filter ────────────────────────────────────────────────────────────────

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_allProducts);
    } else {
      _filtered = _allProducts.where((p) {
        final title = (p.title ?? '').toLowerCase();
        final description = (p.description ?? '').toLowerCase();
        final brand = (p.brand ?? '').toLowerCase();
        return title.contains(_searchQuery) ||
            description.contains(_searchQuery) ||
            brand.contains(_searchQuery);
      }).toList();
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.cyan,
        title: const Text('Products', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // Search bar ---------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      color: Colors.cyan.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products…',
          prefixIcon: const Icon(Icons.search, color: Colors.cyan),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () => _searchController.clear(),
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.cyan.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.cyan, width: 1.5),
          ),
        ),
      ),
    );
  }

  // Body ---------------------------------------------------------------------

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyan),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'No products found.'
                  : 'No results for "$_searchQuery".',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: Colors.cyan,
      onRefresh: () => _fetchProducts(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        // +1 for the loading indicator at the bottom
        itemCount: _filtered.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filtered.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: Colors.cyan),
              ),
            );
          }
          return _buildProductCard(_filtered[index]);
        },
      ),
    );
  }

  // Product card -------------------------------------------------------------

  Widget _buildProductCard(Products product) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetail(product: product),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(20),
        ),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                width: double.infinity,
                height: 200,
                child: Image.network(
                  product.thumbnail ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                ),
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Text(
                        '\$${product.price?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(width: 10),

                      if ((product.discountPercentage ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '-${product.discountPercentage?.toStringAsFixed(
                                1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    product.description ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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