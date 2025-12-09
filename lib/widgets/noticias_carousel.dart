import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class NoticiasCarousel extends StatefulWidget {
  const NoticiasCarousel({super.key});

  @override
  State<NoticiasCarousel> createState() => _NoticiasCarouselState();
}

class _NoticiasCarouselState extends State<NoticiasCarousel> {
  final List<Map<String, String>> noticias = [
    {
      "imagen":
          "https://res.cloudinary.com/dqsacd9ez/image/upload/v1761172771/images_ullfix.jpg",
      "titulo": "Campaña contra el dengue",
      "descripcion":
          "Ya comenzó la vacunación contra el dengue. Consultá a tu médico.",
    },
    {
      "imagen":
          "https://images.unsplash.com/photo-1579154204601-01588f351e67?auto=format&fit=crop&w=1200&q=80",
      "titulo": "Chequeos anuales",
      "descripcion":
          "No olvides hacerte un control clínico una vez al año.",
    },
  ];

  final PageController controller = PageController(viewportFraction: 0.9);
  int currentPage = 0;
  Timer? autoplayTimer;

  @override
  void initState() {
    super.initState();
    // 🕐 Autoplay suave cada 5 segundos
    autoplayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (controller.hasClients) {
        int nextPage = (currentPage + 1) % noticias.length;
        controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    autoplayTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: controller,
            itemCount: noticias.length,
            onPageChanged: (index) => setState(() => currentPage = index),
            itemBuilder: (context, index) {
              final noticia = noticias[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: index == currentPage ? 6 : 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Imagen principal
                      Image.network(
                        noticia["imagen"]!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFF14B8A6),
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      (progress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade300,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined,
                              color: Colors.grey, size: 40),
                        ),
                      ),

                      // Degradado inferior
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      // Glassmorphism sobre el texto
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    noticia["titulo"]!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    noticia["descripcion"]!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Indicadores de página
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(noticias.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: currentPage == index ? 12 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? const Color(0xFF14B8A6)
                    : (isDark ? Colors.white30 : Colors.black26),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
